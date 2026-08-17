package desktop

import (
	"bufio"
	"bytes"
	"fmt"
	"maps"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"strings"
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

var mimeappsWriteMu sync.Mutex

const (
	groupDefaults = "Default Applications"
	groupAdded    = "Added Associations"
	groupRemoved  = "Removed Associations"
)

type MimeAssociations struct {
	Defaults map[string]string
	Added    map[string][]string
	Removed  map[string][]string
}

func newAssociations() *MimeAssociations {
	return &MimeAssociations{
		Defaults: make(map[string]string),
		Added:    make(map[string][]string),
		Removed:  make(map[string][]string),
	}
}

func mimeappsSearchPaths() []string {
	var paths []string
	seen := make(map[string]bool)

	add := func(p string) {
		if p == "" || seen[p] {
			return
		}
		seen[p] = true
		paths = append(paths, p)
	}

	add(filepath.Join(utils.XDGConfigHome(), "mimeapps.list"))

	if env := os.Getenv("XDG_CONFIG_DIRS"); env != "" {
		for d := range strings.SplitSeq(env, ":") {
			add(filepath.Join(strings.TrimSpace(d), "mimeapps.list"))
		}
	} else {
		add("/etc/xdg/mimeapps.list")
	}

	add(filepath.Join(utils.XDGDataHome(), "applications", "mimeapps.list"))

	if env := os.Getenv("XDG_DATA_DIRS"); env != "" {
		for d := range strings.SplitSeq(env, ":") {
			add(filepath.Join(strings.TrimSpace(d), "applications", "mimeapps.list"))
		}
	} else {
		add("/usr/local/share/applications/mimeapps.list")
		add("/usr/share/applications/mimeapps.list")
	}

	return paths
}

func mimeappsWritePath() string {
	return filepath.Join(utils.XDGConfigHome(), "mimeapps.list")
}

func readAssociations(path string) (*MimeAssociations, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return associationsFromData(data), nil
}

func associationsFromData(data []byte) *MimeAssociations {
	groups := parseGroups(data)
	assoc := newAssociations()

	if g := groups[groupDefaults]; g != nil {
		for mime, val := range g.keys {
			parts := splitList(val)
			if len(parts) > 0 {
				assoc.Defaults[mime] = parts[0]
			}
		}
	}

	if g := groups[groupAdded]; g != nil {
		for mime, val := range g.keys {
			assoc.Added[mime] = splitList(val)
		}
	}

	if g := groups[groupRemoved]; g != nil {
		for mime, val := range g.keys {
			assoc.Removed[mime] = splitList(val)
		}
	}

	return assoc
}

func mergedAssociations() *MimeAssociations {
	merged := newAssociations()

	for _, path := range mimeappsSearchPaths() {
		assoc, err := readAssociations(path)
		if err != nil {
			continue
		}
		for mime, app := range assoc.Defaults {
			if _, ok := merged.Defaults[mime]; !ok {
				merged.Defaults[mime] = app
			}
		}
		for mime, apps := range assoc.Added {
			merged.Added[mime] = append(merged.Added[mime], apps...)
		}
		for mime, apps := range assoc.Removed {
			merged.Removed[mime] = append(merged.Removed[mime], apps...)
		}
	}

	return merged
}

// isSafeIniField rejects values that would corrupt a key=value line in mimeapps.list
func isSafeIniField(s string) bool {
	return !strings.ContainsAny(s, "\n\r[]")
}

func writeUserMimeapps(update func(*MimeAssociations)) error {
	mimeappsWriteMu.Lock()
	defer mimeappsWriteMu.Unlock()

	path := mimeappsWritePath()

	original, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		return err
	}

	assoc := associationsFromData(original)
	update(assoc)

	rendered, err := renderMimeapps(original, assoc)
	if err != nil {
		return err
	}
	return atomicWriteFile(path, rendered)
}

func managedGroups(assoc *MimeAssociations) (map[string]map[string]string, error) {
	flatten := func(m map[string][]string) map[string]string {
		out := make(map[string]string, len(m))
		for k, list := range m {
			out[k] = strings.Join(list, ";") + ";"
		}
		return out
	}

	groups := map[string]map[string]string{
		groupDefaults: maps.Clone(assoc.Defaults),
		groupAdded:    flatten(assoc.Added),
		groupRemoved:  flatten(assoc.Removed),
	}
	for name, entries := range groups {
		for k, v := range entries {
			if isSafeIniField(k) && isSafeIniField(v) {
				continue
			}
			return nil, fmt.Errorf("invalid mimeapps.list field in [%s]: %q=%q", name, k, v)
		}
	}
	return groups, nil
}

// renderMimeapps rewrites only the three association groups defined by the
// mime-apps spec (https://specifications.freedesktop.org/mime-apps-spec/),
// keeping comments, blank lines, and unrelated groups verbatim.
func renderMimeapps(original []byte, assoc *MimeAssociations) ([]byte, error) {
	managed, err := managedGroups(assoc)
	if err != nil {
		return nil, err
	}

	written := map[string]map[string]bool{
		groupDefaults: {},
		groupAdded:    {},
		groupRemoved:  {},
	}

	var out []string

	flushMissing := func(group string) {
		entries, ok := managed[group]
		if !ok {
			return
		}
		keys := make([]string, 0, len(entries))
		for k := range entries {
			if !written[group][k] {
				keys = append(keys, k)
			}
		}
		if len(keys) == 0 {
			return
		}
		sort.Strings(keys)

		insertAt := len(out)
		for insertAt > 0 && strings.TrimSpace(out[insertAt-1]) == "" {
			insertAt--
		}
		lines := make([]string, 0, len(keys))
		for _, k := range keys {
			written[group][k] = true
			lines = append(lines, k+"="+entries[k])
		}
		tail := append([]string(nil), out[insertAt:]...)
		out = append(out[:insertAt], append(lines, tail...)...)
	}

	current := ""
	scanner := bufio.NewScanner(bytes.NewReader(original))
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)

		if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			flushMissing(current)
			current = trimmed[1 : len(trimmed)-1]
			out = append(out, line)
			continue
		}

		entries, isManaged := managed[current]
		if !isManaged {
			out = append(out, line)
			continue
		}

		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			out = append(out, line)
			continue
		}

		eq := strings.IndexByte(trimmed, '=')
		if eq <= 0 {
			out = append(out, line)
			continue
		}

		key := strings.TrimSpace(trimmed[:eq])
		val, keep := entries[key]
		if !keep || written[current][key] {
			continue
		}
		written[current][key] = true
		out = append(out, key+"="+val)
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	flushMissing(current)

	for _, group := range []string{groupDefaults, groupAdded, groupRemoved} {
		entries := managed[group]
		pending := make([]string, 0, len(entries))
		for k := range entries {
			if !written[group][k] {
				pending = append(pending, k)
			}
		}
		if len(pending) == 0 {
			continue
		}
		sort.Strings(pending)

		if len(out) > 0 && strings.TrimSpace(out[len(out)-1]) != "" {
			out = append(out, "")
		}
		out = append(out, "["+group+"]")
		for _, k := range pending {
			written[group][k] = true
			out = append(out, k+"="+entries[k])
		}
	}

	if len(out) == 0 {
		return nil, nil
	}
	return []byte(strings.Join(out, "\n") + "\n"), nil
}

func atomicWriteFile(path string, data []byte) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}

	tmp, err := os.CreateTemp(dir, ".mimeapps-*.tmp")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()

	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		os.Remove(tmpPath)
		return err
	}
	if err := tmp.Chmod(0o644); err != nil {
		tmp.Close()
		os.Remove(tmpPath)
		return err
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpPath)
		return err
	}
	if err := os.Rename(tmpPath, path); err != nil {
		os.Remove(tmpPath)
		return err
	}
	return nil
}

func setDefaultAssociation(mimeType, desktopID string) error {
	return setDefaultAssociations([]string{mimeType}, desktopID)
}

func setDefaultAssociations(mimeTypes []string, desktopID string) error {
	if !strings.HasSuffix(desktopID, ".desktop") {
		desktopID += ".desktop"
	}
	return writeUserMimeapps(func(assoc *MimeAssociations) {
		for _, mimeType := range mimeTypes {
			if mimeType == "" {
				continue
			}
			assoc.Defaults[mimeType] = desktopID
			existing := assoc.Added[mimeType]
			if !slices.Contains(existing, desktopID) {
				assoc.Added[mimeType] = append(existing, desktopID)
			}
			removed, ok := assoc.Removed[mimeType]
			if !ok {
				continue
			}
			filtered := removed[:0]
			for _, id := range removed {
				if id != desktopID {
					filtered = append(filtered, id)
				}
			}
			switch {
			case len(filtered) == 0:
				delete(assoc.Removed, mimeType)
			default:
				assoc.Removed[mimeType] = filtered
			}
		}
	})
}
