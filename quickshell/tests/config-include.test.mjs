import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { loadScript } from "./qml-script.mjs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import vm from "node:vm";
import test from "node:test";

const resolve = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/ConfigIncludeResolve.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), resolve);
const plain = value => JSON.parse(JSON.stringify(value));

test("includeSpec returns null off the table", () => {
    assert.equal(resolve.includeSpec("colors", "mango"), null, "colors is deployed by setup, never repaired");
    assert.equal(resolve.includeSpec("colors", "niri"), null, "unknown kind");
    assert.equal(resolve.includeSpec("outputs", "sway"), null, "unknown compositor");
    assert.equal(resolve.includeSpec("outputs", ""), null, "empty compositor");
});

test("binds on hyprland carries dms.binds before dms.binds-user", () => {
    const spec = resolve.includeSpec("binds", "hyprland");
    assert.deepEqual(plain(spec.fragmentNames), ["binds.lua", "binds-user.lua"]);
});

test("includePaths joins the compositor directory, with hypr for hyprland", () => {
    const niri = resolve.includePaths("outputs", "niri", "/home/u/.config");
    assert.equal(niri.configFile, "/home/u/.config/niri/config.kdl");
    assert.deepEqual(plain(niri.fragmentFiles), ["/home/u/.config/niri/dms/outputs.kdl"]);
    const hyprland = resolve.includePaths("layout", "hyprland", "/home/u/.config");
    assert.equal(hyprland.configFile, "/home/u/.config/hypr/hyprland.lua");
    assert.deepEqual(plain(hyprland.fragmentFiles), ["/home/u/.config/hypr/dms/layout.lua"]);
    const mango = resolve.includePaths("cursor", "mango", "/home/u/.config");
    assert.equal(mango.configFile, "/home/u/.config/mango/config.conf");
    assert.deepEqual(plain(mango.fragmentFiles), ["/home/u/.config/mango/dms/cursor.conf"]);
    const binds = resolve.includePaths("binds", "hyprland", "/home/u/.config");
    assert.deepEqual(plain(binds.fragmentFiles), ["/home/u/.config/hypr/dms/binds.lua", "/home/u/.config/hypr/dms/binds-user.lua"]);
    assert.deepEqual(plain(resolve.includePaths("input", "mango", "/home/u/.config").fragmentFiles), ["/home/u/.config/mango/dms/input.conf"]);
    assert.equal(resolve.includePaths("colors", "mango", "/home/u/.config"), null, "no spec, no paths");
});

test("resolveIncludeArgs spells mango as mangowc and names the fragment", () => {
    assert.deepEqual(plain(resolve.resolveIncludeArgs("outputs", "niri")), ["niri", "outputs.kdl"]);
    assert.deepEqual(plain(resolve.resolveIncludeArgs("layout", "hyprland")), ["hyprland", "layout.lua"]);
    assert.deepEqual(plain(resolve.resolveIncludeArgs("input", "hyprland")), ["hyprland", "input.lua"]);
    assert.deepEqual(plain(resolve.resolveIncludeArgs("windowrules", "mango")), ["mangowc", "windowrules.conf"]);
    assert.deepEqual(plain(resolve.resolveIncludeArgs("input", "mango")), ["mangowc", "input.conf"]);
    assert.equal(resolve.resolveIncludeArgs("colors", "mango"), null, "no spec, no args");
});

test("repairScriptFor returns an empty script off the table", () => {
    assert.equal(resolve.repairScriptFor("colors", "mango", "/home/u/.config", "/x"), "");
    assert.equal(resolve.repairScriptFor("nope", "niri", "/home/u/.config", "/x"), "");
});

test("repair preserves config and fragments, backs up, and adds live includes only once", t => {
    const directory = mkdtempSync(join(tmpdir(), "dms-includes-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    for (const [compositor, kind, prefix] of [["niri", "outputs", "//"], ["hyprland", "binds", "--"], ["mango", "binds", "#"]]) {
        const configDir = join(directory, compositor + " space's");
        const paths = resolve.includePaths(kind, compositor, configDir);
        mkdirSync(dirname(paths.configFile), { recursive: true });
        const original = prefix + " user config\n" + paths.includes.map(entry => prefix + " " + entry.includeLine + "\n").join("");
        writeFileSync(paths.configFile, original);
        const fragment = paths.fragmentFiles[0];
        mkdirSync(dirname(fragment), { recursive: true });
        writeFileSync(fragment, "existing fragment\n");
        const backup = paths.configFile + ".backup";
        execFileSync("sh", ["-c", resolve.repairScriptFor(kind, compositor, configDir, backup)]);
        assert.equal(readFileSync(backup, "utf8"), original);
        assert.equal(readFileSync(fragment, "utf8"), "existing fragment\n");
        for (const file of paths.fragmentFiles)
            assert.ok(existsSync(file));
        const repaired = readFileSync(paths.configFile, "utf8");
        assert.ok(repaired.startsWith(original));
        const live = repaired.split("\n").filter(line => !line.trimStart().startsWith(prefix));
        for (const { includeLine } of paths.includes)
            assert.equal(live.filter(line => line === includeLine).length, 1);
        if (compositor === "hyprland")
            assert.ok(live.indexOf(paths.includes[0].includeLine) < live.indexOf(paths.includes[1].includeLine));
        execFileSync("sh", ["-c", resolve.repairScriptFor(kind, compositor, configDir, "")]);
        assert.equal(readFileSync(paths.configFile, "utf8"), repaired);
    }
});

test("mango input fragment maps choices onto libinput numbers and spells numlock per dialect", () => {
    const SPEC = loadScript(new URL("../Common/settings/SettingsSpec.js", import.meta.url)).SPEC;
    const source = readFileSync(new URL("../Services/MangoService.qml", import.meta.url), "utf8");
    const found = source.match(/^    function mangoInputLines\([^)]*\) \{\n[\s\S]*?^    \}/m);
    assert.ok(found, "mangoInputLines not found in MangoService.qml");
    const scope = vm.createContext({});
    vm.runInContext(found[0], scope);
    const defaults = Object.fromEntries(Object.keys(SPEC).filter(key => /^(mouse|touchpad|keyboard)[A-Z]/.test(key)).map(key => [key, SPEC[key].def]));
    const lines = (overrides, snake = false) => [...scope.mangoInputLines(Object.assign({}, defaults, overrides), snake)];
    const value = (list, key) => list.find(line => line.startsWith(key + "="))?.slice(key.length + 1);

    const stock = lines({});
    assert.equal(value(stock, "trackpad_natural_scrolling"), "1");
    assert.equal(value(stock, "mouse_accel_profile"), undefined, "default profile leaves the key to Mango");
    assert.ok(!stock.some(line => /^(xkb_rules_|repeat_|numlock)/.test(line)), "unconfigured keyboard writes nothing");

    const chosen = lines({ mouseScrollMethod: "no-scroll", touchpadAccelProfile: "adaptive", touchpadScrollMethod: "on-button-down", touchpadClickMethod: "clickfinger", touchpadDisableOnExternalMouse: true, keyboardLayouts: "us,de", keyboardRepeatDelay: 300 });
    assert.equal(value(chosen, "mouse_scroll_method"), "0");
    assert.equal(value(chosen, "trackpad_accel_profile"), "2");
    assert.equal(value(chosen, "trackpad_scroll_method"), "4");
    assert.equal(value(chosen, "trackpad_click_method"), "2");
    assert.equal(value(chosen, "trackpad_send_events_mode"), "2");
    assert.equal(value(chosen, "xkb_rules_layout"), "us,de");
    assert.equal(value(chosen, "xkb_rules_variant"), undefined, "empty fields stay out");
    assert.equal(value(chosen, "repeat_delay"), "300");
    assert.equal(value(chosen, "numlockon"), "0");
    assert.equal(value(lines({ keyboardNumlock: true }, true), "numlock_on"), "1");
});
