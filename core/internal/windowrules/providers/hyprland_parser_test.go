package providers

import (
	"os"
	"path/filepath"
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
		wantRule  string
		wantNil   bool
	}{
		{
			name:      "basic float rule",
			line:      "windowrule = float, ^(firefox)$",
			wantClass: "^(firefox)$",
			wantRule:  "float",
		},
		{
			name:      "tile rule",
			line:      "windowrule = tile, steam",
			wantClass: "steam",
			wantRule:  "tile",
		},
		{
			name:      "no match returns empty class",
			line:      "windowrule = float",
			wantClass: "",
			wantRule:  "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parser.parseWindowRuleLine(tt.line)
			if tt.wantNil {
				if result != nil {
					t.Errorf("expected nil, got %+v", result)
				}
				return
			}
			if result == nil {
				t.Fatal("expected non-nil result")
			}
			if result.MatchClass != tt.wantClass {
				t.Errorf("MatchClass = %q, want %q", result.MatchClass, tt.wantClass)
			}
			if result.Rule != tt.wantRule {
				t.Errorf("Rule = %q, want %q", result.Rule, tt.wantRule)
			}
		})
	}
}

func TestParseWindowRuleV2(t *testing.T) {
	parser := NewHyprlandRulesParser("")

	tests := []struct {
		name      string
		line      string
		wantClass string
		wantTitle string
		wantRule  string
		wantValue string
	}{
		{
			name:      "float with class",
			line:      "windowrulev2 = float, class:^(firefox)$",
			wantClass: "^(firefox)$",
			wantRule:  "float",
		},
		{
			name:      "opacity with value",
			line:      "windowrulev2 = opacity 0.8, class:^(code)$",
			wantClass: "^(code)$",
			wantRule:  "opacity",
			wantValue: "0.8",
		},
		{
			name:      "size with value and title",
			line:      "windowrulev2 = size 800 600, class:^(steam)$, title:Settings",
			wantClass: "^(steam)$",
			wantTitle: "Settings",
			wantRule:  "size",
			wantValue: "800 600",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parser.parseWindowRuleLine(tt.line)
			if result == nil {
				t.Fatal("expected non-nil result")
			}
			if result.MatchClass != tt.wantClass {
				t.Errorf("MatchClass = %q, want %q", result.MatchClass, tt.wantClass)
			}
			if result.MatchTitle != tt.wantTitle {
				t.Errorf("MatchTitle = %q, want %q", result.MatchTitle, tt.wantTitle)
			}
			if result.Rule != tt.wantRule {
				t.Errorf("Rule = %q, want %q", result.Rule, tt.wantRule)
			}
			if result.Value != tt.wantValue {
				t.Errorf("Value = %q, want %q", result.Value, tt.wantValue)
			}
		})
	}
}

func TestConvertHyprlandRulesToWindowRules(t *testing.T) {
	hyprRules := []HyprlandWindowRule{
		{MatchClass: "^(firefox)$", Rule: "float"},
		{MatchClass: "^(code)$", Rule: "opacity", Value: "0.9"},
		{MatchClass: "^(steam)$", Rule: "maximize"},
	}

	result := ConvertHyprlandRulesToWindowRules(hyprRules)

	if len(result) != 3 {
		t.Errorf("expected 3 rules, got %d", len(result))
	}

	if result[0].MatchCriteria.AppID != "^(firefox)$" {
		t.Errorf("rule 0 AppID = %q, want ^(firefox)$", result[0].MatchCriteria.AppID)
	}
	if result[0].Actions.OpenFloating == nil || !*result[0].Actions.OpenFloating {
		t.Error("rule 0 should have OpenFloating = true")
	}

	if result[1].Actions.Opacity == nil || *result[1].Actions.Opacity != 0.9 {
		t.Errorf("rule 1 Opacity = %v, want 0.9", result[1].Actions.Opacity)
	}

	if result[2].Actions.OpenMaximized == nil || !*result[2].Actions.OpenMaximized {
		t.Error("rule 2 should have OpenMaximized = true")
	}
}

func TestHyprlandWritableProvider(t *testing.T) {
	tmpDir := t.TempDir()
	provider := NewHyprlandWritableProvider(tmpDir)

	if provider.Name() != "hyprland" {
		t.Errorf("Name() = %q, want hyprland", provider.Name())
	}

	expectedPath := filepath.Join(tmpDir, "dms", "windowrules.lua")
	if provider.GetOverridePath() != expectedPath {
		t.Errorf("GetOverridePath() = %q, want %q", provider.GetOverridePath(), expectedPath)
	}
}

func TestHyprlandSetAndLoadDMSRules(t *testing.T) {
	tmpDir := t.TempDir()
	provider := NewHyprlandWritableProvider(tmpDir)

	rule := newTestWindowRule("test_id", "Test Rule", "^(firefox)$")
	rule.Actions.OpenFloating = boolPtr(true)

	if err := provider.SetRule(rule); err != nil {
		t.Fatalf("SetRule failed: %v", err)
	}

	rules, err := provider.LoadDMSRules()
	if err != nil {
		t.Fatalf("LoadDMSRules failed: %v", err)
	}

	if len(rules) != 1 {
		t.Fatalf("expected 1 rule, got %d", len(rules))
	}

	if rules[0].ID != "test_id" {
		t.Errorf("ID = %q, want test_id", rules[0].ID)
	}
	if rules[0].MatchCriteria.AppID != "^(firefox)$" {
		t.Errorf("AppID = %q, want ^(firefox)$", rules[0].MatchCriteria.AppID)
	}
}

func TestHyprlandSetRuleLeavesConfOnlyInstallReadOnly(t *testing.T) {
	tmpDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(tmpDir, "hyprland.conf"), []byte("windowrulev2 = float, class:^(kitty)$\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	provider := NewHyprlandWritableProvider(tmpDir)
	rule := newTestWindowRule("test_id", "Test Rule", "^(firefox)$")
	rule.Actions.OpenFloating = boolPtr(true)

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
	rule1.Actions.OpenFloating = boolPtr(true)
	rule2 := newTestWindowRule("rule2", "Rule 2", "^(app2)$")
	rule2.Actions.OpenFloating = boolPtr(true)

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
	rule1.Actions.OpenFloating = boolPtr(true)
	rule2 := newTestWindowRule("rule2", "Rule 2", "^(app2)$")
	rule2.Actions.OpenFloating = boolPtr(true)
	rule3 := newTestWindowRule("rule3", "Rule 3", "^(app3)$")
	rule3.Actions.OpenFloating = boolPtr(true)

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

func TestParseHyprlandLuaNoInitialFocusAlias(t *testing.T) {
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
	if err != nil {
		t.Fatalf("ParseHyprlandWindowRules: %v", err)
	}
	if len(res.Rules) != 1 {
		t.Fatalf("expected 1 rule, got %d", len(res.Rules))
	}
	wr := ConvertHyprlandRulesToWindowRules(res.Rules)[0]
	if wr.Actions.NoFocus == nil || !*wr.Actions.NoFocus {
		t.Fatalf("expected no_initial_focus to populate NoFocus action: %#v", wr.Actions)
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

func TestBoolToInt(t *testing.T) {
	if boolToInt(true) != 1 {
		t.Error("boolToInt(true) should be 1")
	}
	if boolToInt(false) != 0 {
		t.Error("boolToInt(false) should be 0")
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
			name: "move string syntax returns false",
			key:  "move",
			raw:  `"100 200"`,
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

func TestLuaRoundTripTableSyntax(t *testing.T) {
	original := windowrules.Actions{
		SizeWidth:  "800",
		SizeHeight: "600",
		MoveX:      "100",
		MoveY:      "200",
	}

	var out []string
	luaAppendActions(original, &out)

	var parsed windowrules.Actions
	for _, line := range out {
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])
		applyLuaActionKey(&parsed, key, val)
	}

	if parsed.SizeWidth != original.SizeWidth {
		t.Errorf("SizeWidth = %q, want %q", parsed.SizeWidth, original.SizeWidth)
	}
	if parsed.SizeHeight != original.SizeHeight {
		t.Errorf("SizeHeight = %q, want %q", parsed.SizeHeight, original.SizeHeight)
	}
	if parsed.MoveX != original.MoveX {
		t.Errorf("MoveX = %q, want %q", parsed.MoveX, original.MoveX)
	}
	if parsed.MoveY != original.MoveY {
		t.Errorf("MoveY = %q, want %q", parsed.MoveY, original.MoveY)
	}
}

func TestLuaRoundTripTableSyntaxExpressions(t *testing.T) {
	original := windowrules.Actions{
		SizeWidth:  "window_w * 0.5",
		SizeHeight: "window_h - 50",
		MoveX:      "100",
		MoveY:      "(monitor_h / 2) + 17",
	}

	var out []string
	luaAppendActions(original, &out)

	var parsed windowrules.Actions
	for _, line := range out {
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])
		applyLuaActionKey(&parsed, key, val)
	}

	if parsed.SizeWidth != original.SizeWidth {
		t.Errorf("SizeWidth = %q, want %q", parsed.SizeWidth, original.SizeWidth)
	}
	if parsed.SizeHeight != original.SizeHeight {
		t.Errorf("SizeHeight = %q, want %q", parsed.SizeHeight, original.SizeHeight)
	}
	if parsed.MoveX != original.MoveX {
		t.Errorf("MoveX = %q, want %q", parsed.MoveX, original.MoveX)
	}
	if parsed.MoveY != original.MoveY {
		t.Errorf("MoveY = %q, want %q", parsed.MoveY, original.MoveY)
	}
}
