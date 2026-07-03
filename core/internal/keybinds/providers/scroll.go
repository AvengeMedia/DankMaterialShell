package providers

import "strings"

// Scroll-wheel binds are captured by the shell as niri's keysym names
// (WheelScrollUp/Down/Left/Right) regardless of the active compositor. Niri
// consumes them natively; every other provider speaks a different dialect, so the
// raw niri token must be translated on write and back again on read. Without this
// the token is emitted verbatim and the compositor rejects the bind (issue #2683).

var canonicalScrollKeys = map[string]string{
	"wheelscrollup":    "WheelScrollUp",
	"wheelscrolldown":  "WheelScrollDown",
	"wheelscrollleft":  "WheelScrollLeft",
	"wheelscrollright": "WheelScrollRight",
}

func isScrollKey(token string) bool {
	_, ok := canonicalScrollKeys[strings.ToLower(token)]
	return ok
}

// Hyprland binds the wheel inside a regular bind using mouse_up/down/left/right.
var hyprlandScrollNative = map[string]string{
	"wheelscrollup":    "mouse_up",
	"wheelscrolldown":  "mouse_down",
	"wheelscrollleft":  "mouse_left",
	"wheelscrollright": "mouse_right",
}

var hyprlandScrollCanonical = map[string]string{
	"mouse_up":    "WheelScrollUp",
	"mouse_down":  "WheelScrollDown",
	"mouse_left":  "WheelScrollLeft",
	"mouse_right": "WheelScrollRight",
}

func hyprlandScrollToNative(token string) (string, bool) {
	v, ok := hyprlandScrollNative[strings.ToLower(token)]
	return v, ok
}

func hyprlandScrollToCanonical(token string) (string, bool) {
	v, ok := hyprlandScrollCanonical[strings.ToLower(token)]
	return v, ok
}

// MangoWC binds the wheel through a dedicated axisbind directive whose key field
// is a direction (UP/DOWN/LEFT/RIGHT) rather than a keysym.
const mangowcAxisBindPrefix = "axisbind"

var mangowcScrollDirection = map[string]string{
	"wheelscrollup":    "UP",
	"wheelscrolldown":  "DOWN",
	"wheelscrollleft":  "LEFT",
	"wheelscrollright": "RIGHT",
}

var mangowcScrollCanonical = map[string]string{
	"up":    "WheelScrollUp",
	"down":  "WheelScrollDown",
	"left":  "WheelScrollLeft",
	"right": "WheelScrollRight",
}

func mangowcScrollToDirection(token string) (string, bool) {
	v, ok := mangowcScrollDirection[strings.ToLower(token)]
	return v, ok
}

func mangowcDirectionToScroll(direction string) (string, bool) {
	v, ok := mangowcScrollCanonical[strings.ToLower(direction)]
	return v, ok
}
