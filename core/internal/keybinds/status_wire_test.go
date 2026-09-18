package keybinds

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

func TestDMSBindsStatusKeySpellings(t *testing.T) {
	keys := marshalKeys(t, DMSBindsStatus{
		Exists:          true,
		Included:        true,
		IncludePosition: 2,
		TotalIncludes:   3,
		BindsAfterDMS:   4,
		Effective:       true,
		OverriddenBy:    4,
		StatusMessage:   "DMS binds are active",
		ConfigFormat:    "lua",
		ReadOnly:        true,
	})

	want := []string{"exists", "included", "includePosition", "totalIncludes", "bindsAfterDms", "effective", "overriddenBy", "statusMessage", "configFormat", "readOnly"}
	if len(keys) != len(want) {
		t.Fatalf("key count = %d, want %d: %v", len(keys), len(want), keys)
	}
	for _, key := range want {
		if _, ok := keys[key]; !ok {
			t.Errorf("missing key %q", key)
		}
	}
}

func TestDMSBindsStatusOmitsFormatAndReadOnlyWhenUnset(t *testing.T) {
	keys := marshalKeys(t, DMSBindsStatus{})

	if _, ok := keys["configFormat"]; ok {
		t.Error("configFormat must be omitted when empty")
	}
	if _, ok := keys["readOnly"]; ok {
		t.Error("readOnly must be omitted when false")
	}
	for _, key := range []string{"exists", "included", "includePosition", "totalIncludes", "bindsAfterDms", "effective", "overriddenBy", "statusMessage"} {
		if _, ok := keys[key]; !ok {
			t.Errorf("zero value must still carry %q", key)
		}
	}
}

func TestDMSBindsStatusValuesSurviveTheWire(t *testing.T) {
	data, err := json.Marshal(DMSBindsStatus{IncludePosition: 2, TotalIncludes: 3, BindsAfterDMS: 4, OverriddenBy: 4, StatusMessage: "x"})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var back DMSBindsStatus
	if err := json.Unmarshal(data, &back); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if back.BindsAfterDMS != 4 {
		t.Errorf("bindsAfterDms = %d, want 4", back.BindsAfterDMS)
	}
	if back.IncludePosition != 2 || back.TotalIncludes != 3 {
		t.Errorf("include position/total = %d/%d, want 2/3", back.IncludePosition, back.TotalIncludes)
	}
}

func TestDMSBindsStatusFromCarriesEveryField(t *testing.T) {
	got := DMSBindsStatusFrom(configfrag.Status{
		Exists:          true,
		Included:        true,
		IncludePosition: 2,
		TotalIncludes:   3,
		EntriesAfterDMS: 7,
		Effective:       true,
		OverriddenBy:    7,
		StatusMessage:   "DMS binds are active",
		ConfigFormat:    "lua",
		ReadOnly:        true,
	})

	want := DMSBindsStatus{
		Exists:          true,
		Included:        true,
		IncludePosition: 2,
		TotalIncludes:   3,
		BindsAfterDMS:   7,
		Effective:       true,
		OverriddenBy:    7,
		StatusMessage:   "DMS binds are active",
		ConfigFormat:    "lua",
		ReadOnly:        true,
	}
	if *got != want {
		t.Errorf("DMSBindsStatusFrom = %+v, want %+v", *got, want)
	}
}

func TestDMSBindsStatusFromKeepsAnUnseenIncludePosition(t *testing.T) {
	got := DMSBindsStatusFrom(configfrag.BuildStatus(configfrag.NewScan(), false, 0, "", false, configfrag.Messages{Missing: "gone"}))
	if got.IncludePosition != -1 {
		t.Errorf("includePosition = %d, want -1", got.IncludePosition)
	}
	if got.StatusMessage != "gone" {
		t.Errorf("statusMessage = %q, want gone", got.StatusMessage)
	}
}
