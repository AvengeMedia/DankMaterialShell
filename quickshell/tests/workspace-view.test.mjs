import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import vm from "node:vm";

function methods(context, path, names) {
    const source = readFileSync(new URL(path, import.meta.url), "utf8");
    for (const name of names) {
        const start = source.indexOf("    function " + name + "(");
        assert.notEqual(start, -1, name);
        const end = source.indexOf("\n    }", start) + 6;
        vm.runInContext(source.slice(start, end), context);
    }
}
function property(context, name, prefix = "    property var ", indent = "    ") {
    const source = readFileSync(new URL("../Modules/DankBar/Widgets/WorkspaceSwitcher.qml", import.meta.url), "utf8");
    const token = prefix + name + ": {";
    const start = source.indexOf(token);
    assert.notEqual(start, -1, name);
    const end = source.indexOf("\n" + indent + "}", start);
    return vm.runInContext("(function(){" + source.slice(start + token.length, end) + "})()", context);
}
const context = vm.createContext({workspaceBackend: "ext", workspaceViewGeneration: 1, WindowManager: {windowsets: []}, Quickshell: {screens: [{name: "DP-1"}, {name: "DP-2"}]}});
context.root = context;
methods(context, "../Services/CompositorService.qml", ["selectWorkspaceBackend", "extWorkspaceRows", "workspaceViewForOutput"]);
for (const [inputs, expected] of [
    [["aqueous", true, true, true, true], "ext"],
    [["aqueous", true, true, false, true], "none"],
    [["aqueous", true, false, true, true], "aqueous"],
    [["aqueous", true, false, true, false], "ext"],
    [["aqueous", true, false, false, false], "none"],
    [["unknown", false, false, true, true], "none"],
    [["unknown", false, true, true, false], "ext"],
    [["labwc", true, false, true, false], "ext"],
]) assert.equal(context.selectWorkspaceBackend(...inputs), expected);
for (const backend of ["niri", "hyprland", "mango", "sway", "scroll", "miracle"]) {
    assert.equal(context.selectWorkspaceBackend(backend, true, false, true, false), "legacy");
    assert.equal(context.selectWorkspaceBackend(backend, true, true, true, false), "ext");
    assert.equal(context.selectWorkspaceBackend(backend, true, true, false, false), "legacy");
}
let activations = 0;
const handle = {id: "", name: "same", active: true, urgent: false, canActivate: true, shouldDisplay: true, coordinates: [1], activate() {activations++;}};
const second = {...handle, coordinates: [0]};
context.WindowManager.windowsets = [handle, second];
let rows = context.extWorkspaceRows([handle, second], 1);
assert.equal(rows[0].key, second);
assert.equal(rows[1].key, handle);
assert.notEqual(rows[0].key, rows[1].key, "duplicate names were used as identity");
assert.equal(rows[0].windows, null);
handle.name = "renamed"; handle.urgent = true;
let updated = context.extWorkspaceRows([handle], 1)[0];
assert.equal(updated.key, handle);
assert.equal(updated.urgent, true);
assert.equal(updated.name, "renamed");
rows[1].activate(); assert.equal(activations, 1);
handle.canActivate = false; rows[1].activate(); assert.equal(activations, 1);
handle.canActivate = true;
context.WindowManager.windowsets = [second]; rows[1].activate(); assert.equal(activations, 1);
context.WindowManager.windowsets = [handle];
context.workspaceViewGeneration = 2; rows[1].activate(); assert.equal(activations, 1);
context.WindowManager.screenProjection = screen => ({windowsets: screen.name === "DP-1" ? [handle] : []});
assert.equal(context.workspaceViewForOutput("DP-2").rows.length, 0, "empty output switched backend");
assert.equal(context.workspaceViewForOutput("removed").rows.length, 0);

const actions = [];
const aq = vm.createContext({available: true, capabilities: {commands: true}, locked: false, seat: {id: "seat0"}, session: "session-a", CompositorService: {workspaceBackend: "aqueous", workspaceViewGeneration: 1},
    workspaces: [{id: "w", name: "same", number: 1, output: "o1", active: true, urgent: false}],
    outputs: [{id: "o1", name: "DP-1"}], focusedOutput: "DP-1", command: (...args) => actions.push(args)});
aq.root = aq;
methods(aq, "../Services/AqueousService.qml", ["taskbarEligible", "workspaceRowsForOutput", "workspacesForOutput", "outputId", "windowFacade"]);
aq.seat = {id: "seat0", window: "window-a"};
aq.Quickshell = {screens: [{name: "DP-1"}]};
const window = {id: "window-a", workspace: "w", output: "o1", app_id: "demo", visible: true, can_activate: true};
aq.toplevels = [aq.windowFacade(window)];
rows = aq.workspaceRowsForOutput("DP-1", 1);
assert.equal(rows[0].key, "session-a:workspace:w");
assert.equal(rows[0].windows[0].key, "session-a:window:window-a");
rows[0].activate(); assert.equal(actions[0][1].session, "session-a");
aq.session = "session-b";
rows[0].windows[0].activate(); assert.equal(actions[1][1].session, "session-a", "cached icon adopted a new session");
aq.CompositorService.workspaceViewGeneration = 2;
rows[0].activate(); rows[0].windows[0].activate(); assert.equal(actions.length, 2, "cached action survived backend change");
aq.locked = true;
assert.equal(aq.workspaceRowsForOutput("DP-1", 2)[0].canActivate, false);
aq.locked = false; aq.seat = null;
assert.equal(aq.workspaceRowsForOutput("DP-1", 2)[0].canActivate, false);
aq.seat = {id: "seat0"}; aq.capabilities.commands = false;
assert.equal(aq.workspaceRowsForOutput("DP-1", 2)[0].canActivate, false);
assert(aq.taskbarEligible({...window, minimized: true, visible: false}));
assert(!aq.taskbarEligible({...window, skip_taskbar: true}));
assert(!aq.taskbarEligible({...window, visible: false}));
aq.workspaces[0].active = false;
assert(aq.taskbarEligible({...window, visible: false}));

const settings = {showWorkspacePadding: true, showOccupiedWorkspacesOnly: false, showWorkspaceApps: true, groupWorkspaceApps: false, groupActiveWorkspaceApps: false, showWorkspaceName: true, showWorkspaceIndex: true};
const widget = vm.createContext({usesWorkspaceView: true, workspaceView: {rows: []}, _placeholderPool: [], SettingsData: settings, CompositorService: {},
    DesktopEntries: {heuristicLookup: id => ({id})}, Paths: {moddedAppId: id => id, isSteamApp: () => false, getAppIcon: id => id, getAppName: id => id}, _desktopEntriesUpdateTrigger: 0});
widget.root = widget;
methods(widget, "../Modules/DankBar/Widgets/WorkspaceSwitcher.qml", ["padWorkspaces", "_makePlaceholder", "getRealWorkspaces", "switchToWorkspaceByModelData", "switchWorkspace", "getWorkspaceIcons", "getWorkspaceIndex", "getWorkspaceIndexFallback"]);
let clicked = [];
const windowFacade = (key, appId) => ({key, id: key, appId, activate: () => clicked.push(key)});
const first = {key: "one", name: "1", number: 1, active: true, windows: [windowFacade("a", "demo"), windowFacade("b", "demo")], canActivate: true, activate: () => clicked.push("one")};
const other = {key: "two", name: "1", number: 2, active: false, windows: [], canActivate: true, activate: () => clicked.push("two")};
widget.workspaceView.rows = [first, other];
widget.workspaceList = property(widget, "workspaceList");
assert.equal(widget.workspaceList.length, 3, "Aqueous padding was skipped");
const placeholder = widget.workspaceList[2];
widget.switchToWorkspaceByModelData(placeholder); assert.equal(clicked.length, 0);
widget.currentWorkspace = "one";
widget.switchWorkspace(-1); assert.equal(clicked.length, 0);
widget.switchWorkspace(1); assert.deepEqual(clicked, ["two"]);
widget.currentWorkspace = "two"; widget.switchWorkspace(1); assert.equal(clicked.length, 1);
widget.currentWorkspace = null; widget.switchWorkspace(-1); assert.equal(clicked.at(-1), "one");
assert.equal(widget.getWorkspaceIndex(other, 1), "2: 1");
assert.equal(widget.getWorkspaceIndex(placeholder, 2), 3);
let icons = widget.getWorkspaceIcons(first);
assert.equal(icons.length, 2);
Object.assign(widget, {workspaceIcons: icons, isPlaceholder: false});
assert.equal(property(widget, "stableIconCount", "                readonly property int ", "                "), icons.length, "icon count disagrees with renderer");
icons[0].windowAction(); assert.equal(clicked.at(-1), "a");
settings.groupWorkspaceApps = true; settings.groupActiveWorkspaceApps = true;
icons = widget.getWorkspaceIcons(first); assert.equal(icons.length, 1); assert.equal(icons[0].count, 2);
assert.equal(widget.getWorkspaceIcons({...first, windows: null}).length, 0, "ext membership was guessed");
settings.showOccupiedWorkspacesOnly = true;
widget.workspaceView.rows = [first, other, {...other, key: "unknown", windows: null}];
assert.equal(property(widget, "workspaceList").filter(row => !row.placeholder).length, 2, "unknown occupancy was treated as empty");
settings.showWorkspacePadding = false;
assert.equal(property(widget, "workspaceList").length, 2);
widget.workspaceView.rows = [];
assert.equal(property(widget, "workspaceList").length, 0, "empty output fabricated a workspace");
console.log("PASS: workspace selection, identities, stale actions, padding, navigation, icons and legacy backend selection");
