package drives

import (
	"errors"
	"os"
	"os/exec"
	"regexp"
)

var wholeDiskPath = regexp.MustCompile(`^/dev/[A-Za-z0-9]+$`)

// Report is smartctl's JSON output for one drive. smartctl sets exit bits for drive warnings too, so the output is
// worth reading whatever ExitCode says.
type Report struct {
	Output   string `json:"output"`
	ExitCode int    `json:"exitCode"`
}

// FullReport runs `smartctl -x --json` on a block device. The system monitor's root helper calls it, so the device
// must be a plain /dev path of a block device.
func FullReport(device string) (*Report, error) {
	if !wholeDiskPath.MatchString(device) {
		return nil, errors.New("invalid device")
	}
	fi, err := os.Stat(device)
	if err != nil || fi.Mode()&os.ModeDevice == 0 || fi.Mode()&os.ModeCharDevice != 0 {
		return nil, errors.New("not a block device")
	}
	path := smartctlPath()
	if path == "" {
		return nil, errors.New("smartctl not found")
	}
	out, err := exec.Command(path, "-x", "--json", device).Output()
	var exitErr *exec.ExitError
	switch {
	case errors.As(err, &exitErr):
		return &Report{Output: string(out), ExitCode: exitErr.ExitCode()}, nil
	case err != nil:
		return nil, err
	}
	return &Report{Output: string(out)}, nil
}
