package desktop

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSetDefaultsPreservesUnrelatedContent(t *testing.T) {
	configHome, _ := setupFakeXDG(t)
	path := filepath.Join(configHome, "mimeapps.list")
	writeFile(t, path, `# managed by hand
[Default Applications]
text/html=firefox.desktop
# pinned image viewer
image/png=eog.desktop

[Added Associations]
text/html=firefox.desktop;

[Custom Section]
foo=bar
`)

	if err := SetDefaults([]string{"inode/directory", "x-scheme-handler/sftp"}, "org.kde.dolphin.desktop"); err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	got := string(data)

	preserved := []string{
		"# managed by hand",
		"# pinned image viewer",
		"text/html=firefox.desktop",
		"image/png=eog.desktop",
		"[Custom Section]",
		"foo=bar",
	}
	for _, want := range preserved {
		if !strings.Contains(got, want) {
			t.Errorf("rewrite lost %q:\n%s", want, got)
		}
	}

	written := []string{
		"inode/directory=org.kde.dolphin.desktop",
		"x-scheme-handler/sftp=org.kde.dolphin.desktop",
	}
	for _, want := range written {
		if !strings.Contains(got, want) {
			t.Errorf("rewrite missing %q:\n%s", want, got)
		}
	}

	if got := GetDefault("inode/directory"); got != "org.kde.dolphin.desktop" {
		t.Errorf("GetDefault(inode/directory) = %q", got)
	}
	if got := GetDefault("x-scheme-handler/sftp"); got != "org.kde.dolphin.desktop" {
		t.Errorf("GetDefault(x-scheme-handler/sftp) = %q", got)
	}
}

func TestSetDefaultReplacesKeyInPlace(t *testing.T) {
	configHome, _ := setupFakeXDG(t)
	path := filepath.Join(configHome, "mimeapps.list")
	writeFile(t, path, `[Default Applications]
inode/directory=foot.desktop
text/html=firefox.desktop
`)

	if err := SetDefault("inode/directory", "org.gnome.Nautilus.desktop"); err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	got := string(data)

	if n := strings.Count(got, "inode/directory=org.gnome.Nautilus.desktop\n"); n != 1 {
		t.Errorf("expected exactly one replaced default line, got %d:\n%s", n, got)
	}
	if strings.Contains(got, "foot.desktop") {
		t.Errorf("old default still present:\n%s", got)
	}
	if !strings.Contains(got, "text/html=firefox.desktop") {
		t.Errorf("unrelated default lost:\n%s", got)
	}
}

func TestSetDefaultsCreatesFileWhenAbsent(t *testing.T) {
	configHome, _ := setupFakeXDG(t)
	path := filepath.Join(configHome, "mimeapps.list")

	if err := SetDefaults([]string{"inode/directory", "x-scheme-handler/sftp"}, "org.kde.dolphin"); err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	got := string(data)

	expected := []string{
		"[Default Applications]",
		"inode/directory=org.kde.dolphin.desktop",
		"x-scheme-handler/sftp=org.kde.dolphin.desktop",
		"[Added Associations]",
	}
	for _, want := range expected {
		if !strings.Contains(got, want) {
			t.Errorf("new file missing %q:\n%s", want, got)
		}
	}

	entries, err := os.ReadDir(configHome)
	if err != nil {
		t.Fatal(err)
	}
	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".tmp") {
			t.Errorf("leftover temp file %q", e.Name())
		}
	}
}

func TestSetDefaultClearsRemovedAssociation(t *testing.T) {
	configHome, _ := setupFakeXDG(t)
	path := filepath.Join(configHome, "mimeapps.list")
	writeFile(t, path, `[Removed Associations]
inode/directory=org.kde.dolphin.desktop;other.desktop;
`)

	if err := SetDefault("inode/directory", "org.kde.dolphin.desktop"); err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	got := string(data)

	if !strings.Contains(got, "inode/directory=other.desktop;") {
		t.Errorf("unrelated removed entry lost:\n%s", got)
	}
	if strings.Contains(got, "org.kde.dolphin.desktop;other.desktop") {
		t.Errorf("chosen app still in removed list:\n%s", got)
	}
	if got := GetDefault("inode/directory"); got != "org.kde.dolphin.desktop" {
		t.Errorf("GetDefault = %q", got)
	}
}

func TestHandlersForMimeExcludesTerminalAndNoDisplay(t *testing.T) {
	_, dataHome := setupFakeXDG(t)
	apps := filepath.Join(dataHome, "applications")
	writeFile(t, filepath.Join(apps, "org.kde.dolphin.desktop"), `[Desktop Entry]
Type=Application
Name=Dolphin
Icon=system-file-manager
MimeType=inode/directory;
`)
	writeFile(t, filepath.Join(apps, "ghost-term.desktop"), `[Desktop Entry]
Type=Application
Name=Ghost Terminal
Terminal=true
MimeType=inode/directory;
`)
	writeFile(t, filepath.Join(apps, "hidden-fm.desktop"), `[Desktop Entry]
Type=Application
Name=Hidden FM
NoDisplay=true
MimeType=inode/directory;
`)
	writeFile(t, filepath.Join(apps, "mimeinfo.cache"), `[MIME Cache]
inode/directory=ghost-term.desktop;org.kde.dolphin.desktop;hidden-fm.desktop;stale.desktop;
`)

	handlers := HandlersForMime("inode/directory")
	byID := make(map[string]*Entry, len(handlers))
	for _, h := range handlers {
		byID[h.ID] = h
	}

	dolphin := byID["org.kde.dolphin.desktop"]
	if dolphin == nil {
		t.Fatal("org.kde.dolphin.desktop missing from handlers")
	}
	if dolphin.Name != "Dolphin" {
		t.Errorf("Name = %q", dolphin.Name)
	}
	if dolphin.Icon != "system-file-manager" {
		t.Errorf("Icon = %q", dolphin.Icon)
	}

	excluded := []string{"ghost-term.desktop", "hidden-fm.desktop", "stale.desktop"}
	for _, id := range excluded {
		if byID[id] != nil {
			t.Errorf("%s should be excluded from handlers", id)
		}
	}
}
