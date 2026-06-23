package main

import (
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/privesc"
)

// runit (Void Linux) service helpers. Services live in /etc/sv and are "enabled"
// by symlinking them into the /var/service supervision dir, so the greeter
// commands branch on isRunit() instead of shelling systemctl.

const (
	runitSvDir      = "/etc/sv"
	runitServiceDir = "/var/service"
)

// isRunit reports whether this system is supervised by runit (Void Linux).
func isRunit() bool {
	if fi, err := os.Stat("/run/runit"); err == nil && fi.IsDir() {
		return true
	}
	if _, err := os.Stat("/run/systemd/system"); err == nil {
		return false
	}
	if fi, err := os.Stat(runitServiceDir); err == nil && fi.IsDir() {
		return true
	}
	return false
}

func runitServiceInstalled(name string) bool {
	fi, err := os.Stat(runitSvDir + "/" + name)
	return err == nil && fi.IsDir()
}

func runitServiceEnabled(name string) bool {
	_, err := os.Lstat(runitServiceDir + "/" + name)
	return err == nil
}

// enableRunitService links a service into /var/service (idempotent).
func enableRunitService(name string) error {
	if !runitServiceInstalled(name) {
		return fmt.Errorf("runit service %q not found in %s", name, runitSvDir)
	}
	if runitServiceEnabled(name) {
		return nil
	}
	return privesc.Run(context.Background(), "", "ln", "-sf",
		runitSvDir+"/"+name, runitServiceDir+"/"+name)
}

// disableRunitService removes a service's supervision symlink.
func disableRunitService(name string) error {
	if !runitServiceEnabled(name) {
		return nil
	}
	return privesc.Run(context.Background(), "", "rm", "-f",
		runitServiceDir+"/"+name)
}

// ensureRunitSeat sets up the seat access a Wayland greeter needs on runit (the
// equivalent of logind on systemd): enables seatd and adds the greeter user to
// the seat/video/input groups. Failures are reported but non-fatal.
func ensureRunitSeat(greeterUser string) {
	if runitServiceInstalled("seatd") {
		if err := enableRunitService("seatd"); err != nil {
			fmt.Printf("  ⚠ could not enable seatd: %v\n", err)
		} else {
			fmt.Println("  ✓ seatd enabled")
		}
	} else {
		fmt.Println("  ⚠ seatd not installed — the greeter compositor needs it for GPU/seat access")
	}
	if err := privesc.Run(context.Background(), "", "usermod", "-aG", "_seatd,video,input", greeterUser); err != nil {
		fmt.Printf("  ⚠ could not add %s to seat groups: %v\n", greeterUser, err)
	} else {
		fmt.Printf("  ✓ %s added to seat groups (_seatd, video, input)\n", greeterUser)
	}
}

// ensureGreetdPamRundir adds pam_rundir to the greetd PAM stack so the post-login
// session gets an XDG_RUNTIME_DIR on systems without logind (Void with seatd).
// Appended outside DMS's managed auth block so it survives `dms greeter sync`.
func ensureGreetdPamRundir() {
	const pamPath = "/etc/pam.d/greetd"
	data, err := os.ReadFile(pamPath)
	if err != nil {
		fmt.Printf("  ⚠ could not read %s: %v\n", pamPath, err)
		return
	}
	if strings.Contains(string(data), "pam_rundir") {
		return
	}
	line := "session    optional    pam_rundir.so"
	if err := privesc.Run(context.Background(), "", "sh", "-c",
		fmt.Sprintf("printf '%%s\\n' %q >> %s", line, pamPath)); err != nil {
		fmt.Printf("  ⚠ could not add pam_rundir to %s: %v\n", pamPath, err)
		return
	}
	fmt.Println("  ✓ pam_rundir added to greetd PAM (provides XDG_RUNTIME_DIR for the session)")
}

// startGreeterHint returns the init-appropriate "start greetd now" command.
func startGreeterHint() string {
	if isRunit() {
		return "  sudo sv up greetd"
	}
	return "  sudo systemctl start greetd"
}
