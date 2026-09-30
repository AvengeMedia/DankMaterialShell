import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const store = loadScript(new URL("../Common/settings/SettingsStore.js", import.meta.url));

test("control center width percentages become square grid cells", () => {
    const migrated = store.migrateToVersion({
        configVersion: 26,
        controlCenterWidth: 800,
        controlCenterWidgets: [{ id: "wifi", width: 75 }, { id: "diskUsage", width: 25, mountPath: "/", instanceId: "disk" }, { id: "battery" }, { id: "plugin_x", width: 100, w: 3, h: 2, enabled: false }]
    }, 27);
    assert.equal(migrated.configVersion, 27);
    assert.equal(migrated.controlCenterColumns, 12);
    assert.equal(migrated.controlCenterWidth, undefined);
    assert.deepEqual(JSON.parse(JSON.stringify(migrated.controlCenterWidgets)), [{ id: "wifi", w: 6, h: 1 }, { id: "diskUsage", mountPath: "/", instanceId: "disk", w: 2, h: 1 }, { id: "battery", w: 4, h: 1 }, { id: "plugin_x", w: 6, h: 2, enabled: false }]);
    assert.equal(store.migrateToVersion(migrated, 27), null);
});

test("sparse settings migrate without inventing grid keys", () => {
    const migrated = store.migrateToVersion({ configVersion: 26, controlCenterWidth: 550, controlCenterWidgets: [{ id: "wifi", width: 50 }, { id: "battery", width: 100 }] }, 27);
    assert.equal(migrated.controlCenterColumns, 8);
    assert.deepEqual(JSON.parse(JSON.stringify(migrated.controlCenterWidgets)), [{ id: "wifi", w: 4, h: 1 }, { id: "battery", w: 8, h: 1 }]);
    const sparse = store.migrateToVersion({ configVersion: 26 }, 27);
    assert.equal(sparse.controlCenterColumns, undefined);
    assert.equal(sparse.controlCenterWidgets, undefined);
});

test("header entries become a user row and lock, power and settings tiles", () => {
    const released = store.migrateToVersion({ configVersion: 18, controlCenterWidgets: [{ id: "wifi", width: 50 }] }, 35);
    assert.deepEqual(JSON.parse(JSON.stringify(released.controlCenterWidgets.map(w => [w.id, w.w, w.h]))), [["user", 5, 1], ["settings", 1, 1], ["lock", 1, 1], ["power", 1, 1], ["wifi", 4, 1]]);
});

test("layouts saved before the running apps tile get one appended", () => {
    const migrated = store.migrateToVersion({ configVersion: 35, controlCenterColumns: 6, controlCenterWidgets: [{ id: "wifi", w: 4, h: 1 }] }, 36);
    assert.deepEqual(JSON.parse(JSON.stringify(migrated.controlCenterWidgets)), [{ id: "wifi", w: 4, h: 1 }, { id: "runningApps", enabled: true, w: 5, h: 1, small: true }]);
    const kept = store.migrateToVersion({ configVersion: 35, controlCenterWidgets: [{ id: "runningApps", w: 2, h: 1, col: 0, row: 3 }] }, 36);
    assert.deepEqual(JSON.parse(JSON.stringify(kept.controlCenterWidgets)), [{ id: "runningApps", w: 2, h: 1, col: 0, row: 3 }]);
});
