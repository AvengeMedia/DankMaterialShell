package configfrag

import (
	"os"
	"path/filepath"
	"testing"
)

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}
}

func recordingWalker(t *testing.T, isDMS func(string) bool) (*Walker, *[]string, func(string) error) {
	t.Helper()
	var visited []string
	record := func(abs string) error {
		visited = append(visited, abs)
		return nil
	}
	return NewWalker(isDMS), &visited, record
}

func TestAFreshScanReportsNoIncludeAtPositionMinusOne(t *testing.T) {
	scan := NewScan()
	if scan.Count != 0 || scan.DMSSeen || scan.DMSPosition != -1 {
		t.Fatalf("fresh scan = %+v, want count 0, unseen, position -1", scan)
	}
}

func TestARelativeSourceResolvesAgainstTheIncludingFile(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "dms", "binds.conf"), "")

	walker, visited, record := recordingWalker(t, nil)
	walker.Include(dir, "dms/binds.conf", record)

	want := filepath.Join(dir, "dms", "binds.conf")
	if len(*visited) != 1 || (*visited)[0] != want {
		t.Errorf("visited = %v, want [%s]", *visited, want)
	}
}

func TestAnAbsoluteSourceIsUsedAsIs(t *testing.T) {
	dir := t.TempDir()
	abs := filepath.Join(dir, "elsewhere.conf")
	writeFile(t, abs, "")

	walker, visited, record := recordingWalker(t, nil)
	walker.Include(filepath.Join(dir, "ignored"), abs, record)

	if len(*visited) != 1 || (*visited)[0] != abs {
		t.Errorf("visited = %v, want [%s]", *visited, abs)
	}
}

func TestATildeSourceExpandsToHomeAndIsNotJoinedToTheBaseDir(t *testing.T) {
	home, err := os.UserHomeDir()
	if err != nil {
		t.Skipf("no home dir: %v", err)
	}

	walker, visited, record := recordingWalker(t, nil)
	walker.Include(t.TempDir(), "~/dms-walker-probe.conf", record)

	want := filepath.Join(home, "dms-walker-probe.conf")
	if len(*visited) != 1 || (*visited)[0] != want {
		t.Errorf("visited = %v, want [%s]", *visited, want)
	}
}

func TestTheDMSFragmentPositionIsItsOrdinalAmongIncludes(t *testing.T) {
	dir := t.TempDir()
	walker, _, record := recordingWalker(t, func(path string) bool { return path == "dms/binds.conf" })

	walker.Include(dir, "first.conf", record)
	walker.Include(dir, "dms/binds.conf", record)
	walker.Include(dir, "third.conf", record)

	scan := walker.Scan()
	if scan.Count != 3 {
		t.Errorf("count = %d, want 3", scan.Count)
	}
	if !scan.DMSSeen {
		t.Error("the dms fragment must be seen")
	}
	if scan.DMSPosition != 2 {
		t.Errorf("position = %d, want 2", scan.DMSPosition)
	}
}

func TestAMissingSourceStillCountsAsAnInclude(t *testing.T) {
	dir := t.TempDir()
	walker := NewWalker(nil)
	missing := func(abs string) error { return os.ErrNotExist }

	walker.Include(dir, "absent.conf", missing)
	walker.Include(dir, "also-absent.conf", missing)

	if walker.Scan().Count != 2 {
		t.Errorf("count = %d, want 2 even though neither file exists", walker.Scan().Count)
	}
}

func TestAnIncludeCycleTerminates(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "a.conf"), "source = b.conf")
	writeFile(t, filepath.Join(dir, "b.conf"), "source = a.conf")

	seen := map[string]bool{}
	walker := NewWalker(nil)
	var follow func(abs string) error
	follow = func(abs string) error {
		if seen[abs] {
			return nil
		}
		seen[abs] = true
		data, err := os.ReadFile(abs)
		if err != nil {
			return err
		}
		walker.IncludeAssignment(filepath.Dir(abs), string(data), follow)
		return nil
	}

	walker.Include(dir, "a.conf", follow)

	if walker.Scan().Count != 3 {
		t.Errorf("count = %d, want 3 (a, b, and the revisit of a)", walker.Scan().Count)
	}
	if len(seen) != 2 {
		t.Errorf("visited %d distinct files, want 2", len(seen))
	}
}

func TestAnAssignmentWithoutAnEqualsIsNotAnInclude(t *testing.T) {
	walker, visited, record := recordingWalker(t, nil)

	if walker.IncludeAssignment(t.TempDir(), "source", record) {
		t.Error("a line with no = must not match the dms fragment")
	}
	if walker.Scan().Count != 0 {
		t.Errorf("count = %d, want 0", walker.Scan().Count)
	}
	if len(*visited) != 0 {
		t.Errorf("visited = %v, want none", *visited)
	}
}

func TestAnAssignmentTrimsSpaceAroundThePath(t *testing.T) {
	dir := t.TempDir()
	walker, visited, record := recordingWalker(t, func(path string) bool { return path == "dms/binds.conf" })

	if !walker.IncludeAssignment(dir, "source =  dms/binds.conf  ", record) {
		t.Error("the spaced mango form must still match the dms fragment")
	}
	want := filepath.Join(dir, "dms", "binds.conf")
	if len(*visited) != 1 || (*visited)[0] != want {
		t.Errorf("visited = %v, want [%s]", *visited, want)
	}
}

func TestOnlyTheFirstEqualsSplitsTheAssignment(t *testing.T) {
	dir := t.TempDir()
	walker, visited, record := recordingWalker(t, nil)

	walker.IncludeAssignment(dir, "source=a=b.conf", record)

	want := filepath.Join(dir, "a=b.conf")
	if len(*visited) != 1 || (*visited)[0] != want {
		t.Errorf("visited = %v, want [%s]", *visited, want)
	}
}

func TestRecordCountsAnIncludeTheCallerResolvesItself(t *testing.T) {
	walker := NewWalker(func(path string) bool { return path == "dms/binds.lua" })

	if walker.Record("other.lua") {
		t.Error("a non-dms module must not match")
	}
	if !walker.Record("dms/binds.lua") {
		t.Error("the dms module must match")
	}

	scan := walker.Scan()
	if scan.Count != 2 || scan.DMSPosition != 2 || !scan.DMSSeen {
		t.Errorf("scan = %+v, want count 2, position 2, seen", scan)
	}
}
