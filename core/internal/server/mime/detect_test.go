package mime

import (
	"os"
	"path/filepath"
	"testing"
)

func writeGlobs(t *testing.T, dataDir, content string) {
	t.Helper()
	dir := filepath.Join(dataDir, "mime")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "globs2"), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestMimeTypeForPathGlobRanking(t *testing.T) {
	home := t.TempDir()
	system := t.TempDir()
	t.Setenv("XDG_DATA_HOME", home)
	t.Setenv("XDG_DATA_DIRS", system)
	writeGlobs(t, system, `# generated
50:text/x-makefile:makefile
50:application/gzip:*.gz
50:application/x-compressed-tar:*.tar.gz
50:text/x-c++src:*.C:cs
50:text/x-csrc:*.c
55:text/x-diff:*.patch
50:text/x-patch:*.patch
50:text/plain:*.txt
50:application/json:*.json
`)
	writeGlobs(t, home, `0:application/json:__NOGLOBS__
50:text/x-myjson:*.json
`)

	dir := t.TempDir()
	cases := []struct{ path, want string }{
		{"/home/u/test.txt", "text/plain"},
		{"/home/u/Makefile", "text/x-makefile"},
		{"/home/u/data.tar.gz", "application/x-compressed-tar"},
		{"/home/u/main.C", "text/x-c++src"},
		{"/home/u/main.c", "text/x-csrc"},
		{"/home/u/fix.patch", "text/x-diff"},
		{"/home/u/NOTES.TXT", "text/plain"},
		{"/home/u/config.json", "text/x-myjson"},
		{"/home/u/unknown.zzz", ""},
		{dir, "inode/directory"},
	}
	for _, c := range cases {
		if got := MimeTypeForPath(c.path); got != c.want {
			t.Errorf("%s: got %q, want %q", c.path, got, c.want)
		}
	}
}
