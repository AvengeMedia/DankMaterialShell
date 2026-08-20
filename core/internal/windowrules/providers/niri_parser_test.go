package providers

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNiriParseBasicWindowRule(t *testing.T) {
	tmpDir := t.TempDir()

	config := `
window-rule {
    match app-id="^firefox$"
    opacity 0.9
    open-floating true
}
`
	if err := os.WriteFile(filepath.Join(tmpDir, "config.kdl"), []byte(config), 0644); err != nil {
		t.Fatal(err)
	}

	parser := NewNiriRulesParser(tmpDir)
	rules, err := parser.Parse()
	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	if len(rules) != 1 {
		t.Fatalf("expected 1 rule, got %d", len(rules))
	}

	rule := rules[0]
	if rule.MatchAppID != "^firefox$" {
		t.Errorf("MatchAppID = %q, want ^firefox$", rule.MatchAppID)
	}
	if rule.Opacity == nil || *rule.Opacity != 0.9 {
		t.Errorf("Opacity = %v, want 0.9", rule.Opacity)
	}
	if rule.OpenFloating == nil || !*rule.OpenFloating {
		t.Error("OpenFloating should be true")
	}
}

func TestNiriParseMultipleRules(t *testing.T) {
	tmpDir := t.TempDir()

	config := `
window-rule {
    match app-id="app1"
    open-maximized true
}

window-rule {
    match app-id="app2"
    open-fullscreen true
}
`
	if err := os.WriteFile(filepath.Join(tmpDir, "config.kdl"), []byte(config), 0644); err != nil {
		t.Fatal(err)
	}

	parser := NewNiriRulesParser(tmpDir)
	rules, err := parser.Parse()
	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	if len(rules) != 2 {
		t.Fatalf("expected 2 rules, got %d", len(rules))
	}

	if rules[0].MatchAppID != "app1" {
		t.Errorf("rule 0 MatchAppID = %q, want app1", rules[0].MatchAppID)
	}
	if rules[1].MatchAppID != "app2" {
		t.Errorf("rule 1 MatchAppID = %q, want app2", rules[1].MatchAppID)
	}
}

func TestConvertNiriRulesToWindowRules(t *testing.T) {
	niriRules := []NiriWindowRule{
		{MatchAppID: "^firefox$", Opacity: new(0.8)},
		{MatchAppID: "^code$", OpenFloating: new(true)},
	}

	result := ConvertNiriRulesToWindowRules(niriRules)

	if len(result) != 2 {
		t.Errorf("expected 2 rules, got %d", len(result))
	}

	if result[0].MatchCriteria.AppID != "^firefox$" {
		t.Errorf("rule 0 AppID = %q, want ^firefox$", result[0].MatchCriteria.AppID)
	}
	if result[0].Actions.Opacity == nil || *result[0].Actions.Opacity != 0.8 {
		t.Errorf("rule 0 Opacity = %v, want 0.8", result[0].Actions.Opacity)
	}

	if result[1].Actions.OpenFloating == nil || !*result[1].Actions.OpenFloating {
		t.Error("rule 1 should have OpenFloating = true")
	}
}

func TestNiriWritableProvider(t *testing.T) {
	tmpDir := t.TempDir()
	provider := NewNiriWritableProvider(tmpDir)

	if provider.Name() != "niri" {
		t.Errorf("Name() = %q, want niri", provider.Name())
	}

	expectedPath := filepath.Join(tmpDir, "dms", "windowrules.kdl")
	if provider.GetOverridePath() != expectedPath {
		t.Errorf("GetOverridePath() = %q, want %q", provider.GetOverridePath(), expectedPath)
	}
}

func TestNiriSetAndLoadDMSRules(t *testing.T) {
	tmpDir := t.TempDir()
	provider := NewNiriWritableProvider(tmpDir)

	rule := newTestWindowRule("test_id", "Test Rule", "^firefox$")
	rule.Actions.OpenFloating = new(true)
	rule.Actions.Opacity = new(0.85)

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
	if rules[0].MatchCriteria.AppID != "^firefox$" {
		t.Errorf("AppID = %q, want ^firefox$", rules[0].MatchCriteria.AppID)
	}
}

func TestNiriRemoveRule(t *testing.T) {
	tmpDir := t.TempDir()
	provider := NewNiriWritableProvider(tmpDir)

	rule1 := newTestWindowRule("rule1", "Rule 1", "app1")
	rule1.Actions.OpenFloating = new(true)
	rule2 := newTestWindowRule("rule2", "Rule 2", "app2")
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

func TestNiriReorderRules(t *testing.T) {
	tmpDir := t.TempDir()
	provider := NewNiriWritableProvider(tmpDir)

	rule1 := newTestWindowRule("rule1", "Rule 1", "app1")
	rule1.Actions.OpenFloating = new(true)
	rule2 := newTestWindowRule("rule2", "Rule 2", "app2")
	rule2.Actions.OpenFloating = new(true)
	rule3 := newTestWindowRule("rule3", "Rule 3", "app3")
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

func TestNiriParseConfigWithInclude(t *testing.T) {
	tmpDir := t.TempDir()

	mainConfig := `
window-rule {
    match app-id="mainapp"
    opacity 1.0
}

include "extra.kdl"
`
	extraConfig := `
window-rule {
    match app-id="extraapp"
    open-maximized true
}
`

	if err := os.WriteFile(filepath.Join(tmpDir, "config.kdl"), []byte(mainConfig), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tmpDir, "extra.kdl"), []byte(extraConfig), 0644); err != nil {
		t.Fatal(err)
	}

	parser := NewNiriRulesParser(tmpDir)
	rules, err := parser.Parse()
	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	if len(rules) != 2 {
		t.Errorf("expected 2 rules, got %d", len(rules))
	}
}

func TestNiriParseSizeNode(t *testing.T) {
	tmpDir := t.TempDir()

	config := `
window-rule {
    match app-id="testapp"
    default-column-width { fixed 800; }
    default-window-height { proportion 0.5; }
}
`
	if err := os.WriteFile(filepath.Join(tmpDir, "config.kdl"), []byte(config), 0644); err != nil {
		t.Fatal(err)
	}

	parser := NewNiriRulesParser(tmpDir)
	rules, err := parser.Parse()
	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	if len(rules) != 1 {
		t.Fatalf("expected 1 rule, got %d", len(rules))
	}

	if rules[0].DefaultColumnWidth != "fixed 800" {
		t.Errorf("DefaultColumnWidth = %q, want 'fixed 800'", rules[0].DefaultColumnWidth)
	}
	if rules[0].DefaultWindowHeight != "proportion 0.5" {
		t.Errorf("DefaultWindowHeight = %q, want 'proportion 0.5'", rules[0].DefaultWindowHeight)
	}
}

func TestFormatSizeProperty(t *testing.T) {
	tests := []struct {
		name     string
		propName string
		value    string
		want     string
	}{
		{
			name:     "fixed size",
			propName: "default-column-width",
			value:    "fixed 800",
			want:     "    default-column-width { fixed 800; }",
		},
		{
			name:     "proportion",
			propName: "default-window-height",
			value:    "proportion 0.5",
			want:     "    default-window-height { proportion 0.5; }",
		},
		{
			name:     "invalid format",
			propName: "default-column-width",
			value:    "invalid",
			want:     "    default-column-width { }",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := formatSizeProperty(tt.propName, tt.value)
			if result != tt.want {
				t.Errorf("formatSizeProperty(%q, %q) = %q, want %q",
					tt.propName, tt.value, result, tt.want)
			}
		})
	}
}

func TestNiriDMSRulesStatus(t *testing.T) {
	tmpDir := t.TempDir()

	config := `
window-rule {
    match app-id="testapp"
    opacity 0.9
}
`
	if err := os.WriteFile(filepath.Join(tmpDir, "config.kdl"), []byte(config), 0644); err != nil {
		t.Fatal(err)
	}

	result, err := ParseNiriWindowRules(tmpDir)
	if err != nil {
		t.Fatalf("ParseNiriWindowRules failed: %v", err)
	}

	if result.DMSStatus == nil {
		t.Fatal("DMSStatus should not be nil")
	}

	if result.DMSStatus.Exists {
		t.Error("DMSStatus.Exists should be false when dms rules file doesn't exist")
	}
}

func TestNiriExcludesSurviveEditOfOtherRule(t *testing.T) {
	tmpDir := t.TempDir()
	provider := NewNiriWritableProvider(tmpDir)

	dmsDir := filepath.Join(tmpDir, "dms")
	if err := os.MkdirAll(dmsDir, 0755); err != nil {
		t.Fatal(err)
	}
	existing := `// @id=thunderbird @name=Thunderbird
window-rule {
    match app-id="^org.mozilla.Thunderbird$"
    open-floating true
    exclude title="^Mozilla Thunderbird$"
    exclude title="^Verfassen:.*"
}

// @id=firefox @name=Firefox
window-rule {
    match app-id="^firefox$"
    open-floating true
}
`
	if err := os.WriteFile(filepath.Join(dmsDir, "windowrules.kdl"), []byte(existing), 0644); err != nil {
		t.Fatal(err)
	}

	edited := newTestWindowRule("firefox", "Firefox", "^firefox$")
	edited.Actions.OpenFloating = new(false)
	if err := provider.SetRule(edited); err != nil {
		t.Fatalf("SetRule failed: %v", err)
	}

	rules, err := provider.LoadDMSRules()
	if err != nil {
		t.Fatalf("LoadDMSRules failed: %v", err)
	}
	if len(rules) != 2 {
		t.Fatalf("expected 2 rules, got %d", len(rules))
	}
	if len(rules[0].Excludes) != 2 {
		t.Fatalf("expected 2 excludes on untouched rule, got %d", len(rules[0].Excludes))
	}
	if rules[0].Excludes[0].Title != "^Mozilla Thunderbird$" {
		t.Errorf("Excludes[0].Title = %q", rules[0].Excludes[0].Title)
	}
	if rules[0].Excludes[1].Title != "^Verfassen:.*" {
		t.Errorf("Excludes[1].Title = %q", rules[0].Excludes[1].Title)
	}
	if rules[1].Actions.OpenFloating == nil || *rules[1].Actions.OpenFloating {
		t.Error("edited rule should have open-floating false")
	}
}
