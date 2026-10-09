package mangoconf

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// DMS-owned fragments under mango/dms; config.conf is the user's and only
// migrated on request.
var fragments = []string{"binds.conf", "colors.conf", "layout.conf", "cursor.conf", "input.conf", "outputs.conf", "windowrules.conf"}

// Migrate respells the dms fragments, and config.conf (after a backup) when includeMain is set.
// It returns the files rewritten; an unwritable file is reported without stopping the others.
func (d Dialect) Migrate(mangoDir string, includeMain bool) ([]string, error) {
	var changed []string
	var errs []error
	paths := make([]string, 0, len(fragments)+1)
	for _, f := range fragments {
		paths = append(paths, filepath.Join(mangoDir, "dms", f))
	}
	if includeMain {
		paths = append(paths, filepath.Join(mangoDir, "config.conf"))
	}
	for _, path := range paths {
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		translated := d.Translate(string(data))
		if translated == string(data) {
			continue
		}
		if filepath.Base(path) == "config.conf" {
			backup := path + ".backup." + time.Now().Format("2006-01-02_15-04-05")
			if err := os.WriteFile(backup, data, 0o644); err != nil {
				errs = append(errs, fmt.Errorf("backup %s: %w", path, err))
				continue
			}
		}
		if err := os.WriteFile(path, []byte(translated), 0o644); err != nil {
			errs = append(errs, fmt.Errorf("write %s: %w", path, err))
			continue
		}
		changed = append(changed, path)
	}
	return changed, errors.Join(errs...)
}

func (d Dialect) String() string {
	if d == Snake {
		return "snake"
	}
	return "legacy"
}
