import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const model = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/WorkspaceModel.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), model);
const fixture = name => JSON.parse(readFileSync(new URL(`fixtures/workspaces/${name}.json`, import.meta.url), "utf8"));
const plain = value => JSON.parse(JSON.stringify(value));
const pick = (records, key) => Array.from(records, record => record[key]);

function niri(scenario) {
    const s = fixture("niri")[scenario];
    const focused = s.allWorkspaces.findIndex(ws => ws.id === s.focusedWorkspaceId);
    return {
        allWorkspaces: s.allWorkspaces,
        currentOutputWorkspaces: s.currentOutput ? s.allWorkspaces.filter(ws => ws.output === s.currentOutput) : s.allWorkspaces,
        focusedIdx: focused >= 0 ? s.allWorkspaces[focused].idx : 1,
        windows: s.windows
    };
}

function hyprland(scenario) {
    const s = fixture("hyprland")[scenario];
    const monitors = s.monitors.map(monitor => ({ name: monitor.name }));
    const monitor = name => monitors.find(m => m.name === name) ?? { name };
    const workspaces = s.workspaces.map(ws => ({ id: ws.id, name: ws.name, monitor: monitor(ws.monitor), lastIpcObject: { monitor: ws.ipcMonitor }, active: ws.active, urgent: ws.urgent }));
    const workspace = id => workspaces.find(ws => ws.id === id) ?? null;
    monitors.forEach((m, i) => m.activeWorkspace = workspace(s.monitors[i].activeWorkspaceId));
    const toplevels = s.toplevels.map(tl => ({ workspace: workspace(tl.workspace), wayland: tl.wayland ? { address: tl.address } : null }));
    return { workspaces, monitors, focusedWorkspace: workspace(s.focusedWorkspaceId), toplevels, windows: toplevels.filter(tl => tl.wayland).map(tl => tl.wayland) };
}

function i3(scenario) {
    const s = fixture("i3")[scenario];
    const monitors = {};
    return { workspaces: s.workspaces.map(ws => ({ ...ws, number: ws.num, monitor: monitors[ws.monitor] ??= { name: ws.monitor } })), windows: s.windows };
}

function mango(scenario, screenName) {
    const s = fixture("mango")[scenario];
    const output = s.outputs[screenName];
    return { available: s.available, tagCount: s.tagCount, output: output ? { tags: output.tags } : null, visibleTags: output?.visibleTags ?? [], activeTags: output?.activeTags ?? [], windows: s.windows };
}

function aqueous(screenName, focusedOutput) {
    const s = fixture("aqueous");
    const focused = focusedOutput ?? s.focusedOutput;
    return { workspaces: s.workspacesByOutput[screenName || focused] ?? [], toplevels: s.toplevels };
}

test("placeholder and neighbor stepping", () => {
    assert.deepEqual(plain(model.placeholder()), { id: null, idx: null, name: "", output: "", active: false, placeholder: true });
    const list = ["a", "b", "c"];
    assert.equal(model.neighbor(list, 0, 1), "b");
    assert.equal(model.neighbor(list, 1, -1), "a");
    assert.equal(model.neighbor(list, 0, -1), null);
    assert.equal(model.neighbor(list, 2, 1), null);
});

test("niri workspaces follow the bar screen, focus and occupied filter", () => {
    const raw = niri("twoScreens");
    const screen = model.niriWorkspacesForScreen(raw, "HDMI-A-1", false, false, {});
    assert.deepEqual(pick(screen, "id"), [5, 6, 7]);
    assert.deepEqual(pick(screen, "idx"), [1, 2, 3]);
    assert.deepEqual(pick(screen, "active"), [true, false, false]);
    assert.deepEqual(pick(screen, "output"), ["HDMI-A-1", "HDMI-A-1", "HDMI-A-1"]);
    assert.deepEqual(pick(model.niriWorkspacesForScreen(raw, "HDMI-A-1", false, true, {}), "id"), [5, 6]);
    const followed = model.niriWorkspacesForScreen(raw, "HDMI-A-1", true, false, {});
    assert.deepEqual(pick(followed, "id"), [1, 2]);
    assert.deepEqual(pick(followed, "name"), ["", "web"]);
    assert.deepEqual(pick(model.niriWorkspacesForScreen(raw, "", false, false, {}), "id"), [1, 2]);
    assert.deepEqual(pick(model.niriWorkspacesForScreen(raw, "DP-9", false, true, {}), "id"), [2]);
    assert.equal(model.niriCurrentIdx(raw, "HDMI-A-1", false), 1);
    assert.equal(model.niriCurrentIdx(raw, "HDMI-A-1", true), 2);
    assert.equal(model.niriCurrentIdx(raw, "", false), 2);
    assert.equal(model.niriCurrentIdx(raw, "DP-9", false), 1);
});

test("niri empty backend keeps both placeholder workspaces, unfiltered", () => {
    const raw = niri("empty");
    for (const occupiedOnly of [false, true]) {
        const list = model.niriWorkspacesForScreen(raw, "HDMI-A-1", false, occupiedOnly, {});
        assert.deepEqual(plain(list), [
            { id: 1, idx: 0, name: "", output: "", active: false, placeholder: false },
            { id: 2, idx: 1, name: "", output: "", active: false, placeholder: false }
        ]);
    }
    assert.equal(model.niriCurrentIdx(raw, "HDMI-A-1", true), 1);
    assert.equal(model.niriActiveWorkspace(raw, "DP-1"), null);
});

test("niri records keep identity until a field changes and drop closed workspaces", () => {
    const raw = niri("twoScreens");
    const cache = {};
    const first = model.niriWorkspacesForScreen(raw, "HDMI-A-1", false, false, cache);
    const second = model.niriWorkspacesForScreen(raw, "HDMI-A-1", false, true, cache);
    assert.equal(second[0], first[0]);
    assert.equal(second[1], first[1]);
    raw.allWorkspaces = raw.allWorkspaces.map(ws => ({ ...ws }));
    assert.equal(model.niriWorkspacesForScreen(raw, "HDMI-A-1", false, false, cache)[1], first[1]);
    raw.allWorkspaces = raw.allWorkspaces.map(ws => ws.id === 6 ? { ...ws, is_active: true } : ws);
    const changed = model.niriWorkspacesForScreen(raw, "HDMI-A-1", false, false, cache);
    assert.equal(changed[0], first[0]);
    assert.notEqual(changed[1], first[1]);
    assert.equal(changed[1].active, true);
    raw.allWorkspaces = raw.allWorkspaces.filter(ws => ws.id !== 6);
    model.niriWorkspacesForScreen(raw, "HDMI-A-1", false, false, cache);
    assert.deepEqual(Object.keys(cache).includes("6"), false);
});

test("niri active workspace, windows, occupancy and urgency", () => {
    const raw = niri("twoScreens");
    assert.deepEqual(plain(model.niriActiveWorkspace(raw, "HDMI-A-1")), { id: 5, idx: 1, name: "", output: "HDMI-A-1", active: true, placeholder: false });
    assert.equal(model.niriActiveWorkspace(raw, "DP-1").name, "web");
    assert.equal(model.niriActiveWorkspace(raw, "").id, 5);
    assert.deepEqual(pick(model.niriWindowsOnWorkspace(raw.windows, { id: 6 }), "id"), [11, 12]);
    assert.deepEqual(plain(model.niriWindowsOnWorkspace(raw.windows, { id: 7 })), []);
    assert.equal(model.niriWorkspaceOccupied(raw.windows, { id: 6 }), true);
    assert.equal(model.niriWorkspaceOccupied(raw.windows, { id: 7 }), false);
    assert.equal(model.niriWorkspaceUrgent(raw.windows, { id: 6 }), true);
    assert.equal(model.niriWorkspaceUrgent(raw.windows, { id: 2 }), false);
    assert.equal(model.niriWorkspaceActive(raw.allWorkspaces, { id: 5 }), true);
    assert.equal(model.niriWorkspaceActive(raw.allWorkspaces, { id: 6 }), false);
});

test("hyprland lists skip special workspaces and fall back per monitor", () => {
    const raw = hyprland("twoScreens");
    const screen = model.hyprlandWorkspacesForScreen(raw, "HDMI-A-1", false, false);
    assert.deepEqual(pick(screen, "id"), [2, 4, -1337]);
    assert.deepEqual(pick(screen, "idx"), [2, 4, null]);
    assert.deepEqual(pick(screen, "name"), ["2", "4", "chat"]);
    assert.deepEqual(pick(screen, "urgent"), [true, false, false]);
    assert.deepEqual(pick(model.hyprlandWorkspacesForScreen(raw, "HDMI-A-1", false, true), "id"), [2, 4]);
    assert.deepEqual(pick(model.hyprlandWorkspacesForScreen(raw, "HDMI-A-1", true, false), "id"), [1, 2, 3, 4, -1337]);
    assert.deepEqual(pick(model.hyprlandWorkspacesForScreen(hyprland("staleMonitor"), "DP-2", false, false), "id"), [5]);
    assert.deepEqual(pick(model.hyprlandWorkspacesForScreen(hyprland("onlySpecial"), "DP-1", false, false), "name"), ["1"]);
    assert.deepEqual(pick(model.hyprlandWorkspacesForScreen(hyprland("empty"), "DP-1", false, true), "id"), [1]);
    assert.equal(model.hyprlandCurrentId(raw, "HDMI-A-1", false), 2);
    assert.equal(model.hyprlandCurrentId(raw, "HDMI-A-1", true), 3);
    assert.equal(model.hyprlandCurrentId(hyprland("empty"), "DP-1", false), 1);
});

test("hyprland scroll targets use ipc monitors, numbered ids and ignore follow focus for current", () => {
    const raw = hyprland("twoScreens");
    assert.deepEqual(pick(model.hyprlandScrollWorkspaces(raw, "HDMI-A-1", false), "id"), [2, 4]);
    assert.deepEqual(pick(model.hyprlandScrollWorkspaces(raw, "HDMI-A-1", true), "id"), [1, 2, 3, 4]);
    assert.deepEqual(pick(model.hyprlandScrollWorkspaces(hyprland("staleMonitor"), "DP-2", false), "id"), [5]);
    assert.deepEqual(pick(model.hyprlandScrollWorkspaces(hyprland("empty"), "DP-1", false), "id"), [1]);
    assert.equal(model.hyprlandScrollCurrentId(raw, "HDMI-A-1"), 2);
    assert.equal(model.hyprlandScrollCurrentId(raw, ""), 1);
});

test("hyprland active workspace, windows and occupancy", () => {
    const raw = hyprland("twoScreens");
    assert.deepEqual(plain(model.hyprlandActiveWorkspace(raw, "HDMI-A-1")), { id: 2, idx: 2, name: "", output: "HDMI-A-1", active: true, placeholder: false });
    assert.equal(model.hyprlandActiveWorkspace(raw, "").id, 3);
    assert.equal(model.hyprlandActiveWorkspace(hyprland("specialActive"), "DP-1"), null);
    assert.deepEqual(plain(model.hyprlandActiveWorkspace(hyprland("namedActive"), "HDMI-A-1")), { id: -1337, idx: null, name: "chat", output: "HDMI-A-1", active: true, placeholder: false });
    assert.equal(model.hyprlandActiveWorkspace(hyprland("empty"), "DP-1"), null);
    assert.deepEqual(pick(model.hyprlandWindowsOnWorkspace(raw.windows, { id: 3 }, raw.toplevels), "address"), ["0xa"]);
    assert.deepEqual(plain(model.hyprlandWindowsOnWorkspace(raw.windows, { id: 1 }, raw.toplevels)), []);
    assert.equal(model.hyprlandWorkspaceOccupied(raw.toplevels, { id: 1 }), true);
    assert.equal(model.hyprlandWorkspaceOccupied(raw.toplevels, { id: 2 }), false);
});

test("mango tags come from the output state, visible or all", () => {
    const dp1 = mango("available", "DP-1");
    const visible = model.mangoWorkspacesForScreen(dp1, "DP-1", false);
    assert.deepEqual(pick(visible, "id"), [1, 2, 3]);
    assert.deepEqual(pick(visible, "idx"), [2, 3, 4]);
    assert.deepEqual(pick(visible, "active"), [false, true, false]);
    assert.deepEqual(pick(visible, "urgent"), [false, false, true]);
    assert.deepEqual(pick(visible, "occupied"), [true, true, true]);
    assert.deepEqual(pick(model.mangoWorkspacesForScreen(dp1, "DP-1", true), "id"), [0, 1, 2, 3, 4]);
    assert.deepEqual(pick(model.mangoWorkspacesForScreen(mango("available", "HDMI-A-1"), "HDMI-A-1", false), "active"), [true, true, false]);
    assert.deepEqual(plain(model.mangoWorkspacesForScreen(mango("available", "DP-2"), "DP-2", false)), []);
    assert.deepEqual(plain(model.mangoWorkspacesForScreen(mango("unavailable", "DP-1"), "DP-1", true)), []);
    assert.equal(model.mangoCurrentTag(dp1), 2);
    assert.equal(model.mangoCurrentTag(mango("available", "DP-2")), -1);
    assert.equal(model.mangoCurrentTag(mango("unavailable", "DP-1")), -1);
});

test("mango scroll targets, active tag and windows", () => {
    const dp1 = mango("available", "DP-1");
    assert.deepEqual(pick(model.mangoScrollWorkspaces(dp1, "DP-1", false), "id"), [1, 2, 3]);
    assert.deepEqual(pick(model.mangoScrollWorkspaces(dp1, "DP-1", true), "id"), [0, 1, 2, 3, 4]);
    assert.deepEqual(pick(model.mangoScrollWorkspaces(dp1, "DP-1", false), "active"), [false, true, false]);
    assert.deepEqual(plain(model.mangoScrollWorkspaces(mango("unavailable", "DP-1"), "DP-1", true)), [{ id: 0, idx: 1, name: "", output: "DP-1", active: true, placeholder: false }]);
    assert.equal(model.mangoScrollCurrentTag(mango("available", "DP-2")), 0);
    assert.equal(model.mangoScrollCurrentTag(mango("available", "DP-9")), 0);
    assert.deepEqual(plain(model.mangoActiveWorkspace(dp1, "DP-1")), { id: 2, idx: 3, name: "", output: "DP-1", active: true, placeholder: false });
    assert.equal(model.mangoActiveWorkspace(mango("available", "HDMI-A-1"), "HDMI-A-1").id, 0);
    assert.equal(model.mangoActiveWorkspace(mango("available", "DP-2"), "DP-2"), null);
    assert.deepEqual(pick(model.mangoWindowsOnWorkspace(dp1.windows, { id: 2 }), "appId"), ["alacritty", "firefox"]);
    assert.deepEqual(pick(model.mangoWindowsOnWorkspace(dp1.windows, { id: 1 }), "appId"), ["firefox"]);
});

test("i3 lists order numbered before named and strip the number prefix", () => {
    const raw = i3("twoScreens");
    const screen = model.i3WorkspacesForScreen(raw, "HDMI-A-1", false);
    assert.deepEqual(pick(screen, "id"), [2, "chat", "notes"]);
    assert.deepEqual(pick(screen, "idx"), [2, null, null]);
    assert.deepEqual(pick(screen, "urgent"), [true, false, false]);
    const followed = model.i3WorkspacesForScreen(raw, "HDMI-A-1", true);
    assert.deepEqual(pick(followed, "id"), [1, 2, 3, "chat", "notes"]);
    assert.deepEqual(pick(followed, "name"), ["1", "2", "code", "chat", "notes"]);
    assert.deepEqual(plain(model.i3WorkspacesForScreen(i3("empty"), "DP-1", false)), [{ id: 1, idx: 1, name: "", output: "", active: false, placeholder: false, urgent: false, focused: false }]);
    assert.deepEqual(pick(model.i3WorkspacesForScreen(raw, "DP-9", false), "id"), [1]);
    assert.equal(model.i3CurrentKey(raw, "HDMI-A-1", false), 1);
    assert.equal(model.i3CurrentKey(raw, "HDMI-A-1", true), 3);
    assert.equal(model.i3CurrentKey(raw, "DP-1", false), 3);
    assert.equal(model.i3StripNumber(3, "3:code"), "code");
    assert.equal(model.i3StripNumber(-1, "3:code"), "3:code");
    assert.equal(model.i3StripNumber(-1, undefined), "");
});

test("i3 scroll order, active workspace, focus and windows", () => {
    const raw = i3("twoScreens");
    assert.deepEqual(pick(model.i3ScrollWorkspaces(raw, "HDMI-A-1", false), "id"), ["notes", "chat", 2]);
    assert.deepEqual(pick(model.i3ScrollWorkspaces(raw, "HDMI-A-1", true), "id"), ["notes", "chat", 1, 2, 3]);
    assert.deepEqual(pick(model.i3ScrollWorkspaces(i3("empty"), "DP-1", false), "id"), [1]);
    assert.deepEqual(plain(model.i3ActiveWorkspace(raw, "HDMI-A-1")), { id: 2, idx: 2, name: "2", output: "HDMI-A-1", active: true, placeholder: false });
    assert.deepEqual(plain(model.i3ActiveWorkspace(raw, "DP-1")), { id: 3, idx: 3, name: "code", output: "DP-1", active: true, placeholder: false });
    assert.equal(model.i3ActiveWorkspace(raw, "").id, 3);
    assert.deepEqual(plain(model.i3ActiveWorkspace(i3("namedActive"), "HDMI-A-1")), { id: "notes", idx: null, name: "notes", output: "HDMI-A-1", active: true, placeholder: false });
    assert.equal(model.i3ActiveWorkspace(i3("empty"), "DP-1"), null);
    assert.equal(model.i3WorkspaceFocused(raw, { id: 3 }), true);
    assert.equal(model.i3WorkspaceFocused(raw, { id: 2 }), false);
    assert.deepEqual(pick(model.i3WindowsOnWorkspace(raw.windows, { id: 2 }), "appId"), ["mpv"]);
    assert.deepEqual(pick(model.i3WindowsOnWorkspace(raw.windows, { id: "chat" }), "appId"), ["zathura"]);
    assert.deepEqual(plain(model.i3WindowsOnWorkspace(raw.windows, { id: 1 })), []);
});

test("aqueous workspaces, current id, active record and windows", () => {
    const raw = aqueous("HDMI-A-1");
    const cache = {};
    const list = model.aqueousWorkspacesForScreen(raw, "HDMI-A-1", false, cache);
    assert.deepEqual(pick(list, "id"), ["w3", "w4", "w5"]);
    assert.deepEqual(pick(list, "idx"), [1, 2, 3]);
    assert.deepEqual(pick(list, "active"), [false, true, false]);
    assert.deepEqual(pick(list, "urgent"), [false, true, false]);
    assert.deepEqual(pick(list, "session"), ["s1", "s1", "s1"]);
    assert.equal(model.aqueousWorkspacesForScreen(raw, "HDMI-A-1", true, cache)[0], list[0]);
    assert.deepEqual(pick(model.aqueousWorkspacesForScreen(raw, "HDMI-A-1", true, cache), "id"), ["w3", "w4"]);
    assert.equal(model.aqueousCurrentId(raw), "w4");
    assert.equal(model.aqueousCurrentId(aqueous("DP-2")), "");
    assert.deepEqual(plain(model.aqueousWorkspacesForScreen(aqueous("", ""), "", false, cache)), []);
    assert.equal(model.aqueousActiveWorkspace(raw, "HDMI-A-1").id, "w4");
    assert.equal(model.aqueousActiveWorkspace(aqueous("DP-2"), "DP-2"), null);
    assert.deepEqual(pick(model.aqueousWindowsOnWorkspace(raw.toplevels, { id: "w3" }), "id"), ["t1"]);
    assert.equal(model.aqueousWorkspaceOccupied(raw.toplevels, { id: "w1" }), true);
    assert.equal(model.aqueousWorkspaceOccupied(raw.toplevels, { id: "w5" }), false);
});
