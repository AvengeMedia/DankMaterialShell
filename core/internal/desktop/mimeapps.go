package desktop

import (
	"bufio"
	"bytes"
	"fmt"
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

	return assoc, nil
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

func writeUserMimeapps(update func(*MimeAssociations)) error {
	mimeappsWriteMu.Lock()
	defer mimeappsWriteMu.Unlock()

	path := mimeappsWritePath()

	assoc, err := readAssociations(path)
	if err != nil {
		if !os.IsNotExist(err) {
			return err
		}
		assoc = newAssociations()
	}

	update(assoc)

	var buf bytes.Buffer
	w := bufio.NewWriter(&buf)

	writeSection := func(name string, entries map[string]string) {
		fmt.Fprintf(w, "[%s]\n", name)
		keys := make([]string, 0, len(entries))
		for k := range entries {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			fmt.Fprintf(w, "%s=%s\n", k, entries[k])
		}
		fmt.Fprintln(w)
	}

	flatten := func(m map[string][]string) map[string]string {
		out := make(map[string]string, len(m))
		for k, list := range m {
			out[k] = strings.Join(list, ";") + ";"
		}
		return out
	}

	writeSection(groupDefaults, assoc.Defaults)
	writeSection(groupAdded, flatten(assoc.Added))
	writeSection(groupRemoved, flatten(assoc.Removed))

	if err := w.Flush(); err != nil {
		return err
	}

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, buf.Bytes(), 0o644)
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
