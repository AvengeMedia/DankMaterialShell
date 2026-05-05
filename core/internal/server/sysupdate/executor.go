package sysupdate

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"sync"
	"syscall"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/privesc"
)

type RunOptions struct {
	Env         []string
	OnLine      func(string)
	AttachStdio bool
}

func Run(ctx context.Context, argv []string, opts RunOptions) error {
	if len(argv) == 0 {
		return fmt.Errorf("sysupdate.Run: empty argv")
	}

	cmd := exec.CommandContext(ctx, argv[0], argv[1:]...)
	if len(opts.Env) > 0 {
		cmd.Env = append(cmd.Environ(), opts.Env...)
	}
	if opts.AttachStdio {
		cmd.Cancel = func() error {
			if cmd.Process == nil {
				return nil
			}
			return cmd.Process.Kill()
		}
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		return cmd.Run()
	}

	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error {
		if cmd.Process == nil {
			return nil
		}
		return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
	}

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}

	if err := cmd.Start(); err != nil {
		return err
	}

	var wg sync.WaitGroup
	wg.Add(2)
	go pump(stdout, opts.OnLine, &wg)
	go pump(stderr, opts.OnLine, &wg)
	wg.Wait()

	return cmd.Wait()
}

func pump(r io.Reader, onLine func(string), wg *sync.WaitGroup) {
	defer wg.Done()
	if onLine == nil {
		_, _ = io.Copy(io.Discard, r)
		return
	}
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		onLine(scanner.Text())
	}
}

func Capture(ctx context.Context, argv []string) (string, error) {
	if len(argv) == 0 {
		return "", fmt.Errorf("sysupdate.Capture: empty argv")
	}
	cmd := exec.CommandContext(ctx, argv[0], argv[1:]...)
	out, err := cmd.Output()
	return string(out), err
}

// privescBin returns the binary to use for privilege escalation.
// When useSudo is true it auto-detects the best available tool (sudo/doas/run0).
// When false it falls back to pkexec for GUI callers.
func privescBin(useSudo bool) string {
	if useSudo {
		if t, err := privesc.Detect(); err == nil {
			return t.Name()
		}
	}
	return "pkexec"
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
