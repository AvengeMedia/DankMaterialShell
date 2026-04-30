package trash

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func setupHomeTrash(t *testing.T) (homeRoot string, trashDir string) {
	t.Helper()
	homeRoot = t.TempDir()
	xdg := filepath.Join(homeRoot, ".local", "share")
	if err := os.MkdirAll(xdg, 0o700); err != nil {
		t.Fatalf("mkdir xdg: %v", err)
	}
	t.Setenv("XDG_DATA_HOME", xdg)
	t.Setenv("HOME", homeRoot)
	trashDir = filepath.Join(xdg, "Trash")
	return homeRoot, trashDir
}

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

func TestPutHomeTrashAbsolutePath(t *testing.T) {
	homeRoot, trashDir := setupHomeTrash(t)

	src := filepath.Join(homeRoot, "doc.txt")
	writeFile(t, src, "hi")

	entry, err := Put(src)
	if err != nil {
		t.Fatalf("Put: %v", err)
	}

	if entry.Name != "doc.txt" {
		t.Errorf("name = %q, want doc.txt", entry.Name)
	}
	if entry.OriginalPath != src {
		t.Errorf("originalPath = %q, want %q", entry.OriginalPath, src)
	}
	if entry.TrashDir != trashDir {
		t.Errorf("trashDir = %q, want %q", entry.TrashDir, trashDir)
	}
	if _, err := os.Stat(src); !os.IsNotExist(err) {
		t.Errorf("source still exists: %v", err)
	}

	body, err := os.ReadFile(filepath.Join(trashDir, "info", "doc.txt.trashinfo"))
	if err != nil {
		t.Fatalf("read trashinfo: %v", err)
	}
	if !strings.HasPrefix(string(body), "[Trash Info]\n") {
		t.Errorf("trashinfo missing header: %q", body)
	}
	if !strings.Contains(string(body), "Path="+src+"\n") {
		t.Errorf("Path key missing or wrong: %q", body)
	}
	if !strings.Contains(string(body), "DeletionDate=") {
		t.Errorf("DeletionDate missing: %q", body)
	}
}

func TestPutPercentEncodesPath(t *testing.T) {
	homeRoot, trashDir := setupHomeTrash(t)

	name := "spaces & %.txt"
	src := filepath.Join(homeRoot, name)
	writeFile(t, src, "x")

	if _, err := Put(src); err != nil {
		t.Fatalf("Put: %v", err)
	}

	body, err := os.ReadFile(filepath.Join(trashDir, "info", name+".trashinfo"))
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	want := "Path=" + filepath.Dir(src) + "/spaces%20&%20%25.txt"
	if !strings.Contains(string(body), want) {
		t.Errorf("expected %q in %q", want, body)
	}
}

func TestPutCollisionGetsUniqueName(t *testing.T) {
	homeRoot, trashDir := setupHomeTrash(t)

	for i := range 3 {
		src := filepath.Join(homeRoot, "dup.txt")
		writeFile(t, src, "x")
		if _, err := Put(src); err != nil {
			t.Fatalf("Put #%d: %v", i, err)
		}
	}

	want := []string{"dup.txt", "dup.2.txt", "dup.3.txt"}
	for _, n := range want {
		if _, err := os.Stat(filepath.Join(trashDir, "files", n)); err != nil {
			t.Errorf("expected %s in trash: %v", n, err)
		}
		if _, err := os.Stat(filepath.Join(trashDir, "info", n+".trashinfo")); err != nil {
			t.Errorf("expected %s.trashinfo: %v", n, err)
		}
	}
}

func TestListAndCount(t *testing.T) {
	homeRoot, _ := setupHomeTrash(t)

	if n, _ := Count(); n != 0 {
		t.Errorf("initial count = %d, want 0", n)
	}
	entries, _ := List()
	if len(entries) != 0 {
		t.Errorf("initial list len = %d, want 0", len(entries))
	}

	for _, n := range []string{"a.txt", "b.txt", "c.log"} {
		src := filepath.Join(homeRoot, n)
		writeFile(t, src, n)
		if _, err := Put(src); err != nil {
			t.Fatalf("Put %s: %v", n, err)
		}
	}

	got, _ := Count()
	if got != 3 {
		t.Errorf("count = %d, want 3", got)
	}
	entries, _ = List()
	if len(entries) != 3 {
		t.Errorf("list len = %d, want 3", len(entries))
	}
	for _, e := range entries {
		if e.OriginalPath == "" {
			t.Errorf("entry %s: empty OriginalPath", e.Name)
		}
		if _, err := time.Parse("2006-01-02T15:04:05", e.DeletionDate); err != nil {
			t.Errorf("entry %s: bad DeletionDate %q: %v", e.Name, e.DeletionDate, err)
		}
	}
}

func TestEmptyClearsAll(t *testing.T) {
	homeRoot, trashDir := setupHomeTrash(t)

	for _, n := range []string{"x", "y", "z"} {
		src := filepath.Join(homeRoot, n)
		writeFile(t, src, n)
		if _, err := Put(src); err != nil {
			t.Fatalf("Put: %v", err)
		}
	}
	if n, _ := Count(); n != 3 {
		t.Fatalf("pre-empty count = %d", n)
	}

	if err := Empty(); err != nil {
		t.Fatalf("Empty: %v", err)
	}

	if n, _ := Count(); n != 0 {
		t.Errorf("post-empty count = %d, want 0", n)
	}
	for _, sub := range []string{"files", "info"} {
		ents, err := os.ReadDir(filepath.Join(trashDir, sub))
		if err != nil {
			t.Fatalf("readdir %s: %v", sub, err)
		}
		if len(ents) != 0 {
			t.Errorf("%s/ has %d entries, want 0", sub, len(ents))
		}
	}
}

func TestRestoreToOriginalPath(t *testing.T) {
	homeRoot, trashDir := setupHomeTrash(t)

	src := filepath.Join(homeRoot, "sub", "dir", "thing.txt")
	writeFile(t, src, "payload")

	entry, err := Put(src)
	if err != nil {
		t.Fatalf("Put: %v", err)
	}

	os.RemoveAll(filepath.Join(homeRoot, "sub"))

	if err := Restore(entry.Name, trashDir); err != nil {
		t.Fatalf("Restore: %v", err)
	}

	body, err := os.ReadFile(src)
	if err != nil {
		t.Fatalf("read restored: %v", err)
	}
	if string(body) != "payload" {
		t.Errorf("restored content = %q, want %q", body, "payload")
	}

	if _, err := os.Stat(entry.InfoPath); !os.IsNotExist(err) {
		t.Errorf("info file still present: %v", err)
	}
	if _, err := os.Stat(entry.FilesPath); !os.IsNotExist(err) {
		t.Errorf("files entry still present: %v", err)
	}
}

func TestRestoreRefusesToOverwrite(t *testing.T) {
	homeRoot, trashDir := setupHomeTrash(t)

	src := filepath.Join(homeRoot, "keep.txt")
	writeFile(t, src, "v1")

	entry, err := Put(src)
	if err != nil {
		t.Fatalf("Put: %v", err)
	}

	writeFile(t, src, "v2-blocking")

	err = Restore(entry.Name, trashDir)
	if err == nil {
		t.Fatalf("expected error on conflicting restore, got nil")
	}
	if !strings.Contains(err.Error(), "exists") {
		t.Errorf("error %q does not mention conflict", err)
	}

	body, _ := os.ReadFile(src)
	if string(body) != "v2-blocking" {
		t.Errorf("blocking file altered: %q", body)
	}
}

func TestPutDirectory(t *testing.T) {
	homeRoot, trashDir := setupHomeTrash(t)

	dir := filepath.Join(homeRoot, "myfolder")
	writeFile(t, filepath.Join(dir, "child.txt"), "inside")

	entry, err := Put(dir)
	if err != nil {
		t.Fatalf("Put dir: %v", err)
	}
	if !entry.IsDir {
		t.Errorf("IsDir = false, want true")
	}

	moved := filepath.Join(trashDir, "files", "myfolder", "child.txt")
	body, err := os.ReadFile(moved)
	if err != nil {
		t.Fatalf("read moved child: %v", err)
	}
	if string(body) != "inside" {
		t.Errorf("child content = %q", body)
	}
}

func TestIsValidSharedTrashRejectsSymlink(t *testing.T) {
	tmp := t.TempDir()
	target := filepath.Join(tmp, "real")
	if err := os.MkdirAll(target, os.ModeSticky|0o777); err != nil {
		t.Fatalf("mkdir target: %v", err)
	}

	link := filepath.Join(tmp, ".Trash")
	if err := os.Symlink(target, link); err != nil {
		t.Fatalf("symlink: %v", err)
	}
	if isValidSharedTrash(link) {
		t.Errorf("symlinked .Trash accepted; spec requires rejection")
	}
}

func TestIsValidSharedTrashRequiresStickyBit(t *testing.T) {
	tmp := t.TempDir()
	dir := filepath.Join(tmp, ".Trash")
	if err := os.MkdirAll(dir, 0o777); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if isValidSharedTrash(dir) {
		t.Errorf(".Trash without sticky bit accepted; spec requires rejection")
	}

	if err := os.Chmod(dir, os.ModeSticky|0o777); err != nil {
		t.Fatalf("chmod: %v", err)
	}
	if !isValidSharedTrash(dir) {
		t.Errorf(".Trash with sticky bit rejected; spec accepts it")
	}
}

func TestPathEncodeRoundTrip(t *testing.T) {
	cases := []string{
		"/home/u/file.txt",
		"/path with spaces/and-symbols & %.txt",
		"relative/path/é unicode.md",
	}
	for _, in := range cases {
		got := pathDecode(pathEncode(in))
		if got != in {
			t.Errorf("round-trip %q -> %q", in, got)
		}
	}
}
