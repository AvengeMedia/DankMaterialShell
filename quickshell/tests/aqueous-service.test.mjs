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
const clone = value => JSON.parse(JSON.stringify(value));
const context = vm.createContext({maxBatchBytes: 4 * 1024 * 1024, state: {}});
context.root = context;
loadMethods(context, "../Services/AqueousService.qml", ["byteLength", "parseJson", "validateCapabilities", "validateEntity", "reduceBatch", "acceptLine", "commandArguments", "commandResult"]);
const caps = JSON.parse(readFileSync(new URL("fixtures/aqueous/capabilities.json", import.meta.url)));
context.capabilities = context.validateCapabilities(caps);
assert.throws(() => context.validateCapabilities({...caps, schema: 2}), /unsupported/);
assert.throws(() => context.validateCapabilities({...caps, commands: undefined}), /capability/);
const batches = readFileSync(new URL("fixtures/aqueous/watch.ndjson", import.meta.url), "utf8").trim().split("\n").map(JSON.parse);
let live;
for (const batch of batches) {
    context.acceptLine(JSON.stringify(batch));
    if (batch.upsert.some(e => e.kind === "window"))
        live = clone(context.state.batch);
}
assert(live, "real fixture had no windows");
assert.equal(context.state.batch.sequence, batches.at(-1).sequence);
const first = batches[0];
const big = {...first, sequence: "900719925474099312345"};
let state = context.reduceBatch(null, big);
const delta = {schema: 1, session: big.session, type: "delta", base_sequence: big.sequence, sequence: "900719925474099312999", upsert: [], removed: []};
state = context.reduceBatch(state, delta);
assert.equal(state.sequence, delta.sequence);
assert.throws(() => context.reduceBatch(null, delta), /continuity/);
assert.throws(() => context.reduceBatch(state, delta), /continuity/);
assert.throws(() => context.reduceBatch(state, {...delta, base_sequence: state.sequence, session: "f".repeat(32)}), /continuity/);
assert.throws(() => context.reduceBatch(null, {...first, base_sequence: "1"}), /baseline/);
assert.throws(() => context.reduceBatch(null, {...first, sequence: 42}), /envelope/);
assert.throws(() => context.parseJson("{"), /JSON/);
assert.throws(() => context.parseJson('"' + "x".repeat(context.maxBatchBytes) + '"'), /4 MiB/);
const unicode = '"' + "é".repeat((context.maxBatchBytes - 2) / 2) + '"';
assert.equal(context.byteLength(unicode), context.maxBatchBytes);
assert.equal(context.parseJson(unicode + "\n").length, (context.maxBatchBytes - 2) / 2);

const old = context.reduceBatch(null, first);
const saved = JSON.stringify(old);
const workspace = old.upsert.find(e => e.kind === "workspace");
const change = {schema: 1, session: old.session, type: "delta", sequence: "99999", base_sequence: old.sequence, upsert: [{...workspace, name: "🫧 日本語", extra: 1}], removed: []};
let next = context.reduceBatch(old, change);
assert.equal(JSON.stringify(old), saved, "reducer mutated a published model");
assert.equal(next.model["workspace:" + workspace.id].name, "🫧 日本語");
next = context.reduceBatch(next, {...change, base_sequence: next.sequence, sequence: "100000", upsert: [{...workspace, name: "updated"}]});
assert.equal(next.model["workspace:" + workspace.id].extra, undefined, "upsert merged old optional fields");
assert.throws(() => context.reduceBatch(old, {...change, removed: ["output:" + workspace.output]}), /dangling/);
assert.equal(JSON.stringify(old), saved, "failed transaction mutated published state");
assert.throws(() => context.reduceBatch(old, {...change, upsert: [workspace, workspace]}), /duplicate/);
assert.throws(() => context.reduceBatch(old, {...change, upsert: [{...workspace, number: "1"}]}), /invalid/);
assert.throws(() => context.reduceBatch(old, {...change, upsert: [{...workspace, kind: "constructor"}]}), /kind/);
assert.equal(context.reduceBatch(next, first).sequence, first.sequence, "snapshot did not reset model");
// Move every association away from one output, then remove it in the same batch.
const outputs = old.upsert.filter(e => e.kind === "output");
const migrating = old.upsert.filter(e => e.output === outputs[0].id).map(e => ({...e, output: outputs[1].id}));
const migrated = context.reduceBatch(old, {...change, upsert: migrating, removed: ["output:" + outputs[0].id]});
assert.equal(migrated.model["output:" + outputs[0].id], undefined);

Object.assign(context, {
    available: true, locked: false, session: live.session, entities: live.upsert,
    workspaces: live.upsert.filter(e => e.kind === "workspace"), outputs: live.upsert.filter(e => e.kind === "output"),
    seats: live.upsert.filter(e => e.kind === "seat"), capabilities: {...caps, commands: true, keyboard: true, overview: true}
});
context.seat = context.seats[0];
const window = live.upsert.find(e => e.kind === "window" && e.can_activate);
const args = (action, fields) => clone(context.commandArguments(action, fields));
assert.deepEqual(args("window.activate", {id: window.id}), ["aqueousctl", "window", "activate", "--id", window.id, "--seat", context.seat.id, "--json"]);
assert.deepEqual(args("window.move", {id: window.id, output: context.outputs[0].id}), ["aqueousctl", "window", "move", "--id", window.id, "--output", context.outputs[0].name, "--json"]);
assert.deepEqual(args("workspace.rename", {id: workspace.id, name: "a; $(echo unsafe)"}).slice(-3), ["--name", "a; $(echo unsafe)", "--json"]);
assert.throws(() => args("window.close", {id: window.id, session: "old"}), /stale session/);
assert.throws(() => args("window.close", {id: "removed"}), /not_found/);
assert.throws(() => args("window.fullscreen", {id: window.id, value: "true"}), /missing state/);
assert.throws(() => args("workspace.rename", {id: workspace.id, name: "a\nb"}), /name/);
assert.throws(() => args("window.move", {id: window.id, output: "missing"}), /not_found/);
assert.throws(() => args("keyboard.set", {group: "removed", index: 0}), /group/);
context.seats = [...context.seats, {...context.seat, id: "seat2"}];
context.seat = null;
assert.throws(() => args("window.activate", {id: window.id}), /ambiguous_seat/);
assert(args("window.activate", {id: window.id, seat: context.seats[0].id}).includes(context.seats[0].id));
context.locked = true;
assert.throws(() => args("window.close", {id: window.id}), /locked/);
context.locked = false;
context.capabilities.commands = false;
assert.throws(() => args("window.close", {id: window.id}), /unsupported/);
context.available = false;
assert.throws(() => args("window.close", {id: window.id}), /stale/);
assert.equal(context.commandResult("window.close", {ok: true, status: "accepted", sequence: "9007199254740993"}, ""), "");
assert(context.commandResult("window.activate", {ok: true, status: "accepted", sequence: "1"}, ""));
assert(context.commandResult("session.exit", null, "EOF"));
assert(context.commandResult("session.exit", {ok: true, status: "accepted", sequence: 1}, ""));
assert(context.commandResult("window.close", {ok: true, status: "accepted", sequence: "1"}, "exit status 1"));

const calls = [];
const settings = vm.createContext({busy: false, CompositorService: {isAqueous: true}, log: {warn() {}}, Quickshell: {env: name => name === "HOME" ? "/private/home" : ""},
    AqueousService: {runJson: (args, input, callback) => calls.push({args: clone(args), input, callback})}});
settings.root = settings;
loadMethods(settings, "../Services/AqueousConfigService.qml", ["requireCapabilities", "helper", "request"]);
const replies = [];
const helperCaps = ["schema_fields", "validate", "stdin_requests", "generation_check", "atomic_file_replace", "shell_dms", "cursor_sync"];
const result = {ok: true, protocol: 1, capabilities: helperCaps, generation: "a"};
settings.request("snapshot", null, (...reply) => replies.push(reply));
assert.deepEqual(calls[0].args, ["aqueous-config", "snapshot", "--shell", "dms"]);
assert.equal(calls[0].input, null);
calls.shift().callback(result, "");
assert.equal(replies[0][0].generation, "a");
const draft = {expected_generation: "a", sync_cursor: true, changes: [{id: "cursor_size", value: 24}]};
settings.request("apply", draft, (...reply) => replies.push(reply));
draft.changes[0].value = 96;
assert.equal(calls[0].args[1], "version");
calls.shift().callback(result, "");
assert.equal(calls[0].args[1], "validate");
const input = calls[0].input;
assert.equal(JSON.parse(input).changes[0].value, 24, "async helper request captured a modified draft");
assert.equal(JSON.parse(input).expected_generation, "a");
assert.equal(JSON.parse(input).backup_dir, "/private/home/.config/DankMaterialShell/aqueous-backups");
calls.shift().callback({ok: true}, "");
assert.equal(calls[0].args[1], "apply");
assert.equal(calls[0].input, input, "apply differed from validated request");
calls.shift().callback({ok: false, code: "external_change"}, "external_change");
assert(replies.at(-1)[1].includes("external_change"));
assert.equal(calls.length, 0, "failed mutation was retried");
settings.request("apply", draft, (...reply) => replies.push(reply));
calls.shift().callback({...result, capabilities: []}, "");
assert(replies.at(-1)[1].includes("unsupported"));
assert.equal(calls.length, 0);
process.stdout.write("PASS: production QML reducer, identity, atomicity, commands and helper generation flow\n");
