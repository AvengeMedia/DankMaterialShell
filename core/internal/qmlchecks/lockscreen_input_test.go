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
}

func TestLockScreenAuthenticationCardOwnsFactorControls(t *testing.T) {
	data, err := os.ReadFile("../../../quickshell/Modules/Settings/LockScreenTab.qml")
	if err != nil {
		t.Fatalf("read lock screen settings QML: %v", err)
	}

	content := string(data)
	authCard := strings.Index(content, `title: I18n.tr("Lock Screen Authentication")`)
	behaviorCard := strings.Index(content, `title: I18n.tr("Lock Screen behaviour")`)
	fingerprintToggle := strings.Index(content, `settingKey: "enableFprint"`)
	u2fToggle := strings.Index(content, `settingKey: "enableU2f"`)
	u2fSource := strings.Index(content, `settingKey: "lockU2fPamPath"`)
	if authCard < 0 || behaviorCard < 0 || fingerprintToggle < 0 || u2fToggle < 0 || u2fSource < 0 {
		t.Fatalf("expected authentication card, factor toggles, and U2F source setting")
	}
	for name, position := range map[string]int{
		"fingerprint toggle": fingerprintToggle,
		"U2F toggle":         u2fToggle,
		"U2F source":         u2fSource,
	} {
		if position < authCard || position > behaviorCard {
			t.Fatalf("%s must remain in the authentication card", name)
		}
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
