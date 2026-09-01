package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestQuickshellVersionFailureDetails(t *testing.T) {
	tests := []struct {
		name   string
		stderr string
		want   string
	}{
		{
			name:   "Qt private API symbol mismatch",
			stderr: "qs: symbol lookup error: qs: undefined symbol: _ZN23QUntypedPropertyBindingC1EP23QPropertyBindingPrivate, version Qt_6_PRIVATE_API",
			want:   "Quickshell is incompatible with the installed Qt libraries. Rebuild or reinstall Quickshell against the current Qt version.",
		},
		{
			name:   "other failure",
			stderr: "qs: unsupported option --version",
			want:   "Run 'qs --version' to inspect the failure.",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := quickshellVersionFailureDetails(tc.stderr); got != tc.want {
				t.Fatalf("quickshellVersionFailureDetails(%q) = %q, want %q", tc.stderr, got, tc.want)
			}
		})
	}
}

// Parsing a full property dump as a bare value would yield a bogus plugin root,
// making the qtengine check warn at a user whose install is fine.
func TestQtQueryValue(t *testing.T) {
	const dumpAll = `QT_INSTALL_PREFIX:/usr
QT_INSTALL_PLUGINS:/usr/lib/qt/plugins
QT_VERSION:5.15.19`

	tests := []struct {
		name   string
		output string
		key    string
		want   string
	}{
		{
			name:   "bare value as qmake prints it",
			output: "/usr/lib/qt6/plugins\n",
			key:    "QT_INSTALL_PLUGINS",
			want:   "/usr/lib/qt6/plugins",
		},
		{
			name:   "key:value line among a full property dump",
			output: dumpAll,
			key:    "QT_INSTALL_PLUGINS",
			want:   "/usr/lib/qt/plugins",
		},
		{
			name:   "a different key from the same dump",
			output: dumpAll,
			key:    "QT_VERSION",
			want:   "5.15.19",
		},
		{
			name:   "key absent from a multi line dump yields nothing",
			output: dumpAll,
			key:    "QT_INSTALL_LIBEXECS",
			want:   "",
		},
		{
			name:   "empty output yields nothing",
			output: "",
			key:    "QT_INSTALL_PLUGINS",
			want:   "",
		},
		{
			name:   "surrounding whitespace is trimmed",
			output: "  QT_INSTALL_PLUGINS:  /usr/lib/qt/plugins  \n",
			key:    "QT_INSTALL_PLUGINS",
			want:   "/usr/lib/qt/plugins",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := qtQueryValue(tc.output, tc.key); got != tc.want {
				t.Fatalf("qtQueryValue(%q, %q) = %q, want %q", tc.output, tc.key, got, tc.want)
			}
		})
	}
}

// stubQtQueryTool writes a fake Qt build tool answering QT_VERSION and
// QT_INSTALL_PLUGINS from the given values, and points PATH at its directory
// alone so the real toolchain cannot interfere.
func stubQtQueryTool(t *testing.T, bin, version, plugins string) string {
	t.Helper()
	dir := t.TempDir()
	script := "#!/bin/sh\ncase \"$2\" in\n  QT_VERSION) echo " + version +
		" ;;\n  QT_INSTALL_PLUGINS) echo " + plugins + " ;;\nesac\n"
	if err := os.WriteFile(filepath.Join(dir, bin), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir)
	return dir
}

func writePlugin(t *testing.T, pluginsDir, file string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Join(pluginsDir, "platformthemes"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(pluginsDir, "platformthemes", file), nil, 0o644); err != nil {
		t.Fatal(err)
	}
}

// qtenginePluginFile("", major) is a path with a directory component, and
// qtPluginPath joins platformthemes/ again — a regression here silently warns
// at every correctly installed system, so pin the full path down.
func TestQtenginePluginPath(t *testing.T) {
	root := t.TempDir()
	if got := qtenginePluginPath([]string{root}, "6"); got != "" {
		t.Fatalf("missing plugin should yield an empty path, got %q", got)
	}
	want := filepath.Join(root, "platformthemes", "libqt6engine-plugin.so")
	if err := os.MkdirAll(filepath.Join(root, "platformthemes"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(want, nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if got := qtenginePluginPath([]string{root}, "6"); got != want {
		t.Fatalf("qtenginePluginPath = %q, want %q", got, want)
	}
}

func TestCheckQtPlatformThemePlugin(t *testing.T) {
	t.Run("qt6ct-kde is flagged as a package name, not a theme", func(t *testing.T) {
		t.Setenv("QT_QPA_PLATFORMTHEME", "qt6ct-kde")
		t.Setenv("PATH", t.TempDir()) // no Qt tools reachable
		results := checkQtPlatformThemePlugin("QT_QPA_PLATFORMTHEME")
		if len(results) != 1 {
			t.Fatalf("got %d results, want 1: %+v", len(results), results)
		}
		if results[0].status != statusWarn {
			t.Fatalf("status = %q, want warn", results[0].status)
		}
		if !strings.Contains(results[0].details, "package name") || !strings.Contains(results[0].details, "qt6ct") {
			t.Fatalf("details should name the package/value mixup, got %q", results[0].details)
		}
	})

	t.Run("installed plugin reports OK", func(t *testing.T) {
		t.Setenv("QT_QPA_PLATFORMTHEME", "qt6ct")
		plugins := t.TempDir()
		writePlugin(t, plugins, "libqt6ct.so")
		stubQtQueryTool(t, "qmake6", "6.11.2", plugins)
		results := checkQtPlatformThemePlugin("QT_QPA_PLATFORMTHEME")
		if len(results) != 1 || results[0].status != statusOK {
			t.Fatalf("got %+v, want one OK result", results)
		}
		if !strings.Contains(results[0].details, "libqt6ct.so") {
			t.Fatalf("details should point at the plugin, got %q", results[0].details)
		}
	})

	t.Run("missing plugin warns with the expected path", func(t *testing.T) {
		t.Setenv("QT_QPA_PLATFORMTHEME", "qt6ct")
		plugins := t.TempDir()
		stubQtQueryTool(t, "qtpaths6", "6.11.2", plugins)
		results := checkQtPlatformThemePlugin("QT_QPA_PLATFORMTHEME")
		if len(results) != 1 || results[0].status != statusWarn {
			t.Fatalf("got %+v, want one warn result", results)
		}
		want := filepath.Join(plugins, "platformthemes", "libqt6ct.so")
		if !strings.Contains(results[0].details, want) {
			t.Fatalf("details should contain expected path %s, got %q", want, results[0].details)
		}
	})

	t.Run("no Qt build tools degrades to info", func(t *testing.T) {
		t.Setenv("QT_QPA_PLATFORMTHEME", "qt6ct")
		t.Setenv("PATH", t.TempDir())
		results := checkQtPlatformThemePlugin("QT_QPA_PLATFORMTHEME")
		if len(results) != 1 || results[0].status != statusInfo {
			t.Fatalf("got %+v, want one info result", results)
		}
	})

	t.Run("unset and qtengine are left to their own checks", func(t *testing.T) {
		t.Setenv("PATH", t.TempDir())
		t.Setenv("QT_QPA_PLATFORMTHEME", "")
		if results := checkQtPlatformThemePlugin("QT_QPA_PLATFORMTHEME"); results != nil {
			t.Fatalf("unset should yield no results, got %+v", results)
		}
		t.Setenv("QT_QPA_PLATFORMTHEME", "qtengine")
		if results := checkQtPlatformThemePlugin("QT_QPA_PLATFORMTHEME"); results != nil {
			t.Fatalf("qtengine should yield no results, got %+v", results)
		}
	})

	t.Run("qt6 variable is not satisfied by a Qt5 tool alone", func(t *testing.T) {
		t.Setenv("QT_QPA_PLATFORMTHEME_QT6", "qt6ct")
		plugins := t.TempDir()
		stubQtQueryTool(t, "qmake-qt5", "5.15.19", plugins)
		results := checkQtPlatformThemePlugin("QT_QPA_PLATFORMTHEME_QT6")
		if len(results) != 1 || results[0].status != statusInfo {
			t.Fatalf("got %+v, want one info result", results)
		}
	})

	t.Run("kde plugin miss degrades to info", func(t *testing.T) {
		t.Setenv("QT_QPA_PLATFORMTHEME", "kde")
		plugins := t.TempDir()
		stubQtQueryTool(t, "qmake6", "6.11.2", plugins)
		results := checkQtPlatformThemePlugin("QT_QPA_PLATFORMTHEME")
		if len(results) != 1 || results[0].status != statusInfo {
			t.Fatalf("got %+v, want one info result", results)
		}
	})

	t.Run("gtk3 resolves through the libq convention", func(t *testing.T) {
		t.Setenv("QT_QPA_PLATFORMTHEME", "gtk3")
		plugins := t.TempDir()
		writePlugin(t, plugins, "libqgtk3.so")
		stubQtQueryTool(t, "qmake6", "6.11.2", plugins)
		results := checkQtPlatformThemePlugin("QT_QPA_PLATFORMTHEME")
		if len(results) != 1 || results[0].status != statusOK {
			t.Fatalf("got %+v, want one OK result", results)
		}
	})
}
