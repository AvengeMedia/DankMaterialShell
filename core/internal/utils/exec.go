package utils

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"time"
	"unicode/utf8"
)

type AppChecker interface {
	CommandExists(cmd string) bool
	AnyCommandExists(cmds ...string) bool
	FlatpakExists(name string) bool
	AnyFlatpakExists(flatpaks ...string) bool
}

type DefaultAppChecker struct{}

func (DefaultAppChecker) CommandExists(cmd string) bool {
	return CommandExists(cmd)
}

func (DefaultAppChecker) AnyCommandExists(cmds ...string) bool {
	return AnyCommandExists(cmds...)
}

func (DefaultAppChecker) FlatpakExists(name string) bool {
	return FlatpakExists(name)
}

func (DefaultAppChecker) AnyFlatpakExists(flatpaks ...string) bool {
	return AnyFlatpakExists(flatpaks...)
}

func CommandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	if err == nil {
		return true
	}
	if strings.ContainsRune(cmd, os.PathSeparator) {
		return false
	}
	for _, dir := range userBinDirs() {
		path := filepath.Join(dir, cmd)
		info, statErr := os.Stat(path)
		if statErr == nil && !info.IsDir() && info.Mode()&0o111 != 0 {
			return true
		}
	}
	return false
}

func AnyCommandExists(cmds ...string) bool {
	return slices.ContainsFunc(cmds, CommandExists)
}

func EnvWithUserBinPath(env []string) []string {
	if env == nil {
		env = os.Environ()
	}

	out := append([]string(nil), env...)
	pathIndex := -1
	pathValue := ""
	for i, entry := range out {
		if strings.HasPrefix(entry, "PATH=") {
			pathIndex = i
			pathValue = strings.TrimPrefix(entry, "PATH=")
			break
		}
	}

	parts := filepath.SplitList(pathValue)
	seen := make(map[string]struct{}, len(parts))
	for _, part := range parts {
		if part != "" {
			seen[part] = struct{}{}
		}
	}

	prepend := make([]string, 0, len(userBinDirs()))
	for _, dir := range userBinDirs() {
		if dir == "" {
			continue
		}
		if _, ok := seen[dir]; ok {
			continue
		}
		prepend = append(prepend, dir)
		seen[dir] = struct{}{}
	}

	parts = append(prepend, parts...)
	newPath := "PATH=" + strings.Join(parts, string(os.PathListSeparator))
	if pathIndex >= 0 {
		out[pathIndex] = newPath
	} else {
		out = append(out, newPath)
	}
	return out
}

func userBinDirs() []string {
	dirs := []string{}
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		dirs = append(dirs,
			filepath.Join(home, ".local", "bin"),
			filepath.Join(home, ".nix-profile", "bin"),
		)
		if user := filepath.Base(home); user != "" && user != string(filepath.Separator) {
			dirs = append(dirs, filepath.Join("/etc/profiles/per-user", user, "bin"))
		}
	}
	dirs = append(dirs, "/usr/local/bin")
	return dirs
}

const maxJSONProcessBytes = 4 * 1024 * 1024

type boundedWriter struct {
	bytes.Buffer
	limit int
}

func (w *boundedWriter) Write(p []byte) (int, error) {
	if len(p) > w.limit-w.Len() {
		return 0, errors.New("process output exceeds size bound")
	}
	return w.Buffer.Write(p)
}

func RunJSON(ctx context.Context, executable string, args []string, input []byte, result any) error {
	if len(input) > maxJSONProcessBytes {
		return errors.New("request exceeds size bound")
	}
	ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, executable, args...)
	cmd.WaitDelay = time.Second
	stdout := &boundedWriter{limit: maxJSONProcessBytes + 1}
	stderr := &boundedWriter{limit: 16 * 1024}
	cmd.Stdout, cmd.Stderr = stdout, stderr
	if input != nil {
		cmd.Stdin = bytes.NewReader(input)
	}
	err := cmd.Run()
	if ctx.Err() != nil {
		return fmt.Errorf("unavailable: command completion uncertain: %w", ctx.Err())
	}
	if stdout.Len() != 0 {
		if decodeErr := DecodeJSON(bytes.TrimSuffix(stdout.Bytes(), []byte{'\n'}), result); decodeErr != nil {
			return errors.Join(err, fmt.Errorf("invalid process JSON: %w", decodeErr))
		}
	}
	if err != nil {
		return fmt.Errorf("%s: %w", executable, err)
	}
	if stdout.Len() == 0 {
		return errors.New("missing command acknowledgement")
	}
	return nil
}

func DecodeJSON(data []byte, target any) error {
	if len(data) > maxJSONProcessBytes || !utf8.Valid(data) {
		return errors.New("invalid UTF-8 or oversized JSON record")
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.UseNumber()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		return errors.New("trailing JSON data")
	}
	return nil
}
