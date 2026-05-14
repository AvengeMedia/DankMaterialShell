package desktop

import (
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

type Entry struct {
	ID         string
	Path       string
	Name       string
	Exec       string
	Icon       string
	Categories []string
	MimeTypes  []string
	NoDisplay  bool
	Hidden     bool
	Terminal   bool
}

type cachedEntry struct {
	entry   *Entry
	modTime time.Time
	size    int64
}

var (
	entryCache   = make(map[string]cachedEntry)
	entryCacheMu sync.Mutex

	listingCache   []*Entry
	listingExpires time.Time
	listingCacheMu sync.Mutex
)

const listingTTL = 5 * time.Second

func applicationDirs() []string {
	seen := make(map[string]bool)
	var dirs []string

	add := func(path string) {
		if path == "" {
			return
		}
		abs, err := filepath.Abs(path)
		if err != nil {
			abs = path
		}
		if seen[abs] {
			return
		}
		seen[abs] = true
		dirs = append(dirs, abs)
	}

	add(filepath.Join(utils.XDGDataHome(), "applications"))

	if env := os.Getenv("XDG_DATA_DIRS"); env != "" {
		for d := range strings.SplitSeq(env, ":") {
			add(filepath.Join(strings.TrimSpace(d), "applications"))
		}
	} else {
		add("/usr/local/share/applications")
		add("/usr/share/applications")
	}

	home, _ := os.UserHomeDir()
	if home != "" {
		add(filepath.Join(home, ".local", "share", "flatpak", "exports", "share", "applications"))
	}
	add("/var/lib/flatpak/exports/share/applications")
	add("/var/lib/snapd/desktop/applications")

	return dirs
}

func parseEntry(path string, id string) (*Entry, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, err
	}

	entryCacheMu.Lock()
	if c, ok := entryCache[path]; ok && c.modTime.Equal(info.ModTime()) && c.size == info.Size() {
		entryCacheMu.Unlock()
		return c.entry, nil
	}
	entryCacheMu.Unlock()

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	groups := parseGroups(data)
	g, ok := groups["Desktop Entry"]
	if !ok {
		return nil, nil
	}

	entry := &Entry{
		ID:         id,
		Path:       path,
		Name:       g.keys["Name"],
		Exec:       g.keys["Exec"],
		Icon:       g.keys["Icon"],
		Categories: splitList(g.keys["Categories"]),
		MimeTypes:  splitList(g.keys["MimeType"]),
		NoDisplay:  parseBool(g.keys["NoDisplay"]),
		Hidden:     parseBool(g.keys["Hidden"]),
		Terminal:   parseBool(g.keys["Terminal"]),
	}

	if t := g.keys["Type"]; t != "" && t != "Application" {
		return nil, nil
	}

	entryCacheMu.Lock()
	entryCache[path] = cachedEntry{entry: entry, modTime: info.ModTime(), size: info.Size()}
	entryCacheMu.Unlock()

	return entry, nil
}

func relativeID(root, path string) string {
	rel, err := filepath.Rel(root, path)
	if err != nil {
		return filepath.Base(path)
	}
	return strings.ReplaceAll(rel, string(filepath.Separator), "-")
}

func AllEntries() []*Entry {
	listingCacheMu.Lock()
	if time.Now().Before(listingExpires) && listingCache != nil {
		out := listingCache
		listingCacheMu.Unlock()
		return out
	}
	listingCacheMu.Unlock()

	seen := make(map[string]bool)
	var entries []*Entry

	for _, dir := range applicationDirs() {
		_ = filepath.WalkDir(dir, func(path string, d os.DirEntry, err error) error {
			if err != nil || d.IsDir() {
				return nil
			}
			if !strings.HasSuffix(path, ".desktop") {
				return nil
			}
			id := relativeID(dir, path)
			if seen[id] {
				return nil
			}
			seen[id] = true

			entry, err := parseEntry(path, id)
			if err != nil || entry == nil {
				return nil
			}
			entries = append(entries, entry)
			return nil
		})
	}

	listingCacheMu.Lock()
	listingCache = entries
	listingExpires = time.Now().Add(listingTTL)
	listingCacheMu.Unlock()

	return entries
}

func EntryByID(id string) *Entry {
	if !strings.HasSuffix(id, ".desktop") {
		id += ".desktop"
	}
	for _, entry := range AllEntries() {
		if entry.ID == id {
			return entry
		}
	}
	return nil
}

func InvalidateCache() {
	entryCacheMu.Lock()
	entryCache = make(map[string]cachedEntry)
	entryCacheMu.Unlock()

	listingCacheMu.Lock()
	listingCache = nil
	listingExpires = time.Time{}
	listingCacheMu.Unlock()
}
