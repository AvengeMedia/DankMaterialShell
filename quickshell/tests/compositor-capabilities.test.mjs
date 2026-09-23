import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const COMPOSITORS = ["niri", "hyprland", "mango", "sway", "scroll", "miracle", "labwc", "aqueous"];
const IDENTITY = { niri: "isNiri", hyprland: "isHyprland", mango: "isMango", sway: "isSway", scroll: "isScroll", miracle: "isMiracle", labwc: "isLabwc", aqueous: "isAqueous", umbriel: "isUmbriel" };

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

test("persistent workspaces cover compositors that open a missing workspace on demand", () => {
    expectSet("supportsPersistentWorkspaces", ["hyprland", "mango", "sway", "scroll", "miracle"]);
});

test("native overview is niri and aqueous, pointer is niri and mango, input is niri", () => {
    expectSet("supportsNativeOverview", ["niri", "aqueous"]);
    expectSet("supportsPointerConfig", ["niri", "mango"]);
    expectSet("supportsInputConfig", ["niri"]);
});

test("every compositor is known and an undetected one is not", () => {
    expectSet("isKnownCompositor", COMPOSITORS);
});

test("configKey is the lowercase key and empty when undetected", () => {
    for (const compositor of COMPOSITORS)
        assert.equal(evaluate("configKey", compositor), compositor);
    assert.equal(evaluate("configKey", undefined), "");
});
