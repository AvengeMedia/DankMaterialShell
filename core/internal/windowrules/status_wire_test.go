package windowrules

import (
	"encoding/json"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/configfrag"
)

func marshalKeys(t *testing.T, v any) map[string]json.RawMessage {
	t.Helper()
	data, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var out map[string]json.RawMessage
	if err := json.Unmarshal(data, &out); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	return out
}

func TestDMSRulesStatusKeySpellings(t *testing.T) {
	keys := marshalKeys(t, DMSRulesStatus{
		Exists:          true,
		Included:        true,
		IncludePosition: 2,
		TotalIncludes:   3,
		RulesAfterDMS:   4,
		Effective:       true,
		OverriddenBy:    4,
		StatusMessage:   "DMS window rules are active",
		ConfigFormat:    "lua",
		ReadOnly:        true,
	})

	want := []string{"exists", "included", "includePosition", "totalIncludes", "rulesAfterDms", "effective", "overriddenBy", "statusMessage", "configFormat", "readOnly"}
	if len(keys) != len(want) {
		t.Fatalf("key count = %d, want %d: %v", len(keys), len(want), keys)
	}
	for _, key := range want {
		if _, ok := keys[key]; !ok {
			t.Errorf("missing key %q", key)
		}
	}
}

func TestDMSRulesStatusOmitsFormatAndReadOnlyWhenUnset(t *testing.T) {
	keys := marshalKeys(t, DMSRulesStatus{})

	if _, ok := keys["configFormat"]; ok {
		t.Error("configFormat must be omitted when empty")
	}
	if _, ok := keys["readOnly"]; ok {
		t.Error("readOnly must be omitted when false")
	}
	for _, key := range []string{"exists", "included", "includePosition", "totalIncludes", "rulesAfterDms", "effective", "overriddenBy", "statusMessage"} {
		if _, ok := keys[key]; !ok {
			t.Errorf("zero value must still carry %q", key)
		}
	}
}

func TestDMSRulesStatusValuesSurviveTheWire(t *testing.T) {
	data, err := json.Marshal(DMSRulesStatus{IncludePosition: 2, TotalIncludes: 3, RulesAfterDMS: 4, OverriddenBy: 4, StatusMessage: "x"})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var back DMSRulesStatus
	if err := json.Unmarshal(data, &back); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if back.RulesAfterDMS != 4 {
		t.Errorf("rulesAfterDms = %d, want 4", back.RulesAfterDMS)
	}
	if back.IncludePosition != 2 || back.TotalIncludes != 3 {
		t.Errorf("include position/total = %d/%d, want 2/3", back.IncludePosition, back.TotalIncludes)
	}
}

func TestDMSRulesStatusFromCarriesEveryField(t *testing.T) {
	got := DMSRulesStatusFrom(configfrag.Status{
		Exists:          true,
		Included:        true,
		IncludePosition: 2,
		TotalIncludes:   3,
		EntriesAfterDMS: 7,
		Effective:       true,
		OverriddenBy:    7,
		StatusMessage:   "DMS window rules are active",
		ConfigFormat:    "lua",
		ReadOnly:        true,
	})

	want := DMSRulesStatus{
		Exists:          true,
		Included:        true,
		IncludePosition: 2,
		TotalIncludes:   3,
		RulesAfterDMS:   7,
		Effective:       true,
		OverriddenBy:    7,
		StatusMessage:   "DMS window rules are active",
		ConfigFormat:    "lua",
		ReadOnly:        true,
	}
	if *got != want {
		t.Errorf("DMSRulesStatusFrom = %+v, want %+v", *got, want)
	}
}

func TestDMSRulesStatusFromKeepsAnUnseenIncludePosition(t *testing.T) {
	got := DMSRulesStatusFrom(configfrag.BuildStatus(configfrag.NewScan(), false, 0, "", false, configfrag.Messages{Missing: "gone"}))
	if got.IncludePosition != -1 {
		t.Errorf("includePosition = %d, want -1", got.IncludePosition)
	}
}
