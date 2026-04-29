package sysupdate

import (
	"context"
	"fmt"
	"os"
	"os/exec"
)

func Run(ctx context.Context, argv []string) error {
	if len(argv) == 0 {
		return fmt.Errorf("sysupdate.Run: empty argv")
	}
	cmd := exec.CommandContext(ctx, argv[0], argv[1:]...)
	return cmd.Run()
}

func Capture(ctx context.Context, argv []string) (string, error) {
	if len(argv) == 0 {
		return "", fmt.Errorf("sysupdate.Capture: empty argv")
	}
	cmd := exec.CommandContext(ctx, argv[0], argv[1:]...)
	out, err := cmd.Output()
	return string(out), err
}

func findTerminal(override string) string {
	if override != "" && commandExists(override) {
		return override
	}
	if t := os.Getenv("TERMINAL"); t != "" && commandExists(t) {
		return t
	}
	for _, t := range []string{"ghostty", "kitty", "foot", "alacritty", "wezterm", "konsole", "gnome-terminal", "xterm"} {
		if commandExists(t) {
			return t
		}
	}
	return ""
}

func wrapInTerminal(term, title, shellCmd string) []string {
	const appID = "dms-sysupdate"
	banner := fmt.Sprintf(
		`printf '\033[1;36m=== %s ===\033[0m\n'; printf '\033[2m$ %s\033[0m\n'; printf '\033[33mYou may be prompted for your sudo password to apply system updates.\033[0m\n\n'`,
		title, shellCmd,
	)
	closer := `printf '\n\033[1;32m=== Done. Press Enter to close. ===\033[0m\n'; read`
	export := `export SUDO_PROMPT="[DMS] sudo password for %u: "; `
	full := export + banner + "; " + shellCmd + "; " + closer

	switch term {
	case "kitty":
		return []string{term, "--class", appID, "-T", title, "-e", "sh", "-c", full}
	case "alacritty":
		return []string{term, "--class", appID, "-T", title, "-e", "sh", "-c", full}
	case "foot":
		return []string{term, "--app-id=" + appID, "--title=" + title, "-e", "sh", "-c", full}
	case "ghostty":
		return []string{term, "--class=" + appID, "--title=" + title, "-e", "sh", "-c", full}
	case "wezterm":
		return []string{term, "--class", appID, "-T", title, "-e", "sh", "-c", full}
	case "xterm":
		return []string{term, "-class", appID, "-T", title, "-e", "sh", "-c", full}
	case "konsole":
		return []string{term, "-p", "tabtitle=" + title, "-e", "sh", "-c", full}
	case "gnome-terminal":
		return []string{term, "--title=" + title, "--", "sh", "-c", full}
	default:
		return []string{term, "-e", "sh", "-c", full}
	}
}
