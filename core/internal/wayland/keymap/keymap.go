package keymap

import (
	"regexp"
	"strconv"
	"strings"

	"github.com/AvengeMedia/dankgo/wayland/client"
	"golang.org/x/sys/unix"
)

const FormatXkbV1 = 1

// wl_keyboard.key carries evdev scancodes; xkb keycodes sit 8 above them.
const evdevOffset = 8

var pc105Codes = map[string]uint32{
	"Escape":    1,
	"p":         25,
	"Return":    28,
	"Control_L": 29,
	"Shift_L":   42,
	"v":         47,
	"Alt_L":     56,
	"space":     57,
	"KP_Enter":  96,
	"Control_R": 97,
	"Alt_R":     100,
}

var pc105Syms = invert(pc105Codes)

// xkbcommon may serialize keysyms as hex instead of names.
var keysymNames = map[uint32]string{
	0x20:   "space",
	0x70:   "p",
	0x76:   "v",
	0xff0d: "Return",
	0xff1b: "Escape",
	0xff8d: "KP_Enter",
	0xffe1: "Shift_L",
	0xffe3: "Control_L",
	0xffe4: "Control_R",
	0xffe9: "Alt_L",
	0xffea: "Alt_R",
}

var (
	keycodeDefRe = regexp.MustCompile(`<([A-Za-z0-9+_-]+)>\s*=\s*(\d+)`)
	keySymbolsRe = regexp.MustCompile(`key\s*<([A-Za-z0-9+_-]+)>\s*\{([^}]*)\}`)
	groupIndexRe = regexp.MustCompile(`\w+\[\d+\]\s*=`)
	symbolListRe = regexp.MustCompile(`\[([^\]]*)\]`)
)

// Keymap maps evdev scancodes to their first-group, first-level keysym names.
// A nil Keymap answers with pc105 positions.
type Keymap struct {
	symByCode map[uint32]string
	codeBySym map[string]uint32
}

// FromEvent owns and closes the keymap fd; nil means no usable xkb keymap.
func FromEvent(e client.KeyboardKeymapEvent) *Keymap {
	defer unix.Close(e.Fd)
	if e.Format != FormatXkbV1 {
		return nil
	}
	text, err := Read(e.Fd, e.Size)
	if err != nil {
		return nil
	}
	return Parse(text)
}

func Read(fd int, size uint32) (string, error) {
	data, err := unix.Mmap(fd, 0, int(size), unix.PROT_READ, unix.MAP_PRIVATE)
	if err != nil {
		return "", err
	}
	text := strings.TrimRight(string(data), "\x00")
	return text, unix.Munmap(data)
}

func Parse(text string) *Keymap {
	xkbCodes := map[string]uint32{}
	for _, m := range keycodeDefRe.FindAllStringSubmatch(text, -1) {
		if code, err := strconv.Atoi(m[2]); err == nil {
			xkbCodes[m[1]] = uint32(code)
		}
	}

	k := &Keymap{symByCode: map[uint32]string{}, codeBySym: map[string]uint32{}}
	for _, m := range keySymbolsRe.FindAllStringSubmatch(text, -1) {
		group := symbolListRe.FindStringSubmatch(groupIndexRe.ReplaceAllString(m[2], ""))
		if group == nil {
			continue
		}
		xkbCode, ok := xkbCodes[m[1]]
		if !ok || xkbCode < evdevOffset {
			continue
		}
		sym := canonicalKeysym(strings.TrimSpace(strings.Split(group[1], ",")[0]))
		if sym == "" {
			continue
		}
		code := xkbCode - evdevOffset
		k.symByCode[code] = sym
		if _, seen := k.codeBySym[sym]; !seen {
			k.codeBySym[sym] = code
		}
	}
	return k
}

func (k *Keymap) Keysym(code uint32) string {
	if k == nil {
		return pc105Syms[code]
	}
	if sym, ok := k.symByCode[code]; ok {
		return sym
	}
	return pc105Syms[code]
}

func (k *Keymap) Keycode(sym string) uint32 {
	if k == nil {
		return pc105Codes[sym]
	}
	if code, ok := k.codeBySym[sym]; ok {
		return code
	}
	return pc105Codes[sym]
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

func invert(m map[string]uint32) map[uint32]string {
	out := make(map[uint32]string, len(m))
	for sym, code := range m {
		out[code] = sym
	}
	return out
}
