package tailscale

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"syscall"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func fakeLookPath(paths map[string]string) func(string) (string, error) {
	return func(name string) (string, error) {
		if p, ok := paths[name]; ok {
			return p, nil
		}
		return "", &exec.Error{Name: name, Err: exec.ErrNotFound}
	}
}

func fakeUser(name string) func() (*user.User, error) {
	return func() (*user.User, error) { return &user.User{Username: name}, nil }
}

var bothBinaries = map[string]string{"pkexec": "/usr/bin/pkexec", "tailscale": "/usr/bin/tailscale"}

type fakeFileInfo struct {
	mode os.FileMode
	sys  any
}

func (f fakeFileInfo) Name() string       { return "" }
func (f fakeFileInfo) Size() int64        { return 0 }
func (f fakeFileInfo) Mode() os.FileMode  { return f.mode }
func (f fakeFileInfo) ModTime() time.Time { return time.Time{} }
func (f fakeFileInfo) IsDir() bool        { return false }
func (f fakeFileInfo) Sys() any           { return f.sys }

func rootFile(mode os.FileMode) fakeFileInfo {
	return fakeFileInfo{mode: mode, sys: &syscall.Stat_t{Uid: 0}}
}

// fakeStat reports safe root-owned binaries unless overridden.
func fakeStat(override map[string]os.FileInfo) func(string) (os.FileInfo, error) {
	return func(p string) (os.FileInfo, error) {
		if fi, ok := override[p]; ok {
			if fi == nil {
				return nil, os.ErrNotExist
			}
			return fi, nil
		}
		if p == "/usr/bin/pkexec" {
			return rootFile(0o755 | os.ModeSetuid), nil
		}
		return rootFile(0o755), nil
	}
}

func TestOperatorGrantArgv(t *testing.T) {
	argv, err := operatorGrantArgv(fakeStat(nil), fakeLookPath(bothBinaries), fakeUser("marlon"))
	require.NoError(t, err)
	assert.Equal(t, []string{"/usr/bin/pkexec", "/usr/bin/tailscale", "set", "--operator=marlon"}, argv)

	_, err = operatorGrantArgv(fakeStat(nil), fakeLookPath(map[string]string{"pkexec": "pkexec", "tailscale": "/usr/bin/tailscale"}), fakeUser("marlon"))
	assert.Error(t, err, "relative path must be rejected")

	_, err = operatorGrantArgv(fakeStat(nil), fakeLookPath(map[string]string{"tailscale": "/usr/bin/tailscale"}), fakeUser("marlon"))
	require.Error(t, err)
	assert.Contains(t, err.Error(), "pkexec")

	_, err = operatorGrantArgv(fakeStat(nil), fakeLookPath(map[string]string{"pkexec": "/usr/bin/pkexec"}), fakeUser("marlon"))
	require.Error(t, err)
	assert.Contains(t, err.Error(), "tailscale")

	for _, name := range []string{"-rf", "a b", "", "x;y"} {
		_, err = operatorGrantArgv(fakeStat(nil), fakeLookPath(bothBinaries), fakeUser(name))
		assert.Error(t, err, "username %q must be rejected", name)
	}
	for _, name := range []string{"_svc", "first.last-2", "machine$"} {
		_, err = operatorGrantArgv(fakeStat(nil), fakeLookPath(bothBinaries), fakeUser(name))
		assert.NoError(t, err, "username %q must be accepted", name)
	}

	_, err = operatorGrantArgv(fakeStat(nil), fakeLookPath(bothBinaries), func() (*user.User, error) { return nil, errors.New("no user") })
	assert.Error(t, err)
}

func TestOperatorGrantArgv_LookPathErrors(t *testing.T) {
	_, err := operatorGrantArgv(fakeStat(nil), fakeLookPath(map[string]string{"pkexec": "/usr/bin/pkexec"}), fakeUser("marlon"))
	require.Error(t, err)
	assert.Contains(t, err.Error(), "tailscale not found")

	refuse := func(name string) (string, error) {
		if name == "pkexec" {
			return "/usr/bin/pkexec", nil
		}
		return "", errors.New("resolves to /snap/bin/snap, refusing to run it under a different name")
	}
	_, err = operatorGrantArgv(fakeStat(nil), refuse, fakeUser("marlon"))
	require.Error(t, err)
	assert.Contains(t, err.Error(), "refusing to run it under a different name")
	assert.NotContains(t, err.Error(), "not found")
}

func TestOperatorGrantArgv_RejectsUnsafeBinaries(t *testing.T) {
	cases := map[string]map[string]os.FileInfo{
		"/usr/bin/tailscale": {"/usr/bin/tailscale": fakeFileInfo{mode: 0o755, sys: &syscall.Stat_t{Uid: 1000}}},
		"/usr/bin/pkexec":    {"/usr/bin/pkexec": rootFile(0o755)},
	}
	for _, mode := range []os.FileMode{0o775, 0o757} {
		cases["/usr/bin/tailscale mode "+mode.String()] = map[string]os.FileInfo{"/usr/bin/tailscale": rootFile(mode)}
	}
	cases["/usr/bin/tailscale missing"] = map[string]os.FileInfo{"/usr/bin/tailscale": nil}
	cases["/usr/bin/tailscale dir"] = map[string]os.FileInfo{"/usr/bin/tailscale": rootFile(0o755 | os.ModeDir)}
	cases["/usr/bin/tailscale no stat_t"] = map[string]os.FileInfo{"/usr/bin/tailscale": fakeFileInfo{mode: 0o755}}

	for name, override := range cases {
		_, err := operatorGrantArgv(fakeStat(override), fakeLookPath(bothBinaries), fakeUser("marlon"))
		require.Error(t, err, name)
		for p := range override {
			assert.Contains(t, err.Error(), filepath.Base(p), name)
		}
	}
}

func TestGrantOperator(t *testing.T) {
	argv := []string{"/usr/bin/pkexec", "/usr/bin/tailscale", "set", "--operator=marlon"}
	var got []string
	runner := func(code int, out string, runErr error) commandRunner {
		return func(ctx context.Context, a []string) ([]byte, int, error) {
			got = a
			_, hasDeadline := ctx.Deadline()
			assert.True(t, hasDeadline)
			return []byte(out), code, runErr
		}
	}

	require.NoError(t, grantOperator(context.Background(), argv, runner(0, "", nil)))
	assert.Equal(t, argv, got)

	for _, code := range []int{126, 127} {
		err := grantOperator(context.Background(), argv, runner(code, "", nil))
		assert.ErrorIs(t, err, ErrOperatorGrantCancelled)
		assert.Equal(t, "permission not granted", err.Error())

		err = grantOperator(context.Background(), argv, runner(code, " No authentication agent found.\n", nil))
		assert.ErrorIs(t, err, ErrOperatorGrantCancelled)
		assert.Equal(t, "permission not granted: No authentication agent found.", err.Error())
	}

	err := grantOperator(context.Background(), argv, runner(1, "  boom\n", nil))
	require.Error(t, err)
	assert.Equal(t, "tailscale set --operator failed: boom", err.Error())

	err = grantOperator(context.Background(), argv, runner(-1, "", errors.New("exec failed")))
	require.Error(t, err)
	assert.Contains(t, err.Error(), "exec failed")

	assert.Error(t, grantOperator(context.Background(), nil, runner(0, "", nil)))
}

func TestExecCommandRunnerExitCode(t *testing.T) {
	out, code, err := execCommandRunner(context.Background(), []string{"/bin/sh", "-c", "echo hi; exit 3"})
	require.NoError(t, err)
	assert.Equal(t, 3, code)
	assert.Equal(t, "hi\n", string(out))

	_, _, err = execCommandRunner(context.Background(), []string{"/nonexistent/binary"})
	assert.Error(t, err)
}

func TestLookPathResolved_FollowsSymlink(t *testing.T) {
	dir := t.TempDir()
	require.NoError(t, os.Mkdir(filepath.Join(dir, "lib"), 0o755))
	real := filepath.Join(dir, "lib", "tool")
	require.NoError(t, os.WriteFile(real, []byte("#!/bin/sh\n"), 0o755))
	link := filepath.Join(dir, "tool")
	require.NoError(t, os.Symlink(real, link))
	t.Setenv("PATH", dir)

	got, err := lookPathResolved("tool")
	require.NoError(t, err)
	want, err := filepath.EvalSymlinks(real)
	require.NoError(t, err)
	assert.Equal(t, want, got)
}

func TestLookPathResolved_RefusesDifferentBasename(t *testing.T) {
	dir := t.TempDir()
	real := filepath.Join(dir, "tailscaled")
	require.NoError(t, os.WriteFile(real, []byte("#!/bin/sh\n"), 0o755))
	require.NoError(t, os.Symlink(real, filepath.Join(dir, "tailscale")))
	t.Setenv("PATH", dir)

	_, err := lookPathResolved("tailscale")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "tailscale")
	assert.Contains(t, err.Error(), "tailscaled")
}
