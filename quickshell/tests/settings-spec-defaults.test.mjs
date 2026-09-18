import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const SPEC = loadScript(new URL("../Common/settings/SettingsSpec.js", import.meta.url)).SPEC;
const settingsData = readFileSync(new URL("../Common/SettingsData.qml", import.meta.url), "utf8");
const osdTab = readFileSync(new URL("../Modules/Settings/OSDTab.qml", import.meta.url), "utf8");

const declarations = new Map();
for (const line of settingsData.split("\n")) {
    const match = line.match(/^\s*(?:readonly\s+)?property\s+[A-Za-z_][\w.]*\s+([A-Za-z_]\w*)\s*:\s*(.*)$/);
    if (!match)
        continue;
    const [, key, initializer] = match;
    if (!declarations.has(key))
        declarations.set(key, []);
    declarations.get(key).push(initializer.trim());
}

const ENUM_EXCEPTIONS = {
    motionEffect: { initializer: "SettingsData.AnimationEffect.Standard", value: 0 },
    fontWeight: { initializer: "Font.Normal", value: 400 },
    textRenderType: { initializer: "SettingsData.TextRenderType.Qt", value: 0 },
    textRenderQuality: { initializer: "SettingsData.TextRenderQuality.Default", value: 0 },
    acSuspendBehavior: { initializer: "SettingsData.SuspendBehavior.Suspend", value: 0 },
    batterySuspendBehavior: { initializer: "SettingsData.SuspendBehavior.Suspend", value: 0 },
    notificationPopupPosition: { initializer: "SettingsData.Position.Top", value: 0 },
    osdPosition: { initializer: "SettingsData.Position.BottomCenter", value: 5 }
};

test("every spec key is declared exactly once in SettingsData.qml", () => {
    const undeclared = Object.keys(SPEC).filter(key => !declarations.has(key));
    assert.deepEqual(undeclared, []);
    const redeclared = Object.keys(SPEC).filter(key => declarations.get(key).length > 1);
    assert.deepEqual(redeclared, []);
});

test("every spec-backed declaration reads its own spec default", () => {
    const offenders = Object.keys(SPEC).filter(key => !(key in ENUM_EXCEPTIONS)).filter(key => declarations.get(key)?.[0] !== `Spec.SPEC.${key}.def`);
    assert.deepEqual(offenders, []);
});

test("enum-valued defaults keep their QML spelling and their persisted number", () => {
    for (const [key, expected] of Object.entries(ENUM_EXCEPTIONS)) {
        assert.equal(declarations.get(key)?.[0], expected.initializer, key);
        assert.equal(SPEC[key].def, expected.value, key);
    }
});

test("the power profile OSD stays off so nothing d-bus activates the daemon", () => {
    assert.equal(SPEC.osdPowerProfileEnabled.def, false);
});

test("every OSD toggle key has a row and every OSD row has a key", () => {
    const rowKeys = [...osdTab.matchAll(/settingKey:\s*"(osd\w*Enabled)"/g)].map(match => match[1]);
    const specKeys = Object.keys(SPEC).filter(key => /^osd\w*Enabled$/.test(key));
    assert.deepEqual(rowKeys.filter(key => !specKeys.includes(key)), []);
    assert.deepEqual(specKeys.filter(key => !rowKeys.includes(key)), []);
    assert.deepEqual(rowKeys.filter((key, index) => rowKeys.indexOf(key) !== index), []);
});
