package matugen

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

const (
	seedCacheFile    = "matugen-seeds.json"
	seedCacheEntries = 8
)

type seedEntry struct {
	Size    int64  `json:"size"`
	ModTime int64  `json:"modTime"`
	Seed    string `json:"seed"`
	Used    int64  `json:"used"`
}

type seedCache struct {
	path    string
	Entries map[string]seedEntry `json:"entries"`
}

func loadSeedCache(stateDir string) *seedCache {
	cache := &seedCache{
		path:    filepath.Join(stateDir, seedCacheFile),
		Entries: map[string]seedEntry{},
	}
	data, err := os.ReadFile(cache.path)
	if err != nil {
		return cache
	}
	if json.Unmarshal(data, cache) != nil || cache.Entries == nil {
		cache.Entries = map[string]seedEntry{}
	}
	return cache
}

func seedCacheKey(imagePath, sourceMode, matugenVersion string) string {
	if sourceMode != SourceModeColorful && !matugenPreferValues[sourceMode] {
		sourceMode = SourceModeDominant
	}
	return imagePath + "|" + sourceMode + "|" + matugenVersion
}

func (c *seedCache) lookup(imagePath, sourceMode, matugenVersion string) (string, bool) {
	entry, ok := c.Entries[seedCacheKey(imagePath, sourceMode, matugenVersion)]
	if !ok {
		return "", false
	}
	info, err := os.Stat(imagePath)
	if err != nil || info.Size() != entry.Size || info.ModTime().UnixNano() != entry.ModTime {
		return "", false
	}
	return entry.Seed, true
}

func (c *seedCache) resolve(imagePath, sourceMode, matugenVersion string, compute func() (string, error)) (string, error) {
	if seed, ok := c.lookup(imagePath, sourceMode, matugenVersion); ok {
		return seed, nil
	}
	seed, err := compute()
	if err != nil {
		return "", err
	}
	c.store(imagePath, sourceMode, matugenVersion, seed)
	return seed, nil
}

func (c *seedCache) store(imagePath, sourceMode, matugenVersion, seed string) {
	info, err := os.Stat(imagePath)
	if err != nil {
		return
	}
	c.Entries[seedCacheKey(imagePath, sourceMode, matugenVersion)] = seedEntry{
		Size:    info.Size(),
		ModTime: info.ModTime().UnixNano(),
		Seed:    seed,
		Used:    time.Now().UnixNano(),
	}
	c.evict()
	if data, err := json.Marshal(c); err == nil {
		_ = os.WriteFile(c.path, data, 0o644)
	}
}

func (c *seedCache) evict() {
	for len(c.Entries) > seedCacheEntries {
		oldestKey := ""
		oldest := int64(0)
		for key, entry := range c.Entries {
			if oldestKey == "" || entry.Used < oldest {
				oldestKey = key
				oldest = entry.Used
			}
		}
		delete(c.Entries, oldestKey)
	}
}
