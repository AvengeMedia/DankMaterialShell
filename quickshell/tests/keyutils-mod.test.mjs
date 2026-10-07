import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const keys = loadScript(new URL("../Common/KeyUtils.js", import.meta.url));

test("symbolic Mod renders with the resolved modifier's glyph", () => {
    assert.deepEqual([...keys.formatKeyTokens("Mod+T", "Alt", "Mod")], ["⌥", "T"]);
});

test("conflict normalization treats sway Mod4 as Super", () => {
    assert.equal(keys.normalizeKeyCombo("Mod4+Return", "Super", ""), keys.normalizeKeyCombo("Super+Return", "Super", ""));
});

test("captured modifiers stay literal when the provider has no symbol", () => {
    assert.deepEqual([...keys.withSymbolicMod(["Super", "Shift"], "Super", "")], ["Super", "Shift"]);
});

test("IME commit sink follows Qt's first requested input-context module", () => {
    assert.equal(keys.compositorTextInputSelected(null, null), true, "unset env loads the wayland text-input context");
    assert.equal(keys.compositorTextInputSelected(null, "fcitx"), false, "an in-process module never enables text-input-v3");
    assert.equal(keys.compositorTextInputSelected("fcitx;wayland", "wayland"), false, "QT_IM_MODULES wins and its first entry decides");
    assert.equal(keys.compositorTextInputSelected(";;", "wayland"), true, "empty QT_IM_MODULES entries fall back to QT_IM_MODULE");
});
