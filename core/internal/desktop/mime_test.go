package desktop

import (
	"os"
	"path/filepath"
	"sync"
	"testing"
)

func setupFakeXDG(t *testing.T) (configHome, dataHome string) {
	t.Helper()
	tmp := t.TempDir()
	configHome = filepath.Join(tmp, "config")
	dataHome = filepath.Join(tmp, "data")
	if err := os.MkdirAll(filepath.Join(dataHome, "applications"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(configHome, 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_CONFIG_HOME", configHome)
	t.Setenv("XDG_DATA_HOME", dataHome)
	t.Setenv("XDG_DATA_DIRS", dataHome)
	t.Setenv("XDG_CONFIG_DIRS", configHome)
	InvalidateCache()

	mimeCacheReloadMu.Lock()
	mimeCacheMap = nil
	mimeCacheReloadMu.Unlock()
	aliasReloadMu.Lock()
	aliasMap = nil
	subclassMap = nil
	aliasReloadMu.Unlock()

	return configHome, dataHome
}

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestParseDesktopEntry(t *testing.T) {
	_, dataHome := setupFakeXDG(t)
	writeFile(t, filepath.Join(dataHome, "applications", "test.desktop"), `[Desktop Entry]
Type=Application
Name=Test
Exec=test %f
Icon=test
MimeType=application/pdf;image/png;
Categories=Office;Viewer;
NoDisplay=false
`)

	entry := EntryByID("test.desktop")
	if entry == nil {
		t.Fatal("entry not found")
	}
	if entry.Name != "Test" {
		t.Errorf("Name = %q", entry.Name)
	}
	if len(entry.MimeTypes) != 2 || entry.MimeTypes[0] != "application/pdf" {
		t.Errorf("MimeTypes = %v", entry.MimeTypes)
	}
	if len(entry.Categories) != 2 || entry.Categories[1] != "Viewer" {
		t.Errorf("Categories = %v", entry.Categories)
	}
}

func TestSetGetDefault(t *testing.T) {
	configHome, dataHome := setupFakeXDG(t)
	writeFile(t, filepath.Join(dataHome, "applications", "foo.desktop"), `[Desktop Entry]
Type=Application
Name=Foo
MimeType=application/pdf;
`)
	writeFile(t, filepath.Join(dataHome, "applications", "bar.desktop"), `[Desktop Entry]
Type=Application
Name=Bar
MimeType=application/pdf;
`)

	if err := SetDefault("application/pdf", "bar.desktop"); err != nil {
		t.Fatal(err)
	}

	if got := GetDefault("application/pdf"); got != "bar.desktop" {
		t.Errorf("GetDefault = %q want bar.desktop", got)
	}

	data, err := os.ReadFile(filepath.Join(configHome, "mimeapps.list"))
	if err != nil {
		t.Fatal(err)
	}
	if !contains(string(data), "application/pdf=bar.desktop") {
		t.Errorf("mimeapps.list missing default:\n%s", string(data))
	}
}

func TestSetDefaultBypassesMimeSupportCheck(t *testing.T) {
	configHome, dataHome := setupFakeXDG(t)
	writeFile(t, filepath.Join(dataHome, "applications", "dms-open.desktop"), `[Desktop Entry]
Type=Application
Name=DMS
MimeType=x-scheme-handler/http;
`)

	if err := SetDefault("application/pdf", "dms-open.desktop"); err != nil {
		t.Fatal(err)
	}

	if got := GetDefault("application/pdf"); got != "dms-open.desktop" {
		t.Errorf("GetDefault = %q, want dms-open.desktop (native impl must not enforce MimeType= check)", got)
	}

	data, _ := os.ReadFile(filepath.Join(configHome, "mimeapps.list"))
	if !contains(string(data), "application/pdf=dms-open.desktop") {
		t.Errorf("mimeapps.list missing override:\n%s", string(data))
	}
}

func TestAliasResolution(t *testing.T) {
	_, dataHome := setupFakeXDG(t)
	writeFile(t, filepath.Join(dataHome, "mime", "aliases"), "text/javascript application/javascript\n")
	writeFile(t, filepath.Join(dataHome, "applications", "editor.desktop"), `[Desktop Entry]
Type=Application
Name=Editor
MimeType=application/javascript;
`)
	writeFile(t, filepath.Join(dataHome, "applications", "mimeinfo.cache"), `[MIME Cache]
application/javascript=editor.desktop;
`)

	if got := GetDefault("text/javascript"); got != "editor.desktop" {
		t.Errorf("GetDefault(text/javascript) = %q want editor.desktop (alias resolution)", got)
	}
}

func TestSetDefaultsBatch(t *testing.T) {
	configHome, dataHome := setupFakeXDG(t)
	writeFile(t, filepath.Join(dataHome, "applications", "dms-open.desktop"), `[Desktop Entry]
Type=Application
Name=DMS
MimeType=x-scheme-handler/http;
`)

	mimes := []string{
		"text/plain", "text/x-csrc", "text/x-python",
		"text/x-shellscript", "application/json",
	}
	if err := SetDefaults(mimes, "dms-open.desktop"); err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(filepath.Join(configHome, "mimeapps.list"))
	if err != nil {
		t.Fatal(err)
	}
	for _, m := range mimes {
		if !contains(string(data), m+"=dms-open.desktop") {
			t.Errorf("missing %s default in mimeapps.list:\n%s", m, string(data))
		}
	}
}

func TestConcurrentSetDefaultNoCorruption(t *testing.T) {
	configHome, dataHome := setupFakeXDG(t)
	writeFile(t, filepath.Join(dataHome, "applications", "app.desktop"), `[Desktop Entry]
Type=Application
Name=App
`)

	mimes := []string{
		"a/1", "a/2", "a/3", "a/4", "a/5", "a/6", "a/7",
	}

	var wg sync.WaitGroup
	for _, m := range mimes {
		wg.Add(1)
		go func(m string) {
			defer wg.Done()
			if err := SetDefault(m, "app.desktop"); err != nil {
				t.Errorf("SetDefault(%s) failed: %v", m, err)
			}
		}(m)
	}
	wg.Wait()

	data, err := os.ReadFile(filepath.Join(configHome, "mimeapps.list"))
	if err != nil {
		t.Fatal(err)
	}
	for _, m := range mimes {
		if !contains(string(data), m+"=app.desktop") {
			t.Errorf("lost write for %s — concurrent writes corrupted file:\n%s", m, string(data))
		}
	}
}

func TestMimeCacheOrdering(t *testing.T) {
	_, dataHome := setupFakeXDG(t)
	writeFile(t, filepath.Join(dataHome, "applications", "a.desktop"), `[Desktop Entry]
Type=Application
Name=A
MimeType=image/png;
`)
	writeFile(t, filepath.Join(dataHome, "applications", "b.desktop"), `[Desktop Entry]
Type=Application
Name=B
MimeType=image/png;
`)
	writeFile(t, filepath.Join(dataHome, "applications", "mimeinfo.cache"), `[MIME Cache]
image/png=b.desktop;a.desktop;
`)

	if got := GetDefault("image/png"); got != "b.desktop" {
		t.Errorf("GetDefault should follow mimeinfo.cache order: got %q want b.desktop", got)
	}
}

func contains(haystack, needle string) bool {
	for i := 0; i+len(needle) <= len(haystack); i++ {
		if haystack[i:i+len(needle)] == needle {
			return true
		}
	}
	return false
}
