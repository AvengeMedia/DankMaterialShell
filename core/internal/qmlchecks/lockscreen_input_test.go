package qmlchecks

import (
	"os"
	"regexp"
	"strings"
	"testing"
)

func TestLockScreenPasswordFieldBypassesTextInputIME(t *testing.T) {
	data, err := os.ReadFile("../../../quickshell/Modules/Lock/LockScreenContent.qml")
	if err != nil {
		t.Fatalf("read lock screen QML: %v", err)
	}

	content := string(data)
	textInputPasswordField := regexp.MustCompile(`(?s)TextInput\s*\{[^{}]*id:\s*passwordField`)
	if textInputPasswordField.MatchString(content) {
		t.Fatalf("passwordField must not be a TextInput because TextInput can route physical keyboard input through IME")
	}

	if !strings.Contains(content, "Keys.onPressed") || !strings.Contains(content, "event.text") {
		t.Fatalf("passwordField should handle physical key text manually instead of relying on a text input control")
	}

	// Wayland IMEs commit unconsumed printable keys as text-input text rather
	// than forwarding raw keys, so the lock screen needs an IME commit sink
	// alongside raw key handling.
	if !strings.Contains(content, "id: imeCommitSink") {
		t.Fatalf("passwordField must keep the imeCommitSink TextInput so IME-routed keyboards can type (#2950)")
	}
	if !strings.Contains(content, "Qt.ImhSensitiveData") {
		t.Fatalf("imeCommitSink must advertise hidden-text hints so IMEs treat it as a password field")
	}
}

func TestLockScreenPamSupportsManagedAndSystemPolicies(t *testing.T) {
	data, err := os.ReadFile("../../../quickshell/Modules/Lock/Pam.qml")
	if err != nil {
		t.Fatalf("read lock screen PAM QML: %v", err)
	}

	content := string(data)
	for _, required := range []string{
		"SettingsData.lockPamExternallyManaged",
		"SettingsData.lockU2fPamPath",
		"customU2fPamActive",
		"u2fSuppressedByPrimaryPam",
	} {
		if !strings.Contains(content, required) {
			t.Fatalf("lock screen PAM must contain %q", required)
		}
	}
	if strings.Contains(content, "runningFromNixStore || resolveUserPam.running") {
		t.Fatalf("DMS-managed policy must generate the sanitized user PAM stack on Nix-store installs")
	}
}
