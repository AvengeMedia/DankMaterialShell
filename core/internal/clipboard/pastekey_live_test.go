package clipboard

import (
	"os"
	"testing"

	wlclient "github.com/AvengeMedia/dankgo/wayland/client"
	"golang.org/x/sys/unix"
)

func TestLiveSeatKeymapResolution(t *testing.T) {
	if os.Getenv("DMS_LIVE_TEST") == "" {
		t.Skip("set DMS_LIVE_TEST=1 to run against the live compositor")
	}

	s, err := connectSession()
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	defer s.Close()

	if s.virtualKeyboardMgr == nil {
		t.Fatal("compositor does not advertise zwp_virtual_keyboard_manager_v1")
	}
	if s.seat == nil {
		t.Fatal("no seat")
	}

	keyboard, err := s.seat.GetKeyboard()
	if err != nil {
		t.Fatalf("get keyboard: %v", err)
	}
	defer keyboard.Release()

	var keymap *wlclient.KeyboardKeymapEvent
	keyboard.SetKeymapHandler(func(e wlclient.KeyboardKeymapEvent) {
		if keymap == nil {
			keymap = &e
		}
	})
	s.display.Roundtrip()

	if keymap == nil {
		t.Fatal("no keymap event")
	}
	defer unix.Close(keymap.Fd)

	text, err := readKeymap(keymap.Fd, keymap.Size)
	if err != nil {
		t.Fatalf("read keymap: %v", err)
	}

	if dump := os.Getenv("DMS_LIVE_DUMP"); dump != "" {
		if err := os.WriteFile(dump, []byte(text), 0o644); err != nil {
			t.Fatalf("dump keymap: %v", err)
		}
	}

	keys := resolveKeycodes(text)
	t.Logf("keymap size=%d resolved ctrl=%d shift=%d v=%d", keymap.Size, keys.ctrl, keys.shift, keys.v)

	if keys.ctrl == fallbackCtrlKey && keys.shift == fallbackShiftKey && keys.v == fallbackVKey {
		t.Log("all keycodes are fallbacks - parsing may not have matched the live keymap")
	}
}
