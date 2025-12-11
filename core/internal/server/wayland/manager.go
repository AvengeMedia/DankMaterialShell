package wayland

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"os"
	"syscall"
	"time"

	wlclient "github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
	"github.com/godbus/dbus/v5"
	"golang.org/x/sys/unix"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/errdefs"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wlr_gamma_control"
)

const animKelvinStep = 25

func NewManager(display *wlclient.Display, config Config) (*Manager, error) {
	if err := config.Validate(); err != nil {
		return nil, err
	}

	if config.ElevationTwilight == 0 {
		config.ElevationTwilight = -6.0
	}
	if config.ElevationDaylight == 0 {
		config.ElevationDaylight = 3.0
	}

	m := &Manager{
		config:        config,
		display:       display,
		ctx:           display.Context(),
		cmdq:          make(chan cmd, 128),
		stopChan:      make(chan struct{}),
		updateTrigger: make(chan struct{}, 1),
		dirty:         make(chan struct{}, 1),
		dbusSignal:    make(chan *dbus.Signal, 16),
	}

	if err := m.setupRegistry(); err != nil {
		return nil, err
	}

	if err := m.setupDBusMonitor(); err != nil {
		log.Warnf("Failed to setup D-Bus monitoring: %v", err)
	}

	m.alive = true
	m.recalcSchedule(time.Now())
	m.updateStateFromSchedule()

	m.notifierWg.Add(1)
	go m.notifier()

	m.wg.Add(1)
	go m.schedulerLoop()

	if m.dbusConn != nil {
		m.wg.Add(1)
		go m.dbusMonitor()
	}

	m.wg.Add(1)
	go m.waylandActor()

	if config.Enabled {
		m.post(func() {
			log.Info("Gamma control enabled at startup")
			gammaMgr := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1)
			if err := m.setupOutputControls(m.availableOutputs, gammaMgr); err != nil {
				log.Errorf("Failed to initialize gamma controls: %v", err)
				return
			}
			m.controlsInitialized = true
		})
	}

	return m, nil
}

func (m *Manager) post(fn func()) {
	select {
	case m.cmdq <- cmd{fn: fn}:
	default:
		log.Warn("Actor command queue full")
	}
}

func (m *Manager) waylandActor() {
	defer m.wg.Done()
	for {
		select {
		case <-m.stopChan:
			return
		case c := <-m.cmdq:
			c.fn()
		}
	}
}

func (m *Manager) allOutputsReady() bool {
	hasOutputs := false
	allReady := true
	m.outputs.Range(func(_ uint32, out *outputState) bool {
		hasOutputs = true
		if out.rampSize == 0 || out.failed {
			allReady = false
			return false
		}
		return true
	})
	return hasOutputs && allReady
}

func (m *Manager) setupDBusMonitor() error {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return fmt.Errorf("system bus: %w", err)
	}

	matchRule := "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep',path='/org/freedesktop/login1'"
	if err := conn.BusObject().Call("org.freedesktop.DBus.AddMatch", 0, matchRule).Err; err != nil {
		conn.Close()
		return fmt.Errorf("add match: %w", err)
	}

	conn.Signal(m.dbusSignal)
	m.dbusConn = conn
	return nil
}

func (m *Manager) setupRegistry() error {
	registry, err := m.display.GetRegistry()
	if err != nil {
		return fmt.Errorf("get registry: %w", err)
	}
	m.registry = registry

	outputs := make([]*wlclient.Output, 0)
	outputNames := make(map[uint32]string)
	var gammaMgr *wlr_gamma_control.ZwlrGammaControlManagerV1

	registry.SetGlobalHandler(func(e wlclient.RegistryGlobalEvent) {
		switch e.Interface {
		case wlr_gamma_control.ZwlrGammaControlManagerV1InterfaceName:
			manager := wlr_gamma_control.NewZwlrGammaControlManagerV1(m.ctx)
			version := e.Version
			if version > 1 {
				version = 1
			}
			if err := registry.Bind(e.Name, e.Interface, version, manager); err == nil {
				gammaMgr = manager
			}
		case "wl_output":
			output := wlclient.NewOutput(m.ctx)
			version := e.Version
			if version > 4 {
				version = 4
			}
			if err := registry.Bind(e.Name, e.Interface, version, output); err != nil {
				return
			}
			outputID := output.ID()
			output.SetNameHandler(func(ev wlclient.OutputNameEvent) {
				outputNames[outputID] = ev.Name
			})
			if gammaMgr != nil {
				outputs = append(outputs, output)
			}
			m.outputRegNames.Store(outputID, e.Name)

			m.configMutex.RLock()
			enabled := m.config.Enabled
			m.configMutex.RUnlock()

			if enabled && m.controlsInitialized {
				m.post(func() {
					if err := m.addOutputControl(output); err != nil {
						log.Warnf("Failed to add output control: %v", err)
					}
				})
			}
		}
	})

	registry.SetGlobalRemoveHandler(func(e wlclient.RegistryGlobalRemoveEvent) {
		m.post(func() {
			var foundID uint32
			var foundOut *outputState
			m.outputs.Range(func(id uint32, out *outputState) bool {
				if out.registryName == e.Name {
					foundID = id
					foundOut = out
					return false
				}
				return true
			})
			if foundOut == nil {
				return
			}
			if foundOut.gammaControl != nil {
				foundOut.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1).Destroy()
			}
			m.outputs.Delete(foundID)

			hasOutputs := false
			m.outputs.Range(func(_ uint32, _ *outputState) bool {
				hasOutputs = true
				return false
			})
			if !hasOutputs {
				m.controlsInitialized = false
			}
		})
	})

	if err := m.display.Roundtrip(); err != nil {
		return fmt.Errorf("roundtrip 1: %w", err)
	}
	if err := m.display.Roundtrip(); err != nil {
		return fmt.Errorf("roundtrip 2: %w", err)
	}

	if gammaMgr == nil {
		return errdefs.ErrNoGammaControl
	}
	if len(outputs) == 0 {
		return fmt.Errorf("no outputs")
	}

	physicalOutputs := make([]*wlclient.Output, 0, len(outputs))
	for _, output := range outputs {
		name := outputNames[output.ID()]
		if len(name) >= 9 && name[:9] == "HEADLESS-" {
			continue
		}
		physicalOutputs = append(physicalOutputs, output)
	}

	m.gammaControl = gammaMgr
	m.availableOutputs = physicalOutputs
	return nil
}

func (m *Manager) setupOutputControls(outputs []*wlclient.Output, manager *wlr_gamma_control.ZwlrGammaControlManagerV1) error {
	for _, output := range outputs {
		control, err := manager.GetGammaControl(output)
		if err != nil {
			continue
		}
		outputID := output.ID()
		registryName, _ := m.outputRegNames.Load(outputID)
		outState := &outputState{
			id:           outputID,
			registryName: registryName,
			output:       output,
			gammaControl: control,
		}
		m.setupControlHandlers(outState, control)
		m.outputs.Store(outputID, outState)
	}
	return nil
}

func (m *Manager) setupControlHandlers(state *outputState, control *wlr_gamma_control.ZwlrGammaControlV1) {
	control.SetGammaSizeHandler(func(e wlr_gamma_control.ZwlrGammaControlV1GammaSizeEvent) {
		if out, ok := m.outputs.Load(state.id); ok {
			out.rampSize = e.Size
			out.failed = false
			out.retryCount = 0
		}
		m.post(func() {
			m.applyCurrentTemp()
		})
	})

	control.SetFailedHandler(func(_ wlr_gamma_control.ZwlrGammaControlV1FailedEvent) {
		out, ok := m.outputs.Load(state.id)
		if !ok {
			return
		}
		out.failed = true
		out.rampSize = 0
		out.retryCount++
		out.lastFailTime = time.Now()

		backoff := time.Duration(300<<uint(min(out.retryCount-1, 4))) * time.Millisecond
		time.AfterFunc(backoff, func() {
			m.post(func() {
				m.recreateOutputControl(out)
			})
		})
	})
}

func (m *Manager) addOutputControl(output *wlclient.Output) error {
	outputID := output.ID()
	gammaMgr := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1)

	control, err := gammaMgr.GetGammaControl(output)
	if err != nil {
		return err
	}

	registryName, _ := m.outputRegNames.Load(outputID)
	outState := &outputState{
		id:           outputID,
		registryName: registryName,
		output:       output,
		gammaControl: control,
	}
	m.setupControlHandlers(outState, control)
	m.outputs.Store(outputID, outState)
	return nil
}

func (m *Manager) recreateOutputControl(out *outputState) error {
	m.configMutex.RLock()
	enabled := m.config.Enabled
	m.configMutex.RUnlock()

	if !enabled || !m.controlsInitialized {
		return nil
	}
	if _, ok := m.outputs.Load(out.id); !ok {
		return nil
	}
	if out.isVirtual {
		return nil
	}
	if out.retryCount >= 10 {
		return nil
	}

	gammaMgr, ok := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1)
	if !ok {
		return fmt.Errorf("no gamma manager")
	}

	control, err := gammaMgr.GetGammaControl(out.output)
	if err != nil {
		return err
	}

	m.setupControlHandlers(out, control)
	out.gammaControl = control
	out.failed = false
	return nil
}

func (m *Manager) recalcSchedule(now time.Time) {
	m.configMutex.RLock()
	config := m.config
	m.configMutex.RUnlock()

	m.scheduleMutex.Lock()
	defer m.scheduleMutex.Unlock()

	dayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	alreadyValid := !m.schedule.times.Sunrise.IsZero()
	if m.schedule.calcDay.Equal(dayStart) && alreadyValid {
		return
	}

	var times SunTimes
	var cond SunCondition

	if config.ManualSunrise != nil && config.ManualSunset != nil {
		dur := time.Hour
		if config.ManualDuration != nil {
			dur = *config.ManualDuration
		}
		sunrise := time.Date(now.Year(), now.Month(), now.Day(),
			config.ManualSunrise.Hour(), config.ManualSunrise.Minute(), config.ManualSunrise.Second(), 0, now.Location())
		sunset := time.Date(now.Year(), now.Month(), now.Day(),
			config.ManualSunset.Hour(), config.ManualSunset.Minute(), config.ManualSunset.Second(), 0, now.Location())
		times = SunTimes{
			Dawn:    sunrise.Add(-dur),
			Sunrise: sunrise,
			Sunset:  sunset,
			Night:   sunset.Add(dur),
		}
		cond = SunNormal
	} else {
		lat, lon := m.getLocation()
		if lat == nil || lon == nil {
			m.gammaState = StateStatic
			return
		}
		times, cond = CalculateSunTimesWithTwilight(*lat, *lon, now, config.ElevationTwilight, config.ElevationDaylight)
	}

	m.schedule.calcDay = dayStart
	m.schedule.times = times
	m.schedule.condition = cond

	switch cond {
	case SunNormal:
		m.gammaState = StateNormal
		tempDiff := config.HighTemp - config.LowTemp
		if tempDiff > 0 {
			dawnDur := times.Sunrise.Sub(times.Dawn)
			nightDur := times.Night.Sub(times.Sunset)
			m.schedule.dawnStepTime = time.Duration(max(1, int(dawnDur.Seconds())*animKelvinStep/tempDiff)) * time.Second
			m.schedule.nightStepTime = time.Duration(max(1, int(nightDur.Seconds())*animKelvinStep/tempDiff)) * time.Second
		}
	case SunMidnightSun:
		m.gammaState = StateStatic
	case SunPolarNight:
		m.gammaState = StateStatic
	}
}

func (m *Manager) getLocation() (*float64, *float64) {
	m.configMutex.RLock()
	config := m.config
	m.configMutex.RUnlock()

	if config.Latitude != nil && config.Longitude != nil {
		return config.Latitude, config.Longitude
	}
	if config.UseIPLocation {
		m.locationMutex.RLock()
		if m.cachedIPLat != nil && m.cachedIPLon != nil {
			lat, lon := m.cachedIPLat, m.cachedIPLon
			m.locationMutex.RUnlock()
			return lat, lon
		}
		m.locationMutex.RUnlock()

		lat, lon, err := FetchIPLocation()
		if err != nil {
			return nil, nil
		}
		m.locationMutex.Lock()
		m.cachedIPLat = lat
		m.cachedIPLon = lon
		m.locationMutex.Unlock()
		return lat, lon
	}
	return nil, nil
}

func (m *Manager) hasValidSchedule() bool {
	m.scheduleMutex.RLock()
	defer m.scheduleMutex.RUnlock()
	return !m.schedule.times.Sunrise.IsZero()
}

func (m *Manager) getSunPosition(now time.Time) float64 {
	m.scheduleMutex.RLock()
	sched := m.schedule
	state := m.gammaState
	m.scheduleMutex.RUnlock()

	if sched.times.Sunrise.IsZero() {
		return 1.0
	}

	switch state {
	case StateStatic:
		if sched.condition == SunMidnightSun {
			return 1.0
		}
		return 0.0
	case StateNormal:
		return m.getSunPositionNormal(now, sched.times)
	}
	return 1.0
}

func (m *Manager) getSunPositionNormal(now time.Time, times SunTimes) float64 {
	if now.Before(times.Dawn) {
		return 0.0
	}
	if now.Before(times.Sunrise) {
		return interpolate(now, times.Dawn, times.Sunrise)
	}
	if now.Before(times.Sunset) {
		return 1.0
	}
	if now.Before(times.Night) {
		return interpolate(now, times.Night, times.Sunset)
	}
	return 0.0
}

func interpolate(now time.Time, start, stop time.Time) float64 {
	if start.Equal(stop) {
		return 1.0
	}
	pos := float64(now.Sub(start)) / float64(stop.Sub(start))
	switch {
	case pos > 1.0:
		return 1.0
	case pos < 0.0:
		return 0.0
	default:
		return pos
	}
}

func (m *Manager) getTempFromPosition(pos float64) int {
	m.configMutex.RLock()
	low, high := m.config.LowTemp, m.config.HighTemp
	m.configMutex.RUnlock()
	return low + int(float64(high-low)*pos)
}

func (m *Manager) getNextDeadline(now time.Time) time.Time {
	m.scheduleMutex.RLock()
	sched := m.schedule
	state := m.gammaState
	m.scheduleMutex.RUnlock()

	switch state {
	case StateStatic:
		return m.tomorrow(now)
	case StateNormal:
		return m.getDeadlineNormal(now, sched)
	}
	return m.tomorrow(now)
}

func (m *Manager) getDeadlineNormal(now time.Time, sched sunSchedule) time.Time {
	times := sched.times
	switch {
	case now.Before(times.Dawn):
		return times.Dawn
	case now.Before(times.Sunrise):
		return now.Add(sched.dawnStepTime)
	case now.Before(times.Sunset):
		return times.Sunset
	case now.Before(times.Night):
		return now.Add(sched.nightStepTime)
	default:
		return m.tomorrowDawn(now)
	}
}

func (m *Manager) tomorrowDawn(now time.Time) time.Time {
	tomorrow := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, now.Location())

	m.configMutex.RLock()
	config := m.config
	m.configMutex.RUnlock()

	if config.ManualSunrise != nil {
		dur := time.Hour
		if config.ManualDuration != nil {
			dur = *config.ManualDuration
		}
		return time.Date(tomorrow.Year(), tomorrow.Month(), tomorrow.Day(),
			config.ManualSunrise.Hour(), config.ManualSunrise.Minute(), config.ManualSunrise.Second(), 0, tomorrow.Location()).Add(-dur)
	}

	lat, lon := m.getLocation()
	if lat == nil || lon == nil {
		return tomorrow
	}

	times, cond := CalculateSunTimesWithTwilight(*lat, *lon, tomorrow, config.ElevationTwilight, config.ElevationDaylight)
	if cond != SunNormal {
		return tomorrow
	}
	return times.Dawn
}

func (m *Manager) tomorrow(now time.Time) time.Time {
	return time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, now.Location())
}

func (m *Manager) schedulerLoop() {
	defer m.wg.Done()

	m.configMutex.RLock()
	enabled := m.config.Enabled
	m.configMutex.RUnlock()

	if enabled {
		m.applyCurrentTemp()
	}

	var timer *time.Timer
	for {
		m.configMutex.RLock()
		enabled := m.config.Enabled
		m.configMutex.RUnlock()

		now := time.Now()
		m.recalcSchedule(now)

		var waitDur time.Duration
		if enabled {
			deadline := m.getNextDeadline(now)
			waitDur = time.Until(deadline)
			if waitDur < time.Second {
				waitDur = time.Second
			}
		} else {
			waitDur = 24 * time.Hour
		}

		if timer != nil {
			timer.Stop()
		}
		timer = time.NewTimer(waitDur)

		select {
		case <-m.stopChan:
			timer.Stop()
			return
		case <-m.updateTrigger:
			timer.Stop()
			m.scheduleMutex.Lock()
			m.schedule.calcDay = time.Time{}
			m.scheduleMutex.Unlock()
			m.recalcSchedule(time.Now())
			m.configMutex.RLock()
			enabled := m.config.Enabled
			m.configMutex.RUnlock()
			if enabled {
				m.applyCurrentTemp()
			}
		case <-timer.C:
			m.configMutex.RLock()
			enabled := m.config.Enabled
			m.configMutex.RUnlock()
			if enabled {
				m.applyCurrentTemp()
			}
		}
	}
}

func (m *Manager) applyCurrentTemp() {
	if !m.controlsInitialized || !m.allOutputsReady() {
		return
	}

	m.configMutex.RLock()
	low, high := m.config.LowTemp, m.config.HighTemp
	m.configMutex.RUnlock()

	if low == high {
		m.applyGamma(low)
		m.updateStateFromSchedule()
		return
	}

	if !m.hasValidSchedule() {
		m.updateStateFromSchedule()
		return
	}

	now := time.Now()
	pos := m.getSunPosition(now)
	temp := m.getTempFromPosition(pos)

	m.applyGamma(temp)
	m.updateStateFromSchedule()
}

func (m *Manager) applyGamma(temp int) {
	m.configMutex.RLock()
	gamma := m.config.Gamma
	m.configMutex.RUnlock()

	if !m.controlsInitialized {
		return
	}

	var outs []*outputState
	m.outputs.Range(func(_ uint32, out *outputState) bool {
		outs = append(outs, out)
		return true
	})
	if len(outs) == 0 {
		return
	}

	type job struct {
		out  *outputState
		data []byte
	}
	var jobs []job

	for _, out := range outs {
		if out.failed || out.rampSize == 0 {
			continue
		}
		ramp := GenerateGammaRamp(out.rampSize, temp, gamma)
		buf := bytes.NewBuffer(make([]byte, 0, int(out.rampSize)*6))
		for _, v := range ramp.Red {
			binary.Write(buf, binary.LittleEndian, v)
		}
		for _, v := range ramp.Green {
			binary.Write(buf, binary.LittleEndian, v)
		}
		for _, v := range ramp.Blue {
			binary.Write(buf, binary.LittleEndian, v)
		}
		jobs = append(jobs, job{out: out, data: buf.Bytes()})
	}

	for _, j := range jobs {
		if err := m.setGammaBytes(j.out, j.data); err != nil {
			j.out.failed = true
			j.out.rampSize = 0
			outID := j.out.id
			time.AfterFunc(300*time.Millisecond, func() {
				m.post(func() {
					if out, ok := m.outputs.Load(outID); ok && out.failed {
						m.recreateOutputControl(out)
					}
				})
			})
		}
	}
}

func (m *Manager) setGammaBytes(out *outputState, data []byte) error {
	fd, err := MemfdCreate("gamma-ramp", 0)
	if err != nil {
		return err
	}
	defer syscall.Close(fd)

	if err := syscall.Ftruncate(fd, int64(len(data))); err != nil {
		return err
	}

	dupFd, err := syscall.Dup(fd)
	if err != nil {
		return err
	}
	f := os.NewFile(uintptr(dupFd), "gamma")
	defer f.Close()

	if _, err := f.Write(data); err != nil {
		return err
	}
	syscall.Seek(fd, 0, 0)

	ctrl := out.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1)
	return ctrl.SetGamma(fd)
}

func (m *Manager) updateStateFromSchedule() {
	now := time.Now()

	m.configMutex.RLock()
	config := m.config
	m.configMutex.RUnlock()

	m.scheduleMutex.RLock()
	times := m.schedule.times
	m.scheduleMutex.RUnlock()

	var pos float64
	var temp int
	var isDay bool
	var deadline time.Time

	if times.Sunrise.IsZero() {
		pos = 1.0
		temp = config.HighTemp
		isDay = true
		deadline = m.tomorrow(now)
	} else {
		pos = m.getSunPosition(now)
		temp = m.getTempFromPosition(pos)
		deadline = m.getNextDeadline(now)
		isDay = now.After(times.Sunrise) && now.Before(times.Sunset)
	}

	newState := State{
		Config:         config,
		CurrentTemp:    temp,
		NextTransition: deadline,
		SunriseTime:    times.Sunrise,
		SunsetTime:     times.Sunset,
		DawnTime:       times.Dawn,
		NightTime:      times.Night,
		IsDay:          isDay,
		SunPosition:    pos,
	}

	m.stateMutex.Lock()
	m.state = &newState
	m.stateMutex.Unlock()

	m.notifySubscribers()
}

func (m *Manager) notifier() {
	defer m.notifierWg.Done()
	const minGap = 100 * time.Millisecond
	timer := time.NewTimer(minGap)
	timer.Stop()
	var pending bool

	for {
		select {
		case <-m.stopChan:
			timer.Stop()
			return
		case <-m.dirty:
			if pending {
				continue
			}
			pending = true
			timer.Reset(minGap)
		case <-timer.C:
			if !pending {
				continue
			}
			currentState := m.GetState()
			if m.lastNotified != nil && !stateChanged(m.lastNotified, &currentState) {
				pending = false
				continue
			}
			m.subscribers.Range(func(_ string, ch chan State) bool {
				select {
				case ch <- currentState:
				default:
				}
				return true
			})
			stateCopy := currentState
			m.lastNotified = &stateCopy
			pending = false
		}
	}
}

func (m *Manager) dbusMonitor() {
	defer m.wg.Done()
	for {
		select {
		case <-m.stopChan:
			return
		case sig := <-m.dbusSignal:
			if sig == nil {
				continue
			}
			m.handleDBusSignal(sig)
		}
	}
}

func (m *Manager) handleDBusSignal(sig *dbus.Signal) {
	if sig.Name != "org.freedesktop.login1.Manager.PrepareForSleep" {
		return
	}
	if len(sig.Body) == 0 {
		return
	}
	preparing, ok := sig.Body[0].(bool)
	if !ok {
		return
	}
	if preparing {
		return
	}
	m.configMutex.RLock()
	enabled := m.config.Enabled
	m.configMutex.RUnlock()
	if enabled {
		m.triggerUpdate()
	}
}

func (m *Manager) triggerUpdate() {
	select {
	case m.updateTrigger <- struct{}{}:
	default:
	}
}

func (m *Manager) SetConfig(config Config) error {
	if err := config.Validate(); err != nil {
		return err
	}
	m.configMutex.Lock()
	m.config = config
	m.configMutex.Unlock()
	m.triggerUpdate()
	return nil
}

func (m *Manager) SetTemperature(low, high int) error {
	m.configMutex.Lock()
	m.config.LowTemp = low
	m.config.HighTemp = high
	err := m.config.Validate()
	m.configMutex.Unlock()
	if err != nil {
		return err
	}
	m.triggerUpdate()
	return nil
}

func (m *Manager) SetLocation(lat, lon float64) error {
	m.configMutex.Lock()
	m.config.Latitude = &lat
	m.config.Longitude = &lon
	m.config.UseIPLocation = false
	err := m.config.Validate()
	m.configMutex.Unlock()
	if err != nil {
		return err
	}
	m.triggerUpdate()
	return nil
}

func (m *Manager) SetUseIPLocation(use bool) {
	m.configMutex.Lock()
	m.config.UseIPLocation = use
	if use {
		m.config.Latitude = nil
		m.config.Longitude = nil
	}
	m.configMutex.Unlock()

	if use {
		m.locationMutex.Lock()
		m.cachedIPLat = nil
		m.cachedIPLon = nil
		m.locationMutex.Unlock()
	}
	m.triggerUpdate()
}

func (m *Manager) SetManualTimes(sunrise, sunset time.Time) error {
	m.configMutex.Lock()
	m.config.ManualSunrise = &sunrise
	m.config.ManualSunset = &sunset
	err := m.config.Validate()
	m.configMutex.Unlock()
	if err != nil {
		return err
	}
	m.triggerUpdate()
	return nil
}

func (m *Manager) ClearManualTimes() {
	m.configMutex.Lock()
	m.config.ManualSunrise = nil
	m.config.ManualSunset = nil
	m.configMutex.Unlock()
	m.triggerUpdate()
}

func (m *Manager) SetGamma(gamma float64) error {
	m.configMutex.Lock()
	m.config.Gamma = gamma
	err := m.config.Validate()
	m.configMutex.Unlock()
	if err != nil {
		return err
	}
	m.triggerUpdate()
	return nil
}

func (m *Manager) SetEnabled(enabled bool) {
	m.configMutex.Lock()
	wasEnabled := m.config.Enabled
	m.config.Enabled = enabled
	highTemp := m.config.HighTemp
	m.configMutex.Unlock()

	switch {
	case enabled && !m.controlsInitialized:
		m.post(func() {
			gammaMgr := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1)
			if err := m.setupOutputControls(m.availableOutputs, gammaMgr); err != nil {
				log.Errorf("Failed to create gamma controls: %v", err)
				return
			}
			m.controlsInitialized = true
			m.triggerUpdate()
		})
	case enabled && !wasEnabled:
		m.triggerUpdate()
	case !enabled && m.controlsInitialized:
		m.post(func() {
			m.outputs.Range(func(id uint32, out *outputState) bool {
				if out.gammaControl != nil {
					out.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1).Destroy()
				}
				return true
			})
			m.outputs.Range(func(key uint32, _ *outputState) bool {
				m.outputs.Delete(key)
				return true
			})
			m.controlsInitialized = false
		})
		_ = highTemp
	}
}

func (m *Manager) Close() {
	close(m.stopChan)
	m.wg.Wait()
	m.notifierWg.Wait()

	m.subscribers.Range(func(key string, ch chan State) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})

	m.outputs.Range(func(_ uint32, out *outputState) bool {
		if ctrl, ok := out.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1); ok {
			ctrl.Destroy()
		}
		return true
	})
	m.outputs.Range(func(key uint32, _ *outputState) bool {
		m.outputs.Delete(key)
		return true
	})

	if manager, ok := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1); ok {
		manager.Destroy()
	}

	if m.dbusConn != nil {
		m.dbusConn.RemoveSignal(m.dbusSignal)
		m.dbusConn.Close()
	}
}

func MemfdCreate(name string, flags int) (int, error) {
	fd, err := unix.MemfdCreate(name, flags)
	if err != nil {
		return -1, err
	}
	return fd, nil
}
