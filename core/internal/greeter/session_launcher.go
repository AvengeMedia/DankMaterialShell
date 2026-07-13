package greeter

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

func sessionDesktopIDFromPath(path string) string {
	id := strings.TrimSpace(path)
	if id == "" {
		return ""
	}
	if strings.ContainsAny(id, "/\\") {
		id = filepath.Base(id)
	}
	if id == "" {
		return ""
	}
	if !strings.HasSuffix(id, ".desktop") {
		id += ".desktop"
	}
	return id
}

func sessionDesktopIDFromMemory(mem greeterAutoLoginMemory) string {
	if id := sessionDesktopIDFromPath(mem.LastSessionDesktopID); id != "" {
		return id
	}
	return sessionDesktopIDFromPath(mem.LastSessionID)
}

func sessionDesktopDirs() []string {
	seen := make(map[string]bool)
	dirs := make([]string, 0, 8)

	addBase := func(base string) {
		base = strings.TrimSpace(base)
		if base == "" {
			return
		}
		for _, sub := range []string{"wayland-sessions", "xsessions"} {
			dir := filepath.Join(base, sub)
			if seen[dir] {
				continue
			}
			seen[dir] = true
			dirs = append(dirs, dir)
		}
	}

	if dataHome := os.Getenv("XDG_DATA_HOME"); dataHome != "" {
		addBase(dataHome)
	} else if home, err := os.UserHomeDir(); err == nil && home != "" {
		addBase(filepath.Join(home, ".local", "share"))
	}

	if dataDirs := os.Getenv("XDG_DATA_DIRS"); dataDirs != "" {
		for _, dir := range strings.Split(dataDirs, ":") {
			addBase(dir)
		}
	} else {
		addBase("/usr/local/share")
		addBase("/usr/share")
	}

	return dirs
}

func ResolveSessionExec(sessionID string) (string, error) {
	return resolveSessionExecInDirs(sessionID, sessionDesktopDirs())
}

func resolveSessionExecInDirs(sessionID string, dirs []string) (string, error) {
	id := sessionDesktopIDFromPath(sessionID)
	if id == "" {
		return "", fmt.Errorf("session id is empty")
	}

	for _, dir := range dirs {
		path := filepath.Join(dir, id)
		execLine, err := execFromDesktopFile(path)
		if err == nil {
			return execLine, nil
		}
		if !os.IsNotExist(err) {
			return "", err
		}
	}

	return "", fmt.Errorf("session desktop file %q was not found", id)
}

// parseExecString splits a Desktop Entry Exec= value into argv without
// involving a shell, mirroring quickshell's DesktopEntry::parseExecString
// (string quoting, value escapes, field code stripping).
func parseExecString(execLine string) []string {
	var args []string
	var cur strings.Builder
	inString := false
	escape := 0
	percent := false

	for _, c := range execLine {
		switch {
		case escape == 0 && c == '\\':
			escape = 1
		case inString:
			switch {
			case c == '\\':
				escape++
				if escape == 4 {
					cur.WriteByte('\\')
					escape = 0
				}
			case escape == 2:
				cur.WriteRune(c)
				escape = 0
			case escape != 0:
				switch c {
				case 's':
					cur.WriteByte(' ')
				case 'n':
					cur.WriteByte('\n')
				case 't':
					cur.WriteByte('\t')
				case 'r':
					cur.WriteByte('\r')
				default:
					cur.WriteRune(c)
				}
				escape = 0
			case c == '"' || c == '\'':
				inString = false
			default:
				cur.WriteRune(c)
			}
		case escape != 0:
			cur.WriteRune(c)
			escape = 0
		case percent:
			if c == '%' {
				cur.WriteByte('%')
			}
			percent = false
		case c == '%':
			percent = true
		case c == '"' || c == '\'':
			inString = true
		case c == ' ':
			if cur.Len() > 0 {
				args = append(args, cur.String())
				cur.Reset()
			}
		default:
			cur.WriteRune(c)
		}
	}
	if cur.Len() > 0 {
		args = append(args, cur.String())
	}
	return args
}

func LaunchSessionByID(sessionID string) error {
	execLine, err := ResolveSessionExec(sessionID)
	if err != nil {
		return err
	}

	argv := parseExecString(strings.TrimSpace(execLine))
	if len(argv) == 0 {
		return fmt.Errorf("session %q has an empty Exec command", sessionID)
	}

	resolved, err := exec.LookPath(argv[0])
	if err != nil {
		return fmt.Errorf("session %q command %q not found: %w", sessionID, argv[0], err)
	}

	env := append(os.Environ(), "XDG_SESSION_TYPE=wayland")
	return syscall.Exec(resolved, argv, env)
}

func LaunchSessionFromMemory(cacheDir, homeDir string) error {
	enabled, _, sessionID, err := resolveGreeterAutoLoginState(cacheDir, homeDir)
	if err != nil {
		return err
	}
	if !enabled {
		return fmt.Errorf("greeter auto-login is disabled")
	}
	if sessionID == "" {
		return fmt.Errorf("greeter auto-login has no remembered session")
	}
	return LaunchSessionByID(sessionID)
}
