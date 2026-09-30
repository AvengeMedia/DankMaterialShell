import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("../Modules/Dock/DockAppButton.qml", import.meta.url), "utf8");
const helpers = source.slice(source.indexOf("    function getToplevelObject("), source.indexOf("    function activate("));
const click = source.slice(source.indexOf("        function handleLeftClick("), source.indexOf("        onPositionChanged:"));

test("left click cycles grouped windows and wraps, including from overview", () => {
    for (const initialFocus of ["none", "active", "overview"]) {
        const windows = [{ activated: false }, { activated: initialFocus === "active" }, { activated: false }];
        const activated = [];
        let overviewFocused = initialFocus === "overview" ? windows[1] : null;
        const context = vm.createContext({
            appData: { type: "grouped", windowCount: windows.length, allWindows: windows.map(toplevel => ({ toplevel })) },
            options: { restoreSpecialWorkspaceOnClick: false },
            contextMenu: { showForButton() { assert.fail("left click opened the context menu"); } },
            height: 0,
            cachedDesktopEntry: null,
            parentDockScreen: null,
            dockApps: null,
            CompositorService: {
                overviewFocusedToplevel: () => overviewFocused,
                activateToplevel(toplevel) {
                    activated.push(windows.indexOf(toplevel));
                    windows.forEach(window => { window.activated = window === toplevel; });
                    overviewFocused = null;
                },
            },
        });
        context.root = context;
        vm.runInContext(helpers + click, context);
        for (let i = 0; i < 4; i++)
            context.handleLeftClick();
        assert.deepEqual(activated, initialFocus === "none" ? [0, 1, 2, 0] : [2, 0, 1, 2], initialFocus);
    }
});
