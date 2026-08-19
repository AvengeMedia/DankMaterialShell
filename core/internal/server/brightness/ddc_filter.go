package brightness

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

// isIgnorableI2CBus checks if an I2C bus should be skipped during DDC probing.
// Based on ddcutil's sysfs_is_ignorable_i2c_device() (sysfs_base.c:1441)
func isIgnorableI2CBus(busno int) bool {
	name := getI2CDeviceSysfsName(busno)
	driver := getI2CSysfsDriver(busno)

	if name != "" && isIgnorableI2CDeviceName(name, driver) {
		log.Debugf("i2c-%d: ignoring '%s' (driver: %s)", busno, name, driver)
		return true
	}

	// Only probe display adapters (0x03xxxx) and docking stations (0x0axxxx)
	class := getI2CDeviceSysfsClass(busno)
	if class != 0 {
		classHigh := class & 0xFFFF0000
		ignorable := (classHigh != 0x030000 && classHigh != 0x0A0000)
		if ignorable {
			log.Debugf("i2c-%d: ignoring class 0x%08x", busno, class)
		}
		return ignorable
	}

	return false
}

// Based on ddcutil's ignorable_i2c_device_sysfs_name() (sysfs_base.c:1408)
func isIgnorableI2CDeviceName(name, driver string) bool {
	ignorablePrefixes := []string{
		"SMBus",
		"Synopsys DesignWare",
		"soc:i2cdsi",
		"smu",
		"mac-io",
		"u4",
		"AMDGPU SMU", // AMD Navi2+ - probing hangs GPU
	}

	for _, prefix := range ignorablePrefixes {
		if strings.HasPrefix(name, prefix) {
			return true
		}
	}

	// nouveau driver: only nvkm-* buses are valid
	if driver == "nouveau" && !strings.HasPrefix(name, "nvkm-") {
		return true
	}

	return false
}

// Based on ddcutil's get_i2c_device_sysfs_name() (sysfs_base.c:1175)
func getI2CDeviceSysfsName(busno int) string {
	path := fmt.Sprintf("/sys/bus/i2c/devices/i2c-%d/name", busno)
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

// Based on ddcutil's get_i2c_device_sysfs_class() (sysfs_base.c:1380)
func getI2CDeviceSysfsClass(busno int) uint32 {
	classPath := fmt.Sprintf("/sys/bus/i2c/devices/i2c-%d/device/class", busno)
	data, err := os.ReadFile(classPath)
	if err != nil {
		classPath = fmt.Sprintf("/sys/bus/i2c/devices/i2c-%d/device/device/device/class", busno)
		data, err = os.ReadFile(classPath)
		if err != nil {
			return 0
		}
	}

	classStr := strings.TrimSpace(string(data))
	classStr = strings.TrimPrefix(classStr, "0x")

	class, err := strconv.ParseUint(classStr, 16, 32)
	if err != nil {
		return 0
	}

	return uint32(class)
}

// Based on ddcutil's get_i2c_sysfs_driver_by_busno() (sysfs_base.c:1284)
func getI2CSysfsDriver(busno int) string {
	devicePath := fmt.Sprintf("/sys/bus/i2c/devices/i2c-%d", busno)
	adapterPath, err := findI2CAdapter(devicePath)
	if err != nil {
		return ""
	}

	driverLink := filepath.Join(adapterPath, "driver")
	target, err := os.Readlink(driverLink)
	if err != nil {
		return ""
	}

	return filepath.Base(target)
}

func findI2CAdapter(devicePath string) (string, error) {
	currentPath := devicePath

	for range 10 {
		if _, err := os.Stat(filepath.Join(currentPath, "name")); err == nil {
			return currentPath, nil
		}

		deviceLink := filepath.Join(currentPath, "device")
		target, err := os.Readlink(deviceLink)
		if err != nil {
			break
		}

		if !filepath.IsAbs(target) {
			target = filepath.Join(filepath.Dir(currentPath), target)
		}
		currentPath = filepath.Clean(target)
	}

	return "", fmt.Errorf("could not find adapter for %s", devicePath)
}
