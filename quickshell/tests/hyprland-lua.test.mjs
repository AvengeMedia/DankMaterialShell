import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";
import { loadScript } from "./qml-script.mjs";

const OutputModel = loadScript(new URL("../Common/OutputModel.js", import.meta.url));
const BlurStrength = loadScript(new URL("../Common/BlurStrength.js", import.meta.url));
const SPEC = loadScript(new URL("../Common/settings/SettingsSpec.js", import.meta.url)).SPEC;
const source = readFileSync(new URL("../Services/HyprlandService.qml", import.meta.url), "utf8");
const extract = name => {
    const found = source.match(new RegExp(`^    function ${name}\\([^)]*\\) \\{\\n[\\s\\S]*?^    \\}`, "m"));
    if (!found)
        throw new Error(`${name} not found in HyprlandService.qml`);
    return found[0];
};

const live = {};
// Every option is reported as supported unless a test shrinks the set
const scope = vm.createContext({
    OutputModel,
    BlurStrength,
    SettingsData: { displayNameMode: "system" },
    liveMonitor: name => live[name] ?? null,
    hyprOptionNames: new Proxy({}, { get: (names, key) => key in names ? names[key] : true })
});
for (const fn of ["getOutputIdentifier", "luaQuoted", "forceFlagValue", "buildOutputsLua", "luaString", "luaTable", "hyprSupports", "blurLines", "decorationLines", "groupbarLines", "hyprScrollMethod", "touchpadNames", "inputLines", "touchpadDeviceLines"])
    vm.runInContext(extract(fn), scope);
const withOptions = (names, run) => {
    const previous = scope.hyprOptionNames;
    scope.hyprOptionNames = names;
    try {
        return run();
    } finally {
        scope.hyprOptionNames = previous;
    }
};
// Arrays from the vm realm fail deepStrictEqual against local ones
const decorationLines = (s, rounding) => [...scope.decorationLines(s, rounding)];
const groupbarLines = s => [...scope.groupbarLines(s)];
const inputLines = s => [...scope.inputLines(s)].map(line => line.trim());
const deviceLines = (s, names) => [...scope.touchpadDeviceLines(s, names)];

const settingsFor = prefix => {
    const defaults = Object.fromEntries(Object.keys(SPEC).filter(key => prefix.test(key)).map(key => [key, SPEC[key].def]));
    return overrides => Object.assign({}, defaults, overrides);
};
const layout = settingsFor(/^(hyprland|blurStrength)/);
const input = settingsFor(/^(mouse|touchpad|keyboard)[A-Z]/);
const table = (lines, name) => {
    const start = lines.indexOf(`${name} = {`);
    return start < 0 ? null : lines.slice(start + 1, lines.indexOf("},", start)).map(line => line.trim());
};

const fallback = 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })';
const saved = OutputModel.parseHyprlandOutputs([
    fallback,
    'hl.monitor({ output = "eDP-1", mode = "2400x1600@120.000", position = "0x0", scale = 1.25, vrr = 0 })',
    'hl.monitor({ output = "DP-1", mode = "preferred", position = "auto", scale = "auto" })',
    'hl.monitor({ output = "DP-2", mode = "preferred", position = "auto-right", scale = "auto" })'
].join("\n"));
const connected = (name, x, y, scale) => ({ name, logical: { x, y, scale, transform: "Normal" }, modes: [], current_mode: -1 });
const monitorLine = (content, name) => content.split("\n").find(line => line.includes(`output = "${name}"`));

test("outputs: the catch-all line is not a monitor and is rewritten verbatim, once, last", () => {
    assert.deepEqual(Object.keys(saved), ["eDP-1", "DP-1", "DP-2"]);
    const content = scope.buildOutputsLua({ "": { name: "", logical: { x: 0, y: 0, scale: 1 } }, "eDP-1": connected("eDP-1", 0, 0, 1.25) }, {}, saved);
    assert.deepEqual(content.split("\n").filter(line => line.includes('output = ""')), [fallback]);
    assert.equal(content.trimEnd().split("\n").at(-1), fallback);
});

test("outputs: auto position and scale survive a rewrite until the written value differs from what Hyprland resolved", () => {
    live["eDP-1"] = { x: 0, y: 0, scale: 1.25 };
    live["DP-1"] = { x: 1920, y: 0, scale: 1.5 };
    const cases = [
        [connected("DP-1", 1920, 0, 1.5 + 1 / 512), 'position = "auto", scale = "auto"'],
        [connected("DP-1", 2000, 0, 1.5), 'position = "2000x0", scale = "auto"'],
        [connected("DP-1", 1920, 0, 2), 'position = "auto", scale = 2']
    ];
    for (const [output, want] of cases) {
        const line = monitorLine(scope.buildOutputsLua({ "eDP-1": connected("eDP-1", 0, 0, 1.25), "DP-1": output }, {}, saved), "DP-1");
        assert.ok(line.includes(want), line);
    }
    const disconnected = monitorLine(scope.buildOutputsLua({ "eDP-1": connected("eDP-1", 0, 0, 1.25), "DP-2": saved["DP-2"] }, {}, saved), "DP-2");
    assert.ok(disconnected.includes('position = "auto-right", scale = "auto"'), disconnected);
});

test("outputs: vrr is written only for a chosen mode, so untouched monitors inherit misc:vrr", () => {
    const vrrFile = OutputModel.parseHyprlandOutputs([
        'hl.monitor({ output = "eDP-1", mode = "2400x1600@120.000", position = "0x0", scale = 1.25, vrr = 0 })',
        'hl.monitor({ output = "DP-1", mode = "preferred", position = "2400x0", scale = 1, vrr = 2 })'
    ].join("\n"));
    const supported = name => Object.assign(connected(name, 0, 0, 1), { vrr_supported: true, vrr_enabled: false });
    const vrrOf = (name, settings) => monitorLine(scope.buildOutputsLua({ [name]: supported(name) }, settings, vrrFile), name).match(/vrr = (-?\d+)/)?.[1];
    const cases = [
        ["eDP-1", {}, undefined],
        ["DP-1", {}, "2"],
        ["DP-1", { "DP-1": { vrr: -1 } }, undefined],
        ["eDP-1", { "eDP-1": { vrr: 0 } }, "0"],
        ["eDP-1", { "eDP-1": { vrrFullscreenOnly: true } }, "2"]
    ];
    assert.deepEqual(cases.map(([name, settings]) => vrrOf(name, settings)), cases.map(c => c[2]));
});

test("outputs: written scale snaps to Hyprland's n/120 grid so live float32 scales round-trip unchanged", () => {
    live["eDP-1"] = { x: 0, y: 0, scale: 1.25 };
    live["DP-1"] = { x: 1920, y: 0, scale: 1.3333333730697632 };
    const scaleOf = (name, scale) => monitorLine(scope.buildOutputsLua({ [name]: connected(name, name === "DP-1" ? 1920 : 0, 0, scale) }, {}, saved), name).match(/scale = ([^,}\s]+)/)[1];
    assert.deepEqual([scaleOf("eDP-1", 1.3333333730697632), scaleOf("eDP-1", 1.33), scaleOf("DP-1", 1.3333333730697632)], ["1.333333", "1.333333", '"auto"']);
});

test("layout: a blur variant forces blur on and writes only its own tuning table", () => {
    assert.equal(table(decorationLines(layout({ hyprlandBlurVariant: "kawase", blurStrength: 16 }), 0), "blur"), null);
    const frost = table(decorationLines(layout({ hyprlandBlurVariant: "frost", blurStrength: 16 }), 0), "blur");
    assert.deepEqual(frost, ["enabled = true,", 'variant = "frost",']);
    const aurora = table(decorationLines(layout({ hyprlandBlurVariant: "aurora", blurStrength: 16 }), 0), "blur");
    assert.deepEqual(aurora.slice(0, 2), ["enabled = true,", 'variant = "aurora",']);
    assert.deepEqual(table(aurora, "aurora"), ["intensity = 0.35,", "speed = 1,"]);
    assert.equal(table(aurora, "haze"), null);
});

test("layout: blur strength writes Hyprland's size and passes, default reach gives two passes and skips the stock size", () => {
    assert.deepEqual(table(decorationLines(layout(), 0), "blur"), ["passes = 2,"]);
    assert.equal(table(decorationLines(layout({ blurStrength: 16 }), 0), "blur"), null);
    assert.deepEqual(table(decorationLines(layout({ blurStrength: 112, hyprlandBlurVariant: "frost" }), 0), "blur"), ["passes = 3,", "enabled = true,", 'variant = "frost",']);
});

test("layout: effects the running Hyprland does not know are not written even when enabled", () => {
    const enabled = layout({
        blurStrength: 16,
        hyprlandBlurVariant: "aurora",
        hyprlandGlowEnabled: true,
        hyprlandWobbleEnabled: true,
        hyprlandMotionBlurEnabled: true,
        hyprlandGroupbarBlur: true
    });
    withOptions({ "decoration:glow:enabled": true }, () => {
        assert.deepEqual(decorationLines(enabled, 12).filter(line => line.endsWith("= {")), ["glow = {"]);
        assert.deepEqual(groupbarLines(enabled), []);
    });
});

test("input: turning natural scroll off is written so the template's true cannot shadow it", () => {
    assert.ok(table(inputLines(input({ touchpadNaturalScroll: false })), "touchpad").includes("natural_scroll = false,"));
});

test("input: keyboard keys stay out until one is configured, then numlock is explicit and kb_file replaces the xkb names", () => {
    const untouched = inputLines(input({ keyboardTrackLayout: "window" }));
    assert.equal(untouched.some(line => /^(kb_|repeat_|numlock)/.test(line)), false);
    const keyboard = inputLines(input({ keyboardLayouts: "us,de", keyboardOptions: "grp:alt_shift_toggle", keyboardRepeatRate: 40 }));
    assert.deepEqual(keyboard.slice(keyboard.lastIndexOf("},") + 1), [
        'kb_layout = "us,de",',
        'kb_options = "grp:alt_shift_toggle",',
        "repeat_rate = 40,",
        "numlock_by_default = false,"
    ]);
    const file = inputLines(input({ keyboardKeymapFile: "/k.xkb", keyboardLayouts: "us" }));
    assert.ok(file.includes('kb_file = "/k.xkb",'));
    assert.equal(file.some(line => line.startsWith("kb_layout")), false);
});

test("input: click method maps to clickfinger_behavior and default leaves it out", () => {
    const clickfinger = method => table(inputLines(input({ touchpadClickMethod: method })), "touchpad").find(line => line.startsWith("clickfinger_behavior"));
    assert.equal(clickfinger("clickfinger"), "clickfinger_behavior = true,");
    assert.equal(clickfinger("button-areas"), "clickfinger_behavior = false,");
    assert.equal(clickfinger("default"), undefined);
});

test("input: an option the running Hyprland does not know is never written", () => {
    withOptions({ "input:sensitivity": false, "input:touchpad:natural_scroll": true, "input:touchpad:tap-to-click": false }, () => {
        assert.deepEqual(inputLines(input({ mouseAccelSpeed: 0.5, touchpadDragLock: true })), ["touchpad = {", "natural_scroll = true,", "},"]);
        assert.deepEqual(deviceLines(input({ touchpadAccelSpeed: 0.3 }), ["elan-touchpad"]), []);
    });
});

test("input: touchpad speed goes per device and pins its own values against the global mouse ones", () => {
    assert.deepEqual(deviceLines(input({ touchpadAccelSpeed: 0.3 }), ["elan-touchpad"]), ['hl.device({ name = "elan-touchpad", sensitivity = 0.30 })']);
    assert.deepEqual(deviceLines(input({ mouseAccelSpeed: -0.5, mouseAccelProfile: "flat", mouseLeftHanded: true }), ["a-touchpad"]), [
        'hl.device({ name = "a-touchpad", sensitivity = 0.00, accel_profile = "", left_handed = false })'
    ]);
    assert.deepEqual([...scope.touchpadNames({ mice: [{ name: "logitech-mx-master-3" }, { name: "elan0670:00-04f3:3150-touchpad" }, { name: "apple-inc.-magic-trackpad" }] })], ["elan0670:00-04f3:3150-touchpad", "apple-inc.-magic-trackpad"]);
});
