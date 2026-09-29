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

test("split header tiles collapse into one pinned header ahead of the layout", () => {
    const migrated = store.migrateToVersion({ configVersion: 32, controlCenterWidgets: [{ id: "userCard", w: 4, h: 1, hostname: false }, { id: "wifi", w: 4, h: 1, col: 0, row: 0 }, { id: "quickActions", w: 4, h: 1, powerAccent: true, actions: [{ id: "power", enabled: true }] }] }, 33);
    assert.deepEqual(JSON.parse(JSON.stringify(migrated.controlCenterWidgets)), [{ id: "header", enabled: true, w: 8, h: 1, hostname: false, actions: [{ id: "power", enabled: true }], powerAccent: true }, { id: "wifi", w: 4, h: 1, col: 0, row: 0 }]);
    assert.equal(migrated.configVersion, 33);
    assert.deepEqual(JSON.parse(JSON.stringify(store.migrateToVersion({ configVersion: 31, controlCenterWidgets: [{ id: "wifi", w: 4, h: 1 }] }, 33).controlCenterWidgets.map(w => w.id))), ["header", "wifi"]);
    assert.equal(store.migrateToVersion({ configVersion: 31 }, 33).controlCenterWidgets, undefined);
});

test("header splits into independently placed user and action widgets with their options", () => {
    const wifi = { id: "wifi", w: 4, h: 1, col: 0, row: 0 };
    const actions = [{ id: "settings", enabled: false }, { id: "edit", enabled: true }];
    const migrated = store.migrateToVersion({ configVersion: 33, controlCenterColumns: 10, controlCenterWidgets: [wifi, { id: "header", w: 8, h: 2, col: 1, row: 3, hostname: false, compositor: false, uptime: false, badge: false, background: false, powerAccent: true, actions }] }, 34);
    assert.deepEqual(JSON.parse(JSON.stringify(migrated.controlCenterWidgets)), [wifi,
        { id: "userCard", enabled: true, w: 6.5, h: 2, hostname: false, compositor: false, uptime: false, badge: false, background: false, col: 1, row: 3 },
        { id: "quickActions", enabled: true, w: 1.5, h: 1.5, actions, powerAccent: true, col: 7.5, row: 3 }
    ]);
    assert.equal(migrated.configVersion, 34);
    assert.equal(store.migrateToVersion(migrated, 34), null);
});

test("header migration respects hidden identity and retains an edit entry point", () => {
    const hidden = store.migrateToVersion({ configVersion: 33, controlCenterWidgets: [{ id: "header", showUser: false, col: 2, row: 1 }] }, 34);
    assert.deepEqual(JSON.parse(JSON.stringify(hidden.controlCenterWidgets)), [{ id: "quickActions", enabled: true, w: 1.5, h: 1.5, col: 2, row: 1 }]);
    const absent = store.migrateToVersion({ configVersion: 33, controlCenterWidgets: [] }, 34);
    assert.equal(absent.controlCenterWidgets[0].id, "quickActions");
    assert.equal(store.migrateToVersion({ configVersion: 33 }, 34).controlCenterWidgets, undefined);
});
