package keymap

import "testing"

const qwertyKeymap = `xkb_keymap {
xkb_keycodes "(unnamed)" {
	minimum = 8;
	maximum = 708;
	<ESC>  = 9;
	<AB04> = 55;
	<LCTL> = 37;
	<LFSH> = 50;
	alias <AL01> = <AC01>;
	indicator 1 = "Caps Lock";
};
xkb_types "(unnamed)" {
	type "ALPHABETIC" {
		modifiers = Shift+Lock;
		map[Shift] = Level2;
		level_name[Level1] = "Base";
	};
};
xkb_symbols "(unnamed)" {
	key <ESC>  { [ Escape ] };
	key <AB04> { type= "ALPHABETIC", [ v, V ] };
	key <LCTL> { [ Control_L ] };
	key <LFSH> { [ Shift_L ] };
};
};`

const hexKeymap = `xkb_keymap {
xkb_keycodes "(unnamed)" {
	<AB04> = 56;
	<LCTL> = 38;
	<LFSH> = 51;
};
xkb_symbols "(unnamed)" {
	key <LCTL> {	[ 0xffe3 ] };
	key <LFSH> {
		type= "PC_ALT_LEVEL2",
		symbols[1]= [ 0xffe1, 0xfe08 ]
	};
	key <AB04> {	[ 0x76, 0x56 ] };
};
};`

const dvorakKeymap = `xkb_keymap {
xkb_keycodes "(unnamed)" {
	<AB09> = 60;
	<LCTL> = 37;
	<LFSH> = 50;
};
xkb_symbols "(unnamed)" {
	key <AB09> { [ v, V ] };
	key <LCTL> { [ Control_L ] };
	key <LFSH> { [ Shift_L ] };
};
};`

const swapEscapeKeymap = `xkb_keymap {
xkb_keycodes "(unnamed)" {
	<ESC>  = 9;
	<RTRN> = 36;
	<CAPS> = 66;
	<KPEN> = 104;
};
xkb_symbols "(unnamed)" {
	key <ESC>  {	[       Caps_Lock ] };
	key <RTRN> {	[          Return ] };
	key <CAPS> {
		type= "ONE_LEVEL",
		symbols[1]= [          Escape ]
	};
	key <KPEN> {	[        KP_Enter ] };
};
};`

func TestKeycode(t *testing.T) {
	tests := []struct {
		name   string
		keymap string
		sym    string
		want   uint32
	}{
		{"qwerty v", qwertyKeymap, "v", 47},
		{"qwerty ctrl", qwertyKeymap, "Control_L", 29},
		{"qwerty shift", qwertyKeymap, "Shift_L", 42},
		{"dvorak v", dvorakKeymap, "v", 52},
		{"hex v", hexKeymap, "v", 48},
		{"hex ctrl", hexKeymap, "Control_L", 30},
		{"hex shift", hexKeymap, "Shift_L", 43},
		{"swapescape escape", swapEscapeKeymap, "Escape", 58},
		{"missing falls back to pc105", dvorakKeymap, "Escape", 1},
		{"empty falls back to pc105", "", "v", 47},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Parse(tt.keymap).Keycode(tt.sym); got != tt.want {
				t.Errorf("Keycode(%q) = %d, want %d", tt.sym, got, tt.want)
			}
		})
	}
}

func TestKeysym(t *testing.T) {
	tests := []struct {
		name   string
		keymap string
		code   uint32
		want   string
	}{
		{"swapescape caps yields Escape", swapEscapeKeymap, 58, "Escape"},
		{"swapescape esc yields Caps_Lock", swapEscapeKeymap, 1, "Caps_Lock"},
		{"swapescape return", swapEscapeKeymap, 28, "Return"},
		{"swapescape keypad enter", swapEscapeKeymap, 96, "KP_Enter"},
		{"qwerty escape", qwertyKeymap, 1, "Escape"},
		{"hex ctrl", hexKeymap, 30, "Control_L"},
		{"unmapped code falls back to pc105", qwertyKeymap, 28, "Return"},
		{"unknown code is empty", qwertyKeymap, 200, ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Parse(tt.keymap).Keysym(tt.code); got != tt.want {
				t.Errorf("Keysym(%d) = %q, want %q", tt.code, got, tt.want)
			}
		})
	}
}

func TestNilKeymapUsesPc105(t *testing.T) {
	var k *Keymap
	if got := k.Keysym(1); got != "Escape" {
		t.Errorf("Keysym(1) = %q, want Escape", got)
	}
	if got := k.Keycode("Control_L"); got != 29 {
		t.Errorf("Keycode(Control_L) = %d, want 29", got)
	}
}
