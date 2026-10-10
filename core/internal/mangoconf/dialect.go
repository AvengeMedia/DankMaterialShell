// Package mangoconf maps Mango config keys between the run-together names of
// Mango <= 0.17.5 and the snake_case names of upstream 8adc6bc3 (mangowm/mango#1491).
// Neither parser accepts the other's names.
package mangoconf

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"sync"
)

type Dialect int

const (
	Legacy Dialect = iota
	Snake
)

// Upstream migration order: where two legacy names share a snake name, the
// window-rule spelling comes first and wins the reverse lookup.
var renames = [][2]string{
	{"windowrule-once", "window_rule_once"},
	{"windowrule", "window_rule"},
	{"monitorrule", "monitor_rule"},
	{"tagrule", "tag_rule"},
	{"layerrule", "layer_rule"},
	{"devicerule", "device_rule"},
	{"source-optional", "source_optional"},
	{"exec-once", "exec_once"},
	{"keymode", "key_mode"},
	{"isnoborder", "no_border"},
	{"isnoshadow", "no_shadow"},
	{"isnoradius", "no_radius"},
	{"isnoanimation", "no_animation"},
	{"isnosizehint", "no_size_hint"},
	{"noblur", "no_blur"},
	{"noshadow", "no_shadow"},
	{"noanim", "no_animation"},
	{"nofocus", "no_focus"},
	{"nofadein", "no_fade_in"},
	{"nofadeout", "no_fade_out"},
	{"noswallow", "no_swallow"},
	{"special_gappih", "special_gap_inner_horizontal"},
	{"special_gappiv", "special_gap_inner_vertical"},
	{"special_gappoh", "special_gap_outer_horizontal"},
	{"special_gappov", "special_gap_outer_vertical"},
	{"gappih", "gap_inner_horizontal"},
	{"gappiv", "gap_inner_vertical"},
	{"gappoh", "gap_outer_horizontal"},
	{"gappov", "gap_outer_vertical"},
	{"overviewgappi", "overview_gap_inner"},
	{"overviewgappo", "overview_gap_outer"},
	{"default_mfact", "default_master_factor"},
	{"default_nmaster", "default_master_count"},
	{"animation_curve_opafadein", "animation_curve_opacity_fade_in"},
	{"animation_curve_opafadeout", "animation_curve_opacity_fade_out"},
	{"dwindle_hsplit", "dwindle_horizontal_split"},
	{"dwindle_vsplit", "dwindle_vertical_split"},
	{"fadein_begin_opacity", "fade_in_begin_opacity"},
	{"fadeout_begin_opacity", "fade_out_begin_opacity"},
	{"focusdir_only_zone_overlap", "focus_direction_only_zone_overlap"},
	{"force_fakemaximize", "force_fake_maximize"},
	{"idleinhibit_ignore_visible", "idle_inhibit_ignore_visible"},
	{"idleinhibit_when_focus", "idle_inhibit_when_focus"},
	{"idleinhibit_when_fullscreen", "idle_inhibit_when_fullscreen"},
	{"syncobj_enable", "sync_obj_enable"},
	{"isfakefullscreen", "is_fake_fullscreen"},
	{"isfloating", "is_floating"},
	{"isfullscreen", "is_fullscreen"},
	{"isunglobal", "is_unmanaged_global"},
	{"isglobal", "is_global"},
	{"isnamedscratchpad", "is_named_scratchpad"},
	{"isopensilent", "is_open_silent"},
	{"isoverlay", "is_overlay"},
	{"istagsilent", "is_tag_silent"},
	{"isterm", "is_term"},
	{"appid", "app_id"},
	{"bordercolor", "border_color"},
	{"borderpx", "border_px"},
	{"dropcolor", "drop_color"},
	{"focuscolor", "focus_color"},
	{"globalcolor", "global_color"},
	{"globalkeybinding", "global_key_binding"},
	{"maximizescreencolor", "maximized_screen_color"},
	{"mfact", "master_factor"},
	{"nmaster", "master_count"},
	{"numlockon", "numlock_on"},
	{"offsetx", "offset_x"},
	{"offsety", "offset_y"},
	{"overlaycolor", "overlay_color"},
	{"rootcolor", "root_color"},
	{"scratchpadcolor", "scratchpad_color"},
	{"shadowscolor", "shadows_color"},
	{"sloppyfocus", "sloppy_focus"},
	{"smartgaps", "smart_gaps"},
	{"splitcolor", "split_color"},
	{"urgentcolor", "urgent_color"},
	{"warpcursor", "warp_cursor"},
}

var toSnake, toLegacy = func() (map[string]string, map[string]string) {
	fwd := make(map[string]string, len(renames))
	rev := make(map[string]string, len(renames))
	for _, r := range renames {
		fwd[r[0]] = r[1]
		if _, ok := rev[r[1]]; !ok {
			rev[r[1]] = r[0]
		}
	}
	return fwd, rev
}()

// Normalize returns the snake_case name for a key in either dialect.
func Normalize(key string) string {
	if s, ok := toSnake[key]; ok {
		return s
	}
	return key
}

// Key spells a snake_case key in this dialect.
func (d Dialect) Key(snake string) string {
	if d == Snake {
		return snake
	}
	if l, ok := toLegacy[snake]; ok {
		return l
	}
	return snake
}

var keyLine = regexp.MustCompile(`^(\s*)([A-Za-z][A-Za-z_-]*)(\s*=\s*)(.*)$`)

// Translate respells every line key, and the field keys of rule lines, in this dialect.
func (d Dialect) Translate(text string) string {
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		m := keyLine.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		key := Normalize(m[2])
		value := m[4]
		switch key {
		case "window_rule", "window_rule_once", "tag_rule":
			value = d.translateFields(value, nil)
		case "layer_rule":
			value = d.translateFields(value, legacyLayerFields)
		}
		lines[i] = m[1] + d.Key(key) + m[3] + value
	}
	return strings.Join(lines, "\n")
}

// Layer rules spell these without the window rules' "is" prefix.
var legacyLayerFields = map[string]string{"no_shadow": "noshadow", "no_animation": "noanim"}

func (d Dialect) translateFields(value string, legacyOverride map[string]string) string {
	parts := strings.Split(value, ",")
	for i, part := range parts {
		k, v, ok := strings.Cut(part, ":")
		if !ok {
			continue
		}
		trimmed := strings.TrimSpace(k)
		key := d.Key(Normalize(trimmed))
		if l, ok := legacyOverride[Normalize(trimmed)]; ok && d == Legacy {
			key = l
		}
		parts[i] = strings.Replace(k, trimmed, key, 1) + ":" + v
	}
	return strings.Join(parts, ",")
}

// Legacy builds carry exec_once as a symbol name, so it cannot tell the dialects apart.
var snakeMarker = []byte("gap_inner_horizontal")

var (
	detectOnce sync.Once
	detected   Dialect
)

// Detect reads the mango binary because master and the last release both report 0.17.5.
func Detect() Dialect {
	detectOnce.Do(func() {
		path, err := exec.LookPath("mango")
		if err != nil {
			return
		}
		detected = DetectBinary(path)
	})
	return detected
}

func DetectBinary(path string) Dialect {
	data, err := os.ReadFile(path)
	if err != nil || !bytes.Contains(data, snakeMarker) {
		return Legacy
	}
	return Snake
}

// Mango reads each line into a 512-byte buffer and the value into 255 bytes; longer is cut silently.
const maxValueLen = 255

func CheckLine(line string) error {
	_, value, ok := strings.Cut(line, "=")
	if !ok || len(strings.TrimSpace(value)) <= maxValueLen {
		return nil
	}
	return fmt.Errorf("line is %d characters after '='; Mango truncates past %d", len(strings.TrimSpace(value)), maxValueLen)
}
