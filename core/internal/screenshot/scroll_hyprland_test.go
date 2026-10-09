package screenshot

import (
	"slices"
	"testing"
)

func TestHyprlandScrollCommands(t *testing.T) {
	cases := []struct {
		name   string
		status string
		focus  []string
		bind   []string
		unbind []string
	}{
		{
			name:   "lua",
			status: `{"configProvider": "lua", "backend": "drm"}`,
			focus:  []string{"dispatch", `hl.dsp.focus({ window = "address:0x55f56b093cf0" })`},
			bind:   []string{"eval", `hl.bind("Return", hl.dsp.exec_cmd("kill -USR1 4242")); hl.bind("Escape", hl.dsp.exec_cmd("kill -USR2 4242"))`},
			unbind: []string{"eval", `hl.unbind("Return"); hl.unbind("Escape")`},
		},
		{
			name:   "hyprland.conf on 0.55/0.56",
			status: `{"configProvider": "hyprlang", "backend": "drm"}`,
			focus:  []string{"dispatch", "focuswindow", "address:0x55f56b093cf0"},
			bind:   []string{"--batch", "keyword bind ,Return,exec,kill -USR1 4242 ; keyword bind ,Escape,exec,kill -USR2 4242"},
			unbind: []string{"--batch", "keyword unbind ,Return ; keyword unbind ,Escape"},
		},
		{
			name:   "pre-0.55 has no status request",
			status: "unknown request",
			focus:  []string{"dispatch", "focuswindow", "address:0x55f56b093cf0"},
			bind:   []string{"--batch", "keyword bind ,Return,exec,kill -USR1 4242 ; keyword bind ,Escape,exec,kill -USR2 4242"},
			unbind: []string{"--batch", "keyword unbind ,Return ; keyword unbind ,Escape"},
		},
	}
	for _, c := range cases {
		lua := hyprlandStatusIsLua([]byte(c.status))
		if got := hyprlandFocusArgs(lua, "0x55f56b093cf0"); !slices.Equal(got, c.focus) {
			t.Errorf("%s focus: got %q want %q", c.name, got, c.focus)
		}
		if got := hyprlandBindScrollKeysArgs(lua, 4242); !slices.Equal(got, c.bind) {
			t.Errorf("%s bind: got %q want %q", c.name, got, c.bind)
		}
		if got := hyprlandUnbindScrollKeysArgs(lua); !slices.Equal(got, c.unbind) {
			t.Errorf("%s unbind: got %q want %q", c.name, got, c.unbind)
		}
	}
}

// Hyprland scales the region by the monitor scale itself; device pixels here
// captured a box offset and enlarged by the scale on fractional outputs
func TestScrollCaptureRect(t *testing.T) {
	cases := []struct {
		comp  Compositor
		scale float64
		want  [4]int
	}{
		{CompositorHyprland, 1.25, [4]int{1230, 160, 642, 480}},
		{CompositorNiri, 1.25, [4]int{1230, 160, 642, 480}},
		{CompositorMango, 1.25, [4]int{1538, 200, 802, 600}},
		{CompositorHyprland, 1, [4]int{1538, 200, 802, 600}},
	}
	for _, c := range cases {
		x, y, w, h := scrollCaptureRect(c.comp, c.scale, 1538, 200, 802, 600)
		if got := [4]int{x, y, w, h}; got != c.want {
			t.Errorf("compositor %d scale %v: got %v want %v", c.comp, c.scale, got, c.want)
		}
	}
}
