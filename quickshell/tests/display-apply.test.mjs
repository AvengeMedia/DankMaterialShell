import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import vm from "node:vm";

function loadMethods(context, path, names) {
    const source = readFileSync(new URL(path, import.meta.url), "utf8");
    for (const name of names) {
        const start = source.indexOf("    function " + name + "(");
        assert.notEqual(start, -1);
        const end = source.indexOf("\n    }", start) + 6;
        vm.runInContext(source.slice(start, end), context);
    }
}

const callbacks = [];
const context = vm.createContext({
    outputs: {}, _cancelOutputWrite: null,
    CompositorService: {compositor: "aqueous"},
    WlrOutputService: {applyOutputsConfig: (_, __, callback) => callbacks.push(callback)},
});
context.root = context;
loadMethods(context, "../Modules/Settings/DisplayConfig/DisplayConfigState.qml", ["backendWriteOutputsConfig"]);
const results = [];
context.backendWriteOutputsConfig({}, success => results.push(["first", success]));
assert.equal(results.length, 0, "UI reported success before backend response");
callbacks[0](false);
assert.deepEqual(results, [["first", false]]);
context.backendWriteOutputsConfig({}, success => results.push(["second", success]));
context.backendWriteOutputsConfig({}, success => results.push(["third", success]));
assert.deepEqual(results.at(-1), ["second", false], "superseded operation did not cancel");
callbacks[1](true);
assert.equal(results.length, 2, "late completion changed a superseded operation");
callbacks[2](true);
callbacks[2](false);
assert.deepEqual(results.at(-1), ["third", true]);
assert.equal(results.length, 3, "callback fired twice");

// Existing compositor writers retain independent callbacks and are not superseded.
const mangoCallbacks = [];
context.CompositorService.compositor = "mango";
context.MangoService = {generateOutputsConfig: (_, callback) => mangoCallbacks.push(callback)};
const mangoResults = [];
context.backendWriteOutputsConfig({}, result => mangoResults.push(["first", result]));
context.backendWriteOutputsConfig({}, result => mangoResults.push(["second", result]));
assert.equal(mangoResults.length, 0);
mangoCallbacks[1](true); mangoCallbacks[0](false);
assert.deepEqual(mangoResults, [["second", true], ["first", false]]);

const requests = [];
const timers = [];
const transport = vm.createContext({
    isConnected: true, pendingRequests: {}, clipboardRequestIds: {}, requestIdCounter: 0,
    log: {warn() {}, debug() {}}, requestSocket: {send: request => requests.push(request)},
    requestTimeoutComponent: {createObject: (_, properties) => {
        const timer = {...properties, start() {}, stop() {}, destroy() { this.destroyed = true; }};
        timers.push(timer);
        return timer;
    }},
});
transport.root = transport;
loadMethods(transport, "../Services/DMSService.qml", ["sendRequest", "handleResponse", "failPendingRequests"]);
const replies = [];
transport.sendRequest("wlroutput.applyConfiguration", {}, response => replies.push(response), 5000);
assert.equal(replies.length, 0);
assert.equal(timers[0].interval, 5000);
transport.handleResponse({id: requests[0].id, error: "timeout"});
transport.handleResponse({id: requests[0].id, result: {success: true}});
assert.equal(replies.length, 1, "late reply after timeout was dispatched");
assert.equal(replies[0].error, "timeout");
assert.equal(timers[0].destroyed, true);
transport.sendRequest("wlroutput.applyConfiguration", {}, response => replies.push(response), 5000);
transport.failPendingRequests();
assert.equal(replies.length, 2);
assert.equal(timers[1].destroyed, true, "disconnect retained timeout timer");

const displayAdapter = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/AqueousDisplays.js", import.meta.url), "utf8").replace(".pragma library", ""), displayAdapter);
const outputReplies = [];
const previews = [];
let helperCalls = 0;
const previewContext = vm.createContext({
    aqueousPreview: null, validatingConfig: false, validationError: "",
    AqueousService: {session: "session"}, AqueousDisplays: displayAdapter,
    I18n: {tr: value => value}, ToastService: {showError() {}},
    freshAqueousOutputs: callback => outputReplies.push(callback),
    changesApplied: value => previews.push(value),
    AqueousConfigService: {apply() { helperCalls++; }},
});
previewContext.root = previewContext;
loadMethods(previewContext, "../Modules/Settings/DisplayConfig/DisplayConfigState.qml", ["aqueousDisplayError", "observeAqueousPreview", "finishAqueousPreview"]);
const mode = {id: "mode", width: 1280, height: 720, refresh: 60000};
const original = {id: "head", name: "DP-1", enabled: true, x: 0, y: 0, scale: 1, transform: 0, currentMode: mode, modes: [mode]};
const applied = {...original, x: 100};
const preview = {session: "session", original: [original], heads: displayAdapter.heads([applied]), fingerprint: null};
previewContext.aqueousPreview = preview;
previewContext.observeAqueousPreview(preview, ["position"], "uncertain timeout");
assert.equal(previews.length, 0);
outputReplies.shift()([applied], "");
assert.equal(previews.length, 1, "committed preview was not recovered after timeout");
assert.equal(preview.fingerprint, displayAdapter.fingerprint([applied]));
previewContext.finishAqueousPreview(true);
outputReplies.shift()([{...original, x: 200}], "");
assert.equal(helperCalls, 0, "saved a preview after another client changed live state");
assert.equal(previewContext.aqueousPreview, preview, "conflict discarded the draft");
process.stdout.write("PASS: actual display callbacks, supersession, timeout, late response and disconnect cleanup\n");
