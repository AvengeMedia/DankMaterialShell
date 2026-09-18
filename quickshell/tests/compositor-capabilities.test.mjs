import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const COMPOSITORS = ["niri", "hyprland", "mango", "sway", "scroll", "miracle", "labwc", "aqueous"];
const IDENTITY = { niri: "isNiri", hyprland: "isHyprland", mango: "isMango", sway: "isSway", scroll: "isScroll", miracle: "isMiracle", labwc: "isLabwc", aqueous: "isAqueous" };

const service = readFileSync(new URL("../Services/CompositorService.qml", import.meta.url), "utf8");

function declarations(source) {
    const found = new Map();
    const re = /^    readonly property (bool|string) (isKnownCompositor|supports[A-Z]\w*|displayName|configKey):\s*/gm;
    let match;
    while ((match = re.exec(source)) !== null) {
        const name = match[2];
        const start = re.lastIndex;
        let end = start;
        if (source[start] === "{") {
            let depth = 0;
            for (let i = start; i < source.length; i++) {
                if (source[i] === "{")
                    depth++;
                if (source[i] === "}")
                    depth--;
                if (depth === 0) {
                    end = i + 1;
                    break;
                }
            }
        } else {
            end = source.indexOf("\n", start);
        }
        if (found.has(name))
            found.get(name).push(source.slice(start, end));
        else
            found.set(name, [source.slice(start, end)]);
    }
    return found;
}

const DECLS = declarations(service);

function run(name, scope) {
    const body = DECLS.get(name)[0];
    const expression = body.startsWith("{") ? `(() => ${body})()` : `(${body})`;
    return vm.runInNewContext(expression, scope);
}

function evaluate(name, compositor) {
    const scope = { compositor: compositor ?? "unknown" };
    for (const [key, flag] of Object.entries(IDENTITY))
        scope[flag] = key === compositor;
    if (name === "configKey")
        return run(name, scope);
    scope.configKey = run("configKey", scope);
    if (name === "isKnownCompositor")
        return run(name, scope);
    scope.isKnownCompositor = run("isKnownCompositor", scope);
    return run(name, scope);
}

function setOf(name) {
    return COMPOSITORS.filter(c => evaluate(name, c) === true);
}

function expectSet(name, expected) {
    assert.deepEqual(setOf(name), expected, name);
    assert.equal(evaluate(name, undefined), false, `${name} on an undetected compositor`);
}

test("every capability is declared exactly once", () => {
    const duplicated = [...DECLS].filter(([, bodies]) => bodies.length > 1).map(([name]) => name);
    assert.deepEqual(duplicated, []);
});

test("window rules, layout, cursor and bar auto hide cover niri, hyprland and mango", () => {
    expectSet("supportsWindowRules", ["niri", "hyprland", "mango"]);
    expectSet("supportsLayoutConfig", ["niri", "hyprland", "mango"]);
    expectSet("supportsCursorConfig", ["niri", "hyprland", "mango"]);
    expectSet("supportsBarAutoHideReveal", ["niri", "hyprland", "mango"]);
});

test("display config, workspaces and smart dock add aqueous", () => {
    expectSet("supportsDisplayConfig", ["niri", "hyprland", "mango", "aqueous"]);
    expectSet("supportsWorkspaces", ["niri", "hyprland", "mango", "aqueous"]);
    expectSet("supportsSmartDock", ["niri", "hyprland", "mango", "aqueous"]);
});

test("workspace urgency and follow focus cover every compositor but labwc", () => {
    expectSet("supportsWorkspaceUrgency", ["niri", "hyprland", "mango", "sway", "scroll", "miracle", "aqueous"]);
    expectSet("supportsWorkspaceFollowFocus", ["niri", "hyprland", "mango", "sway", "scroll", "miracle", "aqueous"]);
});

test("native overview is niri and aqueous, pointer is niri and mango, input is niri", () => {
    expectSet("supportsNativeOverview", ["niri", "aqueous"]);
    expectSet("supportsPointerConfig", ["niri", "mango"]);
    expectSet("supportsInputConfig", ["niri"]);
});

test("every compositor is known and an undetected one is not", () => {
    expectSet("isKnownCompositor", COMPOSITORS);
});

test("displayName is the product spelling and empty when undetected", () => {
    const expected = { niri: "Niri", hyprland: "Hyprland", mango: "MangoWC", sway: "Sway", scroll: "Scroll", miracle: "Miracle WM", labwc: "Labwc", aqueous: "Aqueous" };
    for (const compositor of COMPOSITORS)
        assert.equal(evaluate("displayName", compositor), expected[compositor], compositor);
    assert.equal(evaluate("displayName", undefined), "");
});

test("configKey is the lowercase key and empty when undetected", () => {
    for (const compositor of COMPOSITORS)
        assert.equal(evaluate("configKey", compositor), compositor);
    assert.equal(evaluate("configKey", undefined), "");
});

const CONVERTED = [
    ["Common/SettingsTabs.qml", "supportsWindowRules", "isNiri || isHyprland || isMango"],
    ["Common/SettingsTabs.qml", "supportsLayoutConfig", "isNiri || isHyprland || isMango"],
    ["Common/SettingsTabs.qml", "supportsInputConfig", "isNiri"],
    ["Common/SettingsTabs.qml", "supportsPointerConfig", "isNiri || isMango"],
    ["Modules/Settings/WindowRulesTab.qml", "supportsWindowRules", "isNiri || isHyprland || isMango"],
    ["Modules/DankBar/Widgets/FocusedWindowContextMenu.qml", "supportsWindowRules", "isNiri || isHyprland || isMango"],
    ["Modules/Settings/DankBarTab.qml", "supportsBarAutoHideReveal", "isNiri || isHyprland || isMango"],
    ["Modules/Settings/DankBarTab.qml", "supportsNativeOverview", "isNiri || isAqueous"],
    ["Modules/Settings/DockGeneralTab.qml", "supportsSmartDock", "isNiri || isHyprland || isMango || isAqueous"],
    ["Modules/Settings/FrameTab.qml", "supportsNativeOverview", "isNiri || isAqueous"],
    ["Modules/Settings/WallpaperColorsTab.qml", "supportsCursorConfig", "isNiri || isHyprland || isMango"],
    ["Modules/Settings/WorkspaceAppearanceCard.qml", "supportsWorkspaces", "isNiri || isHyprland || isMango || isAqueous"],
    ["Modules/Settings/WorkspaceAppearanceCard.qml", "supportsWorkspaceUrgency", "isNiri || isHyprland || isMango || isAqueous || isSway || isScroll || isMiracle"],
    ["Modules/Settings/BarWidgetOptions/WorkspaceSwitcherOptions.qml", "supportsWorkspaces", "isNiri || isHyprland || isMango || isAqueous"],
    ["Modules/Settings/BarWidgetOptions/WorkspaceSwitcherOptions.qml", "supportsWorkspaceFollowFocus", "isNiri || isHyprland || isMango || isAqueous || isSway || isScroll || isMiracle"],
    ["Modules/Settings/KeyboardTab.qml", "supportsInputConfig", "isNiri"],
    ["Modules/Settings/MouseTouchpadTab.qml", "supportsInputConfig", "isNiri"],
    ["Modules/Settings/ThemeSurfacesTab.qml", "supportsLayoutConfig", "isNiri || isHyprland || isMango"],
    ["Common/Theme.qml", "supportsLayoutConfig", "isNiri || isHyprland || isMango"],
    ["Services/SettingsSearchService.qml", "supportsPointerConfig", "isNiri || isMango"],
    ["Services/SettingsSearchService.qml", "supportsNativeOverview", "isNiri || isAqueous"],
    ["Services/SettingsSearchService.qml", "supportsSmartDock", "isNiri || isHyprland || isMango || isAqueous"],
    ["Services/SettingsSearchService.qml", "supportsWorkspaceFollowFocus", "isNiri || isHyprland || isMango || isSway || isScroll || isMiracle || isAqueous"],
    ["Services/SettingsSearchService.qml", "supportsWindowRules", "isNiri || isHyprland || isMango"],
    ["Services/SettingsSearchService.qml", "supportsLayoutConfig", "isNiri || isHyprland || isMango"]
];

test("each converted site keeps the truth table its old expression had", () => {
    for (const [file, capability, old] of CONVERTED) {
        for (const compositor of COMPOSITORS) {
            const scope = {};
            for (const [key, flag] of Object.entries(IDENTITY))
                scope[flag] = key === compositor;
            const before = vm.runInNewContext(`(${old})`, scope);
            assert.equal(evaluate(capability, compositor), before, `${file} ${capability} on ${compositor}`);
        }
    }
});

test("the display config greeter check gains aqueous and nothing else", () => {
    const old = "isNiri || isHyprland || isMango";
    const disagree = COMPOSITORS.filter(compositor => {
        const scope = {};
        for (const [key, flag] of Object.entries(IDENTITY))
            scope[flag] = key === compositor;
        return evaluate("supportsDisplayConfig", compositor) !== vm.runInNewContext(`(${old})`, scope);
    });
    assert.deepEqual(disagree, ["aqueous"]);
});

const BACKENDS = ["Services/NiriService.qml", "Services/HyprlandService.qml", "Services/MangoService.qml", "Services/CompositorService.qml"];
const KNOWN_SET_CHAINS = [
    ["DMSShellIPC.qml", "the i3 ipc compositors, no capability name yet"],
    ["Services/BarWidgetService.qml", "focusedScreenDetectionSupported gates aqueous on a runtime probe"],
    ["Services/KeybindsService.qml", "keybind provider availability, a different question from the workspace set"],
    ["Services/SessionService.qml", "the i3 ipc compositors, no capability name yet"]
];

function sourceFiles(dir) {
    const out = [];
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
        const full = `${dir}/${entry.name}`;
        if (entry.isDirectory()) {
            if (entry.name !== "tests")
                out.push(...sourceFiles(full));
            continue;
        }
        if (entry.name.endsWith(".qml") || entry.name.endsWith(".js"))
            out.push(full);
    }
    return out;
}

test("no file outside the backends rebuilds a compositor set by hand", () => {
    const root = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
    const chain = /CompositorService\.is[A-Z]\w*(?:\s*\|\|\s*(?:CompositorService\.)?is[A-Z]\w*){2,}/;
    const offenders = sourceFiles(root)
        .map(path => path.slice(root.length + 1))
        .filter(rel => !BACKENDS.includes(rel))
        .filter(rel => chain.test(readFileSync(`${root}/${rel}`, "utf8")))
        .sort();
    assert.deepEqual(offenders, KNOWN_SET_CHAINS.map(([file]) => file).sort());
});

function identityReads(source) {
    return [...source.matchAll(/CompositorService\.(is[A-Z]\w*)/g)].map(match => match[1]);
}

test("no file reads an identity flag CompositorService does not declare", () => {
    const root = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
    const declared = new Set([...service.matchAll(/^\s*(?:readonly\s+)?property\s+\w+\s+(\w+)\s*:/gm)].map(m => m[1]));
    const functions = new Set([...service.matchAll(/^\s*function\s+(\w+)/gm)].map(m => m[1]));
    const undeclared = [];
    for (const path of sourceFiles(root)) {
        for (const name of identityReads(readFileSync(path, "utf8"))) {
            if (declared.has(name) || functions.has(name))
                continue;
            undeclared.push(`${path.slice(root.length + 1)}: ${name}`);
        }
    }
    assert.deepEqual([...new Set(undeclared)], []);
});
