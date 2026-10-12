package drives

import (
	"bufio"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
)

var installCommands = map[distros.DistroFamily]string{
	distros.FamilyArch:   "sudo pacman -S smartmontools",
	distros.FamilyFedora: "sudo dnf install smartmontools",
	distros.FamilyUbuntu: "sudo apt install smartmontools",
	distros.FamilyDebian: "sudo apt install smartmontools",
	distros.FamilySUSE:   "sudo zypper install smartmontools",
	distros.FamilyVoid:   "sudo xbps-install smartmontools",
	distros.FamilyGentoo: "sudo emerge sys-apps/smartmontools",
}

// smartctlPath also checks sbin directories, which are often missing from a user's PATH.
func smartctlPath() string {
	if p, err := exec.LookPath("smartctl"); err == nil {
		if abs, err := filepath.Abs(p); err == nil {
			return abs
		}
	}
	for _, p := range []string{"/usr/sbin/smartctl", "/sbin/smartctl"} {
		if fi, err := os.Stat(p); err == nil && !fi.IsDir() && fi.Mode()&0o111 != 0 {
			return p
		}
	}
	return ""
}

func installCommand(root string) string {
	// An rpm-ostree system can't install packages with dnf.
	if _, err := os.Stat(filepath.Join(root, "run", "ostree-booted")); err == nil {
		return ""
	}
	f, err := os.Open(filepath.Join(root, "etc", "os-release"))
	if err != nil {
		return ""
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		k, v, ok := strings.Cut(scanner.Text(), "=")
		if !ok || k != "ID" {
			continue
		}
		cfg, ok := distros.Registry[strings.Trim(v, "\"'")]
		if !ok {
			return ""
		}
		return installCommands[cfg.Family]
	}
	return ""
}
