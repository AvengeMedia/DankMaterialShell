package sysupdate

import (
	"errors"
	"os"
	"os/exec"
	"strings"
	"testing"
)

func TestTerminalWrapperPreservesExitStatus(t *testing.T) {
	for _, tt := range []struct {
		command string
		status  int
		message string
	}{
		{"true", 0, "Done."},
		{"false", 1, "Update failed (exit 1)"},
		{"sh -c 'exit 42'", 42, "Update failed (exit 42)"},
	} {
		t.Run(tt.command, func(t *testing.T) {
			argv := wrapInTerminal("xterm", "Test", tt.command, nil)
			cmd := exec.Command("sh", "-c", argv[len(argv)-1])
			cmd.Stdin = strings.NewReader("\n")
			out, err := cmd.CombinedOutput()
			if tt.status == 0 && err != nil {
				t.Fatal(err)
			}
			if tt.status != 0 {
				exitErr, ok := errors.AsType[*exec.ExitError](err)
				if !ok || exitErr.ExitCode() != tt.status {
					t.Fatalf("expected exit %d, got %v (%s)", tt.status, err, out)
				}
			}
			if !strings.Contains(string(out), tt.message) {
				t.Fatalf("missing status message %q: %s", tt.message, out)
			}
		})
	}
}

func TestRunAttachesStdin(t *testing.T) {
	reader, writer, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	if _, err := writer.WriteString("confirmation\n"); err != nil {
		t.Fatal(err)
	}
	writer.Close()
	previous := os.Stdin
	os.Stdin = reader
	defer func() { os.Stdin = previous }()
	if err := Run(t.Context(), []string{"sh", "-c", `read -r answer && [ "$answer" = confirmation ]`}, RunOptions{AttachStdio: true}); err != nil {
		t.Fatalf("attached command did not receive stdin: %v", err)
	}
}
