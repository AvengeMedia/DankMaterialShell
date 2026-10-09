package providers

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/windowrules"
)

func TestParseWindowRuleV1(t *testing.T) {
	parser := NewHyprlandRulesParser("")

	tests := []struct {
		name      string
		line      string
		wantClass string
		wantFloat bool
		wantTile  bool
	}{
		{name: "basic float rule", line: "windowrule = float, ^(firefox)$", wantClass: "^(firefox)$", wantFloat: true},
		{name: "tile rule", line: "windowrule = tile, steam", wantClass: "steam", wantTile: true},
		{name: "no match returns empty class", line: "windowrule = float"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parser.parseWindowRuleLine(tt.line)
			if result == nil {
				t.Fatal("expected non-nil result")
			}
			if result.Match.AppID != tt.wantClass {
				t.Errorf("AppID = %q, want %q", result.Match.AppID, tt.wantClass)
			}
			if (result.Actions.OpenFloating != nil) != tt.wantFloat {
				t.Errorf("OpenFloating = %v, want %v", result.Actions.OpenFloating, tt.wantFloat)
			}
			if (result.Actions.Tile != nil) != tt.wantTile {
				t.Errorf("Tile = %v, want %v", result.Actions.Tile, tt.wantTile)
			}
		})
	}
}

func TestParseWindowRuleV2(t *testing.T) {
	parser := NewHyprlandRulesParser("")

	tests := []struct {
		name        string
		line        string
		wantClass   string
		wantTitle   string
		wantOpacity float64
		wantMax     bool
	}{
		{name: "float with class", line: "windowrulev2 = float, class:^(firefox)$", wantClass: "^(firefox)$"},
		{name: "opacity with value", line: "windowrulev2 = opacity 0.8, class:^(code)$", wantClass: "^(code)$", wantOpacity: 0.8},
		{name: "maximize", line: "windowrulev2 = maximize, class:^(steam)$", wantClass: "^(steam)$", wantMax: true},
		{name: "size with value and title", line: "windowrulev2 = size 800 600, class:^(steam)$, title:Settings", wantClass: "^(steam)$", wantTitle: "Settings"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parser.parseWindowRuleLine(tt.line)
			if result == nil {
				t.Fatal("expected non-nil result")
			}
			if result.Match.AppID != tt.wantClass {
				t.Errorf("AppID = %q, want %q", result.Match.AppID, tt.wantClass)
			}
			if result.Match.Title != tt.wantTitle {
				t.Errorf("Title = %q, want %q", result.Match.Title, tt.wantTitle)
			}
			if tt.wantOpacity != 0 && (result.Actions.Opacity == nil || *result.Actions.Opacity != tt.wantOpacity) {
				t.Errorf("Opacity = %v, want %v", result.Actions.Opacity, tt.wantOpacity)
			}
			if (result.Actions.OpenMaximized != nil) != tt.wantMax {
				t.Errorf("OpenMaximized = %v, want %v", result.Actions.OpenMaximized, tt.wantMax)
			}
		})
	}
}

func TestParseHyprlangMatchSyntax(t *testing.T) {
	tmpDir := t.TempDir()
	conf := `
windowrule = match:class ^(kitty)$, match:initial_title ^Login$, match:focus 1, float on, rounding 12
windowrule = no_initial_focus on, match:fullscreen_state_client 2, match:xdg_tag ^portal$, size 800 600
windowrule {
    name = steam-popups
    match:class = ^steam$
    match:modal = true
    match:title = ^a##b$ # trailing
    border_color = rgb(ff0000)
    move = 10 20
    float = on # x
}
windowrule = match:class ^(mpv)$, opacity 0.8 0.9 # x
`
	if err := os.WriteFile(filepath.Join(tmpDir, "hyprland.conf"), []byte(conf), 0644); err != nil {
		t.Fatal(err)
	}

	res, err := ParseHyprlandWindowRules(tmpDir)
	if err != nil {
		t.Fatalf("ParseHyprlandWindowRules: %v", err)
	}
	got := ConvertHyprlandRulesToWindowRules(res.Rules)
	if len(got) != 4 {
		t.Fatalf("expected 4 rules, got %d", len(got))
	}

	want := []struct {
		match windowrules.MatchCriteria
		act   windowrules.Actions
	}{
		{
			windowrules.MatchCriteria{AppID: "^(kitty)$", InitialTitle: "^Login$", IsFocused: new(true)},
			windowrules.Actions{OpenFloating: new(true), CornerRadius: new(12)},
		},
		{
			windowrules.MatchCriteria{FullscreenStateClient: new(2), XdgTag: "^portal$"},
			windowrules.Actions{NoInitialFocus: new(true), SizeWidth: "800", SizeHeight: "600"},
		},
		{
			windowrules.MatchCriteria{AppID: "^steam$", Title: "^a#b$", Modal: new(true)},
			windowrules.Actions{BorderColor: "rgb(ff0000)", MoveX: "10", MoveY: "20", OpenFloating: new(true)},
		},
		{
			windowrules.MatchCriteria{AppID: "^(mpv)$"},
			windowrules.Actions{Opacity: new(0.8)},
		},
	}
	for i, w := range want {
		if !reflect.DeepEqual(got[i].MatchCriteria, w.match) {
			t.Errorf("rule %d match = %+v, want %+v", i, got[i].MatchCriteria, w.match)
		}
		if !reflect.DeepEqual(got[i].Actions, w.act) {
			t.Errorf("rule %d actions = %+v, want %+v", i, got[i].Actions, w.act)
		}
	}
	if res.DMSStatus.ConfigFormat != "hyprlang" || !res.DMSStatus.ReadOnly {
		t.Errorf("status format=%q readOnly=%v, want hyprlang/true", res.DMSStatus.ConfigFormat, res.DMSStatus.ReadOnly)
	}
}

func TestHyprlandLuaPreferredOverConf(t *testing.T) {
	tmpDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(tmpDir, "hyprland.conf"), []byte("windowrule = match:class ^conf$, float on\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tmpDir, "hyprland.lua"), []byte(`hl.window_rule({ match = { class = "^lua$" }, float = true })`+"\n"), 0644); err != nil {
		t.Fatal(err)
	}

	res, err := ParseHyprlandWindowRules(tmpDir)
	if err != nil {
		t.Fatalf("ParseHyprlandWindowRules: %v", err)
	}
	if len(res.Rules) != 1 || res.Rules[0].Match.AppID != "^lua$" {
		t.Fatalf("expected only the Lua rule, got %+v", res.Rules)
	}
	if res.DMSStatus.ConfigFormat != "lua" || res.DMSStatus.ReadOnly {
		t.Errorf("status format=%q readOnly=%v, want lua/false", res.DMSStatus.ConfigFormat, res.DMSStatus.ReadOnly)
	}
	if err := NewHyprlandWritableProvider(tmpDir).EnsureWritable(); err != nil {
		t.Errorf("EnsureWritable with hyprland.lua present: %v", err)
	}
}

func TestHyprlandLoadDMSRulesFromConfFragment(t *testing.T) {
	tmpDir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(tmpDir, "dms"), 0755); err != nil {
		t.Fatal(err)
	}
	frag := "# DMS-RULE: id=ff, name=Firefox\nwindowrulev2 = float, class:^(firefox)$\n"
	if err := os.WriteFile(filepath.Join(tmpDir, "dms", "windowrules.conf"), []byte(frag), 0644); err != nil {
		t.Fatal(err)
	}

	rules, err := NewHyprlandWritableProvider(tmpDir).LoadDMSRules()
	if err != nil {
		t.Fatalf("LoadDMSRules: %v", err)
	}
	if len(rules) != 1 || rules[0].ID != "ff" || rules[0].Name != "Firefox" || rules[0].MatchCriteria.AppID != "^(firefox)$" {
		t.Fatalf("unexpected rules: %+v", rules)
	}
	if rules[0].Actions.OpenFloating == nil || !*rules[0].Actions.OpenFloating {
		t.Errorf("expected OpenFloating, got %+v", rules[0].Actions)
	}
}

func TestHyprlandSetRuleLeavesConfOnlyInstallReadOnly(t *testing.T) {
	tmpDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(tmpDir, "hyprland.conf"), []byte("windowrulev2 = float, class:^(kitty)$\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	provider := NewHyprlandWritableProvider(tmpDir)
	rule := newTestWindowRule("test_id", "Test Rule", "^(firefox)$")
	rule.Actions.OpenFloating = new(true)

	err := provider.SetRule(rule)
	if err == nil {
		t.Fatal("expected SetRule to reject conf-only Hyprland config")
	}
	if !strings.Contains(err.Error(), "read-only") {
		t.Fatalf("expected read-only error, got %v", err)
	}
	if _, err := os.Stat(filepath.Join(tmpDir, "dms", "windowrules.lua")); !os.IsNotExist(err) {
		t.Fatalf("expected no Lua windowrules file to be created for conf-only config, stat err=%v", err)
	}
}

func TestHyprlandRemoveRule(t *testing.T) {
	tmpDir := t.TempDir()
	provider := NewHyprlandWritableProvider(tmpDir)

	rule1 := newTestWindowRule("rule1", "Rule 1", "^(app1)$")
	rule1.Actions.OpenFloating = new(true)
	rule2 := newTestWindowRule("rule2", "Rule 2", "^(app2)$")
	rule2.Actions.OpenFloating = new(true)

	_ = provider.SetRule(rule1)
	_ = provider.SetRule(rule2)

	if err := provider.RemoveRule("rule1"); err != nil {
		t.Fatalf("RemoveRule failed: %v", err)
	}

	rules, _ := provider.LoadDMSRules()
	if len(rules) != 1 {
		t.Fatalf("expected 1 rule after removal, got %d", len(rules))
	}
	if rules[0].ID != "rule2" {
		t.Errorf("remaining rule ID = %q, want rule2", rules[0].ID)
	}
}

func TestHyprlandReorderRules(t *testing.T) {
	tmpDir := t.TempDir()
	provider := NewHyprlandWritableProvider(tmpDir)

	rule1 := newTestWindowRule("rule1", "Rule 1", "^(app1)$")
	rule1.Actions.OpenFloating = new(true)
	rule2 := newTestWindowRule("rule2", "Rule 2", "^(app2)$")
	rule2.Actions.OpenFloating = new(true)
	rule3 := newTestWindowRule("rule3", "Rule 3", "^(app3)$")
	rule3.Actions.OpenFloating = new(true)

	_ = provider.SetRule(rule1)
	_ = provider.SetRule(rule2)
	_ = provider.SetRule(rule3)

	if err := provider.ReorderRules([]string{"rule3", "rule1", "rule2"}); err != nil {
		t.Fatalf("ReorderRules failed: %v", err)
	}

	rules, _ := provider.LoadDMSRules()
	if len(rules) != 3 {
		t.Fatalf("expected 3 rules, got %d", len(rules))
	}
	expectedOrder := []string{"rule3", "rule1", "rule2"}
	for i, expectedID := range expectedOrder {
		if rules[i].ID != expectedID {
			t.Errorf("rule %d ID = %q, want %q", i, rules[i].ID, expectedID)
		}
	}
}

func TestHyprlandParseConfigWithSource(t *testing.T) {
	tmpDir := t.TempDir()

	mainConfig := `
windowrulev2 = float, class:^(mainapp)$
source = ./extra.conf
`
	extraConfig := `
windowrulev2 = tile, class:^(extraapp)$
`

	if err := os.WriteFile(filepath.Join(tmpDir, "hyprland.conf"), []byte(mainConfig), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tmpDir, "extra.conf"), []byte(extraConfig), 0644); err != nil {
		t.Fatal(err)
	}

	parser := NewHyprlandRulesParser(tmpDir)
	rules, err := parser.Parse()
	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	if len(rules) != 2 {
		t.Errorf("expected 2 rules, got %d", len(rules))
	}
}

func TestParseHyprlandLuaRequiresFragment(t *testing.T) {
	tmpDir := t.TempDir()
	dmsDir := filepath.Join(tmpDir, "dms")
	if err := os.MkdirAll(dmsDir, 0755); err != nil {
		t.Fatal(err)
	}

	mainLua := filepath.Join(tmpDir, "hyprland.lua")
	fragLua := filepath.Join(dmsDir, "windowrules.lua")

	if err := os.WriteFile(fragLua, []byte(`
hl.window_rule({ match = { class = "^test$" }, float = true })
`), 0644); err != nil {
		t.Fatal(err)
	}

	if err := os.WriteFile(mainLua, []byte(`
require("dms.windowrules")
`), 0644); err != nil {
		t.Fatal(err)
	}

	res, err := ParseHyprlandWindowRules(tmpDir)
	if err != nil {
		t.Fatalf("ParseHyprlandWindowRules: %v", err)
	}
	if len(res.Rules) != 1 {
		t.Fatalf("expected 1 rule, got %d", len(res.Rules))
	}
	if !res.DMSRulesIncluded {
		t.Fatal("expected dms.windowrules fragment to be marked included")
	}
	wr := ConvertHyprlandRulesToWindowRules(res.Rules)[0]
	if wr.MatchCriteria.AppID != "^test$" || wr.Actions.OpenFloating == nil || !*wr.Actions.OpenFloating {
		t.Fatalf("unexpected merged rule: %#v", wr)
	}
}

func TestFormatLuaManagedHyprRuleUsesLuaFieldNames(t *testing.T) {
	enabled := true
	rule := windowrules.WindowRule{
		ID:      "test-rule",
		Enabled: true,
		MatchCriteria: windowrules.MatchCriteria{
			AppID: "^app$",
		},
		Actions: windowrules.Actions{
			NoFocus:     &enabled,
			NoShadow:    &enabled,
			NoDim:       &enabled,
			NoBlur:      &enabled,
			NoAnim:      &enabled,
			ForcergbX:   &enabled,
			Idleinhibit: "focus",
		},
	}

	lines := formatLuaManagedHyprRule(rule)
	joined := strings.Join(lines, "\n")
	for _, want := range []string{
		"no_focus = true",
		"no_shadow = true",
		"no_dim = true",
		"no_blur = true",
		"no_anim = true",
		"force_rgbx = true",
		`idle_inhibit = "focus"`,
	} {
		if !strings.Contains(joined, want) {
			t.Fatalf("formatted rule missing %q: %s", want, joined)
		}
	}
}

func TestLuaAppendActionsTableSyntax(t *testing.T) {
	actions := windowrules.Actions{
		SizeWidth:  "800",
		SizeHeight: "600",
		MoveX:      "100",
		MoveY:      "200",
	}

	var out []string
	luaAppendActions(actions, &out)
	joined := strings.Join(out, "\n")
	for _, want := range []string{
		`size = { 800, 600 }`,
		`move = { 100, 200 }`,
	} {
		if !strings.Contains(joined, want) {
			t.Errorf("expected output to contain %q, got:\n%s", want, joined)
		}
	}
}

func TestLuaAppendActionsExprWrap(t *testing.T) {
	actions := windowrules.Actions{
		SizeWidth:  "window_w * 0.5",
		SizeHeight: "window_h - 50",
		MoveX:      "100",
		MoveY:      "(monitor_h / 2) + 17",
	}

	var out []string
	luaAppendActions(actions, &out)
	joined := strings.Join(out, "\n")
	for _, want := range []string{
		`size = { "window_w * 0.5", "window_h - 50" }`,
		`move = { 100, "(monitor_h / 2) + 17" }`,
	} {
		if !strings.Contains(joined, want) {
			t.Errorf("expected output to contain %q, got:\n%s", want, joined)
		}
	}
}

func TestApplyLuaActionKeyTableSyntax(t *testing.T) {
	tests := []struct {
		name      string
		key       string
		raw       string
		wantSizeW string
		wantSizeH string
		wantMoveX string
		wantMoveY string
	}{
		{
			name:      "size table syntax",
			key:       "size",
			raw:       `{ 800, 600 }`,
			wantSizeW: "800",
			wantSizeH: "600",
		},
		{
			name:      "move table syntax",
			key:       "move",
			raw:       `{ 100, 200 }`,
			wantMoveX: "100",
			wantMoveY: "200",
		},
		{
			name: "size string syntax returns false",
			key:  "size",
			raw:  `"800x600"`,
		},
		{
			name:      "size expressions",
			key:       "size",
			raw:       `{ "window_w * 0.5", "window_h - 50" }`,
			wantSizeW: "window_w * 0.5",
			wantSizeH: "window_h - 50",
		},
		{
			name:      "move expressions",
			key:       "move",
			raw:       `{ 100, "(monitor_h / 2) + 17" }`,
			wantMoveX: "100",
			wantMoveY: "(monitor_h / 2) + 17",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var a windowrules.Actions
			result := applyLuaActionKey(&a, tt.key, tt.raw)
			if tt.wantSizeW == "" && tt.wantSizeH == "" && tt.wantMoveX == "" && tt.wantMoveY == "" {
				if result {
					t.Errorf("expected applyLuaActionKey to return false for string syntax, got true")
				}
				return
			}
			if !result {
				t.Fatal("applyLuaActionKey returned false")
			}
			if tt.wantSizeW != "" && a.SizeWidth != tt.wantSizeW {
				t.Errorf("SizeWidth = %q, want %q", a.SizeWidth, tt.wantSizeW)
			}
			if tt.wantSizeH != "" && a.SizeHeight != tt.wantSizeH {
				t.Errorf("SizeHeight = %q, want %q", a.SizeHeight, tt.wantSizeH)
			}
			if tt.wantMoveX != "" && a.MoveX != tt.wantMoveX {
				t.Errorf("MoveX = %q, want %q", a.MoveX, tt.wantMoveX)
			}
			if tt.wantMoveY != "" && a.MoveY != tt.wantMoveY {
				t.Errorf("MoveY = %q, want %q", a.MoveY, tt.wantMoveY)
			}
		})
	}
}

func TestFormatLuaManagedHyprRuleHyprlandKeyNames(t *testing.T) {
	rule := windowrules.WindowRule{
		ID:      "keys",
		Enabled: true,
		MatchCriteria: windowrules.MatchCriteria{
			AppID:       "^app$",
			IsFloating:  new(true),
			Pinned:      new(false),
			Initialised: new(true),
		},
		Actions: windowrules.Actions{
			NoBorder:     new(true),
			NoRounding:   new(true),
			CornerRadius: new(8),
		},
	}
	joined := strings.Join(formatLuaManagedHyprRule(rule), "\n")

	for _, want := range []string{"float = true", "pin = false", "border_size = 0"} {
		if got := strings.Count(joined, want); got != 1 {
			t.Errorf("%q appears %d times, want 1:\n%s", want, got, joined)
		}
	}
	if got := strings.Count(joined, "rounding = "); got != 1 {
		t.Errorf("rounding key appears %d times, want 1:\n%s", got, joined)
	}
	if !strings.Contains(joined, "rounding = 0") {
		t.Errorf("missing rounding = 0:\n%s", joined)
	}
	for _, bad := range []string{"floating", "pinned", "noborder", "norounding", "rounding = 8", "initialised"} {
		if strings.Contains(joined, bad) {
			t.Errorf("unexpected %q:\n%s", bad, joined)
		}
	}
}

func TestFormatLuaManagedHyprRuleCornerRadiusWithoutNoRounding(t *testing.T) {
	rule := windowrules.WindowRule{
		ID:      "radius",
		Enabled: true,
		Actions: windowrules.Actions{CornerRadius: new(8)},
	}
	joined := strings.Join(formatLuaManagedHyprRule(rule), "\n")
	if !strings.Contains(joined, "rounding = 8") {
		t.Errorf("missing rounding = 8:\n%s", joined)
	}
}

func TestFormatLuaManagedHyprRuleCornerRadiusCapped(t *testing.T) {
	rule := windowrules.WindowRule{
		ID:      "radius",
		Enabled: true,
		Actions: windowrules.Actions{CornerRadius: new(24)},
	}
	joined := strings.Join(formatLuaManagedHyprRule(rule), "\n")
	if !strings.Contains(joined, "rounding = 20") {
		t.Errorf("rounding not capped at 20:\n%s", joined)
	}
}

func TestParseMatchLuaSpellings(t *testing.T) {
	tests := []struct {
		name         string
		in           string
		wantFloating *bool
		wantPinned   *bool
	}{
		{"floating", `{ floating = true }`, new(true), nil},
		{"float", `{ float = true }`, new(true), nil},
		{"float false", `{ float = false }`, new(false), nil},
		{"pinned", `{ pinned = true }`, nil, new(true)},
		{"pin", `{ pin = false }`, nil, new(false)},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var m windowrules.MatchCriteria
			parseMatchLua(tt.in, &m)
			if (m.IsFloating == nil) != (tt.wantFloating == nil) || (m.IsFloating != nil && *m.IsFloating != *tt.wantFloating) {
				t.Errorf("floating = %v, want %v", m.IsFloating, tt.wantFloating)
			}
			if (m.Pinned == nil) != (tt.wantPinned == nil) || (m.Pinned != nil && *m.Pinned != *tt.wantPinned) {
				t.Errorf("pinned = %v, want %v", m.Pinned, tt.wantPinned)
			}
		})
	}
}

func TestParseMatchLuaStillReadsInitialised(t *testing.T) {
	var m windowrules.MatchCriteria
	parseMatchLua(`{ initialised = true }`, &m)
	if m.Initialised == nil || !*m.Initialised {
		t.Fatalf("initialised not parsed: %v", m.Initialised)
	}
}

func TestApplyLuaActionKeyBorderAndRounding(t *testing.T) {
	tests := []struct {
		name         string
		key, raw     string
		wantHandled  bool
		wantNoBorder bool
		wantNoRound  bool
		wantRadius   int
	}{
		{"noborder", "noborder", "true", true, true, false, 0},
		{"border_size 0", "border_size", "0", true, true, false, 0},
		{"border_size 2 unmanaged", "border_size", "2", false, false, false, 0},
		{"norounding", "norounding", "true", true, false, true, 0},
		{"rounding 0", "rounding", "0", true, false, true, 0},
		{"rounding 6", "rounding", "6", true, false, false, 6},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var a windowrules.Actions
			if got := applyLuaActionKey(&a, tt.key, tt.raw); got != tt.wantHandled {
				t.Fatalf("handled = %v, want %v", got, tt.wantHandled)
			}
			if gotB := a.NoBorder != nil && *a.NoBorder; gotB != tt.wantNoBorder {
				t.Errorf("NoBorder = %v, want %v", gotB, tt.wantNoBorder)
			}
			if gotR := a.NoRounding != nil && *a.NoRounding; gotR != tt.wantNoRound {
				t.Errorf("NoRounding = %v, want %v", gotR, tt.wantNoRound)
			}
			if tt.wantRadius == 0 {
				if a.CornerRadius != nil {
					t.Errorf("CornerRadius = %d, want nil", *a.CornerRadius)
				}
			} else if a.CornerRadius == nil || *a.CornerRadius != tt.wantRadius {
				t.Errorf("CornerRadius = %v, want %d", a.CornerRadius, tt.wantRadius)
			}
		})
	}
}

func TestHyprlandLuaRoundTripMatchAndActions(t *testing.T) {
	provider := NewHyprlandWritableProvider(t.TempDir())
	rule := newTestWindowRule("rt", "Round Trip", "^throwaway$")
	rule.MatchCriteria.IsFloating = new(true)
	rule.MatchCriteria.Pinned = new(false)
	rule.Actions.NoBorder = new(true)
	rule.Actions.NoRounding = new(true)
	rule.Actions.CornerRadius = new(8)

	if err := provider.SetRule(rule); err != nil {
		t.Fatalf("SetRule: %v", err)
	}
	rules, err := provider.LoadDMSRules()
	if err != nil {
		t.Fatalf("LoadDMSRules: %v", err)
	}
	if len(rules) != 1 {
		t.Fatalf("expected 1 rule, got %d", len(rules))
	}
	got := rules[0]
	if got.MatchCriteria.IsFloating == nil || !*got.MatchCriteria.IsFloating {
		t.Errorf("IsFloating lost: %v", got.MatchCriteria.IsFloating)
	}
	if got.MatchCriteria.Pinned == nil || *got.MatchCriteria.Pinned {
		t.Errorf("Pinned lost: %v", got.MatchCriteria.Pinned)
	}
	if got.Actions.NoBorder == nil || !*got.Actions.NoBorder {
		t.Errorf("NoBorder lost")
	}
	if got.Actions.NoRounding == nil || !*got.Actions.NoRounding {
		t.Errorf("NoRounding lost")
	}
	if got.Actions.CornerRadius != nil {
		t.Errorf("CornerRadius = %d, want nil (suppressed by NoRounding)", *got.Actions.CornerRadius)
	}
}

func ruleOrder(t *testing.T, content string, ids ...string) {
	t.Helper()
	last := -1
	for _, id := range ids {
		i := strings.Index(content, id)
		if i < 0 || i < last {
			t.Fatalf("rule %q missing or out of order (want %v) in:\n%s", id, ids, content)
		}
		last = i
	}
}

func TestHyprlandEndToEndWriterOrderAndKeys(t *testing.T) {
	provider := NewHyprlandWritableProvider(t.TempDir())

	user1 := newTestWindowRule("user1", "User 1", "^throwaway$")
	user1.MatchCriteria.IsFloating = new(true)
	user1.Actions.NoBorder = new(true)
	user1.Actions.NoRounding = new(true)
	opaque := newTestWindowRule(windowrules.OpaqueRuleID, "Opaque", ".*")
	opaque.Actions.Opaque = new(true)
	user2 := newTestWindowRule("user2", "User 2", "^tiled$")
	user2.Actions.Tile = new(true)

	for _, r := range []windowrules.WindowRule{user1, opaque, user2} {
		if err := provider.SetRule(r); err != nil {
			t.Fatalf("SetRule %s: %v", r.ID, err)
		}
	}

	read := func() string {
		b, err := os.ReadFile(provider.GetOverridePath())
		if err != nil {
			t.Fatal(err)
		}
		return string(b)
	}
	content := read()
	for _, want := range []string{"float = true", "border_size = 0", "rounding = 0"} {
		if !strings.Contains(content, want) {
			t.Errorf("missing %q in:\n%s", want, content)
		}
	}
	for _, bad := range []string{"floating =", "noborder", "norounding"} {
		if strings.Contains(content, bad) {
			t.Errorf("unexpected %q in:\n%s", bad, content)
		}
	}
	ruleOrder(t, content, "user1", "user2", windowrules.OpaqueRuleID)

	if err := provider.ReorderRules([]string{"user2", "user1"}); err != nil {
		t.Fatalf("ReorderRules: %v", err)
	}
	ruleOrder(t, read(), "user2", "user1", windowrules.OpaqueRuleID)

	rules, err := provider.LoadDMSRules()
	if err != nil {
		t.Fatalf("LoadDMSRules: %v", err)
	}
	got := map[string]windowrules.WindowRule{}
	for _, r := range rules {
		got[r.ID] = r
	}
	if len(got) != 3 {
		t.Fatalf("expected 3 rules, got %d", len(got))
	}
	if a := got[windowrules.OpaqueRuleID].Actions.Opaque; a == nil || !*a {
		t.Error("opaque lost")
	}
	if a := got["user2"].Actions.Tile; a == nil || !*a {
		t.Error("tile lost")
	}
	if a := got["user1"].Actions.NoBorder; a == nil || !*a {
		t.Error("NoBorder lost")
	}
}

func TestNiriEndToEndOpaqueLast(t *testing.T) {
	provider := NewNiriWritableProvider(t.TempDir())
	opaque := newTestWindowRule(windowrules.OpaqueRuleID, "Opaque", ".*")
	opaque.Actions.Opacity = new(1.0)
	user := newTestWindowRule("user1", "User 1", "^a$")
	user.Actions.OpenFloating = new(true)

	for _, r := range []windowrules.WindowRule{opaque, user} {
		if err := provider.SetRule(r); err != nil {
			t.Fatalf("SetRule %s: %v", r.ID, err)
		}
	}
	b, err := os.ReadFile(provider.GetOverridePath())
	if err != nil {
		t.Fatal(err)
	}
	content := string(b)
	if !strings.Contains(content, "opacity 1.00") {
		t.Errorf("missing opacity 1.00 in:\n%s", content)
	}
	if strings.Index(content, "^a$") > strings.Index(content, "opacity 1.00") {
		t.Errorf("opaque rule not last in:\n%s", content)
	}
}

func TestHyprlandLuaRoundTripCatalogKeys(t *testing.T) {
	tests := []struct {
		name  string
		lua   string
		match windowrules.MatchCriteria
		act   windowrules.Actions
	}{
		{"initial_class", `initial_class = "^steam$"`, windowrules.MatchCriteria{InitialClass: "^steam$"}, windowrules.Actions{}},
		{"initial_title", `initial_title = "^Login$"`, windowrules.MatchCriteria{InitialTitle: "^Login$"}, windowrules.Actions{}},
		{"tag", `tag = "negative:games"`, windowrules.MatchCriteria{Tag: "negative:games"}, windowrules.Actions{}},
		{"workspace", `workspace = "w[tv1]"`, windowrules.MatchCriteria{Workspace: "w[tv1]"}, windowrules.Actions{}},
		{"content", `content = "video"`, windowrules.MatchCriteria{Content: "video"}, windowrules.Actions{}},
		{"xdg_tag", `xdg_tag = "^portal$"`, windowrules.MatchCriteria{XdgTag: "^portal$"}, windowrules.Actions{}},
		{"focus", `focus = false`, windowrules.MatchCriteria{IsFocused: new(false)}, windowrules.Actions{}},
		{"group", `group = true`, windowrules.MatchCriteria{Grouped: new(true)}, windowrules.Actions{}},
		{"modal", `modal = true`, windowrules.MatchCriteria{Modal: new(true)}, windowrules.Actions{}},
		{"fullscreen_state_internal", `fullscreen_state_internal = 2`, windowrules.MatchCriteria{FullscreenStateInternal: new(2)}, windowrules.Actions{}},
		{"fullscreen_state_client", `fullscreen_state_client = 0`, windowrules.MatchCriteria{FullscreenStateClient: new(0)}, windowrules.Actions{}},
		{"no_initial_focus", `no_initial_focus = true`, windowrules.MatchCriteria{}, windowrules.Actions{NoInitialFocus: new(true)}},
		{"focus_on_activate", `focus_on_activate = false`, windowrules.MatchCriteria{}, windowrules.Actions{FocusOnActivate: new(false)}},
		{"stay_focused", `stay_focused = true`, windowrules.MatchCriteria{}, windowrules.Actions{StayFocused: new(true)}},
		{"confine_pointer", `confine_pointer = true`, windowrules.MatchCriteria{}, windowrules.Actions{ConfinePointer: new(true)}},
		{"no_xdg_drags", `no_xdg_drags = true`, windowrules.MatchCriteria{}, windowrules.Actions{NoXdgDrags: new(true)}},
		{"no_auto_hdr", `no_auto_hdr = true`, windowrules.MatchCriteria{}, windowrules.Actions{NoAutoHDR: new(true)}},
		{"no_glow", `no_glow = true`, windowrules.MatchCriteria{}, windowrules.Actions{NoGlow: new(true)}},
		{"no_wobble", `no_wobble = true`, windowrules.MatchCriteria{}, windowrules.Actions{NoWobble: new(true)}},
		{"scrolling_width", `scrolling_width = 0.5`, windowrules.MatchCriteria{}, windowrules.Actions{ScrollingWidth: new(0.5)}},
		{"tonemap", `tonemap = "clamp"`, windowrules.MatchCriteria{}, windowrules.Actions{Tonemap: "clamp"}},
		{"suppress_event", `suppress_event = "maximize fullscreen"`, windowrules.MatchCriteria{}, windowrules.Actions{SuppressEvent: "maximize fullscreen"}},
		{"monitor silent", `monitor = "DP-1 silent"`, windowrules.MatchCriteria{}, windowrules.Actions{Monitor: "DP-1 silent"}},
		{"border_color per focus", `border_color = "rgb(ff0000)"`, windowrules.MatchCriteria{IsFocused: new(true)}, windowrules.Actions{BorderColor: "rgb(ff0000)"}},
		{"rounding at cap", `rounding = 20`, windowrules.MatchCriteria{}, windowrules.Actions{CornerRadius: new(20)}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			provider := NewHyprlandWritableProvider(t.TempDir())
			rule := newTestWindowRule("rt", "Round Trip", "^app$")
			tt.match.AppID = "^app$"
			rule.MatchCriteria = tt.match
			rule.Actions = tt.act
			if tt.act == (windowrules.Actions{}) {
				rule.Actions.OpenFloating = new(true)
			}
			if err := provider.SetRule(rule); err != nil {
				t.Fatalf("SetRule: %v", err)
			}
			written, err := os.ReadFile(provider.GetOverridePath())
			if err != nil {
				t.Fatal(err)
			}
			if !strings.Contains(string(written), tt.lua) {
				t.Fatalf("missing %q in:\n%s", tt.lua, written)
			}
			rules, err := provider.LoadDMSRules()
			if err != nil || len(rules) != 1 {
				t.Fatalf("LoadDMSRules: %v, %d rules", err, len(rules))
			}
			if !reflect.DeepEqual(rules[0].MatchCriteria, rule.MatchCriteria) {
				t.Errorf("match = %+v, want %+v", rules[0].MatchCriteria, rule.MatchCriteria)
			}
			if !reflect.DeepEqual(rules[0].Actions, rule.Actions) {
				t.Errorf("actions = %+v, want %+v", rules[0].Actions, rule.Actions)
			}
		})
	}
}

func TestHyprlandNoInitialFocusStaysDistinct(t *testing.T) {
	tmpDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(tmpDir, "hyprland.lua"), []byte(`
hl.window_rule({
	match = { class = "^steam$" },
	no_initial_focus = true,
})
`), 0644); err != nil {
		t.Fatal(err)
	}
	res, err := ParseHyprlandWindowRules(tmpDir)
	if err != nil || len(res.Rules) != 1 {
		t.Fatalf("ParseHyprlandWindowRules: %v, %d rules", err, len(res.Rules))
	}
	wr := ConvertHyprlandRulesToWindowRules(res.Rules)[0]
	if wr.Actions.NoFocus != nil {
		t.Errorf("no_initial_focus leaked into NoFocus")
	}
	joined := strings.Join(formatLuaManagedHyprRule(wr), "\n")
	if !strings.Contains(joined, "no_initial_focus = true") || strings.Contains(joined, "no_focus") {
		t.Errorf("no_initial_focus not re-emitted unchanged:\n%s", joined)
	}
}
