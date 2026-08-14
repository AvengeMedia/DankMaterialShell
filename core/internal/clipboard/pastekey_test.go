package clipboard

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

func TestResolveKeycodes(t *testing.T) {
	tests := []struct {
		name   string
		keymap string
		want   pasteKeycodes
	}{
		{"qwerty", qwertyKeymap, pasteKeycodes{ctrl: 29, shift: 42, v: 47}},
		{"dvorak", dvorakKeymap, pasteKeycodes{ctrl: 29, shift: 42, v: 52}},
		{"hex keysyms", hexKeymap, pasteKeycodes{ctrl: 30, shift: 43, v: 48}},
		{"empty falls back", "", pasteKeycodes{ctrl: fallbackCtrlKey, shift: fallbackShiftKey, v: fallbackVKey}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := resolveKeycodes(tt.keymap)
			if got != tt.want {
				t.Errorf("resolveKeycodes() = %+v, want %+v", got, tt.want)
			}
		})
	}
}
