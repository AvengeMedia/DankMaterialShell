import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("../Services/SessionService.qml", import.meta.url), "utf8");
const logout = source.match(/^ {4}function _logout\(\) \{\n[\s\S]*?^ {4}\}$/m)[0];

function logoutOn(compositor) {
    const calls = [];
    const flags = ["isAqueous", "isNiri", "isMango", "isLabwc", "isUmbriel", "isSway", "isScroll", "isMiracle", "isHyprland"];
    const CompositorService = Object.fromEntries(flags.map(flag => [flag, flag === compositor]));
    const context = vm.createContext({
        CompositorService,
        SettingsData: { customPowerActionLogout: "" },
        HyprlandService: { exit: () => calls.push("hyprland exit") },
        DMSService: { sendRequest: method => calls.push(method) },
        log: { warn() {} }
    });
    vm.runInContext(logout.replace(/^ {4}/gm, ""), context);
    context._logout();
    return calls;
}

test("logout ends the logind session on compositors without a quit request", () => {
    assert.deepEqual(logoutOn(null), ["loginctl.terminate"]);
});

test("hyprland still quits through its own dispatcher", () => {
    assert.deepEqual(logoutOn("isHyprland"), ["hyprland exit"]);
});
