package matugen

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestSeedCacheLookupInvalidation(t *testing.T) {
	dir := t.TempDir()
	img := filepath.Join(dir, "wall.png")
	assert.NoError(t, os.WriteFile(img, []byte("a"), 0o644))

	loadSeedCache(dir).store(img, "dominant", "4.2.0", "#6c46dc")
	cache := loadSeedCache(dir)

	seed, ok := cache.lookup(img, "dominant", "4.2.0")
	assert.True(t, ok)
	assert.Equal(t, "#6c46dc", seed)

	_, ok = cache.lookup(img, "colorful", "4.2.0")
	assert.False(t, ok, "source mode is part of the key")
	seed, ok = cache.lookup(img, "", "4.2.0")
	assert.True(t, ok, "empty mode is dominant")
	assert.Equal(t, "#6c46dc", seed)
	_, ok = cache.lookup(img, "dominant", "4.3.0")
	assert.False(t, ok, "matugen version is part of the key")

	assert.NoError(t, os.WriteFile(img, []byte("ab"), 0o644))
	_, ok = cache.lookup(img, "dominant", "4.2.0")
	assert.False(t, ok, "rewritten file must miss")
}
