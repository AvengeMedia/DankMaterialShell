package providers

import (
	"encoding/json"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	"reflect"
	"testing"
)

func aqueousFixture(t *testing.T) aqueousConfig {
	t.Helper()
	var snapshot aqueousConfig
	err := utils.DecodeJSON([]byte(`{"ok":true,"protocol":1,"generation":"abc","capabilities":["keybinds"],"fields":[{"id":"spawn_terminal","category":"keybinds","type":"string_list","label":"Terminal","value":["Super+Return","Super+T"]},{"id":"close","category":"keybinds","type":"string_list","label":"Close","value":[]}],"custom_keybinds":[{"id":"custom:12","chord":"Super+R","command":"printf 'hello; $world'"}]}`), &snapshot)
	if err != nil {
		t.Fatal(err)
	}
	return snapshot
}

func TestAqueousCheatsheetIncludesUnboundAndCustom(t *testing.T) {
	sheet, err := AqueousCheatSheet(aqueousFixture(t))
	if err != nil {
		t.Fatal(err)
	}
	if sheet.Generation != "abc" || len(sheet.Binds["Compositor"]) != 3 {
		t.Fatal("lost generation or multiple bindings")
	}
	if sheet.Binds["Compositor"][2].Key != "" || sheet.Binds["Compositor"][2].Action != "close" {
		t.Fatal("unbound action lost")
	}
	if sheet.Binds["Custom"][0].Action != "spawn printf 'hello; $world'" {
		t.Fatal("custom command modified")
	}
}

func TestAqueousBindingReplacementIsOneRequest(t *testing.T) {
	snapshot := aqueousFixture(t)
	request, err := AqueousBindRequest(snapshot, AqueousBindEdit{Generation: "abc", OriginalKey: "Super+Return", Key: "Super+Enter", Action: "spawn_terminal"})
	if err != nil {
		t.Fatal(err)
	}
	data, _ := json.Marshal(request["changes"])
	if string(data) != `[{"id":"spawn_terminal","value":["Super+T","Super+Enter"]}]` {
		t.Fatalf("wrong atomic replacement: %s", data)
	}
	if request["expected_generation"] != "abc" {
		t.Fatal("generation replaced")
	}
	if !reflect.DeepEqual(snapshot, aqueousFixture(t)) {
		t.Fatal("draft mutated snapshot")
	}
}

func TestAqueousBindingConflictAndRemove(t *testing.T) {
	for _, edit := range []AqueousBindEdit{
		{Generation: "stale", Key: "Super+T", Remove: true},
		{Generation: "abc", OriginalKey: "Super+Return", Key: "Super+R", Action: "close"},
		{Generation: "abc", Key: "Super+Q", Action: "invented_action"},
	} {
		if _, err := AqueousBindRequest(aqueousFixture(t), edit); err == nil {
			t.Fatal("invalid edit accepted")
		}
	}
	request, err := AqueousBindRequest(aqueousFixture(t), AqueousBindEdit{Generation: "abc", Key: "Super+R", Remove: true})
	if err != nil {
		t.Fatal(err)
	}
	data, _ := json.Marshal(request["custom_keybind_changes"])
	if string(data) != `[{"id":"custom:12","op":"delete"}]` {
		t.Fatalf("wrong removal: %s", data)
	}
}
