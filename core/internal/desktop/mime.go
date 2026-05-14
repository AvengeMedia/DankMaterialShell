package desktop

import (
	"bufio"
	"bytes"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

var (
	aliasMap      map[string]string
	subclassMap   map[string][]string
	aliasLoaded   time.Time
	aliasReloadMu sync.Mutex

	mimeCacheMap      map[string][]string
	mimeCacheLoaded   time.Time
	mimeCacheReloadMu sync.Mutex
)

const aliasTTL = 60 * time.Second
const mimeCacheTTL = 10 * time.Second

func mimeDataDirs() []string {
	var dirs []string
	seen := make(map[string]bool)

	add := func(p string) {
		if p == "" || seen[p] {
			return
		}
		seen[p] = true
		dirs = append(dirs, p)
	}

	add(filepath.Join(utils.XDGDataHome(), "mime"))

	if env := os.Getenv("XDG_DATA_DIRS"); env != "" {
		for d := range strings.SplitSeq(env, ":") {
			add(filepath.Join(strings.TrimSpace(d), "mime"))
		}
	} else {
		add("/usr/local/share/mime")
		add("/usr/share/mime")
	}

	return dirs
}

func loadAliasTables() {
	aliases := make(map[string]string)
	subclasses := make(map[string][]string)

	for _, dir := range mimeDataDirs() {
		readKV(filepath.Join(dir, "aliases"), func(k, v string) {
			if _, ok := aliases[k]; !ok {
				aliases[k] = v
			}
		})
		readKV(filepath.Join(dir, "subclasses"), func(k, v string) {
			subclasses[k] = append(subclasses[k], v)
		})
	}

	aliasMap = aliases
	subclassMap = subclasses
	aliasLoaded = time.Now()
}

func readKV(path string, fn func(k, v string)) {
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	scanner := bufio.NewScanner(bytes.NewReader(data))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || line[0] == '#' {
			continue
		}
		sp := strings.IndexByte(line, ' ')
		if sp <= 0 {
			continue
		}
		fn(strings.TrimSpace(line[:sp]), strings.TrimSpace(line[sp+1:]))
	}
}

func ensureAliasTables() {
	aliasReloadMu.Lock()
	defer aliasReloadMu.Unlock()

	if aliasMap == nil || time.Since(aliasLoaded) > aliasTTL {
		loadAliasTables()
	}
}

func loadMimeCache() {
	merged := make(map[string][]string)
	seen := make(map[string]map[string]bool)

	for _, dir := range applicationDirs() {
		data, err := os.ReadFile(filepath.Join(dir, "mimeinfo.cache"))
		if err != nil {
			continue
		}
		groups := parseGroups(data)
		g := groups["MIME Cache"]
		if g == nil {
			continue
		}
		for mime, val := range g.keys {
			ids := splitList(val)
			if len(ids) == 0 {
				continue
			}
			if seen[mime] == nil {
				seen[mime] = make(map[string]bool)
			}
			for _, id := range ids {
				if seen[mime][id] {
					continue
				}
				seen[mime][id] = true
				merged[mime] = append(merged[mime], id)
			}
		}
	}

	mimeCacheMap = merged
	mimeCacheLoaded = time.Now()
}

func ensureMimeCache() {
	mimeCacheReloadMu.Lock()
	defer mimeCacheReloadMu.Unlock()

	if mimeCacheMap == nil || time.Since(mimeCacheLoaded) > mimeCacheTTL {
		loadMimeCache()
	}
}

func cacheAppsForMime(mimeType string) []string {
	ensureMimeCache()
	return mimeCacheMap[mimeType]
}

func StripMimeParams(mimeType string) string {
	if semi := strings.IndexByte(mimeType, ';'); semi >= 0 {
		mimeType = mimeType[:semi]
	}
	return strings.TrimSpace(mimeType)
}

func canonicalMime(mimeType string) string {
	ensureAliasTables()
	mimeType = StripMimeParams(mimeType)
	if target, ok := aliasMap[mimeType]; ok {
		return target
	}
	return mimeType
}

func mimeChain(mimeType string) []string {
	ensureAliasTables()

	root := canonicalMime(mimeType)
	visited := map[string]bool{root: true}
	chain := []string{root}

	queue := []string{root}
	for len(queue) > 0 {
		cur := queue[0]
		queue = queue[1:]
		for _, parent := range subclassMap[cur] {
			if visited[parent] {
				continue
			}
			visited[parent] = true
			chain = append(chain, parent)
			queue = append(queue, parent)
		}
	}

	return chain
}

func entrySupportsMime(entry *Entry, chain []string) bool {
	for _, m := range entry.MimeTypes {
		canonical := canonicalMime(m)
		if slices.Contains(chain, canonical) || slices.Contains(chain, m) {
			return true
		}
	}
	return false
}

func GetDefault(mimeType string) string {
	merged := mergedAssociations()
	chain := mimeChain(mimeType)

	for _, m := range chain {
		if id, ok := merged.Defaults[m]; ok {
			if !slices.Contains(merged.Removed[m], id) {
				return id
			}
		}
	}

	for _, m := range chain {
		for _, id := range merged.Added[m] {
			if !slices.Contains(merged.Removed[m], id) {
				return id
			}
		}
	}

	for _, m := range chain {
		for _, id := range cacheAppsForMime(m) {
			if !slices.Contains(merged.Removed[m], id) {
				return id
			}
		}
	}

	for _, m := range chain {
		for _, entry := range AllEntries() {
			if entry.Hidden || entry.NoDisplay {
				continue
			}
			if slices.Contains(merged.Removed[m], entry.ID) {
				continue
			}
			if entrySupportsMime(entry, []string{m}) {
				return entry.ID
			}
		}
	}

	return ""
}

func SetDefault(mimeType, desktopID string) error {
	return setDefaultAssociation(mimeType, desktopID)
}

func SetDefaults(mimeTypes []string, desktopID string) error {
	return setDefaultAssociations(mimeTypes, desktopID)
}

func AppsForMime(mimeType string) []string {
	merged := mergedAssociations()
	chain := mimeChain(mimeType)
	removed := make(map[string]bool)
	for _, m := range chain {
		for _, id := range merged.Removed[m] {
			removed[id] = true
		}
	}

	seen := make(map[string]bool)
	var out []string

	add := func(id string) {
		if id == "" || removed[id] || seen[id] {
			return
		}
		seen[id] = true
		out = append(out, id)
	}

	for _, m := range chain {
		if id := merged.Defaults[m]; id != "" {
			add(id)
		}
		for _, id := range merged.Added[m] {
			add(id)
		}
	}

	for _, m := range chain {
		for _, id := range cacheAppsForMime(m) {
			add(id)
		}
	}

	for _, entry := range AllEntries() {
		if entry.Hidden {
			continue
		}
		if entrySupportsMime(entry, chain) {
			add(entry.ID)
		}
	}

	return out
}

func QueryDefaults(mimeTypes []string) map[string]string {
	out := make(map[string]string, len(mimeTypes))
	for _, m := range mimeTypes {
		out[m] = GetDefault(m)
	}
	return out
}
