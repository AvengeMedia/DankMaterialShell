package brightness

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

// isIgnorableI2CBus checks if an I2C bus should be skipped during DDC probing.
// Based on ddcutil's sysfs_is_ignorable_i2c_device() (src/sysfs/sysfs_simple.c)
func isIgnorableI2CBus(busno int) bool {
	name := getI2CDeviceSysfsName(busno)
	if name == "DPMST" {
		return false
	}
	driver := getI2CSysfsDriver(busno)

	if name != "" && isIgnorableI2CDeviceName(name, driver) {
		log.Debugf("i2c-%d: ignoring '%s' (driver: %s)", busno, name, driver)
		return true
	}

	// Only probe display adapters (0x03xxxx) and docking stations (0x0axxxx)
	class := getI2CDeviceSysfsClass(busno)
	if class == 0 {
		// No PCI class says nothing about a platform adapter, but a real adapter always has a name.
		return name == ""
	}

	classHigh := class & 0xFFFF0000
	ignorable := (classHigh != 0x030000 && classHigh != 0x0A0000)
	if ignorable {
		log.Debugf("i2c-%d: ignoring class 0x%08x", busno, class)
	}
	return ignorable
}

// Based on ddcutil's ignorable_i2c_device_sysfs_name() (src/sysfs/sysfs_simple.c)
func isIgnorableI2CDeviceName(name, driver string) bool {
	ignorablePrefixes := []string{
		"SMBus",
		"Synopsys DesignWare",
		"soc:i2cdsi",
		"smu",
		"mac-io",
		"u4",
		"AMDGPU SMU",            // AMD Navi2+ - probing hangs GPU
		"AMDGPU DM i2c OEM bus", // RGB controllers, not displays
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

// Based on ddcutil's get_i2c_device_sysfs_class() (src/sysfs/sysfs_simple.c)
func getI2CDeviceSysfsClass(busno int) uint32 {
	paths := []string{
		fmt.Sprintf("/sys/bus/i2c/devices/i2c-%d", busno),
		fmt.Sprintf("/sys/bus/i2c/devices/i2c-%d/device", busno),
		fmt.Sprintf("/sys/bus/i2c/devices/i2c-%d/i2c-dev/i2c-%d/device", busno, busno),
	}
	for _, path := range paths {
		adapter := findI2CAdapter(path)
		if adapter == "" {
			continue
		}
		data, err := os.ReadFile(filepath.Join(adapter, "class"))
		if err != nil {
			continue
		}
		class, err := strconv.ParseUint(strings.TrimPrefix(strings.TrimSpace(string(data)), "0x"), 16, 32)
		if err == nil && class != 0 {
			return uint32(class)
		}
	}
	return 0
}

// Based on ddcutil's get_driver_for_busno() (src/sysfs/sysfs_simple.c)
func getI2CSysfsDriver(busno int) string {
	adapter := findI2CAdapter(fmt.Sprintf("/sys/bus/i2c/devices/i2c-%d", busno))
	if adapter == "" {
		return ""
	}
	module, err := filepath.EvalSymlinks(filepath.Join(adapter, "driver", "module"))
	if err != nil {
		return ""
	}
	return filepath.Base(module)
}

// Based on ddcutil's sysfs_find_adapter() (src/sysfs/sysfs_simple.c): the nearest
// ancestor under /sys/devices carrying a class attribute.
func findI2CAdapter(path string) string {
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil {
		return ""
	}
	for strings.HasPrefix(resolved, "/sys/devices") {
		if info, err := os.Stat(filepath.Join(resolved, "class")); err == nil && info.Mode().IsRegular() {
			return resolved
		}
		resolved = filepath.Dir(resolved)
	}
	return ""
}

// ddcutil's known_reliable_drivers (src/sysfs/sysfs_base.c): drivers that keep the DRM connector
// edid, status and dpms attributes current.
var sysfsReliableDrivers = []string{"i915", "xe", "amdgpu", "radeon", "nouveau"}

var (
	drmConnectorPattern = regexp.MustCompile(`^card[0-9]+-`)
	i2cBusPattern       = regexp.MustCompile(`^i2c-([0-9]+)$`)
)

type ddcBusVerdict int

const (
	ddcBusSkip ddcBusVerdict = iota
	ddcBusHasEDID
	ddcBusNeedsEDIDRead
)

// Based on ddcutil's i2c_edid_exists() and its laptop panel exclusion (src/i2c/i2c_bus_core.c).
func ddcBusVerdictFor(busno int, connectors map[int]string) ddcBusVerdict {
	name := getI2CDeviceSysfsName(busno)
	displayLink := name == "DisplayLink I2C Adapter"
	reliable := slices.Contains(sysfsReliableDrivers, getI2CSysfsDriver(busno))

	connector, mapped := connectors[busno]
	if !mapped {
		if reliable && !displayLink && name != "DPMST" && len(connectors) > 0 {
			return ddcBusSkip
		}
		return ddcBusNeedsEDIDRead
	}
	if strings.Contains(connector, "-eDP-") || strings.Contains(connector, "-LVDS-") {
		return ddcBusSkip
	}
	if reliable || displayLink {
		if len(drmConnectorAttr(connector, "edid")) >= 128 {
			return ddcBusHasEDID
		}
		return ddcBusSkip
	}
	if strings.TrimSpace(drmConnectorAttr(connector, "status")) == "disconnected" {
		return ddcBusSkip
	}
	return ddcBusNeedsEDIDRead
}

// Based on ddcutil's dpms_check_drm_asleep_by_businfo() (src/sysfs/sysfs_dpms.c).
func ddcDisplayAsleep(busno int, connectors map[int]string) bool {
	connector, mapped := connectors[busno]
	if !mapped || !slices.Contains(sysfsReliableDrivers, getI2CSysfsDriver(busno)) {
		return false
	}
	return strings.TrimSpace(drmConnectorAttr(connector, "dpms")) != "On"
}

// Based on ddcutil's get_connector_bus_numbers() (src/sysfs/sysfs_simple.c): a DP connector's own
// i2c-N directory, any other connector's ddc/i2c-dev/i2c-N.
func drmConnectorsByBus() map[int]string {
	connectors := map[int]string{}
	entries, err := os.ReadDir("/sys/class/drm")
	if err != nil {
		return connectors
	}
	for _, entry := range entries {
		name := entry.Name()
		if !drmConnectorPattern.MatchString(name) {
			continue
		}
		dir := filepath.Join("/sys/class/drm", name)
		if !strings.Contains(name, "-DP-") {
			dir = filepath.Join(dir, "ddc", "i2c-dev")
		}
		if busno, ok := i2cSubdirBus(dir); ok {
			connectors[busno] = name
		}
	}
	return connectors
}

func i2cSubdirBus(dir string) (int, bool) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0, false
	}
	for _, entry := range entries {
		match := i2cBusPattern.FindStringSubmatch(entry.Name())
		if match == nil {
			continue
		}
		if busno, err := strconv.Atoi(match[1]); err == nil {
			return busno, true
		}
	}
	return 0, false
}

func drmConnectorAttr(connector, attr string) string {
	data, err := os.ReadFile(filepath.Join("/sys/class/drm", connector, attr))
	if err != nil {
		return ""
	}
	return string(data)
}

var edidHeader = []byte{0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00}

// Based on ddcutil's is_valid_raw_edid() (src/util/edid.c).
func isValidEDID(edid []byte) bool {
	if len(edid) < 128 || !bytes.Equal(edid[:8], edidHeader) {
		return false
	}
	var sum byte
	for _, b := range edid[:128] {
		sum += b
	}
	return sum == 0
}

// Based on ddcutil's is_laptop_parsed_edid() (src/util/edid.c).
func isLaptopEDID(edid []byte) bool {
	return edidDescriptorText(edid, 0xfc) == "" && edidDescriptorText(edid, 0xff) == ""
}

// Based on ddcutil's get_edid_descriptor_strings() (src/util/edid.c).
func edidDescriptorText(edid []byte, tag byte) string {
	text := ""
	for i := range 4 {
		descriptor := edid[54+i*18 : 72+i*18]
		if descriptor[0] != 0 || descriptor[1] != 0 || descriptor[2] != 0 || descriptor[4] != 0 || descriptor[3] != tag {
			continue
		}
		raw := descriptor[5:18]
		if end := bytes.IndexByte(raw, 0x0a); end >= 0 {
			raw = raw[:end]
		}
		text = strings.TrimRight(string(raw), " \t\n\v\f\r")
	}
	return text
}
