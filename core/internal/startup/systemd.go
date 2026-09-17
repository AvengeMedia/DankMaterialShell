package startup

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"time"
	"unicode"
)

type commandSystemd struct{}

func (commandSystemd) List(ctx context.Context) ([]SystemdUnit, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	output, err := exec.CommandContext(ctx, "systemctl", "--user", "list-unit-files", "--type=service", "--no-legend", "--no-pager", "--plain").Output()
	if err != nil {
		return nil, fmt.Errorf("list user unit files: %w", err)
	}

	states := make(map[string]string)
	var names []string
	for line := range strings.SplitSeq(string(output), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 || !strings.HasSuffix(fields[0], ".service") || strings.Contains(fields[0], "@") {
			continue
		}
		if fields[1] != "enabled" && fields[1] != "disabled" {
			continue
		}
		states[fields[0]] = fields[1]
		names = append(names, fields[0])
	}
	if len(names) == 0 {
		return nil, nil
	}

	args := []string{"--user", "show", "--no-pager", "--property=Id,Description,LoadState,UnitFileState,FragmentPath,SourcePath,Transient,DefaultDependencies,Before,After,Requires,Requisite,BindsTo,PartOf,RequiredBy,ExecStart"}
	args = append(args, names...)
	output, err = exec.CommandContext(ctx, "systemctl", args...).Output()
	if err != nil {
		return nil, fmt.Errorf("inspect user unit files: %w", err)
	}

	units := parseSystemdShow(output)
	for i := range units {
		if units[i].UnitFileState == "" {
			units[i].UnitFileState = states[units[i].Name]
		}
		units[i].InstallTargets = readInstallTargets(units[i].FragmentPath)
	}
	return units, nil
}

func (commandSystemd) SetEnabled(ctx context.Context, name string, enabled bool) error {
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	action := "disable"
	if enabled {
		action = "enable"
	}
	output, err := exec.CommandContext(ctx, "systemctl", "--user", action, "--", name).CombinedOutput()
	if err != nil {
		detail := strings.TrimSpace(string(output))
		if detail == "" {
			detail = err.Error()
		}
		return fmt.Errorf("systemctl --user %s %s: %s", action, name, detail)
	}
	return nil
}

func parseSystemdShow(data []byte) []SystemdUnit {
	var units []SystemdUnit
	var current *SystemdUnit
	for line := range strings.SplitSeq(string(data), "\n") {
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		if key == "Id" {
			units = append(units, SystemdUnit{Name: value, DefaultDependencies: true})
			current = &units[len(units)-1]
			continue
		}
		if current == nil {
			continue
		}
		switch key {
		case "Description":
			current.Description = value
		case "LoadState":
			current.LoadState = value
		case "UnitFileState":
			current.UnitFileState = value
		case "FragmentPath":
			current.FragmentPath = value
		case "SourcePath":
			current.SourcePath = value
		case "ExecStart":
			current.ExecStart = value
		case "Before":
			current.Before = strings.Fields(value)
		case "Requires":
			current.Requires = strings.Fields(value)
		case "Requisite":
			current.Requisite = strings.Fields(value)
		case "BindsTo":
			current.BindsTo = strings.Fields(value)
		case "PartOf":
			current.PartOf = strings.Fields(value)
		case "RequiredBy":
			current.RequiredBy = strings.Fields(value)
		case "Transient":
			current.Transient = value == "yes"
		case "DefaultDependencies":
			current.DefaultDependencies = value != "no"
		}
	}
	return units
}

func readInstallTargets(path string) []string {
	if path == "" {
		return nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}

	var targets []string
	inInstall := false
	scanner := bufio.NewScanner(bytes.NewReader(data))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			inInstall = line == "[Install]"
			continue
		}
		if !inInstall {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok || (key != "WantedBy" && key != "RequiredBy") {
			continue
		}
		targets = append(targets, strings.Fields(value)...)
	}
	return targets
}

var protectedWords = map[string]struct{}{
	"atspi": {}, "audio": {}, "authentication": {}, "bluez": {}, "bus": {}, "cgroup": {},
	"colord": {}, "compositor": {}, "cosmic": {}, "daemon": {}, "dbus": {}, "dconf": {}, "dirmngr": {},
	"dms": {}, "dsearch": {}, "fcitx": {}, "geoclue": {}, "gpg": {}, "greeter": {}, "gss": {}, "gvfs": {},
	"hyprland": {}, "ibus": {}, "iwd": {}, "keyboxd": {}, "keyring": {}, "kwin": {}, "labwc": {},
	"login": {}, "logind": {}, "mango": {}, "mangowc": {}, "networkmanager": {}, "niri": {},
	"obex": {}, "packagekit": {}, "pipewire": {}, "polkit": {}, "portal": {}, "pulse": {},
	"pulseaudio": {}, "quickshell": {}, "river": {}, "secret": {}, "session": {}, "socket": {},
	"ssh": {}, "sway": {}, "systemd": {}, "target": {}, "udev": {}, "wayfire": {}, "wireplumber": {}, "xdg": {},
}

var genericApplicationWords = map[string]struct{}{
	"app": {}, "application": {}, "client": {}, "desktop": {}, "service": {}, "startup": {},
}

var allowedInstallTargets = []string{
	"default.target",
	"graphical-session.target",
	"xdg-desktop-autostart.target",
}

var protectedDependencyTargets = []string{
	"basic.target",
	"default.target",
	"graphical-session-pre.target",
	"graphical-session.target",
	"sockets.target",
}

func classifySystemdUnit(unit SystemdUnit, applications []Application) (Entry, Category) {
	if !safeSystemdUnit(unit) {
		return Entry{}, CategoryProtected
	}
	application, ok := matchingApplication(unit, applications)
	if !ok {
		return Entry{}, CategoryProtected
	}
	description := strings.TrimSpace(unit.Description)
	if strings.EqualFold(description, application.Name) {
		description = ""
	}
	return Entry{
		ID:          string(SourceSystemd) + ":" + unit.Name,
		Name:        application.Name,
		Description: description,
		Icon:        application.Icon,
		Source:      SourceSystemd,
		Enabled:     unit.UnitFileState == "enabled",
		Category:    CategoryApplication,
		Mutable:     true,
	}, CategoryApplication
}

func safeSystemdUnit(unit SystemdUnit) bool {
	if filepath.Base(unit.Name) != unit.Name || !strings.HasSuffix(unit.Name, ".service") || strings.Contains(unit.Name, "@") {
		return false
	}
	if unit.LoadState != "loaded" || (unit.UnitFileState != "enabled" && unit.UnitFileState != "disabled") {
		return false
	}
	if unit.Transient || !unit.DefaultDependencies || unit.FragmentPath == "" || unit.ExecStart == "" {
		return false
	}
	path := filepath.Clean(unit.FragmentPath)
	if strings.HasPrefix(path, "/run/") || strings.HasPrefix(path, "/tmp/") || strings.HasPrefix(path, "/proc/") || strings.HasPrefix(path, "/sys/") || strings.HasPrefix(path, "/dev/") || strings.Contains(path, "/generator") || strings.Contains(path, "/transient") || unit.SourcePath != "" {
		return false
	}
	if containsProtectedWord(strings.TrimSuffix(unit.Name, ".service")) || containsProtectedWord(unit.Description) || containsProtectedWord(executableFromSystemd(unit.ExecStart)) {
		return false
	}
	if len(unit.InstallTargets) == 0 || slices.ContainsFunc(unit.InstallTargets, func(target string) bool {
		return !slices.Contains(allowedInstallTargets, target)
	}) {
		return false
	}
	if intersects(unit.Before, protectedDependencyTargets) || intersects(unit.RequiredBy, protectedDependencyTargets) || intersects(unit.Requisite, protectedDependencyTargets) || intersects(unit.BindsTo, protectedDependencyTargets) {
		return false
	}
	return true
}

func intersects(values, protected []string) bool {
	return slices.ContainsFunc(values, func(value string) bool { return slices.Contains(protected, value) })
}

func containsProtectedWord(value string) bool {
	for _, word := range words(value) {
		if _, protected := protectedWords[word]; protected {
			return true
		}
	}
	return false
}

func executableFromSystemd(execStart string) string {
	if index := strings.Index(execStart, "path="); index >= 0 {
		value := execStart[index+len("path="):]
		if end := strings.IndexAny(value, " ;}"); end >= 0 {
			value = value[:end]
		}
		return filepath.Base(value)
	}
	return execStart
}

func matchingApplication(unit SystemdUnit, applications []Application) (Application, bool) {
	unitStem := strings.TrimSuffix(unit.Name, ".service")
	unitWords := wordSet(unitStem + " " + executableFromSystemd(unit.ExecStart))
	unitName := normalized(unitStem)
	description := normalized(unit.Description)

	bestScore := 0
	var best Application
	for _, application := range applications {
		if application.Name == "" {
			continue
		}
		appID := strings.TrimSuffix(application.ID, ".desktop")
		appName := normalized(application.Name)
		appExec := normalized(executableFromDesktop(application.Exec))
		if appName == "" || containsProtectedWord(appID+" "+application.Name+" "+appExec) {
			continue
		}

		score := 0
		if len(appName) >= 4 && (unitName == appName || description == appName) {
			score += 100
		}
		if len(appName) >= 4 && strings.Contains(unitName, appName) {
			score += 40
		}
		if appExec != "" && normalized(executableFromSystemd(unit.ExecStart)) == appExec {
			score += 80
		}
		for word := range meaningfulWords(appID + " " + application.Name + " " + application.Exec) {
			if _, matches := unitWords[word]; matches {
				score += 15
			}
		}
		if score > bestScore {
			bestScore = score
			best = application
		}
	}
	return best, bestScore >= 40
}

func executableFromDesktop(execLine string) string {
	fields := strings.Fields(execLine)
	if len(fields) == 0 {
		return ""
	}
	return filepath.Base(strings.Trim(fields[0], "\"'"))
}

func meaningfulWords(value string) map[string]struct{} {
	result := wordSet(value)
	for word := range result {
		_, generic := genericApplicationWords[word]
		if len(word) < 4 || generic {
			delete(result, word)
		}
	}
	return result
}

func wordSet(value string) map[string]struct{} {
	result := make(map[string]struct{})
	for _, word := range words(value) {
		result[word] = struct{}{}
	}
	return result
}

func words(value string) []string {
	return strings.FieldsFunc(strings.ToLower(value), func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) })
}

func normalized(value string) string {
	return strings.Join(words(value), "")
}
