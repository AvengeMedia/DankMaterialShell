// Package trash implements the FreeDesktop.org Trash specification 1.0.
// See: https://specifications.freedesktop.org/trash-spec/trashspec-1.0.html
package trash

import (
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const trashInfoExt = ".trashinfo"

type Entry struct {
	Name         string `json:"name"`
	OriginalPath string `json:"originalPath"`
	DeletionDate string `json:"deletionDate"`
	TrashDir     string `json:"trashDir"`
	FilesPath    string `json:"filesPath"`
	InfoPath     string `json:"infoPath"`
	Size         int64  `json:"size"`
	IsDir        bool   `json:"isDir"`
}

func homeTrashDir() (string, error) {
	xdg := os.Getenv("XDG_DATA_HOME")
	if xdg == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		xdg = filepath.Join(home, ".local", "share")
	}
	return filepath.Join(xdg, "Trash"), nil
}

func ensureTrashDirs(trashDir string) error {
	if err := os.MkdirAll(filepath.Join(trashDir, "files"), 0o700); err != nil {
		return err
	}
	return os.MkdirAll(filepath.Join(trashDir, "info"), 0o700)
}

func fsDevice(path string) (uint64, error) {
	var st syscall.Stat_t
	if err := syscall.Lstat(path, &st); err != nil {
		return 0, err
	}
	return uint64(st.Dev), nil
}

func fsDeviceWalkUp(start string) (uint64, error) {
	cur := start
	for {
		if dev, err := fsDevice(cur); err == nil {
			return dev, nil
		}
		parent := filepath.Dir(cur)
		if parent == cur {
			return 0, fmt.Errorf("no existing ancestor for %s", start)
		}
		cur = parent
	}
}

func findTopDir(path string) (string, error) {
	abs, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	dev, err := fsDevice(abs)
	if err != nil {
		return "", err
	}
	cur := abs
	for {
		parent := filepath.Dir(cur)
		if parent == cur {
			return cur, nil
		}
		pdev, err := fsDevice(parent)
		if err != nil {
			return cur, nil
		}
		if pdev != dev {
			return cur, nil
		}
		cur = parent
	}
}

// isValidSharedTrash enforces the spec's checks on $topdir/.Trash:
// must exist, must be a directory, must not be a symlink, must have sticky bit.
func isValidSharedTrash(p string) bool {
	info, err := os.Lstat(p)
	if err != nil {
		return false
	}
	if info.Mode()&os.ModeSymlink != 0 {
		return false
	}
	if !info.IsDir() {
		return false
	}
	return info.Mode()&os.ModeSticky != 0
}

// trashDirForPath chooses the correct trash dir per spec and returns the value
// to store in the .trashinfo Path field (absolute for home, relative-to-topdir
// for per-mountpoint trash).
func trashDirForPath(absPath string) (trashDir string, storedPath string, err error) {
	home, err := homeTrashDir()
	if err != nil {
		return "", "", err
	}

	pathDev, err := fsDevice(absPath)
	if err != nil {
		return "", "", err
	}
	homeDev, err := fsDeviceWalkUp(home)
	if err != nil {
		return "", "", err
	}

	if pathDev == homeDev {
		return home, absPath, nil
	}

	topDir, err := findTopDir(absPath)
	if err != nil {
		return "", "", err
	}

	uid := strconv.Itoa(os.Getuid())
	stored, rerr := filepath.Rel(topDir, absPath)
	if rerr != nil || strings.HasPrefix(stored, "..") {
		stored = absPath
	}

	shared := filepath.Join(topDir, ".Trash")
	if isValidSharedTrash(shared) {
		return filepath.Join(shared, uid), stored, nil
	}
	return filepath.Join(topDir, ".Trash-"+uid), stored, nil
}

// uniqueName returns a basename in trashDir that does not collide with an
// existing entry in either files/ or info/.
func uniqueName(trashDir, basename string) (string, error) {
	filesDir := filepath.Join(trashDir, "files")
	infoDir := filepath.Join(trashDir, "info")
	if !exists(filepath.Join(filesDir, basename)) && !exists(filepath.Join(infoDir, basename+trashInfoExt)) {
		return basename, nil
	}
	ext := filepath.Ext(basename)
	stem := strings.TrimSuffix(basename, ext)
	for i := 2; i < 100000; i++ {
		candidate := fmt.Sprintf("%s.%d%s", stem, i, ext)
		if !exists(filepath.Join(filesDir, candidate)) && !exists(filepath.Join(infoDir, candidate+trashInfoExt)) {
			return candidate, nil
		}
	}
	return "", errors.New("could not find unique trash name")
}

func exists(p string) bool {
	_, err := os.Lstat(p)
	return err == nil
}

// pathEncode percent-escapes a POSIX path per RFC 2396, preserving "/".
func pathEncode(p string) string {
	parts := strings.Split(p, "/")
	for i, seg := range parts {
		parts[i] = url.PathEscape(seg)
	}
	return strings.Join(parts, "/")
}

func pathDecode(p string) string {
	if d, err := url.PathUnescape(p); err == nil {
		return d
	}
	return p
}

func writeTrashInfo(infoPath, storedPath string, when time.Time) error {
	body := "[Trash Info]\nPath=" + pathEncode(storedPath) +
		"\nDeletionDate=" + when.Format("2006-01-02T15:04:05") + "\n"
	f, err := os.OpenFile(infoPath, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = f.WriteString(body)
	return err
}

// Put trashes a single file or directory.
func Put(path string) (Entry, error) {
	abs, err := filepath.Abs(path)
	if err != nil {
		return Entry{}, err
	}
	info, err := os.Lstat(abs)
	if err != nil {
		return Entry{}, err
	}

	trashDir, storedPath, err := trashDirForPath(abs)
	if err != nil {
		return Entry{}, err
	}
	if err := ensureTrashDirs(trashDir); err != nil {
		return Entry{}, fmt.Errorf("create trash dir %s: %w", trashDir, err)
	}

	name, err := uniqueName(trashDir, filepath.Base(abs))
	if err != nil {
		return Entry{}, err
	}

	infoPath := filepath.Join(trashDir, "info", name+trashInfoExt)
	when := time.Now()
	if err := writeTrashInfo(infoPath, storedPath, when); err != nil {
		return Entry{}, err
	}

	target := filepath.Join(trashDir, "files", name)
	if err := os.Rename(abs, target); err != nil {
		os.Remove(infoPath)
		return Entry{}, err
	}

	return Entry{
		Name:         name,
		OriginalPath: storedPath,
		DeletionDate: when.Format("2006-01-02T15:04:05"),
		TrashDir:     trashDir,
		FilesPath:    target,
		InfoPath:     infoPath,
		Size:         info.Size(),
		IsDir:        info.IsDir(),
	}, nil
}

// allTrashDirs returns the home trash plus every per-mountpoint trash dir
// that exists (and passes the spec's safety checks for $topdir/.Trash).
func allTrashDirs() []string {
	var dirs []string
	if h, err := homeTrashDir(); err == nil {
		dirs = append(dirs, h)
	}

	uid := strconv.Itoa(os.Getuid())
	for _, mount := range readMountPoints() {
		shared := filepath.Join(mount, ".Trash")
		if isValidSharedTrash(shared) {
			candidate := filepath.Join(shared, uid)
			if info, err := os.Stat(candidate); err == nil && info.IsDir() {
				dirs = append(dirs, candidate)
			}
		}
		candidate := filepath.Join(mount, ".Trash-"+uid)
		if info, err := os.Lstat(candidate); err == nil && info.IsDir() && info.Mode()&os.ModeSymlink == 0 {
			dirs = append(dirs, candidate)
		}
	}
	return dirs
}

// readMountPoints returns user-visible mount points from /proc/self/mountinfo,
// skipping pseudo and system filesystems.
func readMountPoints() []string {
	data, err := os.ReadFile("/proc/self/mountinfo")
	if err != nil {
		return nil
	}
	skipPrefixes := []string{"/proc", "/sys", "/dev"}
	var out []string
	seen := map[string]bool{}
	for line := range strings.SplitSeq(string(data), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 5 {
			continue
		}
		mp := fields[4]
		if mp == "/" {
			continue
		}
		skip := false
		for _, p := range skipPrefixes {
			if mp == p || strings.HasPrefix(mp, p+"/") {
				skip = true
				break
			}
		}
		if skip || seen[mp] {
			continue
		}
		seen[mp] = true
		out = append(out, mp)
	}
	return out
}

func List() ([]Entry, error) {
	var entries []Entry
	for _, d := range allTrashDirs() {
		es, _ := listOne(d)
		entries = append(entries, es...)
	}
	return entries, nil
}

func listOne(trashDir string) ([]Entry, error) {
	infoDir := filepath.Join(trashDir, "info")
	filesDir := filepath.Join(trashDir, "files")
	dir, err := os.ReadDir(infoDir)
	if err != nil {
		return nil, err
	}
	var entries []Entry
	for _, ent := range dir {
		if !strings.HasSuffix(ent.Name(), trashInfoExt) {
			continue
		}
		name := strings.TrimSuffix(ent.Name(), trashInfoExt)
		infoPath := filepath.Join(infoDir, ent.Name())
		filesPath := filepath.Join(filesDir, name)

		body, err := os.ReadFile(infoPath)
		if err != nil {
			continue
		}

		e := Entry{Name: name, TrashDir: trashDir, InfoPath: infoPath, FilesPath: filesPath}
		for line := range strings.SplitSeq(string(body), "\n") {
			if v, ok := strings.CutPrefix(line, "Path="); ok {
				e.OriginalPath = pathDecode(v)
				continue
			}
			if v, ok := strings.CutPrefix(line, "DeletionDate="); ok {
				e.DeletionDate = v
			}
		}
		if info, err := os.Lstat(filesPath); err == nil {
			e.Size = info.Size()
			e.IsDir = info.IsDir()
		}
		entries = append(entries, e)
	}
	return entries, nil
}

func Count() (int, error) {
	n := 0
	for _, d := range allTrashDirs() {
		ents, err := os.ReadDir(filepath.Join(d, "info"))
		if err != nil {
			continue
		}
		for _, e := range ents {
			if strings.HasSuffix(e.Name(), trashInfoExt) {
				n++
			}
		}
	}
	return n, nil
}

func Empty() error {
	var firstErr error
	for _, d := range allTrashDirs() {
		if err := emptyOne(d); err != nil && firstErr == nil {
			firstErr = err
		}
	}
	return firstErr
}

func emptyOne(trashDir string) error {
	var firstErr error
	for _, sub := range []string{"files", "info"} {
		path := filepath.Join(trashDir, sub)
		ents, err := os.ReadDir(path)
		if err != nil {
			continue
		}
		for _, e := range ents {
			if err := os.RemoveAll(filepath.Join(path, e.Name())); err != nil && firstErr == nil {
				firstErr = err
			}
		}
	}
	os.Remove(filepath.Join(trashDir, "directorysizes"))
	return firstErr
}

// Restore returns a trashed item to its original location.
func Restore(name, trashDir string) error {
	if trashDir == "" {
		h, err := homeTrashDir()
		if err != nil {
			return err
		}
		trashDir = h
	}

	infoPath := filepath.Join(trashDir, "info", name+trashInfoExt)
	filesPath := filepath.Join(trashDir, "files", name)

	body, err := os.ReadFile(infoPath)
	if err != nil {
		return err
	}

	var stored string
	for line := range strings.SplitSeq(string(body), "\n") {
		if v, ok := strings.CutPrefix(line, "Path="); ok {
			stored = pathDecode(v)
			break
		}
	}
	if stored == "" {
		return errors.New("invalid .trashinfo: missing Path")
	}

	target := stored
	if !filepath.IsAbs(stored) {
		topDir := filepath.Dir(trashDir)
		if filepath.Base(topDir) == ".Trash" {
			topDir = filepath.Dir(topDir)
		}
		target = filepath.Join(topDir, stored)
	}

	if exists(target) {
		return fmt.Errorf("restore target already exists: %s", target)
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return err
	}
	if err := os.Rename(filesPath, target); err != nil {
		return err
	}
	os.Remove(infoPath)
	return nil
}
