import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("../DMSShellIPC.qml", import.meta.url), "utf8");
const barBlock = source.slice(source.indexOf("    function getBarConfig("), source.indexOf('        target: "bar"'));
const functions = [...barBlock.matchAll(/^ {4,8}function (\w+)\(([^)]*)\)(?:: \w+)? \{\n[\s\S]*?^\s{4,8}\}$/gm)];
const untyped = functions.map(match => match[0].replace(/\((.*?)\)(?:: \w+)? \{/, (_, params) => "(" + params.replace(/: \w+/g, "") + ") {"));

function shell(barConfigs, toggleResults = []) {
    const updates = [];
    const reveals = [];
    const SettingsData = {
        barConfigs,
        Position: { Top: 0, Bottom: 1, Left: 2, Right: 3 },
        isIslandBarConfig: bar => bar.island === true,
        updateBarConfig: (id, patch) => updates.push([id, patch]),
        setBarIpcReveal: (id, on) => reveals.push(["set", id, on]),
        toggleBarIpcReveal: id => {
            reveals.push(["toggle", id]);
            return toggleResults.shift();
        }
    };
    const context = vm.createContext({ SettingsData });
    for (const body of untyped)
        vm.runInContext(body.replace(/^ {4}/gm, ""), context);
    return { context, updates, reveals };
}

const bars = [{ id: "main", name: "Main", visible: true, autoHide: false, position: 0 }, { id: "isle", name: "Isle", island: true, visible: true, autoHide: true, position: 1 }, { id: "hidden", name: "Hidden", visible: false, autoHide: true, position: 2 }];

test("selector errors come back before any update", () => {
    const { context, updates } = shell(bars);
    assert.equal(context.reveal("bogus", "main"), "BAR_INVALID_SELECTOR");
    assert.equal(context.hide("id", "nope"), "BAR_NOT_FOUND");
    assert.equal(context.status("index", "7"), "BAR_NOT_FOUND");
    assert.deepEqual(updates, []);
});

test("island bars refuse mutations but answer queries", () => {
    const { context, updates } = shell(bars);
    for (const fn of ["reveal", "hide", "toggle", "autoHide", "manualHide", "toggleAutoHide", "toggleReveal"])
        assert.equal(context[fn]("id", "isle"), "BAR_IS_ISLAND", fn);
    assert.equal(context.status("id", "isle"), "visible");
    assert.equal(context.getPosition("id", "isle"), "bottom");
    assert.equal(context.setPosition("id", "isle", "left"), "BAR_POSITION_SET_SUCCESS");
    assert.deepEqual(JSON.parse(JSON.stringify(updates)), [["isle", { position: 2 }]]);
});

test("visibility and auto hide handlers write the expected patches", () => {
    const { context, updates } = shell(bars);
    assert.equal(context.reveal("name", "Main"), "BAR_SHOW_SUCCESS");
    assert.equal(context.hide("index", "0"), "BAR_HIDE_SUCCESS");
    assert.equal(context.toggle("id", "main"), "BAR_HIDE_SUCCESS");
    assert.equal(context.toggle("id", "hidden"), "BAR_SHOW_SUCCESS");
    assert.equal(context.autoHide("id", "main"), "BAR_AUTO_HIDE_SUCCESS");
    assert.equal(context.manualHide("id", "hidden"), "BAR_MANUAL_HIDE_SUCCESS");
    assert.equal(context.toggleAutoHide("id", "main"), "BAR_AUTO_HIDE_SUCCESS");
    assert.equal(context.toggleAutoHide("id", "hidden"), "BAR_MANUAL_HIDE_SUCCESS");
    assert.equal(context.status("id", "hidden"), "hidden");
    assert.equal(context.getPosition("id", "hidden"), "left");
    assert.equal(context.setPosition("id", "main", "Nowhere"), "BAR_INVALID_POSITION");
    assert.deepEqual(JSON.parse(JSON.stringify(updates)), [["main", { visible: true }], ["main", { visible: false }], ["main", { visible: false }], ["hidden", { visible: true }], ["main", { autoHide: true }], ["hidden", { autoHide: false }], ["main", { autoHide: true }], ["hidden", { autoHide: false }]]);
});

test("toggleReveal only works on auto hide bars and unhides first", () => {
    const { context, updates, reveals } = shell(bars, [true, false]);
    assert.equal(context.toggleReveal("id", "main"), "BAR_AUTO_HIDE_DISABLED");
    assert.equal(context.toggleReveal("id", "hidden"), "BAR_REVEAL_SUCCESS");
    assert.deepEqual(JSON.parse(JSON.stringify(updates)), [["hidden", { visible: true }]]);
    assert.deepEqual(reveals, [["set", "hidden", true]]);
    bars[2].visible = true;
    assert.equal(context.toggleReveal("id", "hidden"), "BAR_REVEAL_SUCCESS");
    assert.equal(context.toggleReveal("id", "hidden"), "BAR_TUCK_SUCCESS");
    assert.deepEqual(reveals.slice(1), [["toggle", "hidden"], ["toggle", "hidden"]]);
    bars[2].visible = false;
});
