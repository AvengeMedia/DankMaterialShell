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

// tokenizeExecLine splits a Desktop Entry Exec= value into argv, honoring
// basic single/double quoting and backslash escapes, but never invokes a
// shell. Session .desktop files can live in a user-writable directory
// (~/.local/share/wayland-sessions), so shell metacharacters in Exec=
// must never reach an actual shell -- they're just literal argv text here.
func tokenizeExecLine(execLine string) ([]string, error) {
	var tokens []string
	var cur strings.Builder
	hasCur := false
	runes := []rune(execLine)
	i := 0
	for i < len(runes) {
		c := runes[i]
		switch {
		case c == ' ' || c == '\t':
			if hasCur {
				tokens = append(tokens, cur.String())
				cur.Reset()
				hasCur = false
			}
			i++
		case c == '\'':
			hasCur = true
			i++
			for i < len(runes) && runes[i] != '\'' {
				cur.WriteRune(runes[i])
				i++
			}
			if i >= len(runes) {
				return nil, fmt.Errorf("unterminated single quote")
			}
			i++
		case c == '"':
			hasCur = true
			i++
			for i < len(runes) && runes[i] != '"' {
				if runes[i] == '\\' && i+1 < len(runes) {
					if next := runes[i+1]; next == '"' || next == '\\' || next == '$' || next == '`' {
						cur.WriteRune(next)
						i += 2
						continue
					}
				}
				cur.WriteRune(runes[i])
				i++
			}
			if i >= len(runes) {
				return nil, fmt.Errorf("unterminated double quote")
			}
			i++
		case c == '\\' && i+1 < len(runes):
			hasCur = true
			cur.WriteRune(runes[i+1])
			i += 2
		default:
			hasCur = true
			cur.WriteRune(c)
			i++
		}
	}
	if hasCur {
		tokens = append(tokens, cur.String())
	}
	return tokens, nil
}

func LaunchSessionByID(sessionID string) error {
	execLine, err := ResolveSessionExec(sessionID)
	if err != nil {
		return err
	}
	execLine = strings.TrimSpace(execLine)
	if execLine == "" {
		return fmt.Errorf("session %q has an empty Exec command", sessionID)
	}

	tokens, err := tokenizeExecLine(execLine)
	if err != nil {
		return fmt.Errorf("session %q has an invalid Exec command: %w", sessionID, err)
	}

	argv := make([]string, 0, len(tokens))
	for _, tok := range tokens {
		if strings.HasPrefix(tok, "%") {
			continue // field codes (%f/%U/etc.) -- sessions take no file args
		}
		argv = append(argv, tok)
	}
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
