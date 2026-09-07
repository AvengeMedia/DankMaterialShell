import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import vm from "node:vm";

const read = path => readFileSync(new URL(path, import.meta.url), "utf8");
function methods(context, source, names) {
    for (const name of names) {
        const start = source.indexOf("    function " + name + "(");
        assert.notEqual(start, -1);
        vm.runInContext(source.slice(start, source.indexOf("\n    }", start) + 6), context);
    }
}
const settings = read("../Modules/Settings/WorkspacesTab.qml");
function setting(context, key, property) {
    const start = settings.indexOf('settingKey: "' + key + '"');
    const row = settings.slice(start, settings.indexOf("onToggled:", start));
    const expression = row.match(new RegExp(property + ": ([^\\n]+)"))?.[1];
    return expression ? vm.runInContext(expression, context) : true;
}
const compositor = {};
let forced = false;
const conditions = vm.createContext({CompositorService: compositor, AqueousService: {available: true}, Quickshell: {env: () => forced ? "1" : "0"}});
const search = read("../Services/SettingsSearchService.qml");
const conditionStart = search.indexOf("readonly property var conditionMap: (") + "readonly property var conditionMap: ".length;
const conditionMap = vm.runInContext(search.slice(conditionStart, search.indexOf("})", conditionStart) + 2), conditions);
const index = JSON.parse(read("../translations/settings_search_index.json"));
for (const backend of ["Aqueous", "Niri", "Hyprland", "Mango", "Sway", "Scroll", "Miracle", "Labwc"]) {
    for (const key of Object.keys(compositor)) delete compositor[key];
    compositor["is" + backend] = true;
    for (const key of ["showWorkspaceApps", "showOccupiedWorkspacesOnly", "reverseScrolling", "workspaceFollowFocus"]) {
        const visible = setting(conditions, key, "visible");
        const expected = ["Aqueous", "Niri", "Hyprland", "Mango", ...(key === "workspaceFollowFocus" ? ["Sway", "Scroll", "Miracle"] : [])].includes(backend);
        assert.equal(!!visible, expected, backend + ": " + key);
        assert.equal(!!conditionMap[index.find(e => e.section === key).conditionKey](), expected, "search disagrees with settings");
    }
}
for (const key of Object.keys(compositor)) delete compositor[key];
compositor.isAqueous = true;
for (const [available, force, expected] of [[true, false, true], [true, true, false], [false, false, false]]) {
    conditions.AqueousService.available = available; forced = force;
    for (const key of ["showWorkspaceApps", "showOccupiedWorkspacesOnly"])
        assert.equal(setting(conditions, key, "enabled"), expected);
    assert.equal(setting(conditions, "workspaceFollowFocus", "enabled"), true);
    assert.equal(setting(conditions, "reverseScrolling", "enabled"), true);
}
const appearance = read("../Modules/Settings/WorkspaceAppearanceCard.qml");
assert.equal(vm.runInContext(appearance.match(/workspaceStateColorsVisible: ([^\n]+)/)[1], conditions), true);

const service = vm.createContext({available: true, locked: false, session: "session-a", capabilities: {commands: true},
    seat: {id: "seat0", output: "output-a"}, outputs: [], workspaces: [
        {kind: "workspace", id: "one", output: "output-a", active: true, name: "Duplicate", aqueousSession: "session-a"},
        {kind: "workspace", id: "two", output: "output-b", active: true, name: "Duplicate", aqueousSession: "session-a"}
    ]});
service.entities = service.workspaces; service.seats = [service.seat];
methods(service, read("../Services/AqueousService.qml"), ["commandPayload", "byteLength"]);
const callbacks = [], commands = [], errors = [], legacy = [];
service.command = (action, fields, callback) => {
    try { commands.push(service.commandPayload(action, fields)); callbacks.push(callback); }
    catch (error) { errors.push(String(error)); callback(false); }
};
const modal = vm.createContext({CompositorService: {isAqueous: true}, AqueousService: service,
    aqueousWorkspace: null, renaming: false, nameInput: {text: "", forceActiveFocus() {}},
    Qt: {callLater: fn => fn()}, I18n: {tr: text => text}, ToastService: {showError: (...args) => errors.push(args)},
    NiriService: {renameWorkspace: name => legacy.push(name)}, HyprlandService: {renameWorkspace: name => legacy.push(name)}});
modal.root = modal;
const modalSource = read("../Modals/WorkspaceRenameModal.qml");
methods(modal, modalSource, ["show", "hide", "submitAndClose", "renameWorkspace"]);
const visibleStart = modalSource.indexOf("    onVisibleChanged: {") + "    onVisibleChanged: ".length;
vm.runInContext("function visibilityChanged() " + modalSource.slice(visibleStart, modalSource.indexOf("\n    }", visibleStart) + 6), modal);
let visible = false;
Object.defineProperty(modal, "visible", {get: () => visible, set: value => { visible = value; modal.visibilityChanged(); }});
assert(modal.show("ignored"));
assert.equal(modal.nameInput.text, "Duplicate");
assert.equal(modal.aqueousWorkspace.id, "one");
service.seat.output = "output-b";
modal.nameInput.text = "日本語 🫧";
modal.submitAndClose(); modal.submitAndClose();
assert.equal(commands.length, 1, "double submission");
assert.deepEqual(JSON.parse(JSON.stringify(commands[0])), {action: "workspace.rename", fields: {id: "one", name: "日本語 🫧"}});
assert(modal.visible && modal.renaming, "closed before command result");
callbacks.shift()(false);
assert(modal.visible && !modal.renaming);
assert.equal(modal.nameInput.text, "日本語 🫧", "failure discarded the draft");
modal.submitAndClose(); callbacks.shift()(true);
assert(!modal.visible && !modal.aqueousWorkspace);

for (const mutate of [() => service.locked = true, () => service.session = "session-b", () => service.entities = [], () => service.capabilities.commands = false, () => service.available = false]) {
    Object.assign(service, {available: true, locked: false, session: "session-a", entities: service.workspaces, capabilities: {commands: true}});
    assert(modal.show("")); modal.nameInput.text = "Retained draft";
    mutate(); const previous = commands.length; modal.submitAndClose();
    assert.equal(commands.length, previous);
    assert(modal.visible && !modal.renaming);
    assert.equal(modal.nameInput.text, "Retained draft");
    modal.hide();
}
Object.assign(service, {available: true, locked: false, session: "session-a", entities: service.workspaces, capabilities: {commands: true}});
for (const name of ["bad\nname", "🫧".repeat(257)]) {
    assert(modal.show("")); modal.nameInput.text = name; modal.submitAndClose();
    assert(modal.visible && !modal.renaming); modal.hide();
}
assert(modal.show("")); modal.nameInput.text = "Old dialog"; modal.submitAndClose();
modal.hide(); assert(modal.show(""));
callbacks.shift()(true);
assert(modal.visible, "late result closed a newly opened dialog"); modal.hide();
service.seat = null; assert.equal(modal.show(""), false); assert(!modal.visible);
modal.CompositorService = {isNiri: true}; assert(modal.show("Niri")); modal.submitAndClose();
modal.CompositorService = {isHyprland: true}; assert(modal.show("Hyprland")); modal.submitAndClose();
assert.deepEqual(legacy, ["Niri", "Hyprland"]);
process.stdout.write("PASS: workspace settings/search, forced-ext controls, captured rename target, failures and existing compositor dispatch\n");
