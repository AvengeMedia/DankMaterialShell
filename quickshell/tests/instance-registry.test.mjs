import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const registry = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/InstanceRegistry.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), registry);
const configs = ["z", "a", "vertical", "dock"];
const screens = ["DP-2", "DP-1"];
function entry(barId, section, occurrenceOrder, screenName = "DP-2", widgetId = "clock") {
    const instanceId = `${barId}:${section}:${occurrenceOrder}`;
    return { key: registry.key(screenName, instanceId), widgetId, screenName, instanceId, item: {}, context: {
        barId, section, occurrenceOrder, occurrenceId: "entry_" + occurrenceOrder,
        kind: barId === "dock" ? "dock" : "bar", surface: { config: { position: barId === "vertical" ? 2 : 0 } }
    } };
}
const select = (entries, target, widgetId = "clock", eligible) => registry.select(entries, widgetId, target, configs, screens, eligible);

test("duplicates resolve by screen, horizontal/config, section and numeric occurrence order", () => {
    const entries = {};
    for (const screen of screens.slice().reverse())
        for (const config of configs.slice().reverse())
            for (const section of ["right", "center", "left"])
                for (const occurrence of [10, 2, 1]) {
                    const value = entry(config, section, occurrence, screen);
                    entries[value.key] = value;
                }
    assert.equal(select(entries).instanceId, "z:left:1");
    assert.equal(select(entries).screenName, "DP-2");
    assert.equal(select(entries, { screenName: "DP-1", barId: "a", section: "right", occurrenceId: "entry_2" }).instanceId, "a:right:2");
    for (const target of [{ screenName: "missing" }, { barId: "missing" }, { instanceId: "missing" }, { occurrenceId: "missing" }])
        assert.equal(select(entries, target), null);
    assert.equal(select(entries, null, "missingPlugin"), null);
    assert.equal(select(entries, null, "clock", candidate => candidate.context.barId === "a").instanceId, "a:left:1");
});

test("captured registration owns release across replacement and reorder", () => {
    const old = entry("z", "left", 0);
    const replacement = entry("z", "left", 0);
    let entries = { [old.key]: replacement };
    assert.equal(registry.release(entries, old), entries);
    const moved = { ...replacement, key: registry.key("DP-2", "z:right:1") };
    entries = { [moved.key]: moved };
    assert.equal(registry.release(entries, replacement), entries);
    assert.deepEqual(Object.keys(registry.release(entries, moved)), []);
    assert.equal(registry.release(entries, null), entries);
});

test("plugin variants and explicit occurrences remain independent", () => {
    const first = entry("a", "center", 1, "DP-1", "plugin:variant");
    const second = entry("a", "center", 2, "DP-1", "plugin:variant");
    const entries = { [second.key]: second, [first.key]: first };
    assert.equal(select(entries, { instanceId: first.instanceId }, "plugin:variant"), first);
    assert.equal(select(registry.release(entries, first), {}, "plugin:variant"), second);
});
