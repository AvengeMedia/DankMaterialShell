package brightness

import (
	"encoding/binary"
	"fmt"
	"math"
	"os"
	"strings"
	"syscall"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"golang.org/x/sys/unix"
)

const (
	I2C_SLAVE       = 0x0703
	DDCCI_ADDR      = 0x37
	DDCCI_VCP_GET   = 0x01
	DDCCI_VCP_SET   = 0x03
	VCP_BRIGHTNESS  = 0x10
	DDC_SOURCE_ADDR = 0x51
)

func NewDDCBackend() (*DDCBackend, error) {
	b := &DDCBackend{
		scanInterval:    30 * time.Second,
		debounceTimers:  make(map[string]*time.Timer),
		debouncePending: make(map[string]ddcPendingSet),
	}

	if err := b.scanI2CDevices(); err != nil {
		return nil, err
	}

	return b, nil
}

func (b *DDCBackend) scanI2CDevices() error {
	b.scanMutex.Lock()
	lastScan := b.lastScan
	b.scanMutex.Unlock()

	if time.Since(lastScan) < b.scanInterval {
		return nil
	}

	b.scanMutex.Lock()
	defer b.scanMutex.Unlock()

	if time.Since(b.lastScan) < b.scanInterval {
		return nil
	}

	b.devices.Range(func(key string, value *ddcDevice) bool {
		b.devices.Delete(key)
		return true
	})

	for i := 0; i < 32; i++ {
		busPath := fmt.Sprintf("/dev/i2c-%d", i)
		if _, err := os.Stat(busPath); os.IsNotExist(err) {
			continue
		}

		if isIgnorableI2CBus(i) {
			log.Debugf("Skipping ignorable i2c-%d", i)
			continue
		}

		dev, err := b.probeDDCDevice(i)
		if err != nil || dev == nil {
			continue
		}

		id := fmt.Sprintf("ddc:i2c-%d", i)
		dev.id = id
		b.devices.Store(id, dev)
		log.Debugf("found DDC device on i2c-%d", i)
	}

	b.lastScan = time.Now()

	return nil
}

func (b *DDCBackend) probeDDCDevice(bus int) (*ddcDevice, error) {
	busPath := fmt.Sprintf("/dev/i2c-%d", bus)

	fd, err := syscall.Open(busPath, syscall.O_RDWR, 0)
	if err != nil {
		return nil, err
	}
	defer syscall.Close(fd)

	if _, _, errno := syscall.Syscall(syscall.SYS_IOCTL, uintptr(fd), I2C_SLAVE, uintptr(DDCCI_ADDR)); errno != 0 {
		return nil, errno
	}

	dummy := make([]byte, 32)
	syscall.Read(fd, dummy)

	writebuf := []byte{0x00}
	n, err := syscall.Write(fd, writebuf)
	if err == nil && n == len(writebuf) {
		name := b.getDDCName(bus)
		dev := &ddcDevice{
			bus:  bus,
			addr: DDCCI_ADDR,
			name: name,
		}
		b.readInitialBrightness(fd, dev)
		return dev, nil
	}

	readbuf := make([]byte, 4)
	n, err = syscall.Read(fd, readbuf)
	if err != nil || n == 0 {
		return nil, fmt.Errorf("x37 unresponsive")
	}

	name := b.getDDCName(bus)

	dev := &ddcDevice{
		bus:  bus,
		addr: DDCCI_ADDR,
		name: name,
	}
	b.readInitialBrightness(fd, dev)
	return dev, nil
}

func (b *DDCBackend) getDDCName(bus int) string {
	sysfsPath := fmt.Sprintf("/sys/class/i2c-adapter/i2c-%d/name", bus)
	data, err := os.ReadFile(sysfsPath)
	if err != nil {
		return fmt.Sprintf("I2C-%d", bus)
	}

	name := strings.TrimSpace(string(data))
	if name == "" {
		name = fmt.Sprintf("I2C-%d", bus)
	}

	return name
}

func (b *DDCBackend) readInitialBrightness(fd int, dev *ddcDevice) {
	cap, err := b.getVCPFeature(fd, VCP_BRIGHTNESS)
	if err != nil {
		log.Debugf("failed to read initial brightness for %s: %v", dev.name, err)
		return
	}

	dev.max = cap.max
	dev.lastBrightness = cap.current
	log.Debugf("initialized %s with brightness %d/%d", dev.name, cap.current, cap.max)
}

func (b *DDCBackend) GetDevices() ([]Device, error) {
	if err := b.scanI2CDevices(); err != nil {
		log.Debugf("DDC scan error: %v", err)
	}

	devices := make([]Device, 0)

	b.devices.Range(func(id string, dev *ddcDevice) bool {
		devices = append(devices, Device{
			Class:          ClassDDC,
			ID:             id,
			Name:           dev.name,
			Current:        dev.lastBrightness,
			Max:            dev.max,
			CurrentPercent: dev.lastBrightness,
			Backend:        "ddc",
		})
		return true
	})

	return devices, nil
}

func (b *DDCBackend) SetBrightness(id string, value int, exponential bool, callback func()) error {
	return b.SetBrightnessWithExponent(id, value, exponential, 1.2, callback)
}

func (b *DDCBackend) SetBrightnessWithExponent(id string, value int, exponential bool, exponent float64, callback func()) error {
	_, ok := b.devices.Load(id)

	if !ok {
		return fmt.Errorf("device not found: %s", id)
	}

	if value < 0 {
		return fmt.Errorf("value out of range: %d", value)
	}

	b.debounceMutex.Lock()
	b.debouncePending[id] = ddcPendingSet{
		percent:  value,
		callback: callback,
	}

	if timer, exists := b.debounceTimers[id]; exists {
		timer.Reset(200 * time.Millisecond)
	} else {
		b.debounceTimers[id] = time.AfterFunc(200*time.Millisecond, func() {
			b.debounceMutex.Lock()
			pending, exists := b.debouncePending[id]
			if exists {
				delete(b.debouncePending, id)
			}
			b.debounceMutex.Unlock()

			if !exists {
				return
			}

			err := b.setBrightnessImmediateWithExponent(id, pending.percent)
			if err != nil {
				log.Debugf("Failed to set brightness for %s: %v", id, err)
			}

			if pending.callback != nil {
				pending.callback()
			}
		})
	}
	b.debounceMutex.Unlock()

	return nil
}

func (b *DDCBackend) setBrightnessImmediateWithExponent(id string, value int) error {
	dev, ok := b.devices.Load(id)

	if !ok {
		return fmt.Errorf("device not found: %s", id)
	}

	busPath := fmt.Sprintf("/dev/i2c-%d", dev.bus)

	fd, err := syscall.Open(busPath, syscall.O_RDWR, 0)
	if err != nil {
		return fmt.Errorf("open i2c device: %w", err)
	}
	defer syscall.Close(fd)

	if _, _, errno := syscall.Syscall(syscall.SYS_IOCTL, uintptr(fd), I2C_SLAVE, uintptr(dev.addr)); errno != 0 {
		return fmt.Errorf("set i2c slave addr: %w", errno)
	}

	max := dev.max
	if max == 0 {
		cap, err := b.getVCPFeature(fd, VCP_BRIGHTNESS)
		if err != nil {
			return fmt.Errorf("get current capability: %w", err)
		}
		max = cap.max
		dev.max = max
		b.devices.Store(id, dev)
	}

	if err := b.setVCPFeature(fd, VCP_BRIGHTNESS, value); err != nil {
		return fmt.Errorf("set vcp feature: %w", err)
	}

	log.Debugf("set %s to %d/%d", id, value, max)

	dev.max = max
	dev.lastBrightness = value
	b.devices.Store(id, dev)

	return nil
}

func (b *DDCBackend) getVCPFeature(fd int, vcp byte) (*ddcCapability, error) {
	for flushTry := 0; flushTry < 3; flushTry++ {
		dummy := make([]byte, 32)
		n, _ := syscall.Read(fd, dummy)
		if n == 0 {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}

	data := []byte{
		DDCCI_VCP_GET,
		vcp,
	}

	payload := []byte{
		DDC_SOURCE_ADDR,
		byte(len(data)) | 0x80,
	}
	payload = append(payload, data...)
	payload = append(payload, ddcciChecksum(payload))

	n, err := syscall.Write(fd, payload)
	if err != nil || n != len(payload) {
		return nil, fmt.Errorf("write i2c: %w", err)
	}

	time.Sleep(50 * time.Millisecond)

	pollFds := []unix.PollFd{
		{
			Fd:     int32(fd),
			Events: unix.POLLIN,
		},
	}

	pollTimeout := 200
	pollResult, err := unix.Poll(pollFds, pollTimeout)
	if err != nil {
		return nil, fmt.Errorf("poll i2c: %w", err)
	}
	if pollResult == 0 {
		return nil, fmt.Errorf("poll timeout after %dms", pollTimeout)
	}
	if pollFds[0].Revents&unix.POLLIN == 0 {
		return nil, fmt.Errorf("poll returned but POLLIN not set")
	}

	response := make([]byte, 12)
	n, err = syscall.Read(fd, response)
	if err != nil || n < 8 {
		return nil, fmt.Errorf("read i2c: %w", err)
	}

	if response[0] != 0x6E || response[2] != 0x02 {
		return nil, fmt.Errorf("invalid ddc response")
	}

	resultCode := response[3]
	if resultCode != 0x00 {
		return nil, fmt.Errorf("vcp feature not supported")
	}

	responseVCP := response[4]
	if responseVCP != vcp {
		return nil, fmt.Errorf("vcp mismatch: wanted 0x%02x, got 0x%02x", vcp, responseVCP)
	}

	maxHigh := response[6]
	maxLow := response[7]
	currentHigh := response[8]
	currentLow := response[9]

	max := int(binary.BigEndian.Uint16([]byte{maxHigh, maxLow}))
	current := int(binary.BigEndian.Uint16([]byte{currentHigh, currentLow}))

	return &ddcCapability{
		vcp:     vcp,
		max:     max,
		current: current,
	}, nil
}

func ddcciChecksum(payload []byte) byte {
	sum := byte(0x6E)
	for _, b := range payload {
		sum ^= b
	}
	return sum
}

func (b *DDCBackend) setVCPFeature(fd int, vcp byte, value int) error {
	data := []byte{
		DDCCI_VCP_SET,
		vcp,
		byte(value >> 8),
		byte(value & 0xFF),
	}

	payload := []byte{
		DDC_SOURCE_ADDR,
		byte(len(data)) | 0x80,
	}
	payload = append(payload, data...)
	payload = append(payload, ddcciChecksum(payload))

	if _, _, errno := syscall.Syscall(syscall.SYS_IOCTL, uintptr(fd), I2C_SLAVE, uintptr(DDCCI_ADDR)); errno != 0 {
		return fmt.Errorf("set i2c slave for write: %w", errno)
	}

	n, err := syscall.Write(fd, payload)
	if err != nil || n != len(payload) {
		return fmt.Errorf("write i2c: wrote %d/%d: %w", n, len(payload), err)
	}

	time.Sleep(50 * time.Millisecond)

	return nil
}

func (b *DDCBackend) percentToValue(percent int, max int, exponential bool) int {
	const minValue = 1

	if percent == 0 {
		return minValue
	}

	usableRange := max - minValue
	var value int

	if exponential {
		const exponent = 2.0
		normalizedPercent := float64(percent) / 100.0
		hardwarePercent := math.Pow(normalizedPercent, 1.0/exponent)
		value = minValue + int(math.Round(hardwarePercent*float64(usableRange)))
	} else {
		value = minValue + ((percent - 1) * usableRange / 99)
	}

	if value < minValue {
		value = minValue
	}
	if value > max {
		value = max
	}

	return value
}

func (b *DDCBackend) valueToPercent(value int, max int, exponential bool) int {
	const minValue = 1

	if max == 0 {
		return 0
	}

	if value <= minValue {
		return 1
	}

	usableRange := max - minValue
	if usableRange == 0 {
		return 100
	}

	var percent int

	if exponential {
		const exponent = 2.0
		linearPercent := 1 + ((value - minValue) * 99 / usableRange)
		normalizedLinear := float64(linearPercent) / 100.0
		expPercent := math.Pow(normalizedLinear, exponent)
		percent = int(math.Round(expPercent * 100.0))
	} else {
		percent = 1 + ((value - minValue) * 99 / usableRange)
	}

	if percent > 100 {
		percent = 100
	}
	if percent < 1 {
		percent = 1
	}

	return percent
}

func (b *DDCBackend) Close() {
}
