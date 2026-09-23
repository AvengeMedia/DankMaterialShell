import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

function functions(source, indent, context) {
    const pattern = new RegExp(`^${indent}function (\\w+)\\(([^)]*)\\)(?:: \\w+)? \\{([\\s\\S]*?)^${indent}\\}`, "gm");
    for (const [, name, parameters, body] of source.matchAll(pattern)) {
        const args = parameters.replace(/:\s*\w+/g, "");
        vm.runInContext(`function ${name}(${args}) {${body}}`, context);
    }
    return context;
}

const settingsSource = readFileSync(new URL("../Common/SettingsData.qml", import.meta.url), "utf8");
const islandSource = readFileSync(new URL("../Modules/DankIsland/DankIsland.qml", import.meta.url), "utf8");

test("shared shortcuts follow the last eligible surface independently on each screen", () => {
    const screens = [{ name: "internal" }, { name: "external" }];
    const dot = { id: "dot", dot: true, islandSharedRouting: "last-used" };
    const island = { id: "island", island: true };
    const configs = { internal: [dot, island], external: [dot, island] };
    const settings = functions(settingsSource, "    ", vm.createContext({ lastUsedBarByScreen: {} }));
    settings.activeIslandConfigsForScreen = screen => configs[screen.name];
    settings.getActiveBarEdgesForScreen = () => ["top"];
    settings.islandSetting = (config, key) => config[key];

    assert.equal(settings.sharedTriggerIslandConfig(screens[0]), null);
    settings.recordBarInteraction(screens[0], "dot");
    assert.equal(settings.sharedTriggerIslandConfig(screens[0]), dot);
    assert.equal(settings.sharedTriggerIslandConfig(screens[1]), null);
    settings.recordBarInteraction(screens[1], "island");
    assert.equal(settings.sharedTriggerIslandConfig(screens[1]), island);
    settings.recordBarInteraction(screens[0], "standard");
    assert.equal(settings.sharedTriggerIslandConfig(screens[0]), null);
    assert.equal(settings.sharedTriggerIslandConfig(screens[1]), island);

    settings.recordBarInteraction(screens[0], "dot");
    configs.internal = [island];
    assert.equal(settings.sharedTriggerIslandConfig(screens[0]), null, "disabled/removed dots cannot retain routing");
    configs.internal = [dot, island];
    dot.islandSharedRouting = "always";
    settings.recordBarInteraction(screens[0], "standard");
    assert.equal(settings.sharedTriggerIslandConfig(screens[0]), dot, "fixed routing still wins");
    dot.islandSharedRouting = "normal";
    assert.equal(settings.sharedTriggerIslandConfig(screens[0]), null);
    settings.getActiveBarEdgesForScreen = () => [];
    assert.equal(settings.sharedTriggerIslandConfig(screens[0]), island, "sole-island fallback is preserved");
    configs.internal = [dot];
    assert.equal(settings.sharedTriggerIslandConfig(screens[0]), dot, "a dot alone on the screen takes the shortcuts");
    configs.internal = [dot, island];
    settings.getActiveBarEdgesForScreen = () => ["top"];
    island.islandSharedRouting = "last-used";
    settings.recordBarInteraction(screens[0], "dot");
    assert.equal(settings.sharedTriggerIslandConfig(screens[0]), dot, "a free island can enable last-used routing for all surfaces");
    island.islandSharedRouting = "always";
    assert.equal(settings.sharedTriggerIslandConfig(screens[0]), island, "always-here also supports islands");
    dot.islandSharedRouting = "last-used";
    settings.recordBarInteraction(screens[0], "standard");
    assert.equal(settings.sharedTriggerIslandConfig(screens[0]), null, "last-used takes precedence over a fixed instance");
});

test("always-here is exclusive among islands and dots sharing a screen", () => {
    const screens = [{ name: "internal" }, { name: "external" }];
    const covers = { dot: ["internal", "external"], island: ["internal"], remote: ["external"] };
    const settings = functions(settingsSource, "    ", vm.createContext({
        Quickshell: { screens },
        barConfigs: [{ id: "dot", dot: true, islandSharedRouting: "always" }, { id: "island", island: true }, { id: "remote", island: true, islandSharedRouting: "always" }]
    }));
    settings.updateBarConfigs = () => {};
    settings.barConfigCoversScreen = (cfg, screen) => covers[cfg.id].includes(screen.name);
    settings.setIslandSharedRouting("island", "always");
    assert.deepEqual([...settings.barConfigs].map(cfg => cfg.islandSharedRouting), [undefined, "always", "always"], "same-screen always is reset, other-screen always is kept");
    settings.setIslandSharedRouting("island", "last-used");
    assert.deepEqual([...settings.barConfigs].map(cfg => cfg.islandSharedRouting), [undefined, "last-used", "always"]);
});

test("dot IPC has island command parity and preserves monitor and instance addressing", () => {
    const handlers = {};
    for (const kind of ["island", "dot"]) {
        const source = islandSource.split(`target: "${kind}"`)[1].split("\n    IpcHandler {")[0];
        const root = Object.fromEntries(["Open", "Toggle", "Show", "Close", "Cycle", "Status", "Move", "Center"].map(name => [`ipc${name}`, (...args) => args]));
        handlers[kind] = functions(source, "        ", vm.createContext({ root }));
    }
    const names = handler => Object.keys(handler).filter(key => key !== "root").sort();
    assert.deepEqual(names(handlers.dot), names(handlers.island));
    assert.deepEqual(handlers.island.notifications(), ["notificationcenter", "", "", "island"]);
    for (const name of ["openOn", "toggleOn", "showOn"])
        assert.deepEqual(handlers.dot[name]("weather", "external"), ["weather", "external", "", "dot"]);
    for (const name of ["closeOn", "cycleOn", "statusOn"])
        assert.deepEqual(handlers.dot[name]("external"), ["external", "", "dot"]);
    assert.deepEqual(handlers.dot.notificationsOn("external"), ["notificationcenter", "external", "", "dot"]);
    for (const name of ["openInstance", "toggleInstance"])
        assert.deepEqual(handlers.dot[name]("launcher", "external", "second-dot"), ["launcher", "external", "second-dot", "dot"]);
});


test("shared launcher entry points bypass a previously loaded launcher and forward query/mode", () => {
    const calls = [];
    let fallbacks = 0;
    let overridden = true;
    const screen = { name: "external" };
    const source = readFileSync(new URL("../Services/PopoutService.qml", import.meta.url), "utf8");
    const service = functions(source, "    ", vm.createContext({
        CompositorService: { getFocusedScreen: () => screen },
        SettingsData: { sharedShortcutsOverridden: () => overridden },
        dankIslandRouter: {
            openLauncher: (...args) => { calls.push(["open", ...args]); return true; },
            toggleLauncher: (...args) => { calls.push(["toggle", ...args]); return true; }
        },
        dankLauncherV2Modal: { show: () => fallbacks++, hide() {}, toggle: () => fallbacks++ }
    }));
    service._sharedTriggerIsland = () => ({ screen, barId: "clicked-dot" });
    service._setDankLauncherV2TriggerUsesOverlayLayer = () => {};
    service._setDankLauncherV2EdgeHoverManaged = () => {};
    for (const [method, argument, action, query, mode] of [
        ["openDankLauncherV2", undefined, "open", "", ""],
        ["toggleDankLauncherV2", undefined, "toggle", "", ""],
        ["openDankLauncherV2WithQuery", "firefox", "open", "firefox", ""],
        ["toggleDankLauncherV2WithQuery", "firefox", "toggle", "firefox", ""],
        ["openDankLauncherV2WithMode", "files", "open", "", "files"],
        ["toggleDankLauncherV2WithMode", "files", "toggle", "", "files"]
    ]) {
        service[method](argument);
        assert.deepEqual(calls.at(-1), [action, query, mode, screen, "clicked-dot"]);
    }
    assert.equal(fallbacks, 0);
    overridden = false;
    service.openDankLauncherV2();
    assert.equal(fallbacks, 1, "normal routing preserves the configured launcher");
});
