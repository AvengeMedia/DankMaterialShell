import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";
import { loadScript } from "./qml-script.mjs";

function functionSource(file, name) {
    const source = readFileSync(new URL(file, import.meta.url), "utf8");
    const found = source.match(new RegExp(`^    function ${name}\\([^)]*\\)(?:: \\w+)? \\{\\n[\\s\\S]*?^    \\}`, "m"));
    if (!found)
        throw new Error(`${name} not found in ${file}`);
    return found[0];
}

test("the lock IPC switch drops the lock demo keybind action and keeps the others", () => {
    const getDmsActions = functionSource("../Services/KeybindsService.qml", "getDmsActions");
    const Actions = loadScript(new URL("../Common/KeybindActions.js", import.meta.url));
    for (const disableLockIpcUnlock of [false, true]) {
        const context = vm.createContext({ Actions, CompositorService: { isNiri: false, isHyprland: false }, AdminPolicy: { disableLockIpcUnlock } });
        vm.runInContext(getDmsActions, context);
        const ids = context.getDmsActions().map(action => action.id);
        assert.equal(ids.includes("spawn dms ipc call lock demo"), !disableLockIpcUnlock);
        assert.ok(ids.includes("spawn dms ipc call lock lock"));
        assert.equal(ids.length, Actions.getDmsActions(false, false).length - (disableLockIpcUnlock ? 1 : 0));
    }
});

test("the user plugin switch keeps the user tree out of a scan and a resync", () => {
    const user = "/home/user/.config/DankMaterialShell/plugins";
    const system = "/etc/xdg/quickshell/dms-plugins";
    const folder = dirs => ({ folder: "", count: dirs.length, get: (i, role) => role === "filePath" ? "file://" + dirs[i] : 0 });
    for (const disableUserPlugins of [false, true]) {
        const loaded = [];
        const context = vm.createContext({
            Date,
            AdminPolicy: { disableUserPlugins },
            Paths: { toFileUrl: path => "file://" + path },
            pluginDirectory: user,
            systemPluginDirectory: system,
            userWatcher: folder([user + "/probe"]),
            systemWatcher: folder([system + "/admitted"]),
            resyncDebounce: { restart() {} },
            checkPluginDirectoryExists() {},
            knownManifests: {},
            pathToPluginId: {},
            directoryModifiedTimes: {},
            loadPluginManifestFile: (path, source) => loaded.push([path, source])
        });
        context.root = context;
        for (const name of ["snapshotModel", "resyncAll", "scanPlugins"])
            vm.runInContext(functionSource("../Services/PluginService.qml", name), context);
        context.scanPlugins();
        assert.equal(context.userWatcher.folder, disableUserPlugins ? "" : "file://" + user);
        assert.equal(context.systemWatcher.folder, "file://" + system);
        context.resyncAll();
        const userManifests = disableUserPlugins ? [] : [[user + "/probe/plugin.json", "user"]];
        assert.deepEqual(loaded, [...userManifests, [system + "/admitted/plugin.json", "system"]]);
    }
});
