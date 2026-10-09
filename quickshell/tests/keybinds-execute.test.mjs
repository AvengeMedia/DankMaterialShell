import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../Services/KeybindsService.qml", import.meta.url), "utf8");

function extract(name) {
    const found = source.match(new RegExp(`^    function ${name}\\([^)]*\\) \\{\\n[\\s\\S]*?^    \\}`, "m"));
    if (!found)
        throw new Error(`${name} not found in KeybindsService.qml`);
    return found[0];
}

const calls = [];
const scope = vm.createContext({
    currentProvider: "hyprland",
    cheatsheetProvider: "",
    log: { info() {} },
    HyprlandService: { luaConfigActive: true },
    Quickshell: { execDetached: argv => calls.push(Array.from(argv)) },
    MangoService: { dispatch() {} }
});
vm.runInContext(extract("executeAction") + "\n" + extract("canExecuteAction"), scope);

test("hyprland runs the Lua dispatch as one argv entry and refuses legacy text without it", () => {
    scope.HyprlandService.luaConfigActive = true;
    const lua = 'hl.dsp.focus({ direction = "l" })';
    calls.length = 0;
    assert.equal(scope.executeAction("movefocus l", lua), true);
    assert.deepEqual(calls, [["hyprctl", "dispatch", lua]]);
    for (const args of [["movefocus l", ""], ["movefocus l"]]) {
        calls.length = 0;
        assert.equal(scope.executeAction(...args), false, args.join(" | "));
        assert.deepEqual(calls, []);
    }
});

test("hyprland on a conf config dispatches the legacy text", () => {
    scope.HyprlandService.luaConfigActive = false;
    for (const args of [["movefocus l", ""], ["movefocus l"]]) {
        calls.length = 0;
        assert.equal(scope.executeAction(...args), true, args.join(" | "));
        assert.deepEqual(calls, [["sh", "-c", "hyprctl dispatch movefocus l"]]);
    }
});

test("hyprland rows without a Lua action run only on a conf config", () => {
    const cases = [
        [true, "movefocus l", 'hl.dsp.focus({ direction = "l" })', true],
        [true, "movefocus l", "", false],
        [false, "movefocus l", "", true],
        [false, "movewindow", "", false],
        [false, "exit", "", false]
    ];
    for (const [lua, action, luaAction, expected] of cases) {
        scope.HyprlandService.luaConfigActive = lua;
        assert.equal(scope.canExecuteAction(action, luaAction), expected, `${lua} ${action}`);
    }
});
