package main

import "testing"

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
