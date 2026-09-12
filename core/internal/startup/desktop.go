package startup

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
)

const managedOverrideKey = "X-DMS-Managed"

type desktopFile struct {
	content []byte
	keys    map[string]string
	valid   bool
}

type xdgRecord struct {
	id     string
	user   *desktopFile
	system *desktopFile
	entry  Entry
}

func readDesktopFile(path string) (*desktopFile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	keys := make(map[string]string)
	scanner := bufio.NewScanner(bytes.NewReader(data))
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	inDesktopEntry := false
	foundDesktopEntry := false
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			inDesktopEntry = line == "[Desktop Entry]"
			foundDesktopEntry = foundDesktopEntry || inDesktopEntry
			continue
		}
		if !inDesktopEntry {
			continue
		}
		eq := strings.IndexByte(line, '=')
		if eq <= 0 {
			continue
		}
		key := strings.TrimSpace(line[:eq])
		if strings.Contains(key, "[") {
			continue
		}
		if _, exists := keys[key]; exists {
			continue
		}
		keys[key] = strings.TrimSpace(line[eq+1:])
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}

	typeName := keys["Type"]
	return &desktopFile{
		content: data,
		keys:    keys,
		valid:   foundDesktopEntry && (typeName == "" || typeName == "Application"),
	}, nil
}

func desktopBool(value string) bool {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "1", "true", "yes":
		return true
	default:
		return false
	}
}

func desktopList(value string) []string {
	fields := strings.FieldsFunc(value, func(r rune) bool { return r == ';' || r == ':' })
	for i := range fields {
		fields[i] = strings.ToLower(strings.TrimSpace(fields[i]))
	}
	return slices.DeleteFunc(fields, func(value string) bool { return value == "" })
}

func desktopString(value string) string {
	var out strings.Builder
	for i := 0; i < len(value); i++ {
		if value[i] != '\\' || i+1 >= len(value) {
			out.WriteByte(value[i])
			continue
		}
		i++
		switch value[i] {
		case 'n':
			out.WriteByte('\n')
		case 'r':
			out.WriteByte('\r')
		case 't':
			out.WriteByte('\t')
		case 's':
			out.WriteByte(' ')
		case '\\':
			out.WriteByte('\\')
		default:
			out.WriteByte('\\')
			out.WriteByte(value[i])
		}
	}
	return out.String()
}

func desktopVisible(keys map[string]string, currentDesktops []string) bool {
	current := make(map[string]struct{}, len(currentDesktops))
	for _, desktop := range currentDesktops {
		current[strings.ToLower(desktop)] = struct{}{}
	}

	only := desktopList(keys["OnlyShowIn"])
	if len(only) > 0 {
		matched := slices.ContainsFunc(only, func(desktop string) bool {
			_, ok := current[desktop]
			return ok
		})
		if !matched {
			return false
		}
	}

	not := desktopList(keys["NotShowIn"])
	return !slices.ContainsFunc(not, func(desktop string) bool {
		_, ok := current[desktop]
		return ok
	})
}

func mergedDesktopKeys(user, system *desktopFile) map[string]string {
	keys := make(map[string]string)
	if system != nil {
		for key, value := range system.keys {
			keys[key] = value
		}
	}
	if user != nil {
		for key, value := range user.keys {
			keys[key] = value
		}
	}
	return keys
}

func desktopEnabled(keys map[string]string) bool {
	if desktopBool(keys["Hidden"]) {
		return false
	}
	value, exists := keys["X-GNOME-Autostart-enabled"]
	return !exists || desktopBool(value)
}

func (m *Manager) listXDG() ([]xdgRecord, error) {
	systemFiles := make(map[string]*desktopFile)
	for _, configDir := range m.systemConfigDirs {
		dir := filepath.Join(configDir, "autostart")
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, dirEntry := range entries {
			id := dirEntry.Name()
			if dirEntry.IsDir() || !validDesktopID(id) || systemFiles[id] != nil {
				continue
			}
			file, err := readDesktopFile(filepath.Join(dir, id))
			if err != nil {
				continue
			}
			systemFiles[id] = file
		}
	}

	userFiles := make(map[string]*desktopFile)
	userDir := filepath.Join(m.userConfigDir, "autostart")
	entries, err := os.ReadDir(userDir)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, fmt.Errorf("read user autostart directory: %w", err)
	}
	for _, dirEntry := range entries {
		id := dirEntry.Name()
		if dirEntry.IsDir() || !validDesktopID(id) {
			continue
		}
		file, err := readDesktopFile(filepath.Join(userDir, id))
		if err != nil {
			continue
		}
		userFiles[id] = file
	}

	ids := make(map[string]struct{}, len(systemFiles)+len(userFiles))
	for id := range systemFiles {
		ids[id] = struct{}{}
	}
	for id := range userFiles {
		ids[id] = struct{}{}
	}

	records := make([]xdgRecord, 0, len(ids))
	for id := range ids {
		user := userFiles[id]
		system := systemFiles[id]
		effective := user
		if effective == nil {
			effective = system
		}
		if effective == nil || !effective.valid {
			continue
		}
		keys := mergedDesktopKeys(user, system)
		if desktopBool(keys["NoDisplay"]) || !desktopVisible(keys, m.currentDesktops) {
			continue
		}
		name := desktopString(keys["Name"])
		execLine := keys["Exec"]
		if name == "" || execLine == "" || !safeXDGApplication(id, keys) {
			continue
		}

		records = append(records, xdgRecord{
			id:     id,
			user:   user,
			system: system,
			entry: Entry{
				ID:          string(SourceXDG) + ":" + id,
				Name:        name,
				Description: desktopString(keys["Comment"]),
				Icon:        keys["Icon"],
				Source:      SourceXDG,
				Enabled:     desktopEnabled(keys),
				Category:    CategoryApplication,
				Mutable:     true,
				Removable:   user != nil && system == nil && desktopBool(user.keys[managedOverrideKey]),
			},
		})
	}
	return records, nil
}

func safeXDGApplication(id string, keys map[string]string) bool {
	identity := id + " " + keys["Name"] + " " + keys["Comment"] + " " + executableFromDesktop(keys["Exec"])
	return !containsProtectedWord(identity)
}

func validDesktopID(id string) bool {
	return id != "" && filepath.Base(id) == id && strings.HasSuffix(id, ".desktop")
}

func updateDesktopKeys(content []byte, values map[string]string) []byte {
	lines := strings.Split(string(content), "\n")
	found := make(map[string]bool, len(values))
	inDesktopEntry := false
	insertAt := -1
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			if inDesktopEntry && insertAt < 0 {
				insertAt = i
			}
			inDesktopEntry = trimmed == "[Desktop Entry]"
			continue
		}
		if !inDesktopEntry {
			continue
		}
		eq := strings.IndexByte(trimmed, '=')
		if eq <= 0 {
			continue
		}
		key := strings.TrimSpace(trimmed[:eq])
		value, ok := values[key]
		if !ok || found[key] {
			continue
		}
		lines[i] = key + "=" + value
		found[key] = true
	}
	if insertAt < 0 {
		insertAt = len(lines)
	}
	missing := make([]string, 0, len(values))
	for key, value := range values {
		if !found[key] {
			missing = append(missing, key+"="+value)
		}
	}
	slices.Sort(missing)
	lines = slices.Insert(lines, insertAt, missing...)
	return []byte(strings.Join(lines, "\n"))
}

func atomicWriteFile(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".dms-startup-*")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	if err := tmp.Chmod(0o644); err != nil {
		tmp.Close()
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpPath, path)
}
