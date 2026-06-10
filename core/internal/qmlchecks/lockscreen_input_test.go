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
