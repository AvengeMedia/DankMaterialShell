package clipboard

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"

	wlclient "github.com/AvengeMedia/dankgo/wayland/client"
	"golang.org/x/sys/unix"
)

const (
	xkbKeymapFormatV1 = 1

	keyStateReleased = 0
	keyStatePressed  = 1

	// xkb real modifier bit positions are fixed: Shift=0, Lock=1, Control=2
	shiftModMask = 1 << 0
	ctrlModMask  = 1 << 2

	// evdev fallbacks for a standard pc105 map
	fallbackCtrlKey  = 29 // KEY_LEFTCTRL
	fallbackShiftKey = 42 // KEY_LEFTSHIFT
	fallbackVKey     = 47 // KEY_V
)

// SendPasteKeystroke emulates a paste shortcut via zwp_virtual_keyboard_v1
// using the seat's own keymap, so keycodes stay valid for XWayland clients
// (a synthetic wtype-style keymap breaks X11 apps like Steam). withShift
// selects ctrl+shift+v for terminal targets.
func SendPasteKeystroke(withShift bool) (err error) {
	s, err := connectSession()
	if err != nil {
		return err
	}
	defer s.Close()

	if s.virtualKeyboardMgr == nil {
		return fmt.Errorf("compositor does not support zwp_virtual_keyboard_manager_v1")
	}
	if s.seat == nil {
		return fmt.Errorf("no seat available")
	}

	keyboard, err := s.seat.GetKeyboard()
	if err != nil {
		return fmt.Errorf("get keyboard: %w", err)
	}
	defer keyboard.Release()

	var keymap *wlclient.KeyboardKeymapEvent
	keyboard.SetKeymapHandler(func(e wlclient.KeyboardKeymapEvent) {
		if keymap == nil {
			keymap = &e
		}
	})

	s.display.Roundtrip()

	if keymap == nil || keymap.Format != xkbKeymapFormatV1 {
		return fmt.Errorf("no xkb keymap from seat")
	}
	defer unix.Close(keymap.Fd)

	keymapText, err := readKeymap(keymap.Fd, keymap.Size)
	if err != nil {
		return fmt.Errorf("read keymap: %w", err)
	}
	keys := resolveKeycodes(keymapText)

	vk, err := s.virtualKeyboardMgr.CreateVirtualKeyboard(s.seat)
	if err != nil {
		return fmt.Errorf("create virtual keyboard: %w", err)
	}
	defer vk.Destroy()

	if err := vk.Keymap(xkbKeymapFormatV1, keymap.Fd, keymap.Size); err != nil {
		return fmt.Errorf("set keymap: %w", err)
	}

	mods := uint32(ctrlModMask)
	held := []uint32{keys.ctrl}
	if withShift {
		mods |= shiftModMask
		held = append(held, keys.shift)
	}

	t := uint32(0)
	var pressed []uint32
	press := func(key uint32) error {
		t++
		if err := vk.Key(t, key, keyStatePressed); err != nil {
			return err
		}
		pressed = append(pressed, key)
		return nil
	}

	// all releases happen here so error paths can't leave keys held or
	// modifiers latched for the compositor to interpret on destroy
	defer func() {
		for i := len(pressed) - 1; i >= 0; i-- {
			t++
			if e := vk.Key(t, pressed[i], keyStateReleased); e != nil && err == nil {
				err = fmt.Errorf("key release: %w", e)
			}
		}
		if e := vk.Modifiers(0, 0, 0, 0); e != nil && err == nil {
			err = fmt.Errorf("clear modifiers: %w", e)
		}
		s.display.Roundtrip()
	}()

	for _, key := range held {
		if err := press(key); err != nil {
			return fmt.Errorf("key press: %w", err)
		}
	}
	if err := vk.Modifiers(mods, 0, 0, 0); err != nil {
		return fmt.Errorf("set modifiers: %w", err)
	}
	if err := press(keys.v); err != nil {
		return fmt.Errorf("key press: %w", err)
	}
	return nil
}

func readKeymap(fd int, size uint32) (string, error) {
	data, err := unix.Mmap(fd, 0, int(size), unix.PROT_READ, unix.MAP_PRIVATE)
	if err != nil {
		return "", err
	}
	text := strings.TrimRight(string(data), "\x00")
	return text, unix.Munmap(data)
}

type pasteKeycodes struct {
	ctrl  uint32
	shift uint32
	v     uint32
}

var (
	keycodeDefRe = regexp.MustCompile(`<([A-Za-z0-9+_-]+)>\s*=\s*(\d+)`)
	keySymbolsRe = regexp.MustCompile(`key\s*<([A-Za-z0-9+_-]+)>\s*\{([^}]*)\}`)
	groupIndexRe = regexp.MustCompile(`\w+\[\d+\]\s*=`)
	symbolListRe = regexp.MustCompile(`\[([^\]]*)\]`)
)

// xkbcommon may serialize keysyms as hex escapes instead of names
// (e.g. "0x76" for v, "0xffe3" for Control_L).
var keysymNames = map[uint32]string{
	0x76:   "v",
	0xffe3: "Control_L",
	0xffe1: "Shift_L",
}

func canonicalKeysym(sym string) string {
	if !strings.HasPrefix(sym, "0x") && !strings.HasPrefix(sym, "0X") {
		return sym
	}
	value, err := strconv.ParseUint(sym[2:], 16, 32)
	if err != nil {
		return sym
	}
	if name, ok := keysymNames[uint32(value)]; ok {
		return name
	}
	return sym
}

// resolveKeycodes finds the evdev keycodes producing the keysyms we need in
// the seat keymap's first group, falling back to pc105 positions.
func resolveKeycodes(keymap string) pasteKeycodes {
	codes := map[string]uint32{}
	for _, m := range keycodeDefRe.FindAllStringSubmatch(keymap, -1) {
		if code, err := strconv.Atoi(m[2]); err == nil {
			codes[m[1]] = uint32(code)
		}
	}

	keys := pasteKeycodes{ctrl: fallbackCtrlKey, shift: fallbackShiftKey, v: fallbackVKey}
	want := map[string]*uint32{
		"Control_L": &keys.ctrl,
		"Shift_L":   &keys.shift,
		"v":         &keys.v,
	}

	for _, m := range keySymbolsRe.FindAllStringSubmatch(keymap, -1) {
		group := symbolListRe.FindStringSubmatch(groupIndexRe.ReplaceAllString(m[2], ""))
		if group == nil {
			continue
		}
		xkbCode, ok := codes[m[1]]
		if !ok || xkbCode < 8 {
			continue
		}
		level1 := canonicalKeysym(strings.TrimSpace(strings.Split(group[1], ",")[0]))
		target, wanted := want[level1]
		if !wanted {
			continue
		}
		*target = xkbCode - 8
		delete(want, level1)
		if len(want) == 0 {
			break
		}
	}

	return keys
}
