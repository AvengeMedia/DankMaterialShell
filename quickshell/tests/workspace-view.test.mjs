import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import vm from "node:vm";

const source = readFileSync(new URL("../Modules/DankBar/Widgets/WorkspaceSwitcher.qml", import.meta.url), "utf8");
function methods(context, text, names, indent = "    ") {
    for (const name of names) {
        const start = text.indexOf(indent + "function " + name + "(");
        assert.notEqual(start, -1, name);
        const end = text.indexOf("\n" + indent + "}", start) + indent.length + 2;
        vm.runInContext(text.slice(start, end), context);
    }
}
function property(context, name, type = "property var", indent = "    ") {
    const token = indent + type + " " + name + ": ";
    const start = source.indexOf(token) + token.length;
    assert(start >= token.length, name);
    if (source[start] !== "{")
        return vm.runInContext(source.slice(start, source.indexOf("\n", start)), context);
    const end = source.indexOf("\n" + indent + "}", start);
    return vm.runInContext("(function()" + source.slice(start, end) + "})()", context);
}
const settings = {showWorkspacePadding: true, showOccupiedWorkspacesOnly: false, showWorkspaceApps: true,
    groupWorkspaceApps: false, groupActiveWorkspaceApps: false, showWorkspaceName: true, showWorkspaceIndex: true};
let forced = "0";
const aq = {available: true, toplevels: []};
const compositor = {compositor: "aqueous", compositorDetected: true, isAqueous: true};
const widget = vm.createContext({AqueousService: aq, CompositorService: compositor, SettingsData: settings,
    Quickshell: {env: () => forced}, WindowManager: {windowsets: [{}]}, _placeholderPool: [], effectiveScreenName: "DP-1",
    DesktopEntries: {heuristicLookup: id => ({id})}, Paths: {moddedAppId: id => id, isSteamApp: () => false, getAppIcon: id => id, getAppName: id => id}, _desktopEntriesUpdateTrigger: 0});
widget.root = widget;
methods(widget, source, ["padWorkspaces", "_makePlaceholder", "getRealWorkspaces", "switchToWorkspaceByModelData", "switchWorkspace", "getWorkspaceIcons", "getWorkspaceIndex", "getWorkspaceIndexFallback", "getExtWorkspaceActiveWorkspace"]);
for (const [name, force, available, expectedAq, expectedExt] of [
    ["aqueous", "0", true, true, false], ["aqueous", "1", true, false, true],
    ["aqueous", "0", false, false, true], ["labwc", "0", false, false, true],
    ...["niri", "hyprland", "mango", "sway", "scroll", "miracle"].flatMap(n => [[n, "0", false, false, false], [n, "1", false, false, true]])
]) {
    Object.assign(compositor, {compositor: name, isAqueous: name === "aqueous"});
    forced = force; aq.available = available;
    widget.useAqueous = property(widget, "useAqueous", "readonly property bool");
    widget.useExtWorkspace = property(widget, "useExtWorkspace", "readonly property bool");
    assert.equal(widget.useAqueous, expectedAq, name);
    assert.equal(widget.useExtWorkspace, expectedExt, name);
}
Object.assign(compositor, {compositor: "aqueous", isAqueous: true});
Object.assign(widget, {useAqueous: true, useExtWorkspace: false});
let clicked = [];
const first = {id: "one", aqueousSession: "session-a", name: "1", number: 1, active: true};
const other = {id: "two", aqueousSession: "session-a", name: "1", number: 2, active: false};
aq.workspacesForOutput = () => [first, other];
aq.activateWorkspace = w => clicked.push(w);
aq.toplevels = ["a", "b"].map(id => ({id, aqueousKey: "session-a:window:" + id, aqueousSession: "session-a", aqueousWorkspaceId: "one", appId: "demo"}));
compositor.sortedToplevels = aq.toplevels;
widget.workspaceList = property(widget, "workspaceList");
assert.equal(widget.workspaceList.length, 3);
const placeholder = widget.workspaceList[2];
widget.switchToWorkspaceByModelData(placeholder); assert.equal(clicked.length, 0);
widget.currentWorkspace = "one";
widget.switchWorkspace(-1); assert.equal(clicked.length, 0);
widget.switchWorkspace(1); assert.equal(clicked[0], other);
widget.currentWorkspace = "two"; widget.switchWorkspace(1); assert.equal(clicked.length, 1);
assert.equal(widget.getWorkspaceIndex(other, 1), "2: 1");
assert.equal(widget.getWorkspaceIndex(placeholder, 2), 3);
let icons = widget.getWorkspaceIcons(first);
assert.equal(icons.length, 2);
assert.equal(icons[0].windowSession, "session-a");
Object.assign(widget, {modelData: first, isPlaceholder: false, loadedIcons: icons});
assert.equal(property(widget, "stableIconCount", "readonly property int", "                "), icons.length);
settings.groupWorkspaceApps = true; settings.groupActiveWorkspaceApps = true;
assert.equal(widget.getWorkspaceIcons(first).length, 1);
settings.showOccupiedWorkspacesOnly = true;
assert.equal(property(widget, "workspaceList").length, 3);
settings.showWorkspacePadding = false;
assert.equal(property(widget, "workspaceList").length, 1);
aq.workspacesForOutput = () => [];
assert.equal(property(widget, "workspaceList").length, 0);

// Native handles remain authoritative even with missing IDs and duplicate names.
Object.assign(widget, {useAqueous: false, useExtWorkspace: true});
const handles = [0, 1].map(i => ({id: "", name: "Duplicate", active: i === 0, activate: () => clicked.push(i)}));
widget.extProjection = {windowsets: handles}; widget.workspaceList = handles;
widget.currentWorkspace = widget.getExtWorkspaceActiveWorkspace();
assert.equal(widget.currentWorkspace, handles[0]);
widget.switchWorkspace(1); assert.equal(clicked.at(-1), 1);
assert.equal(widget.getWorkspaceIcons(handles[0]).length, 0);

// Rendered icons carry their old session into the command validator after restart.
Object.assign(widget, {useAqueous: true, useExtWorkspace: false, appIconsLoader: {item: {iconsLayout: {
    mapFromItem: () => ({x: 0, y: 0}), childAt: () => ({windowId: icons[0].windowId, windowSession: icons[0].windowSession})
}}}, mouseArea: {}});
widget.delegateRoot = widget;
methods(widget, source, ["windowIdAt", "focusWindowAt"], "                ");
aq.command = (action, fields) => clicked.push({action, fields});
assert(widget.focusWindowAt(0, 0));
assert.equal(clicked.at(-1).fields.session, "session-a");
const service = vm.createContext({available: true, session: "session-b", seat: {id: "seat0"}, command: null});
service.root = service;
const serviceSource = readFileSync(new URL("../Services/AqueousService.qml", import.meta.url), "utf8");
methods(service, serviceSource, ["activateWorkspace", "commandArguments"]);
service.command = (action, fields) => assert.throws(() => service.commandArguments(action, fields), /stale session/);
service.activateWorkspace(first);
assert.throws(() => service.commandArguments(clicked.at(-1).action, clicked.at(-1).fields), /stale session/);
process.stdout.write("PASS: existing backend selection, Aqueous padding/icons, native handle identity and captured sessions\n");
