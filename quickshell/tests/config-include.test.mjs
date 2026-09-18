import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const resolve = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/ConfigIncludeResolve.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), resolve);
const plain = value => JSON.parse(JSON.stringify(value));

const kdl = (name, fragments = [name]) => ({
    configName: "config.kdl",
    fragmentNames: fragments.map(fragment => `${fragment}.kdl`),
    includes: fragments.map(fragment => ({ grepPattern: `include.*"dms/${fragment}.kdl"`, includeLine: `include "dms/${fragment}.kdl"` }))
});
const lua = (name, fragments = [name]) => ({
    configName: "hyprland.lua",
    fragmentNames: fragments.map(fragment => `${fragment}.lua`),
    includes: fragments.map(fragment => ({ grepPattern: `dms.${fragment}`, includeLine: `require("dms.${fragment}")` }))
});
const conf = (name, grepPattern, includeLine) => ({
    configName: "config.conf",
    fragmentNames: [`${name}.conf`],
    includes: [{ grepPattern, includeLine }]
});

const expected = {
    outputs: { niri: kdl("outputs"), hyprland: lua("outputs"), mango: conf("outputs", "source.*dms/outputs.conf", "source=./dms/outputs.conf") },
    layout: { niri: kdl("layout"), hyprland: lua("layout"), mango: conf("layout", "source.*dms/layout.conf", "source=./dms/layout.conf") },
    input: { niri: kdl("input"), hyprland: null, mango: null },
    windowrules: { niri: kdl("windowrules"), hyprland: lua("windowrules"), mango: conf("windowrules", "dms/windowrules.conf", "source=./dms/windowrules.conf") },
    cursor: { niri: kdl("cursor"), hyprland: lua("cursor"), mango: conf("cursor", "source.*dms/cursor.conf", "source=./dms/cursor.conf") },
    binds: { niri: kdl("binds"), hyprland: lua("binds", ["binds", "binds-user"]), mango: conf("binds", "source.*dms/binds.conf", "source = ./dms/binds.conf") }
};

test("includeSpec reproduces every site's strings byte for byte", () => {
    for (const [kind, compositors] of Object.entries(expected))
        for (const [compositor, spec] of Object.entries(compositors))
            assert.deepEqual(plain(resolve.includeSpec(kind, compositor)), spec, `${kind} on ${compositor}`);
});

test("includeSpec returns null off the table", () => {
    assert.equal(resolve.includeSpec("input", "hyprland"), null, "input exists for niri only");
    assert.equal(resolve.includeSpec("input", "mango"), null, "input exists for niri only");
    assert.equal(resolve.includeSpec("colors", "niri"), null, "unknown kind");
    assert.equal(resolve.includeSpec("outputs", "sway"), null, "unknown compositor");
    assert.equal(resolve.includeSpec("outputs", ""), null, "empty compositor");
});

test("binds on hyprland carries dms.binds before dms.binds-user", () => {
    const spec = resolve.includeSpec("binds", "hyprland");
    assert.deepEqual(plain(spec.fragmentNames), ["binds.lua", "binds-user.lua"]);
    assert.deepEqual(plain(spec.includes.map(include => include.includeLine)), ['require("dms.binds")', 'require("dms.binds-user")']);
});

test("includePaths joins the compositor directory, with hypr for hyprland", () => {
    const niri = resolve.includePaths("outputs", "niri", "/home/u/.config");
    assert.equal(niri.configFile, "/home/u/.config/niri/config.kdl");
    assert.deepEqual(plain(niri.fragmentFiles), ["/home/u/.config/niri/dms/outputs.kdl"]);
    assert.deepEqual(plain(niri.includes), [{ grepPattern: 'include.*"dms/outputs.kdl"', includeLine: 'include "dms/outputs.kdl"' }]);
    const hyprland = resolve.includePaths("layout", "hyprland", "/home/u/.config");
    assert.equal(hyprland.configFile, "/home/u/.config/hypr/hyprland.lua");
    assert.deepEqual(plain(hyprland.fragmentFiles), ["/home/u/.config/hypr/dms/layout.lua"]);
    const mango = resolve.includePaths("cursor", "mango", "/home/u/.config");
    assert.equal(mango.configFile, "/home/u/.config/mango/config.conf");
    assert.deepEqual(plain(mango.fragmentFiles), ["/home/u/.config/mango/dms/cursor.conf"]);
    const binds = resolve.includePaths("binds", "hyprland", "/home/u/.config");
    assert.deepEqual(plain(binds.fragmentFiles), ["/home/u/.config/hypr/dms/binds.lua", "/home/u/.config/hypr/dms/binds-user.lua"]);
    assert.equal(resolve.includePaths("input", "hyprland", "/home/u/.config"), null, "no spec, no paths");
});

test("resolveIncludeArgs spells mango as mangowc and names the fragment", () => {
    assert.deepEqual(plain(resolve.resolveIncludeArgs("outputs", "niri")), ["niri", "outputs.kdl"]);
    assert.deepEqual(plain(resolve.resolveIncludeArgs("layout", "hyprland")), ["hyprland", "layout.lua"]);
    assert.deepEqual(plain(resolve.resolveIncludeArgs("windowrules", "mango")), ["mangowc", "windowrules.conf"]);
    assert.equal(resolve.resolveIncludeArgs("input", "mango"), null, "no spec, no args");
});

test("repairScriptFor niri outputs backs up, creates the fragment and appends the kdl include", () => {
    const script = resolve.repairScriptFor("outputs", "niri", "/home/u/.config", "/home/u/.config/niri/config.kdl.backup1700000000");
    assert.match(script, /^cp '\/home\/u\/\.config\/niri\/config\.kdl' '\/home\/u\/\.config\/niri\/config\.kdl\.backup1700000000' 2>\/dev\/null \|\| true; /, "backup first");
    assert.ok(script.includes("mkdir -p '/home/u/.config/niri/dms'"), "dms dir");
    assert.ok(script.includes("touch '/home/u/.config/niri/dms/outputs.kdl'"), "fragment touched");
    assert.ok(script.includes("grep -Fqx '// DMS Include Configs'"), "kdl section header");
    assert.ok(script.includes(`grep -q 'include.*"dms/outputs.kdl"'`), "grep pattern");
    assert.ok(script.includes(`printf '%s\\n' 'include "dms/outputs.kdl"' >>`), "include line appended");
    assert.equal(script.includes("mkdir -p '/home/u/.config/niri/dms'; touch"), true, "one mkdir before the touch");
});

test("repairScriptFor hyprland binds touches both fragments and appends both requires", () => {
    const script = resolve.repairScriptFor("binds", "hyprland", "/home/u/.config", "/home/u/.config/hypr/hyprland.lua.dmsbackup1700000000");
    assert.ok(script.includes("touch '/home/u/.config/hypr/dms/binds.lua' '/home/u/.config/hypr/dms/binds-user.lua'"), "both fragments in one touch");
    assert.ok(script.includes("grep -Fqx '-- DMS Include Configs'"), "lua section header");
    const first = script.indexOf(`printf '%s\\n' 'require("dms.binds")' >>`);
    const second = script.indexOf(`printf '%s\\n' 'require("dms.binds-user")' >>`);
    assert.ok(first > 0 && second > first, "dms.binds appended before dms.binds-user");
    assert.ok(script.includes("grep -q 'dms.binds'"), "first grep pattern");
    assert.ok(script.includes("grep -q 'dms.binds-user'"), "second grep pattern");
    assert.ok(script.includes("cp '/home/u/.config/hypr/hyprland.lua' '/home/u/.config/hypr/hyprland.lua.dmsbackup1700000000'"), "keybinds backup name passes through");
});

test("repairScriptFor mango binds keeps the spaced source line under the # header", () => {
    const script = resolve.repairScriptFor("binds", "mango", "/home/u/.config", "/home/u/.config/mango/config.conf.dmsbackup1700000000");
    assert.ok(script.includes("grep -Fqx '# DMS Include Configs'"), "conf section header");
    assert.ok(script.includes("grep -q 'source.*dms/binds.conf'"), "grep pattern");
    assert.ok(script.includes(`printf '%s\\n' 'source = ./dms/binds.conf' >>`), "spaced include line");
    assert.equal(script.includes("source=./dms/binds.conf"), false, "no unspaced variant");
    const layout = resolve.repairScriptFor("layout", "mango", "/home/u/.config", "");
    assert.ok(layout.includes(`'source=./dms/layout.conf' >>`), "other mango lines stay unspaced");
    assert.equal(layout.startsWith("mkdir -p"), true, "no backup command without a backup file");
});

test("repairScriptFor returns an empty script off the table", () => {
    assert.equal(resolve.repairScriptFor("input", "hyprland", "/home/u/.config", "/x"), "");
    assert.equal(resolve.repairScriptFor("nope", "niri", "/home/u/.config", "/x"), "");
});

test("buildRepairScript skips comment-only matches before grepping the pattern", () => {
    const script = resolve.buildRepairScript({
        configFile: "/c/config.kdl",
        fragmentFile: "/c/dms/x.kdl",
        grepPattern: 'include.*"dms/x.kdl"',
        includeLine: 'include "dms/x.kdl"'
    });
    assert.ok(script.includes(`if ! grep -v '^[[:space:]]*\\(//\\|#\\|--\\)' '/c/config.kdl' 2>/dev/null | grep -q 'include.*"dms/x.kdl"'; then`), "comment filter precedes the pattern grep");
    assert.ok(script.includes("grep -q 'include.*dms/'"), "managed include pattern groups with earlier dms includes");
    assert.ok(script.includes(`elif [ -s '/c/config.kdl' ]; then printf '\\n%s\\n%s\\n' '// DMS Include Configs' 'include "dms/x.kdl"' >>`), "non-empty config gets a blank line before the header");
    assert.equal(script.startsWith("cp "), false, "no backup without backupFile");
});
