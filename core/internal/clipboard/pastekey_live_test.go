package clipboard

import (
	"os"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/wayland/keymap"
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

	var seatKeymap *wlclient.KeyboardKeymapEvent
	keyboard.SetKeymapHandler(func(e wlclient.KeyboardKeymapEvent) {
		if seatKeymap == nil {
			seatKeymap = &e
		}
	})
	s.display.Roundtrip()

	if seatKeymap == nil {
		t.Fatal("no keymap event")
	}
	defer unix.Close(seatKeymap.Fd)

	text, err := keymap.Read(seatKeymap.Fd, seatKeymap.Size)
	if err != nil {
		t.Fatalf("read keymap: %v", err)
	}

	if dump := os.Getenv("DMS_LIVE_DUMP"); dump != "" {
		if err := os.WriteFile(dump, []byte(text), 0o644); err != nil {
			t.Fatalf("dump keymap: %v", err)
		}
	}

	keys := keymap.Parse(text)
	t.Logf("keymap size=%d resolved ctrl=%d shift=%d v=%d", seatKeymap.Size,
		keys.Keycode("Control_L"), keys.Keycode("Shift_L"), keys.Keycode("v"))
}
