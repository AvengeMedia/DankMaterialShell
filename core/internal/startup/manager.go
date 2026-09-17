package startup

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/desktop"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

type Manager struct {
	userConfigDir    string
	systemConfigDirs []string
	currentDesktops  []string
	applications     []Application
	systemd          SystemdBackend
}

func NewManager() *Manager {
	configDirs := []string{"/etc/xdg"}
	if value := os.Getenv("XDG_CONFIG_DIRS"); value != "" {
		configDirs = filepath.SplitList(value)
	}
	currentDesktops := desktopList(os.Getenv("XDG_CURRENT_DESKTOP"))
	applications := make([]Application, 0)
	for _, entry := range desktop.AllEntries() {
		if entry.Hidden || entry.NoDisplay || entry.Name == "" || entry.Exec == "" {
			continue
		}
		name := entry.Name
		if file, err := readDesktopFile(entry.Path); err == nil && file.keys["Name"] != "" {
			name = desktopString(file.keys["Name"])
		}
		applications = append(applications, Application{ID: entry.ID, Name: name, Exec: entry.Exec, Icon: entry.Icon})
	}
	return &Manager{
		userConfigDir:    utils.XDGConfigHome(),
		systemConfigDirs: configDirs,
		currentDesktops:  currentDesktops,
		applications:     applications,
		systemd:          commandSystemd{},
	}
}

func (m *Manager) List(ctx context.Context) ([]Entry, error) {
	xdg, err := m.listXDG()
	if err != nil {
		return nil, err
	}
	entries := make([]Entry, 0, len(xdg))
	for _, record := range xdg {
		entries = append(entries, record.entry)
	}

	units, err := m.systemd.List(ctx)
	if err == nil {
		for _, unit := range units {
			entry, category := classifySystemdUnit(unit, m.applications)
			if category == CategoryApplication && entry.Mutable {
				entries = append(entries, entry)
			}
		}
	}

	slices.SortStableFunc(entries, func(left, right Entry) int {
		if cmp := strings.Compare(strings.ToLower(left.Name), strings.ToLower(right.Name)); cmp != 0 {
			return cmp
		}
		return strings.Compare(left.ID, right.ID)
	})
	return entries, nil
}

func (m *Manager) SetEnabled(ctx context.Context, id string, enabled bool) error {
	source, name, ok := strings.Cut(id, ":")
	if !ok {
		return ErrProtected
	}
	switch Source(source) {
	case SourceXDG:
		return m.setXDGEnabled(name, enabled)
	case SourceSystemd:
		return m.setSystemdEnabled(ctx, name, enabled)
	default:
		return ErrProtected
	}
}

func (m *Manager) setXDGEnabled(id string, enabled bool) error {
	if !validDesktopID(id) {
		return ErrProtected
	}
	records, err := m.listXDG()
	if err != nil {
		return err
	}
	index := slices.IndexFunc(records, func(record xdgRecord) bool { return record.id == id })
	if index < 0 {
		return ErrNotFound
	}
	record := records[index]
	if record.entry.Enabled == enabled {
		return nil
	}

	userPath := filepath.Join(m.userConfigDir, "autostart", id)
	if !enabled && record.user == nil {
		content := []byte("[Desktop Entry]\nType=Application\nHidden=true\n" + managedOverrideKey + "=true\n")
		return atomicWriteFile(userPath, content)
	}
	if enabled && record.user != nil && record.system != nil && (desktopBool(record.user.keys[managedOverrideKey]) || record.user.keys["Name"] == "" || record.user.keys["Exec"] == "") {
		if err := os.Remove(userPath); err != nil && !os.IsNotExist(err) {
			return fmt.Errorf("remove XDG autostart override: %w", err)
		}
		return nil
	}

	file := record.user
	if file == nil {
		file = record.system
	}
	if file == nil {
		return ErrNotFound
	}
	values := map[string]string{
		"Hidden":                    fmt.Sprintf("%t", !enabled),
		"X-GNOME-Autostart-enabled": fmt.Sprintf("%t", enabled),
	}
	return atomicWriteFile(userPath, updateDesktopKeys(file.content, values))
}

func (m *Manager) setSystemdEnabled(ctx context.Context, name string, enabled bool) error {
	if filepath.Base(name) != name || !strings.HasSuffix(name, ".service") {
		return ErrProtected
	}
	units, err := m.systemd.List(ctx)
	if err != nil {
		return fmt.Errorf("inspect systemd startup service: %w", err)
	}
	index := slices.IndexFunc(units, func(unit SystemdUnit) bool { return unit.Name == name })
	if index < 0 {
		return ErrNotFound
	}
	entry, category := classifySystemdUnit(units[index], m.applications)
	if category != CategoryApplication || !entry.Mutable {
		return ErrProtected
	}
	if entry.Enabled == enabled {
		return nil
	}
	return m.systemd.SetEnabled(ctx, name, enabled)
}

func (m *Manager) Add(name, execLine, icon string) (Entry, error) {
	name = strings.TrimSpace(name)
	execLine = strings.TrimSpace(execLine)
	icon = strings.TrimSpace(icon)
	if name == "" || execLine == "" || strings.ContainsAny(name, "\x00\r\n") || strings.ContainsAny(execLine, "\x00\r\n") || strings.ContainsAny(icon, "\x00\r\n") {
		return Entry{}, ErrInvalidEntry
	}

	dir := filepath.Join(m.userConfigDir, "autostart")
	base := desktopSlug(name)
	id := base + ".desktop"
	for suffix := 2; ; suffix++ {
		_, err := os.Lstat(filepath.Join(dir, id))
		if os.IsNotExist(err) {
			break
		}
		if err != nil {
			return Entry{}, fmt.Errorf("check XDG autostart entry: %w", err)
		}
		id = fmt.Sprintf("%s-%d.desktop", base, suffix)
	}

	var content strings.Builder
	content.WriteString("[Desktop Entry]\nType=Application\nName=")
	content.WriteString(escapeDesktopString(name))
	content.WriteString("\nExec=")
	content.WriteString(execLine)
	content.WriteByte('\n')
	if icon != "" {
		content.WriteString("Icon=")
		content.WriteString(escapeDesktopString(icon))
		content.WriteByte('\n')
	}
	content.WriteString(managedOverrideKey + "=true\n")
	if err := atomicWriteFile(filepath.Join(dir, id), []byte(content.String())); err != nil {
		return Entry{}, fmt.Errorf("write XDG autostart entry: %w", err)
	}
	return Entry{
		ID: string(SourceXDG) + ":" + id, Name: name, Icon: icon, Source: SourceXDG, Enabled: true,
		Category: CategoryApplication, Mutable: true, Removable: true,
	}, nil
}

func (m *Manager) Remove(id string) error {
	source, name, ok := strings.Cut(id, ":")
	if !ok || Source(source) != SourceXDG || !validDesktopID(name) {
		return ErrProtected
	}
	records, err := m.listXDG()
	if err != nil {
		return err
	}
	index := slices.IndexFunc(records, func(record xdgRecord) bool { return record.id == name })
	if index < 0 {
		return ErrNotFound
	}
	if !records[index].entry.Removable {
		return ErrProtected
	}
	if err := os.Remove(filepath.Join(m.userConfigDir, "autostart", name)); err != nil {
		if os.IsNotExist(err) {
			return ErrNotFound
		}
		return fmt.Errorf("remove XDG autostart entry: %w", err)
	}
	return nil
}

func desktopSlug(value string) string {
	words := words(value)
	if len(words) == 0 {
		return "startup-app"
	}
	return strings.Join(words, "-")
}

func escapeDesktopString(value string) string {
	value = strings.ReplaceAll(value, "\\", "\\\\")
	return strings.ReplaceAll(value, "\t", "\\t")
}
