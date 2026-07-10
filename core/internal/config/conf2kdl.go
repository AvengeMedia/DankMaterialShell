package config

import (
	"regexp"
	"strings"
)

// ConfToKDL converts an asteroidz legacy `key=value` fragment into nested
// (Niri-style) KDL — the inverse of the compositor's semantic walker
// (src/config/parse_config.h + contrib/kdlnest.py). Options are grouped into
// sections by KEY_MAP; binds/rules/tags/outputs/env/spawn get structural
// blocks. Used when DMS deploys asteroidz config fragments.

var kdlKeyMap = map[string]string{
	"xkb_layout": "input/keyboard/xkb/layout",
	"repeat_delay": "input/keyboard/repeat/delay",
	"repeat_rate": "input/keyboard/repeat/rate",
	"cursor_theme": "input/cursor/theme",
	"cursor_size": "input/cursor/size",
	"enable_titlebar": "layout/titlebar/enable",
	"titlebar_height": "layout/titlebar/height",
	"borderpx": "layout/border/width",
	"bordercolor": "layout/border/color",
	"focuscolor": "layout/border/focus-color",
	"urgentcolor": "layout/border/urgent-color",
	"border_gradient": "layout/border/gradient/enable",
	"border_gradient_angle": "layout/border/gradient/angle",
	"border_gradient_color2": "layout/border/gradient/color2",
	"monocle_tab_max_width": "layout/monocle/tab-max-width",
	"scroller_structs": "layout/scroller/structs",
	"scroller_default_proportion": "layout/scroller/default-proportion",
	"scroller_default_proportion_single": "layout/scroller/default-proportion-single",
	"scroller_focus_center": "layout/scroller/focus-center",
	"scroller_prefer_center": "layout/scroller/prefer-center",
	"scroller_proportion_preset": "layout/scroller/preset",
	"scroller_edge_scroll": "layout/scroller/edge-scroll/enable",
	"scroller_edge_scroll_size": "layout/scroller/edge-scroll/size",
	"scroller_edge_scroll_delay": "layout/scroller/edge-scroll/delay",
	"edge_scroller_pointer_focus": "layout/scroller/edge-scroll/pointer-focus",
	"edge_scroller_focus_allow_speed": "layout/scroller/edge-scroll/allow-speed",
	"blur": "effects/blur/enable",
	"blur_layer": "effects/blur/layer",
	"blur_optimized": "effects/blur/optimized",
	"blur_unfocused_strength": "effects/blur/unfocused-strength",
	"blur_params_num_passes": "effects/blur/passes",
	"blur_params_radius": "effects/blur/radius",
	"blur_params_noise": "effects/blur/params/noise",
	"blur_params_brightness": "effects/blur/params/brightness",
	"blur_params_contrast": "effects/blur/params/contrast",
	"blur_params_saturation": "effects/blur/params/saturation",
	"blur_transparency_threshold": "effects/blur/transparency-threshold",
	"shadows": "effects/shadow/enable",
	"layer_shadows": "effects/shadow/layer",
	"shadow_only_floating": "effects/shadow/only-floating",
	"shadows_size": "effects/shadow/size",
	"shadows_blur": "effects/shadow/blur",
	"shadows_position_x": "effects/shadow/position/x",
	"shadows_position_y": "effects/shadow/position/y",
	"shadowscolor": "effects/shadow/color",
	"shadows_unfocused_scale": "effects/shadow/unfocused-scale",
	"shadows_tiled_scale": "effects/shadow/tiled-scale",
	"shadows_contact": "effects/shadow/contact/enable",
	"shadows_contact_size": "effects/shadow/contact/size",
	"shadows_contact_blur": "effects/shadow/contact/blur",
	"shadows_contact_position_x": "effects/shadow/contact/position/x",
	"shadows_contact_position_y": "effects/shadow/contact/position/y",
	"shadowscolor_contact": "effects/shadow/contact/color",
	"pill_decorate_border_width": "pill/border-width",
	"pill_decorate_corner_radius": "pill/corner-radius",
	"pill_decorate_padding_x": "pill/padding/x",
	"pill_decorate_padding_y": "pill/padding/y",
	"pill_decorate_font_desc": "pill/font",
	"pill_decorate_bg_color": "pill/bg-color",
	"pill_decorate_fg_color": "pill/fg-color",
	"pill_decorate_focus_bg_color": "pill/focus-bg-color",
	"pill_decorate_focus_fg_color": "pill/focus-fg-color",
	"animation_curve_type": "animations/curve",
	"spring_damping": "animations/spring/damping",
	"spring_frequency": "animations/spring/frequency",
	"animation_type_open": "animations/window-open/type",
	"animation_duration_open": "animations/window-open/duration",
	"fadein_begin_opacity": "animations/window-open/fade-begin-opacity",
	"animation_type_close": "animations/window-close/type",
	"animation_duration_close": "animations/window-close/duration",
	"fadeout_begin_opacity": "animations/window-close/fade-begin-opacity",
	"overviewgappi": "overview/gaps/inner",
	"overviewgappo": "overview/gaps/outer",
	"hotarea_size": "overview/hotarea/size",
	"enable_hotarea": "overview/hotarea/enable",
	"ov_tab_mode": "overview/tab-mode",
	"ov_no_resize": "overview/no-resize",
	"xwayland_persistence": "misc/xwayland-persistence",
	"syncobj_enable": "misc/syncobj",
	"focus_on_activate": "misc/focus-on-activate",
	"allow_tearing": "misc/allow-tearing",
	"sdr_reference_luminance": "misc/sdr/reference-luminance",
	"sdr_saturation": "misc/sdr/saturation",
	"dpms_wake_retrain": "misc/dpms-wake-retrain",
	"drag_tile_to_tile": "misc/drag-tile-to-tile",
	"icon_theme": "misc/icon-theme",
}

type kdlRuleField struct{ where, nice string }

var kdlRuleMap = map[string]kdlRuleField{
	"appid": {"match", "app-id"}, "title": {"match", "title"},
	"isfloating": {"act", "open-floating"}, "isfullscreen": {"act", "open-fullscreen"},
	"noblur": {"act", "no-blur"}, "isnoborder": {"act", "no-border"},
	"isnoshadow": {"act", "no-shadow"}, "isnoradius": {"act", "no-rounding"},
	"isnoanimation": {"act", "no-animation"},
}
var kdlOutputMap = map[string]string{
	"bitdepth": "bit-depth", "icc_profile": "icc-profile",
	"hdr_max_luminance": "max-luminance", "hdr_min_luminance": "min-luminance",
	"hdr_max_fall": "max-fall",
}
var kdlModBack = map[string]string{"SUPER": "Super", "CTRL": "Ctrl", "ALT": "Alt", "SHIFT": "Shift"}
var kdlBindRe2 = regexp.MustCompile(`^bind[slrp]*$`)
var kdlNumRe2 = regexp.MustCompile(`^-?\d+(\.\d+)?$`)
var kdlBareRe2 = regexp.MustCompile(`^[^\s{}()="\\;/]+$`)

func kdlQuote(s string) string {
	if s == "" {
		return `""`
	}
	if kdlNumRe2.MatchString(s) {
		return s
	}
	if s == "true" || s == "false" || s == "null" {
		return `"` + s + `"`
	}
	if kdlBareRe2.MatchString(s) {
		return s
	}
	return `"` + strings.ReplaceAll(strings.ReplaceAll(s, `\`, `\\`), `"`, `\"`) + `"`
}

type kdlTree struct {
	leafKeys []string
	leafVals map[string]string
	subKeys  []string
	subs     map[string]*kdlTree
}

func newKdlTree() *kdlTree {
	return &kdlTree{leafVals: map[string]string{}, subs: map[string]*kdlTree{}}
}
func (t *kdlTree) put(path, val string) {
	parts := strings.Split(path, "/")
	n := t
	for _, p := range parts[:len(parts)-1] {
		if n.subs[p] == nil {
			n.subs[p] = newKdlTree()
			n.subKeys = append(n.subKeys, p)
		}
		n = n.subs[p]
	}
	leaf := parts[len(parts)-1]
	if _, ok := n.leafVals[leaf]; !ok {
		n.leafKeys = append(n.leafKeys, leaf)
	}
	n.leafVals[leaf] = val
}
func (t *kdlTree) render(indent int) []string {
	pad := strings.Repeat("    ", indent)
	var out []string
	for _, k := range t.leafKeys {
		if v := t.leafVals[k]; v == "" {
			out = append(out, pad+k)
		} else {
			out = append(out, pad+k+" "+kdlQuote(v))
		}
	}
	for _, name := range t.subKeys {
		out = append(out, pad+name+" {")
		out = append(out, t.subs[name].render(indent+1)...)
		out = append(out, pad+"}")
	}
	return out
}
func (t *kdlTree) empty() bool { return len(t.leafKeys) == 0 && len(t.subKeys) == 0 }

func ConfToKDL(content string) string {
	root := newKdlTree()
	var binds, mbinds, tags, outputs, env, spawn, source, rules []string

	for _, raw := range strings.Split(content, "\n") {
		line := strings.TrimRight(raw, "\r")
		s := strings.TrimSpace(line)
		if s == "" || strings.HasPrefix(s, "#") {
			continue
		}
		eq := strings.Index(line, "=")
		if eq < 0 {
			continue
		}
		key := strings.TrimSpace(line[:eq])
		val := strings.TrimSpace(line[eq+1:])

		switch {
		case kdlBindRe2.MatchString(key) || key == "mousebind":
			f := strings.Split(val, ",")
			var mods []string
			for _, m := range strings.Split(f[0], "+") {
				if m == "" {
					continue
				}
				if b, ok := kdlModBack[m]; ok {
					mods = append(mods, b)
				} else {
					mods = append(mods, m)
				}
			}
			chord := f[1]
			if len(mods) > 0 {
				chord = strings.Join(mods, "+") + "+" + f[1]
			}
			act := ""
			if len(f) > 2 {
				act = f[2]
			}
			var args []string
			for _, a := range f[3:] {
				args = append(args, kdlQuote(a))
			}
			block := chord + " { " + act
			if len(args) > 0 {
				block += " " + strings.Join(args, " ")
			}
			block += "; }"
			if key == "mousebind" {
				mbinds = append(mbinds, block)
			} else {
				binds = append(binds, block)
			}
		case key == "env":
			f := strings.SplitN(val, ",", 2)
			v := ""
			if len(f) > 1 {
				v = f[1]
			}
			env = append(env, f[0]+" "+kdlQuote(v))
		case key == "exec-once" || key == "exec":
			kind := "spawn-at-startup"
			if key == "exec" {
				kind = "spawn"
			}
			var toks []string
			for _, t := range strings.Split(val, " ") {
				toks = append(toks, kdlQuote(t))
			}
			spawn = append(spawn, kind+" "+strings.Join(toks, " "))
		case key == "source" || key == "source-optional":
			if strings.HasSuffix(val, ".conf") {
				val = strings.TrimSuffix(val, ".conf") + ".kdl"
			}
			source = append(source, key+" "+kdlQuote(val))
		case key == "windowrule":
			var match, act []string
			for _, fld := range strings.Split(val, ",") {
				ci := strings.Index(fld, ":")
				if ci < 0 {
					continue
				}
				fk, fv := fld[:ci], fld[ci+1:]
				rf, ok := kdlRuleMap[fk]
				nice := fk
				if ok {
					nice = rf.nice
				}
				if ok && rf.where == "match" {
					match = append(match, nice+"="+kdlQuote(fv))
				} else if fv == "1" && (strings.HasPrefix(nice, "open-") || strings.HasPrefix(nice, "no-")) {
					act = append(act, nice)
				} else {
					act = append(act, nice+" "+kdlQuote(fv))
				}
			}
			parts := []string{}
			if len(match) > 0 {
				parts = append(parts, "match "+strings.Join(match, " "))
			}
			parts = append(parts, act...)
			rules = append(rules, "window-rule { "+strings.Join(parts, "; ")+" }")
		case key == "tagrule":
			id, ch := "", []string{}
			for _, fld := range strings.Split(val, ",") {
				ci := strings.Index(fld, ":")
				if ci < 0 {
					continue
				}
				fk, fv := fld[:ci], fld[ci+1:]
				switch fk {
				case "id":
					id = fv
				case "layout_name":
					ch = append(ch, "layout "+kdlQuote(fv))
				default:
					ch = append(ch, fk+" "+kdlQuote(fv))
				}
			}
			tags = append(tags, "tag "+kdlQuote(id)+" { "+strings.Join(ch, "; ")+" }")
		case key == "monitorrule":
			name, ch := "", []string{}
			for _, fld := range strings.Split(val, ",") {
				ci := strings.Index(fld, ":")
				if ci < 0 {
					continue
				}
				fk, fv := fld[:ci], fld[ci+1:]
				if fk == "name" {
					name = strings.Trim(fv, "^$")
				} else {
					nice := fk
					if m, ok := kdlOutputMap[fk]; ok {
						nice = m
					}
					if fv == "1" {
						ch = append(ch, nice)
					} else {
						ch = append(ch, nice+" "+kdlQuote(fv))
					}
				}
			}
			outputs = append(outputs, "output "+kdlQuote(name)+" { "+strings.Join(ch, "; ")+" }")
		default:
			if path, ok := kdlKeyMap[key]; ok {
				root.put(path, val)
			} else {
				root.put("misc/"+key, val)
			}
		}
	}

	var blocks []string
	if !root.empty() {
		blocks = append(blocks, strings.Join(root.render(0), "\n"))
	}
	if len(env) > 0 {
		blocks = append(blocks, "environment {\n    "+strings.Join(env, "\n    ")+"\n}")
	}
	blocks = append(blocks, spawn...)
	if len(binds) > 0 {
		blocks = append(blocks, "binds {\n    "+strings.Join(binds, "\n    ")+"\n}")
	}
	if len(mbinds) > 0 {
		blocks = append(blocks, "mouse-binds {\n    "+strings.Join(mbinds, "\n    ")+"\n}")
	}
	blocks = append(blocks, tags...)
	blocks = append(blocks, rules...)
	blocks = append(blocks, outputs...)
	blocks = append(blocks, source...)
	return strings.Join(blocks, "\n\n") + "\n"
}
