package greeter

import (
	"path/filepath"
	"reflect"
	"testing"
)

func TestParseExecString(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		exec string
		want []string
	}{
		{"plain", "niri --session", []string{"niri", "--session"}},
		{"extra spaces", "niri   --session", []string{"niri", "--session"}},
		{"double quoted arg", `env "with space" run`, []string{"env", "with space", "run"}},
		{"single quoted arg", `env 'with space' run`, []string{"env", "with space", "run"}},
		{"escaped quote in quotes", `sh "say \\"hi\\""`, []string{"sh", `say "hi"`}},
		{"field code dropped", "gnome-session %U", []string{"gnome-session"}},
		{"field code mid-arg", "app --url=%u --run", []string{"app", "--url=", "--run"}},
		{"literal percent", "app 100%% done", []string{"app", "100%", "done"}},
		{"shell metachars stay literal", "sh -c $(reboot); echo", []string{"sh", "-c", "$(reboot);", "echo"}},
		{"empty", "", nil},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := parseExecString(tt.exec); !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("parseExecString(%q) = %#v, want %#v", tt.exec, got, tt.want)
			}
		})
	}
}

func TestExecFromDesktopFileOnlyReadsDesktopEntryGroup(t *testing.T) {
	t.Parallel()

	path := filepath.Join(t.TempDir(), "example.desktop")
	writeTestFile(t, path, `[Desktop Action other]
Exec=/wrong/binary

[Desktop Entry]
Name=Example
Exec = /right/binary --flag
`)

	got, err := execFromDesktopFile(path)
	if err != nil {
		t.Fatalf("execFromDesktopFile returned error: %v", err)
	}
	if got != "/right/binary --flag" {
		t.Fatalf("execFromDesktopFile = %q, want %q", got, "/right/binary --flag")
	}
}
