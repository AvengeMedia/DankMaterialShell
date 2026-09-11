package main

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
	"github.com/spf13/cobra"
)

var greeterCmd = &cobra.Command{
	Use:                "greeter",
	Short:              "Deprecated: moved to the standalone dms-greeter binary",
	Long:               "The greeter has moved to the standalone dms-greeter package.\nThis command forwards to 'dms-greeter' when it is installed.",
	DisableFlagParsing: true,
	SilenceUsage:       true,
	RunE: func(_ *cobra.Command, args []string) error {
		binary, err := exec.LookPath("dms-greeter")
		if err != nil {
			return fmt.Errorf("'dms greeter' has moved to the standalone dms-greeter package.\n  %s", greeterPackageInstallHint())
		}
		if isLegacyWrapperScript(binary) {
			return fmt.Errorf("'dms greeter' has moved to the standalone dms-greeter package; %s is the old wrapper script.\n  %s", binary, greeterPackageInstallHint())
		}
		fmt.Fprintln(os.Stderr, "warning: 'dms greeter' is deprecated; use 'dms-greeter' directly")
		return syscall.Exec(binary, append([]string{"dms-greeter"}, args...), os.Environ())
	},
}

func isLegacyWrapperScript(path string) bool {
	file, err := os.Open(path)
	if err != nil {
		return false
	}
	defer file.Close()
	header := make([]byte, 2)
	if _, err := file.Read(header); err != nil {
		return false
	}
	return string(header) == "#!"
}

func greeterPackageInstallHint() string {
	osInfo, err := distros.GetOSInfo()
	if err != nil {
		return "Install package: dms-greeter"
	}
	config, exists := distros.Registry[osInfo.Distribution.ID]
	if !exists {
		return "Install package: dms-greeter"
	}

	switch config.Family {
	case distros.FamilyDebian:
		return "Install with 'sudo apt install dms-greeter' (requires DankLinux OBS repo — see https://danklinux.com/docs/dankgreeter/installation#debian)"
	case distros.FamilySUSE:
		return "Install with 'sudo zypper install dms-greeter' (requires DankLinux OBS repo — see https://danklinux.com/docs/dankgreeter/installation#opensuse)"
	case distros.FamilyUbuntu:
		return "Install with 'sudo apt install dms-greeter' (requires ppa:avengemedia/danklinux: sudo add-apt-repository ppa:avengemedia/danklinux)"
	case distros.FamilyFedora:
		return "Install with 'sudo dnf install dms-greeter' (requires COPR: sudo dnf copr enable avengemedia/danklinux)"
	case distros.FamilyArch:
		return "Install from AUR with 'paru -S greetd-dms-greeter-bin' or 'yay -S greetd-dms-greeter-bin'"
	case distros.FamilyVoid:
		return "Install with 'sudo xbps-install -S dms-greeter' (requires DMS XBPS repo: echo 'repository=https://void.danklinux.com/dms/current' | sudo tee /etc/xbps.d/dms.conf)"
	default:
		return "Install the dms-greeter package for your distribution"
	}
}
