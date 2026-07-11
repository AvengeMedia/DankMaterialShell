package providers

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/windowrules"
)

func TestParseMangoWindowRuleLine(t *testing.T) {
	fields := parseMangoWindowRuleLine("appid:firefox,title:Gmail,isfloating:1,tags:2,monitor:HDMI-A-1")
	if fields["appid"] != "firefox" {
		t.Errorf("appid = %q, want firefox", fields["appid"])
	}
	if fields["title"] != "Gmail" {
		t.Errorf("title = %q, want Gmail", fields["title"])
	}
	if fields["isfloating"] != "1" {
		t.Errorf("isfloating = %q, want 1", fields["isfloating"])
	}
	if fields["tags"] != "2" {
		t.Errorf("tags = %q, want 2", fields["tags"])
	}
	if fields["monitor"] != "HDMI-A-1" {
		t.Errorf("monitor = %q, want HDMI-A-1", fields["monitor"])
	}
}

func TestConvertMangoRulesToWindowRules(t *testing.T) {
	mangoRules := []MangoWindowRule{
		{Source: "config.conf", Fields: parseMangoWindowRuleLine("appid:discord,tags:9,isfloating:1,noblur:1")},
	}
	rules := ConvertMangoRulesToWindowRules(mangoRules)
	if len(rules) != 1 {
		t.Fatalf("got %d rules, want 1", len(rules))
	}
	r := rules[0]
	if r.MatchCriteria.AppID != "discord" {
		t.Errorf("AppID = %q, want discord", r.MatchCriteria.AppID)
	}
	if r.Actions.Workspace != "9" {
		t.Errorf("Workspace = %q, want 9", r.Actions.Workspace)
	}
	if r.Actions.OpenFloating == nil || !*r.Actions.OpenFloating {
		t.Errorf("OpenFloating = %v, want true", r.Actions.OpenFloating)
	}
	if r.Actions.NoBlur == nil || !*r.Actions.NoBlur {
		t.Errorf("NoBlur = %v, want true", r.Actions.NoBlur)
	}
}

func TestMangoSetAndLoadRoundTrip(t *testing.T) {
	tmpDir := t.TempDir()
	provider := NewMangoWritableProvider(tmpDir)

	floating := true
	rule := windowrules.WindowRule{
		ID:      "rule_test",
		Name:    "Float Discord",
		Enabled: true,
		MatchCriteria: windowrules.MatchCriteria{
			AppID: "discord",
		},
		Actions: windowrules.Actions{
			OpenFloating: &floating,
			Workspace:    "9",
			SizeWidth:    "1000",
			SizeHeight:   "900",
		},
	}

	if err := provider.SetRule(rule); err != nil {
		t.Fatalf("SetRule: %v", err)
	}

	expectedPath := filepath.Join(tmpDir, "dms", "windowrules.conf")
	if _, err := os.Stat(expectedPath); err != nil {
		t.Fatalf("override file not written: %v", err)
	}

	loaded, err := provider.LoadDMSRules()
	if err != nil {
		t.Fatalf("LoadDMSRules: %v", err)
	}
	if len(loaded) != 1 {
		t.Fatalf("got %d rules, want 1", len(loaded))
	}
	got := loaded[0]
	if got.ID != "rule_test" {
		t.Errorf("ID = %q, want rule_test", got.ID)
	}
	if got.Name != "Float Discord" {
		t.Errorf("Name = %q, want 'Float Discord'", got.Name)
	}
	if got.MatchCriteria.AppID != "discord" {
		t.Errorf("AppID = %q, want discord", got.MatchCriteria.AppID)
	}
	if got.Actions.Workspace != "9" {
		t.Errorf("Workspace = %q, want 9", got.Actions.Workspace)
	}
	if got.Actions.SizeWidth != "1000" {
		t.Errorf("SizeWidth = %q, want 1000", got.Actions.SizeWidth)
	}
	if got.Actions.SizeHeight != "900" {
		t.Errorf("SizeHeight = %q, want 900", got.Actions.SizeHeight)
	}
	if got.Actions.OpenFloating == nil || !*got.Actions.OpenFloating {
		t.Errorf("OpenFloating = %v, want true", got.Actions.OpenFloating)
	}

	// Remove and confirm empty.
	if err := provider.RemoveRule("rule_test"); err != nil {
		t.Fatalf("RemoveRule: %v", err)
	}
	loaded, _ = provider.LoadDMSRules()
	if len(loaded) != 0 {
		t.Errorf("after remove got %d rules, want 0", len(loaded))
	}
}

func TestMangoRoundTripWithSizeWidthHeight(t *testing.T) {
	tmpDir := t.TempDir()
	provider := NewMangoWritableProvider(tmpDir)

	rule := windowrules.WindowRule{
		ID:      "rule_roundtrip",
		Name:    "Size Test",
		Enabled: true,
		MatchCriteria: windowrules.MatchCriteria{
			AppID: "testapp",
		},
		Actions: windowrules.Actions{
			SizeWidth:  "800",
			SizeHeight: "600",
		},
	}

	if err := provider.SetRule(rule); err != nil {
		t.Fatalf("SetRule: %v", err)
	}

	loaded, err := provider.LoadDMSRules()
	if err != nil {
		t.Fatalf("LoadDMSRules: %v", err)
	}
	if len(loaded) != 1 {
		t.Fatalf("got %d rules, want 1", len(loaded))
	}
	got := loaded[0]
	if got.Actions.SizeWidth != "800" {
		t.Errorf("SizeWidth = %q, want 800", got.Actions.SizeWidth)
	}
	if got.Actions.SizeHeight != "600" {
		t.Errorf("SizeHeight = %q, want 600", got.Actions.SizeHeight)
	}
}
