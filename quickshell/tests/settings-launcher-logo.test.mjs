import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const store = loadScript(new URL("../Common/settings/SettingsStore.js", import.meta.url));

test("launcher logo globals land on every launcher button instance and are dropped", () => {
    const migrated = JSON.parse(JSON.stringify(store.migrateToVersion({
        configVersion: 28,
        launcherLogoMode: "os",
        launcherLogoColorOverride: "#ff0000",
        launcherLogoColorInvertOnMode: true,
        barConfigs: [{ id: "a", leftWidgets: ["launcherButton"], rightWidgets: [{ id: "launcherButton", enabled: false, launcherLogoMode: "dank" }] }, { id: "b", centerWidgets: ["clock"] }]
    }, 29)));
    assert.equal(migrated.configVersion, 29);
    assert.deepEqual(migrated.barConfigs[0].leftWidgets, [{ id: "launcherButton", enabled: true, launcherLogoMode: "os", launcherLogoColorOverride: "#ff0000" }]);
    assert.deepEqual(migrated.barConfigs[0].rightWidgets, [{ id: "launcherButton", enabled: false, launcherLogoMode: "dank", launcherLogoColorOverride: "#ff0000" }]);
    assert.deepEqual(migrated.barConfigs[1].centerWidgets, ["clock"]);
    assert.deepEqual(Object.keys(migrated).filter(key => key.startsWith("launcherLogo")), []);
});
