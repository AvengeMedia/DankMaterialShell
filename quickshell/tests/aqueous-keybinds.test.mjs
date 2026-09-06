import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import vm from "node:vm";

const copy = value => JSON.parse(JSON.stringify(value));
const adapter = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/AqueousKeybinds.js", import.meta.url), "utf8"), adapter);
function methods(context, path, names) {
    const source = readFileSync(new URL(path, import.meta.url), "utf8");
    for (const name of names) {
        const start = source.indexOf("    function " + name + "(");
        const end = source.indexOf("\n    }", start) + 6;
        vm.runInContext(source.slice(start, end), context);
    }
}
const snapshot = {
    provider: "aqueous", generation: "before-blur", binds: {
        Compositor: [{key: "Super+Return", action: "spawn_terminal"}, {key: "", action: "close"}],
        Custom: [{key: "Super+Shift+S", action: "spawn old-screenshot", source: "dms"}]
    }
};
const draft = {
    baseline: copy(snapshot), session: "session", operation: "set",
    originalKey: "Super+Shift+S", originalAction: "spawn old-screenshot",
    binding: {keys: [{key: "Super+Shift+S"}], action: "spawn old-screenshot"},
    data: {key: "Super+Shift+S", action: "spawn dms screenshot"}
};
const fresh = {...copy(snapshot), generation: "after-blur"};
assert(adapter.unchanged(snapshot, fresh));
fresh.binds.Custom[0].desc = "Different display label";
assert(adapter.unchanged(snapshot, fresh));
for (const change of [
    s => s.binds.Compositor[0].key = "Super+T",
    s => s.binds.Compositor.pop(),
    s => s.binds.Custom[0].action = "spawn another-command",
    s => s.binds.Custom.push(copy(s.binds.Custom[0])),
    s => s.binds.Compositor.reverse()
]) {
    const changed = copy(fresh);
    change(changed);
    assert(!adapter.unchanged(snapshot, changed));
    assert(adapter.changes(snapshot, changed).length);
}
assert.throws(() => adapter.inventory({...snapshot, generation: ""}), /invalid/);
assert.throws(() => adapter.inventory({...snapshot, binds: {Custom: []}}), /missing/);
assert.throws(() => adapter.inventory({...snapshot, binds: {Custom: [], Compositor: [{action: "x"}]}}), /invalid/);
assert.equal(adapter.issue(draft, fresh, false), "");
assert.equal(adapter.issue({...draft, originalKey: "gone"}, fresh, true), "target_removed");
assert.equal(adapter.issue({...draft, data: {...draft.data, key: "Super+Return"}}, fresh, true), "destination_occupied");
const changed = copy(fresh);
changed.binds.Custom[0].action = "spawn external-command";
assert.equal(adapter.issue(draft, changed, false), "target_changed");
assert.equal(adapter.issue(draft, changed, true), "");
const duplicate = copy(fresh);
duplicate.binds.Custom.push(copy(duplicate.binds.Custom[0]));
assert.equal(adapter.issue(draft, duplicate, true), "ambiguous_target");
assert.equal(adapter.issue({...draft, data: {key: "Super+Q", action: "removed_action"}}, fresh, true), "invalid_action");
assert.deepEqual(copy(adapter.argumentsFor(draft, fresh.generation)), ["dms", "keybinds", "set", "aqueous", "Super+Shift+S", "spawn dms screenshot", "--expected-generation", "after-blur", "--json"]);

function service() {
    const calls = [], results = [], events = [], deferred = [];
    const c = vm.createContext({
        aqueousSession: "session", bindEditSession: "session", requiresBindReview: true, currentProvider: "aqueous", aqueousBusy: false, _aqueousRequest: 0,
        _aqueousLoading: false, _loadPending: false, _pendingSavedKey: "", _rawData: copy(snapshot),
        saving: false, loading: false, lastError: "", removeProcess: {running: false},
        AqueousKeybinds: adapter, I18n: {tr: s => s}, Qt: {callLater: (fn, ...args) => deferred.push(() => fn(...args))},
        AqueousService: {runJson: (args, input, callback) => calls.push({args: copy(args), callback})},
        bindSaveCompleted: ok => events.push(["completed", ok]), bindRemoved: key => events.push(["removed", key]),
        _processData: () => events.push(["loaded"])
    });
    c.root = c;
    methods(c, "../Services/KeybindsService.qml", ["readAqueousBinds", "_mutateAqueous", "loadBinds"]);
    const flush = () => {
        let n = 0;
        while (deferred.length) {
            assert(n++ < 10, "refresh loop");
            deferred.shift()();
        }
    };
    const submit = d => c._mutateAqueous(d || copy(draft), result => results.push(result));
    return {c, calls, results, events, flush, submit};
}
{
    const {c, calls, results, events, submit, flush} = service();
    const edit = copy(draft);
    submit(edit);
    edit.data.action = "spawn modified-after-click";
    assert.equal(c.aqueousBusy, true);
    calls.shift().callback(fresh, "");
    const mutation = calls.shift();
    assert(mutation.args.includes("after-blur"));
    assert(mutation.args.includes("spawn dms screenshot"), "mutation must capture the clicked draft");
    assert.equal(c._pendingSavedKey, "", "no success marker before acknowledgement");
    submit();
    assert.equal(results.pop().code, "busy");
    assert.equal(calls.length, 0);
    mutation.callback({success: true, code: "applied", generation: "saved"}, "");
    assert.equal(results[0].success, true);
    assert.equal(c.aqueousBusy, false);
    assert.equal(c._pendingSavedKey, draft.data.key);
    assert.deepEqual(events, [["completed", true]]);
    flush();
    assert.equal(calls.shift().args[2], "show");
}
for (const external of [changed, duplicate, {...fresh, binds: {...fresh.binds, Custom: []}}]) {
    const {c, calls, results, submit} = service();
    submit();
    calls.shift().callback(external, "");
    assert.equal(results[0].code, "external_change");
    assert.equal(calls.length, 0, "changed inventory must not write");
    assert.equal(c.aqueousBusy, false);
    assert.equal(c._pendingSavedKey, "");
}
for (const operation of ["set", "remove", "reset"]) {
    for (const code of ["external_change", "read_only", "uncertain"]) {
        const {c, calls, results, events, submit, flush} = service();
        submit({...copy(draft), operation});
        calls.shift().callback(fresh, "");
        const response = code === "uncertain" ? null : {success: false, code};
        calls.shift().callback(response, code === "uncertain" ? "timeout" : code);
        flush();
        assert.equal(results[0].code, code);
        assert.equal(calls.length, 0, "failed mutation must not retry");
        assert.equal(events.length, 0, "failed mutation must not report success");
        assert.equal(c._pendingSavedKey, "");
    }
}
{
    const {c, calls, results, submit} = service();
    submit();
    calls.shift().callback(null, "helper unavailable");
    assert.equal(results[0].code, "load_failed");
    assert.equal(calls.length, 0);
    assert.equal(c.aqueousBusy, false);
    submit({...draft, session: "stale"});
    assert.equal(results.at(-1).code, "invalidated");
    assert.equal(calls.length, 0);
}
{
    const {c, calls, results, submit} = service();
    submit();
    c._aqueousRequest++;
    c.aqueousSession = "other-session";
    calls.shift().callback(fresh, "");
    assert.equal(results.length, 0, "late preparation callback must be ignored");
    assert.equal(calls.length, 0);
}
{
    const {c, calls, results, events, submit} = service();
    submit();
    calls.shift().callback(fresh, "");
    c._aqueousRequest++;
    c.aqueousSession = "other-session";
    calls.shift().callback({success: true, generation: "saved"}, "");
    assert.equal(results.length, 0, "late mutation callback must be ignored");
    assert.equal(events.length, 0);
    assert.equal(c._pendingSavedKey, "");
}
{
    const {c, calls, flush} = service();
    c.loadBinds(); c.loadBinds(); c.loadBinds();
    assert.equal(calls.length, 1);
    calls.shift().callback(fresh, ""); flush();
    assert.equal(calls.length, 1, "refresh requests must coalesce into one trailing load");
    calls.shift().callback(fresh, ""); flush();
    assert.equal(calls.length, 0);
    assert.equal(c._aqueousLoading, false);
}

{
    // Execute the production save failure handler and then an unrelated data load.
    const {c, events} = service();
    Object.assign(c, {provider: c.currentProvider, savedKey: "failed-key", exitCode: 1, log: {error() {}}, _maybeWarnHyprlandLegacyConf() {}, _dataVersion: 0,
        bindsLoaded() {}, bindSaved: key => events.push(["saved", key]), _rawData: {}, CompositorService: {isMango: false}});
    const source = readFileSync(new URL("../Services/KeybindsService.qml", import.meta.url), "utf8");
    const start = source.indexOf("        onExited: exitCode => {", source.indexOf("id: saveProcess"));
    const end = source.indexOf("\n        }", start);
    vm.runInContext("(function() {" + source.slice(source.indexOf("{", start) + 1, end) + "})()", c);
    methods(c, "../Services/KeybindsService.qml", ["_processData"]);
    c._processData();
    assert.equal(c._pendingSavedKey, "");
    assert.equal(c.savedKey, "");
    assert(!events.some(event => event[0] === "saved"));
}

{
    const {c, events, calls} = service();
    Object.assign(c, {provider: "hyprland", savedKey: "old-provider-key", exitCode: 0, saving: true});
    const source = readFileSync(new URL("../Services/KeybindsService.qml", import.meta.url), "utf8");
    const start = source.indexOf("        onExited: exitCode => {", source.indexOf("id: saveProcess"));
    const end = source.indexOf("\n        }", start);
    vm.runInContext("(function() {" + source.slice(source.indexOf("{", start) + 1, end) + "})()", c);
    assert.equal(c.saving, false);
    assert.equal(c.savedKey, "");
    assert.equal(c._pendingSavedKey, "");
    assert.equal(events.length, 0, "a previous provider's acknowledgement must not report an Aqueous save");
    assert.equal(calls.length, 0);
}

function editor() {
    const reads = [], writes = [], events = [];
    const {c: svc} = service();
    methods(svc, "../Services/KeybindsService.qml", ["captureBindEdit", "updateBindEdit", "reconcileBindEdit", "bindEditError"]);
    Object.assign(svc, {
        bindMutationBusy: false,
        saveBind: (key, data, d, cb) => writes.push({draft: copy(d), callback: cb}),
        removeBind: (key, d, cb) => writes.push({draft: copy(d), callback: cb}),
        resetBind: (key, d, cb) => writes.push({draft: copy(d), callback: cb}),
        loadBindReview: cb => reads.push(cb), loadBinds: () => events.push("load")
    });
    const c = vm.createContext({editDraft: copy(draft), reviewSnapshot: null, editBusy: false, reviewingEdit: false, editInvalidated: false,
        _editRequest: 0, _editAlive: true, editError: "", I18n: {tr: s => s}, KeybindsService: svc,
        confirmEditRemoval: () => events.push("confirm")});
    Object.defineProperty(c, "hasEditDraft", {get: () => c.editDraft !== null});
    c.keybindsTab = c;
    methods(c, "../Modules/Settings/KeybindsTab.qml", ["beginEdit", "submitEdit", "reloadEdit", "acceptReview", "discardEdit", "updateEditDraft", "prepareRemoval"]);
    return {c, reads, writes, events};
}

{
    const {c, reads, writes} = editor();
    c.submitEdit();
    writes.shift().callback({success: false, code: "external_change", snapshot: changed});
    const retained = copy(c.editDraft.data);
    c.submitEdit(); assert.equal(writes.length, 0, "review must block Save");
    c.reloadEdit(); reads.shift()(changed, "");
    assert.deepEqual(copy(c.editDraft.data), retained);
    c.acceptReview();
    assert.equal(c.reviewingEdit, false);
    assert.equal(c.editDraft.originalAction, "spawn external-command");
    c.submitEdit();
    assert.equal(writes[0].draft.baseline.generation, changed.generation);
    assert.deepEqual(writes[0].draft.data, retained);
}
{
    const {c, events, writes} = editor();
    c.editDraft.operation = "remove";
    c.reviewSnapshot = changed; c.reviewingEdit = true;
    c.acceptReview();
    assert.deepEqual(events, ["confirm"], "reviewed removal must be confirmed again");
    assert.equal(writes.length, 0);
    c.discardEdit();
    assert.equal(c.editDraft, null);
    assert.equal(c.reviewSnapshot, null);
}
for (const current of [duplicate, {...fresh, binds: {...fresh.binds, Custom: []}}]) {
    const {c, writes} = editor();
    c.reviewSnapshot = current; c.reviewingEdit = true;
    c.acceptReview();
    assert.equal(c.reviewingEdit, true);
    assert(c.editError);
    assert.equal(writes.length, 0);
}
for (const provider of ["hyprland", "niri"]) {
    const {c, calls} = service();
    Object.assign(c, {
        currentProvider: provider, readOnly: false, saveProcess: {}, removeProcess: {},
        Actions: {isValidAction: () => true}
    });
    methods(c, "../Services/KeybindsService.qml", ["saveBind", "removeBind", "resetBind"]);
    c.saveBind("Super+S", {key: "Super+P", action: "spawn screenshot", desc: "Screenshot"});
    assert.deepEqual(copy(c.saveProcess.command), ["dms", "keybinds", "set", provider, "Super+P", "spawn screenshot", "--desc", "Screenshot", "--replace-key", "Super+S"]);
    assert.equal(c.saveProcess.running, true);
    c.removeBind("Super+P");
    assert.deepEqual(copy(c.removeProcess.command), ["dms", "keybinds", "remove", provider, "Super+P"]);
    c.resetBind("Super+P");
    assert.deepEqual(copy(c.removeProcess.command), ["dms", "keybinds", "reset", provider, "Super+P"]);
    assert.equal(calls.length, 0, "other providers must retain their existing subprocess flow");
}
for (const provider of ["hyprland", "niri"]) {
    const writes = [];
    const c = vm.createContext({
        editDraft: null, hasEditDraft: false, expandedKey: "", showingNewBind: false,
        KeybindsService: {
            currentProvider: provider, requiresBindReview: false, readOnly: false,
            saveBind: (key, data) => writes.push([key, copy(data)]),
            captureBindEdit: () => assert.fail("ordinary edits must not capture review state")
        }
    });
    c.keybindsTab = c;
    methods(c, "../Modules/Settings/KeybindsTab.qml", ["toggleExpanded", "startNewBind", "cancelNewBind", "saveBind"]);
    c.toggleExpanded("spawn screenshot");
    assert.equal(c.expandedKey, "spawn screenshot");
    c.toggleExpanded("spawn screenshot");
    assert.equal(c.expandedKey, "");
    c.startNewBind();
    assert.equal(c.showingNewBind, true);
    c.cancelNewBind();
    assert.equal(c.showingNewBind, false);
    c.saveBind("Super+S", {key: "Super+P", action: "spawn screenshot"});
    assert.deepEqual(writes, [["Super+S", {key: "Super+P", action: "spawn screenshot"}]]);
    assert.equal(c._editingKey, "Super+P");
    assert.equal(c.expandedKey, "spawn screenshot");
}
{
    const {c} = service();
    methods(c, "../Services/KeybindsService.qml", ["captureBindEdit", "updateBindEdit", "reconcileBindEdit"]);
    const binding = {action: draft.originalAction, keys: [{key: draft.originalKey}]};
    const captured = c.captureBindEdit(binding, draft.originalKey);
    binding.keys[0].key = "changed-after-open";
    c._rawData.generation = "changed-after-open";
    assert.equal(captured.provider, "aqueous");
    assert.equal(captured.session, "session");
    assert.equal(captured.binding.keys[0].key, draft.originalKey);
    assert.equal(captured.baseline.generation, snapshot.generation);
    const edited = c.updateBindEdit(captured, draft.originalKey, draft.data);
    const result = c.reconcileBindEdit(edited, changed);
    assert.equal(result.draft.baseline.generation, changed.generation);
    assert.equal(result.draft.originalAction, changed.binds.Custom[0].action);
    assert.deepEqual(copy(result.draft.data), copy(draft.data));
    assert.equal(edited.baseline.generation, snapshot.generation);
    assert.equal(c.reconcileBindEdit(edited, duplicate).code, "ambiguous_target");
}
for (const operation of ["set", "remove", "reset"]) {
    const {c, calls, results} = service();
    methods(c, "../Services/KeybindsService.qml", ["saveBind", "removeBind", "resetBind"]);
    const edit = {...copy(draft), operation};
    const complete = result => results.push(result);
    if (operation === "set")
        c.saveBind(edit.originalKey, edit.data, edit, complete);
    else
        c[operation === "remove" ? "removeBind" : "resetBind"](edit.originalKey, edit, complete);
    calls.shift().callback(fresh, "");
    assert.equal(calls[0].args[2], operation);
    calls.shift().callback({success: true, generation: "saved"}, "");
    assert.equal(results[0].success, true);
}
{
    const {c, calls, submit, flush} = service();
    submit();
    c.loadBinds();
    calls.shift().callback(fresh, "");
    calls.shift().callback({success: true, generation: "saved"}, "");
    flush();
    assert.equal(calls.length, 1, "success and a pending refresh must share one read");
    calls.shift().callback(fresh, "");
    flush();
    assert.equal(calls.length, 0);
}
{
    const {c, writes} = editor();
    const before = copy(c.editDraft);
    const removal = c.prepareRemoval(draft.originalKey, "remove");
    assert.equal(removal.operation, "remove");
    assert.deepEqual(copy(c.editDraft), before, "opening or cancelling removal must preserve the edit");
    assert.equal(writes.length, 0);
}
console.log("PASS: Aqueous keybind inventory, preparation, mutation results, refresh and draft review");
