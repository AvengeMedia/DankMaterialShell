import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("../Services/WlrOutputService.qml", import.meta.url), "utf8");
const heads = source.match(/^ {4}function outputsConfigHeads\([^)]*\) \{\n[\s\S]*?^ {4}\}$/m)[0];
const context = vm.createContext({ OutputModel: { transformIndex: name => ["Normal", "90"].indexOf(name) } });
vm.runInContext(heads.replace(/^ {4}/gm, ""), context);

const output = (vrr_supported, vrr_enabled) => ({
    modes: [{ id: 7, width: 2560, height: 1440, refresh_rate: 143998 }],
    current_mode: 0,
    logical: { x: 0, y: 0, scale: 1, transform: "Normal" },
    vrr_supported,
    vrr_enabled
});

test("the vrr toggle reaches heads that support adaptive sync, and only those", () => {
    const outputs = { "DP-1": output(true, true), "DP-2": output(true, false), "HDMI-A-1": output(false, true) };
    const result = context.outputsConfigHeads(outputs, { "DP-1": true, "DP-2": true, "HDMI-A-1": true });
    assert.deepEqual(Array.from(result, head => [head.name, head.adaptiveSync]), [["DP-1", 1], ["DP-2", 0], ["HDMI-A-1", undefined]]);
});
