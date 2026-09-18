import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const store = loadScript(new URL("../Common/settings/SettingsStore.js", import.meta.url));

test("removed widget padding becomes zero padding", () => {
    const migrated = store.migrateToVersion({
        configVersion: 24,
        barConfigs: [{ id: "a", removeWidgetPadding: true, widgetPadding: 12 }, { id: "b", removeWidgetPadding: false, widgetPadding: 6 }, { id: "c" }]
    }, 27);
    assert.equal(migrated.configVersion, 27);
    assert.deepEqual(JSON.parse(JSON.stringify(migrated.barConfigs)), [{ id: "a", widgetPadding: 0 }, { id: "b", widgetPadding: 6 }, { id: "c" }]);
});

test("settings without bars migrate cleanly", () => {
    const migrated = store.migrateToVersion({ configVersion: 24 }, 27);
    assert.equal(migrated.configVersion, 27);
});
