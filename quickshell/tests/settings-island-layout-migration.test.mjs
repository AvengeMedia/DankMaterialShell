import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const store = loadScript(new URL("../Common/settings/SettingsStore.js", import.meta.url));

test("version 42 island layouts migrate into the configured compact widgets", () => {
    const migrated = store.migrateToVersion({
        configVersion: 42,
        barConfigs: [{
            id: "island",
            island: true,
            islandHomeLayout: [{ id: "workspaces" }, { id: "media" }],
            centerWidgets: [{ id: "music", enabled: false }, { id: "clipboard", enabled: true }]
        }]
    }, 43);

    assert.equal(migrated.configVersion, 43);
    assert.deepEqual(JSON.parse(JSON.stringify(migrated.barConfigs[0].centerWidgets.map(widget => [widget.id, widget.enabled]))), [
        ["workspaceSwitcher", true],
        ["music", true],
        ["clipboard", true]
    ]);
    assert.equal(migrated.barConfigs[0].islandHomeLayout, undefined);
    assert.equal(store.migrateToVersion(migrated, 43), null);
});
