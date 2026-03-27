package pam

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeTestFile(t *testing.T, path string, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("failed to create parent dir for %s: %v", path, err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("failed to write %s: %v", path, err)
	}
}

type pamTestEnv struct {
	pamDir               string
	greetdPath           string
	dankshellPath        string
	dankshellU2fPath     string
	tmpDir               string
	homeDir              string
	availableModules     map[string]bool
	fingerprintAvailable bool
}

func newPamTestEnv(t *testing.T) *pamTestEnv {
	t.Helper()

	root := t.TempDir()
	pamDir := filepath.Join(root, "pam.d")
	tmpDir := filepath.Join(root, "tmp")
	homeDir := filepath.Join(root, "home")

	for _, dir := range []string{pamDir, tmpDir, homeDir} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatalf("failed to create %s: %v", dir, err)
		}
	}

	return &pamTestEnv{
		pamDir:           pamDir,
		greetdPath:       filepath.Join(pamDir, "greetd"),
		dankshellPath:    filepath.Join(pamDir, "dankshell"),
		dankshellU2fPath: filepath.Join(pamDir, "dankshell-u2f"),
		tmpDir:           tmpDir,
		homeDir:          homeDir,
		availableModules: map[string]bool{},
	}
}

func (e *pamTestEnv) writePamFile(t *testing.T, name string, content string) {
	t.Helper()
	writeTestFile(t, filepath.Join(e.pamDir, name), content)
}

func (e *pamTestEnv) writeSettings(t *testing.T, content string) {
	t.Helper()
	writeTestFile(t, filepath.Join(e.homeDir, ".config", "DankMaterialShell", "settings.json"), content)
}

func (e *pamTestEnv) deps(isNixOS bool) syncDeps {
	return syncDeps{
		pamDir:           e.pamDir,
		greetdPath:       e.greetdPath,
		dankshellPath:    e.dankshellPath,
		dankshellU2fPath: e.dankshellU2fPath,
		isNixOS:          func() bool { return isNixOS },
		readFile:         os.ReadFile,
		stat:             os.Stat,
		createTemp: func(_ string, pattern string) (*os.File, error) {
			return os.CreateTemp(e.tmpDir, pattern)
		},
		removeFile: os.Remove,
		runSudoCmd: func(_ string, command string, args ...string) error {
			switch command {
			case "cp":
				if len(args) != 2 {
					return fmt.Errorf("unexpected cp args: %v", args)
				}
				data, err := os.ReadFile(args[0])
				if err != nil {
					return err
				}
				if err := os.MkdirAll(filepath.Dir(args[1]), 0o755); err != nil {
					return err
				}
				return os.WriteFile(args[1], data, 0o644)
			case "chmod":
				if len(args) != 2 {
					return fmt.Errorf("unexpected chmod args: %v", args)
				}
				return nil
			case "rm":
				if len(args) != 2 || args[0] != "-f" {
					return fmt.Errorf("unexpected rm args: %v", args)
				}
				if err := os.Remove(args[1]); err != nil && !os.IsNotExist(err) {
					return err
				}
				return nil
			default:
				return fmt.Errorf("unexpected sudo command: %s %v", command, args)
			}
		},
		pamModuleExists: func(module string) bool {
			return e.availableModules[module]
		},
		fingerprintAvailableForCurrentUser: func() bool {
			return e.fingerprintAvailable
		},
	}
}

func readFileString(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("failed to read %s: %v", path, err)
	}
	return string(data)
}

func TestHasManagedLockscreenPamFile(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		content string
		want    bool
	}{
		{
			name: "both markers present",
			content: "#%PAM-1.0\n" +
				LockscreenPamManagedBlockStart + "\n" +
				"auth sufficient pam_unix.so\n" +
				LockscreenPamManagedBlockEnd + "\n",
			want: true,
		},
		{
			name: "missing end marker is not managed",
			content: "#%PAM-1.0\n" +
				LockscreenPamManagedBlockStart + "\n" +
				"auth sufficient pam_unix.so\n",
			want: false,
		},
		{
			name:    "custom file is not managed",
			content: "#%PAM-1.0\nauth sufficient pam_unix.so\n",
			want:    false,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			if got := hasManagedLockscreenPamFile(tt.content); got != tt.want {
				t.Fatalf("hasManagedLockscreenPamFile() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestBuildManagedLockscreenPamContent(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name            string
		files           map[string]string
		wantContains    []string
		wantNotContains []string
		wantCounts      map[string]int
		wantErr         string
	}{
		{
			name: "preserves custom modules and strips direct u2f and fprint directives",
			files: map[string]string{
				"login": "#%PAM-1.0\n" +
					"auth include system-auth\n" +
					"account include system-auth\n" +
					"session include system-auth\n",
				"system-auth": "auth requisite pam_nologin.so\n" +
					"auth sufficient pam_unix.so try_first_pass nullok\n" +
					"auth sufficient pam_u2f.so cue\n" +
					"auth sufficient pam_fprintd.so max-tries=1\n" +
					"auth required pam_radius_auth.so conf=/etc/raddb/server\n" +
					"account required pam_access.so\n" +
					"session optional pam_lastlog.so silent\n",
			},
			wantContains: []string{
				"#%PAM-1.0",
				LockscreenPamManagedBlockStart,
				LockscreenPamManagedBlockEnd,
				"auth requisite pam_nologin.so",
				"auth sufficient pam_unix.so try_first_pass nullok",
				"auth required pam_radius_auth.so conf=/etc/raddb/server",
				"account required pam_access.so",
				"session optional pam_lastlog.so silent",
			},
			wantNotContains: []string{
				"pam_u2f",
				"pam_fprintd",
			},
			wantCounts: map[string]int{
				"auth required pam_radius_auth.so conf=/etc/raddb/server": 1,
				"account required pam_access.so":                          1,
			},
		},
		{
			name: "resolves nested include substack and @include transitively",
			files: map[string]string{
				"login": "#%PAM-1.0\n" +
					"auth include system-auth\n" +
					"account include system-auth\n" +
					"password include system-auth\n" +
					"session include system-auth\n",
				"system-auth": "auth substack custom-auth\n" +
					"account include custom-auth\n" +
					"password include custom-auth\n" +
					"session @include common-session\n",
				"custom-auth": "auth required pam_custom.so one=two\n" +
					"account required pam_custom_account.so\n" +
					"password required pam_custom_password.so\n",
				"common-session": "session optional pam_fprintd.so max-tries=1\n" +
					"session optional pam_lastlog.so silent\n",
			},
			wantContains: []string{
				"auth required pam_custom.so one=two",
				"account required pam_custom_account.so",
				"password required pam_custom_password.so",
				"session optional pam_lastlog.so silent",
			},
			wantNotContains: []string{
				"pam_fprintd",
			},
			wantCounts: map[string]int{
				"auth required pam_custom.so one=two":      1,
				"account required pam_custom_account.so":   1,
				"password required pam_custom_password.so": 1,
				"session optional pam_lastlog.so silent":   1,
			},
		},
		{
			name: "missing include fails",
			files: map[string]string{
				"login": "#%PAM-1.0\nauth include missing-auth\n",
			},
			wantErr: "failed to read PAM file",
		},
		{
			name: "cyclic include fails",
			files: map[string]string{
				"login":       "#%PAM-1.0\nauth include system-auth\n",
				"system-auth": "auth include login\n",
			},
			wantErr: "cyclic PAM include detected",
		},
		{
			name: "no auth directives remain after filtering fails",
			files: map[string]string{
				"login":       "#%PAM-1.0\nauth include system-auth\n",
				"system-auth": "auth sufficient pam_u2f.so cue\n",
			},
			wantErr: "no auth directives remained after filtering",
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			env := newPamTestEnv(t)
			for name, content := range tt.files {
				env.writePamFile(t, name, content)
			}

			content, err := buildManagedLockscreenPamContent(env.pamDir, os.ReadFile)
			if tt.wantErr != "" {
				if err == nil {
					t.Fatalf("expected error containing %q, got nil", tt.wantErr)
				}
				if !strings.Contains(err.Error(), tt.wantErr) {
					t.Fatalf("error = %q, want substring %q", err.Error(), tt.wantErr)
				}
				return
			}
			if err != nil {
				t.Fatalf("buildManagedLockscreenPamContent returned error: %v", err)
			}

			for _, want := range tt.wantContains {
				if !strings.Contains(content, want) {
					t.Errorf("missing expected string %q in output:\n%s", want, content)
				}
			}
			for _, notWant := range tt.wantNotContains {
				if strings.Contains(content, notWant) {
					t.Errorf("unexpected string %q found in output:\n%s", notWant, content)
				}
			}
			for want, wantCount := range tt.wantCounts {
				if gotCount := strings.Count(content, want); gotCount != wantCount {
					t.Errorf("count for %q = %d, want %d\noutput:\n%s", want, gotCount, wantCount, content)
				}
			}
		})
	}
}

func TestSyncLockscreenPamConfigWithDeps(t *testing.T) {
	t.Parallel()

	t.Run("custom dankshell file is skipped untouched", func(t *testing.T) {
		t.Parallel()

		env := newPamTestEnv(t)
		customContent := "#%PAM-1.0\nauth required pam_unix.so\n"
		env.writePamFile(t, "dankshell", customContent)

		var logs []string
		err := syncLockscreenPamConfigWithDeps(func(msg string) {
			logs = append(logs, msg)
		}, "", env.deps(false))
		if err != nil {
			t.Fatalf("syncLockscreenPamConfigWithDeps returned error: %v", err)
		}

		if got := readFileString(t, env.dankshellPath); got != customContent {
			t.Fatalf("custom dankshell content changed\ngot:\n%s\nwant:\n%s", got, customContent)
		}
		if len(logs) == 0 || !strings.Contains(logs[0], "Custom /etc/pam.d/dankshell found") {
			t.Fatalf("expected custom-file skip log, got %v", logs)
		}
	})

	t.Run("managed dankshell file is rewritten from resolved login stack", func(t *testing.T) {
		t.Parallel()

		env := newPamTestEnv(t)
		env.writePamFile(t, "login", "#%PAM-1.0\nauth include system-auth\naccount include system-auth\n")
		env.writePamFile(t, "system-auth", "auth sufficient pam_unix.so try_first_pass nullok\nauth sufficient pam_u2f.so cue\naccount required pam_access.so\n")
		env.writePamFile(t, "dankshell", "#%PAM-1.0\n"+LockscreenPamManagedBlockStart+"\nauth required pam_env.so\n"+LockscreenPamManagedBlockEnd+"\n")

		var logs []string
		err := syncLockscreenPamConfigWithDeps(func(msg string) {
			logs = append(logs, msg)
		}, "", env.deps(false))
		if err != nil {
			t.Fatalf("syncLockscreenPamConfigWithDeps returned error: %v", err)
		}

		output := readFileString(t, env.dankshellPath)
		for _, want := range []string{
			LockscreenPamManagedBlockStart,
			"auth sufficient pam_unix.so try_first_pass nullok",
			"account required pam_access.so",
			LockscreenPamManagedBlockEnd,
		} {
			if !strings.Contains(output, want) {
				t.Errorf("missing expected string %q in rewritten dankshell:\n%s", want, output)
			}
		}
		if strings.Contains(output, "pam_u2f") {
			t.Errorf("rewritten dankshell still contains pam_u2f:\n%s", output)
		}
		if len(logs) == 0 || !strings.Contains(logs[len(logs)-1], "Created or updated /etc/pam.d/dankshell") {
			t.Fatalf("expected success log, got %v", logs)
		}
	})

	t.Run("mutable systems fail when login stack cannot be converted safely", func(t *testing.T) {
		t.Parallel()

		env := newPamTestEnv(t)
		err := syncLockscreenPamConfigWithDeps(func(string) {}, "", env.deps(false))
		if err == nil {
			t.Fatal("expected error when login PAM file is missing, got nil")
		}
		if !strings.Contains(err.Error(), "failed to build") {
			t.Fatalf("error = %q, want substring %q", err.Error(), "failed to build")
		}
	})

	t.Run("NixOS remains informational and does not write dankshell", func(t *testing.T) {
		t.Parallel()

		env := newPamTestEnv(t)
		var logs []string

		err := syncLockscreenPamConfigWithDeps(func(msg string) {
			logs = append(logs, msg)
		}, "", env.deps(true))
		if err != nil {
			t.Fatalf("syncLockscreenPamConfigWithDeps returned error on NixOS path: %v", err)
		}
		if len(logs) == 0 || !strings.Contains(logs[0], "NixOS detected") || !strings.Contains(logs[0], "/etc/pam.d/login") {
			t.Fatalf("expected NixOS informational log mentioning /etc/pam.d/login, got %v", logs)
		}
		if _, err := os.Stat(env.dankshellPath); !os.IsNotExist(err) {
			t.Fatalf("expected no dankshell file to be written on NixOS path, stat err = %v", err)
		}
	})
}

func TestSyncLockscreenU2FPamConfigWithDeps(t *testing.T) {
	t.Parallel()

	t.Run("enabled creates managed file", func(t *testing.T) {
		t.Parallel()

		env := newPamTestEnv(t)
		var logs []string

		err := syncLockscreenU2FPamConfigWithDeps(func(msg string) {
			logs = append(logs, msg)
		}, "", true, env.deps(false))
		if err != nil {
			t.Fatalf("syncLockscreenU2FPamConfigWithDeps returned error: %v", err)
		}

		got := readFileString(t, env.dankshellU2fPath)
		if got != buildManagedLockscreenU2FPamContent() {
			t.Fatalf("unexpected managed dankshell-u2f content:\n%s", got)
		}
		if len(logs) == 0 || !strings.Contains(logs[len(logs)-1], "Created or updated /etc/pam.d/dankshell-u2f") {
			t.Fatalf("expected create log, got %v", logs)
		}
	})

	t.Run("enabled rewrites existing managed file", func(t *testing.T) {
		t.Parallel()

		env := newPamTestEnv(t)
		env.writePamFile(t, "dankshell-u2f", "#%PAM-1.0\n"+LockscreenU2FPamManagedBlockStart+"\nauth required pam_u2f.so old\n"+LockscreenU2FPamManagedBlockEnd+"\n")

		if err := syncLockscreenU2FPamConfigWithDeps(func(string) {}, "", true, env.deps(false)); err != nil {
			t.Fatalf("syncLockscreenU2FPamConfigWithDeps returned error: %v", err)
		}
		if got := readFileString(t, env.dankshellU2fPath); got != buildManagedLockscreenU2FPamContent() {
			t.Fatalf("managed dankshell-u2f was not rewritten:\n%s", got)
		}
	})

	t.Run("disabled removes DMS-managed file", func(t *testing.T) {
		t.Parallel()

		env := newPamTestEnv(t)
		env.writePamFile(t, "dankshell-u2f", buildManagedLockscreenU2FPamContent())

		var logs []string
		err := syncLockscreenU2FPamConfigWithDeps(func(msg string) {
			logs = append(logs, msg)
		}, "", false, env.deps(false))
		if err != nil {
			t.Fatalf("syncLockscreenU2FPamConfigWithDeps returned error: %v", err)
		}
		if _, err := os.Stat(env.dankshellU2fPath); !os.IsNotExist(err) {
			t.Fatalf("expected managed dankshell-u2f to be removed, stat err = %v", err)
		}
		if len(logs) == 0 || !strings.Contains(logs[len(logs)-1], "Removed DMS-managed /etc/pam.d/dankshell-u2f") {
			t.Fatalf("expected removal log, got %v", logs)
		}
	})

	t.Run("disabled preserves custom file", func(t *testing.T) {
		t.Parallel()

		env := newPamTestEnv(t)
		customContent := "#%PAM-1.0\nauth required pam_u2f.so cue\n"
		env.writePamFile(t, "dankshell-u2f", customContent)

		var logs []string
		err := syncLockscreenU2FPamConfigWithDeps(func(msg string) {
			logs = append(logs, msg)
		}, "", false, env.deps(false))
		if err != nil {
			t.Fatalf("syncLockscreenU2FPamConfigWithDeps returned error: %v", err)
		}
		if got := readFileString(t, env.dankshellU2fPath); got != customContent {
			t.Fatalf("custom dankshell-u2f content changed\ngot:\n%s\nwant:\n%s", got, customContent)
		}
		if len(logs) == 0 || !strings.Contains(logs[0], "Custom /etc/pam.d/dankshell-u2f found") {
			t.Fatalf("expected custom-file log, got %v", logs)
		}
	})
}

func TestSyncGreeterPamConfigWithDeps(t *testing.T) {
	t.Parallel()

	t.Run("adds managed block for enabled auth modules", func(t *testing.T) {
		t.Parallel()

		env := newPamTestEnv(t)
		env.availableModules["pam_fprintd.so"] = true
		env.availableModules["pam_u2f.so"] = true
		env.writePamFile(t, "greetd", "#%PAM-1.0\nauth include system-auth\naccount include system-auth\n")
		env.writePamFile(t, "system-auth", "auth sufficient pam_unix.so\naccount required pam_unix.so\n")

		settings := AuthSettings{GreeterEnableFprint: true, GreeterEnableU2f: true}
		if err := syncGreeterPamConfigWithDeps(func(string) {}, "", settings, false, env.deps(false)); err != nil {
			t.Fatalf("syncGreeterPamConfigWithDeps returned error: %v", err)
		}

		got := readFileString(t, env.greetdPath)
		for _, want := range []string{
			GreeterPamManagedBlockStart,
			"auth sufficient pam_fprintd.so max-tries=1 timeout=5",
			"auth sufficient pam_u2f.so cue nouserok timeout=10",
			GreeterPamManagedBlockEnd,
		} {
			if !strings.Contains(got, want) {
				t.Errorf("missing expected string %q in greetd PAM:\n%s", want, got)
			}
		}
		if strings.Index(got, GreeterPamManagedBlockStart) > strings.Index(got, "auth include system-auth") {
			t.Fatalf("managed block was not inserted before first auth line:\n%s", got)
		}
	})

	t.Run("avoids duplicate fingerprint when included stack already provides it", func(t *testing.T) {
		t.Parallel()

		env := newPamTestEnv(t)
		env.availableModules["pam_fprintd.so"] = true
		env.fingerprintAvailable = true
		original := "#%PAM-1.0\nauth include system-auth\naccount include system-auth\n"
		env.writePamFile(t, "greetd", original)
		env.writePamFile(t, "system-auth", "auth sufficient pam_fprintd.so max-tries=1\nauth sufficient pam_unix.so\n")

		settings := AuthSettings{GreeterEnableFprint: true}
		if err := syncGreeterPamConfigWithDeps(func(string) {}, "", settings, false, env.deps(false)); err != nil {
			t.Fatalf("syncGreeterPamConfigWithDeps returned error: %v", err)
		}

		got := readFileString(t, env.greetdPath)
		if got != original {
			t.Fatalf("greetd PAM changed despite included pam_fprintd stack\ngot:\n%s\nwant:\n%s", got, original)
		}
		if strings.Contains(got, GreeterPamManagedBlockStart) {
			t.Fatalf("managed block should not be inserted when included stack already has pam_fprintd:\n%s", got)
		}
	})
}

func TestRemoveManagedGreeterPamBlockWithDeps(t *testing.T) {
	t.Parallel()

	env := newPamTestEnv(t)
	env.writePamFile(t, "greetd", "#%PAM-1.0\n"+
		legacyGreeterPamFprintComment+"\n"+
		"auth sufficient pam_fprintd.so max-tries=1\n"+
		GreeterPamManagedBlockStart+"\n"+
		"auth sufficient pam_u2f.so cue nouserok timeout=10\n"+
		GreeterPamManagedBlockEnd+"\n"+
		"auth include system-auth\n")

	if err := removeManagedGreeterPamBlockWithDeps(func(string) {}, "", env.deps(false)); err != nil {
		t.Fatalf("removeManagedGreeterPamBlockWithDeps returned error: %v", err)
	}

	got := readFileString(t, env.greetdPath)
	if strings.Contains(got, GreeterPamManagedBlockStart) || strings.Contains(got, legacyGreeterPamFprintComment) {
		t.Fatalf("managed or legacy DMS auth lines remained in greetd PAM:\n%s", got)
	}
	if !strings.Contains(got, "auth include system-auth") {
		t.Fatalf("expected non-DMS greetd auth lines to remain:\n%s", got)
	}
}

func TestSyncAuthConfigWithDeps(t *testing.T) {
	t.Parallel()

	t.Run("creates lockscreen targets and skips greetd when greeter is not installed", func(t *testing.T) {
		t.Parallel()

		env := newPamTestEnv(t)
		env.writeSettings(t, `{"enableU2f":true}`)
		env.writePamFile(t, "login", "#%PAM-1.0\nauth include system-auth\naccount include system-auth\n")
		env.writePamFile(t, "system-auth", "auth sufficient pam_unix.so try_first_pass nullok\naccount required pam_access.so\n")

		var logs []string
		err := syncAuthConfigWithDeps(func(msg string) {
			logs = append(logs, msg)
		}, "", SyncAuthOptions{HomeDir: env.homeDir}, env.deps(false))
		if err != nil {
			t.Fatalf("syncAuthConfigWithDeps returned error: %v", err)
		}

		if _, err := os.Stat(env.dankshellPath); err != nil {
			t.Fatalf("expected dankshell to be created: %v", err)
		}
		if got := readFileString(t, env.dankshellU2fPath); got != buildManagedLockscreenU2FPamContent() {
			t.Fatalf("unexpected dankshell-u2f content:\n%s", got)
		}
		if len(logs) == 0 || !strings.Contains(logs[len(logs)-1], "greetd not found") {
			t.Fatalf("expected greetd skip log, got %v", logs)
		}
	})

	t.Run("separate greeter and lockscreen toggles are respected", func(t *testing.T) {
		t.Parallel()

		env := newPamTestEnv(t)
		env.availableModules["pam_fprintd.so"] = true
		env.writeSettings(t, `{"enableU2f":false,"greeterEnableFprint":true,"greeterEnableU2f":false}`)
		env.writePamFile(t, "login", "#%PAM-1.0\nauth include system-auth\naccount include system-auth\n")
		env.writePamFile(t, "system-auth", "auth sufficient pam_unix.so try_first_pass nullok\naccount required pam_access.so\n")
		env.writePamFile(t, "greetd", "#%PAM-1.0\nauth include system-auth\naccount include system-auth\n")

		err := syncAuthConfigWithDeps(func(string) {}, "", SyncAuthOptions{HomeDir: env.homeDir}, env.deps(false))
		if err != nil {
			t.Fatalf("syncAuthConfigWithDeps returned error: %v", err)
		}

		dankshell := readFileString(t, env.dankshellPath)
		if strings.Contains(dankshell, "pam_fprintd") || strings.Contains(dankshell, "pam_u2f") {
			t.Fatalf("lockscreen PAM should strip fingerprint and U2F modules:\n%s", dankshell)
		}
		if _, err := os.Stat(env.dankshellU2fPath); !os.IsNotExist(err) {
			t.Fatalf("expected dankshell-u2f to remain absent when enableU2f is false, stat err = %v", err)
		}

		greetd := readFileString(t, env.greetdPath)
		if !strings.Contains(greetd, "auth sufficient pam_fprintd.so max-tries=1 timeout=5") {
			t.Fatalf("expected greetd PAM to receive fingerprint auth block:\n%s", greetd)
		}
		if strings.Contains(greetd, "auth sufficient pam_u2f.so cue nouserok timeout=10") {
			t.Fatalf("did not expect greetd PAM to receive U2F auth block:\n%s", greetd)
		}
	})

	t.Run("NixOS remains informational and non-mutating", func(t *testing.T) {
		t.Parallel()

		env := newPamTestEnv(t)
		env.availableModules["pam_fprintd.so"] = true
		env.availableModules["pam_u2f.so"] = true
		env.writeSettings(t, `{"enableU2f":true,"greeterEnableFprint":true,"greeterEnableU2f":true}`)
		originalGreetd := "#%PAM-1.0\nauth include system-auth\naccount include system-auth\n"
		env.writePamFile(t, "greetd", originalGreetd)

		var logs []string
		err := syncAuthConfigWithDeps(func(msg string) {
			logs = append(logs, msg)
		}, "", SyncAuthOptions{HomeDir: env.homeDir}, env.deps(true))
		if err != nil {
			t.Fatalf("syncAuthConfigWithDeps returned error: %v", err)
		}

		if _, err := os.Stat(env.dankshellPath); !os.IsNotExist(err) {
			t.Fatalf("expected dankshell to remain absent on NixOS path, stat err = %v", err)
		}
		if _, err := os.Stat(env.dankshellU2fPath); !os.IsNotExist(err) {
			t.Fatalf("expected dankshell-u2f to remain absent on NixOS path, stat err = %v", err)
		}
		if got := readFileString(t, env.greetdPath); got != originalGreetd {
			t.Fatalf("expected greetd PAM to remain unchanged on NixOS path\ngot:\n%s\nwant:\n%s", got, originalGreetd)
		}
		if len(logs) < 2 || !strings.Contains(strings.Join(logs, "\n"), "NixOS detected") {
			t.Fatalf("expected informational NixOS logs, got %v", logs)
		}
	})
}
