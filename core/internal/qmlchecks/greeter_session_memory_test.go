package qmlchecks

import (
	"os"
	"strings"
	"testing"
)

func TestGreeterRememberLastSessionFallsBackToDesktopID(t *testing.T) {
	data, err := os.ReadFile("../../../quickshell/Modules/Greetd/GreeterContent.qml")
	if err != nil {
		t.Fatalf("read greeter QML: %v", err)
	}

	content := string(data)
	if !strings.Contains(content, "GreetdMemory.lastSessionDesktopId || desktopIdFromPath(GreetdMemory.lastSessionId)") {
		t.Fatalf("remembered greeter sessions should derive a desktop id from legacy absolute session paths")
	}
	if !strings.Contains(content, "GreeterState.sessionDesktopIds[i] === savedDesktopId") {
		t.Fatalf("remembered greeter sessions should match current sessions by desktop id")
	}
}
