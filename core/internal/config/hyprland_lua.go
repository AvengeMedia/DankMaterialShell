package config

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

const (
	hyprlandStartupBegin = "-- DMS_STARTUP_BEGIN"
	hyprlandStartupEnd   = "-- DMS_STARTUP_END"
)

func extractHyprlangMonitorLines(hyprlang string) []string {
	re := regexp.MustCompile(`(?m)^\s*#?\s*monitor\s*=.*$`)
	return re.FindAllString(hyprlang, -1)
}

func hyprlangMonitorLineToLua(line string) (string, error) {
	re := regexp.MustCompile(`(?i)^\s*#?\s*monitor\s*=\s*(.*)\s*$`)
	m := re.FindStringSubmatch(line)
	if m == nil {
		return "", fmt.Errorf("not a monitor line")
	}
	rest := strings.TrimSpace(m[1])
	parts := strings.Split(rest, ",")
	for i := range parts {
		parts[i] = strings.TrimSpace(parts[i])
	}
	if len(parts) < 4 {
		if len(parts) == 2 && strings.EqualFold(parts[1], "disable") {
			return fmt.Sprintf(`hl.monitor({ output = %s, disabled = true })`, strconv.Quote(parts[0])), nil
		}
		return "", fmt.Errorf("expected at least 4 comma-separated fields")
	}
	out := parts[0]
	mode := parts[1]
	pos := parts[2]
	scaleStr := parts[3]

	scaleField := formatMonitorScaleLua(scaleStr)
	fields := []string{
		fmt.Sprintf("output = %s", strconv.Quote(out)),
		fmt.Sprintf("mode = %s", strconv.Quote(mode)),
		fmt.Sprintf("position = %s", strconv.Quote(pos)),
		scaleField,
	}
	for i := 4; i < len(parts); i += 2 {
		key := strings.ToLower(strings.TrimSpace(parts[i]))
		if key == "" {
			continue
		}
		if i+1 >= len(parts) {
			fields = append(fields, fmt.Sprintf("%s = true", hyprlangMonitorOptionToLuaKey(key)))
			continue
		}
		val := strings.TrimSpace(parts[i+1])
		if converted, ok := formatMonitorOptionLua(key, val); ok {
			fields = append(fields, converted)
		}
	}
	return fmt.Sprintf(`hl.monitor({ %s })`, strings.Join(fields, ", ")), nil
}

func formatMonitorScaleLua(scaleStr string) string {
	if scaleStr == "auto" {
		return `scale = "auto"`
	}
	if f, err := strconv.ParseFloat(scaleStr, 64); err == nil {
		return fmt.Sprintf(`scale = %g`, f)
	}
	return fmt.Sprintf(`scale = %s`, strconv.Quote(scaleStr))
}

func hyprlangMonitorOptionToLuaKey(key string) string {
	switch strings.ToLower(strings.TrimSpace(key)) {
	case "10bit":
		return "bitdepth"
	default:
		return strings.ReplaceAll(strings.ToLower(strings.TrimSpace(key)), "-", "_")
	}
}

func formatMonitorOptionLua(key, val string) (string, bool) {
	luaKey := hyprlangMonitorOptionToLuaKey(key)
	switch luaKey {
	case "transform", "vrr", "bitdepth", "supports_wide_color", "supports_hdr", "sdr_max_luminance", "max_luminance", "max_avg_luminance":
		if _, err := strconv.Atoi(val); err == nil {
			return fmt.Sprintf("%s = %s", luaKey, val), true
		}
	case "sdrbrightness", "sdrsaturation", "sdr_min_luminance", "min_luminance":
		if _, err := strconv.ParseFloat(val, 64); err == nil {
			return fmt.Sprintf("%s = %s", luaKey, val), true
		}
	case "cm", "sdr_eotf", "icc", "mirror":
		return fmt.Sprintf("%s = %s", luaKey, strconv.Quote(val)), true
	}
	return "", false
}

func transformHyprlandLuaForNonSystemd(config, terminalCommand string) string {
	start := strings.Index(config, hyprlandStartupBegin)
	end := strings.Index(config, hyprlandStartupEnd)
	if start == -1 || end == -1 || end <= start {
		return config
	}
	endClose := end + len(hyprlandStartupEnd)
	replacement := hyprlandStartupBegin + "\n" +
		`hl.env("QT_QPA_PLATFORM", "wayland;xcb")` + "\n" +
		`hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")` + "\n" +
		`hl.env("QT_QPA_PLATFORMTHEME", "gtk3")` + "\n" +
		`hl.env("QT_QPA_PLATFORMTHEME_QT6", "gtk3")` + "\n" +
		fmt.Sprintf(`hl.env("TERMINAL", %s)`, strconv.Quote(terminalCommand)) + "\n\n" +
		`hl.on("hyprland.start", function()` + "\n" +
		`	hl.exec_cmd("dms run")` + "\n" +
		`end)` + "\n" +
		hyprlandStartupEnd
	return config[:start] + replacement + config[endClose:]
}

func readExistingHyprlandConfig(configDir string) (data string, sourcePath string, err error) {
	luaPath := filepath.Join(configDir, "hyprland.lua")
	if b, e := os.ReadFile(luaPath); e == nil {
		return string(b), luaPath, nil
	} else if !os.IsNotExist(e) {
		return "", "", e
	}
	confPath := filepath.Join(configDir, "hyprland.conf")
	if b, e := os.ReadFile(confPath); e == nil {
		return string(b), confPath, nil
	} else if !os.IsNotExist(e) {
		return "", "", e
	}
	return "", "", nil
}

// CleanupStrayHyprlandConfFile moves a stray ~/.config/hypr/hyprland.conf
// into .dms-backups/<timestamp>/ only when hyprland.lua also exists, which
// proves Lua is the live config and the .conf is an autogen Hyprland 0.55
// produced when launched without -c. If only hyprland.conf exists, the user
// has not migrated and we must leave their config alone.
func CleanupStrayHyprlandConfFile(logFn func(format string, v ...any)) {
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") == "" {
		return
	}
	home := os.Getenv("HOME")
	if home == "" {
		return
	}
	configDir := filepath.Join(home, ".config", "hypr")
	luaPath := filepath.Join(configDir, "hyprland.lua")
	if _, err := os.Stat(luaPath); err != nil {
		return
	}
	confPath := filepath.Join(configDir, "hyprland.conf")
	if _, err := os.Stat(confPath); err != nil {
		return
	}
	ts := time.Now().Format("2006-01-02_15-04-05")
	dst := filepath.Join(configDir, hyprlandBackupDirName, ts, "hyprland.conf")
	if err := moveHyprlandConfigFile(confPath, dst); err != nil {
		if logFn != nil {
			logFn("Could not move stray hyprland.conf: %v", err)
		}
		return
	}
	if logFn != nil {
		logFn("Moved stray hyprland.conf to %s", dst)
	}
}
