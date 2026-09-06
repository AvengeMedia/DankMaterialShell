import assert from "node:assert/strict";
import {mkdtempSync, mkdirSync, readFileSync, writeFileSync} from "node:fs";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {spawnSync} from "node:child_process";
import vm from "node:vm";

const adapter = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/AqueousBlur.js", import.meta.url), "utf8"), adapter);
const original = '# User rules: 日本語\r\n[[window]]\r\napp_id = "example"\r\nblur = true\r\n\r\n[[layer]]\r\nnamespace = "*"\r\nblur = true\r\n';
const enabled = adapter.rules(original, true, false, false);
const disabled = adapter.rules(enabled, false, false, false);
assert(enabled.endsWith(original), "existing rules must remain byte-for-byte intact");
assert(disabled.endsWith(original));
assert.equal(adapter.rules(original, false, false, false), original, "first disabled startup must not write configuration");
assert.equal(adapter.rules(enabled, true, false, false), enabled, "reconciliation must be idempotent");
assert.equal(adapter.rules(disabled, false, false, false), disabled);
assert.equal(adapter.rules(enabled, true, false, true), original, "protocol support must remove forced layer blur");
assert.throws(() => adapter.rules(null, true, false, false), /snapshot/);
assert.throws(() => adapter.rules("# BEGIN DMS BACKGROUND BLUR\n", true, false, false), /incomplete/);
assert.throws(() => adapter.rules("# comment\n" + enabled, true, false, false), /once at the start/);
assert.throws(() => adapter.rules(enabled + enabled, true, false, false), /once at the start/);
assert.throws(() => adapter.rules("custom_root = true\n", true, false, false), /root assignments/);

function layerBlur(source, namespace) {
    const parsed = spawnSync("python3", ["-c", "import json,sys,tomllib; print(json.dumps(tomllib.loads(sys.stdin.read())))"], {input: source, encoding: "utf8", timeout: 2000});
    assert.equal(parsed.status, 0, parsed.stderr);
    const match = JSON.parse(parsed.stdout).layer.find(rule => {
        const pattern = rule.namespace.split("*").map(part => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join(".*");
        return new RegExp("^" + pattern + "$").test(namespace);
    });
    return match?.blur;
}
for (const namespace of ["dms:bar", "dms:dock", "dms:dash", "dms:dash:background", "dms:notification-popup", "dms:plugins:test"])
    assert.equal(layerBlur(enabled, namespace), true, namespace);
for (const namespace of ["dms:frame", "dms:spotlight:clickcatcher", "dms:dankisland:dismiss", "dms:dock-exclusion", "dms:frame-launcher-hover", "dms:blurwallpaper", "dms:fade-to-lock", "dms:desktop-widget-grid"])
    assert.equal(layerBlur(enabled, namespace), false, namespace);
assert.equal(layerBlur(adapter.rules(enabled, true, true, false), "dms:frame"), true);
assert.equal(layerBlur(disabled, "dms:bar"), false, "off must override later wildcard rules");
assert.equal(layerBlur(disabled, "waybar"), true, "off must leave other applications alone");

const caps = ["schema_fields", "validate", "stdin_requests", "generation_check", "atomic_file_replace", "shell_dms"];
const snapshot = source => ({protocol: 1, capabilities: caps, generation: "generation-1", fields: [{id: "blur.enabled", value: true}], raw_files: {rules: source}});
function harness() {
    const calls = [];
    const deferred = [];
    const context = vm.createContext({
        contextKey: "session-1", supported: false, globalEnabled: false, appliedEnabled: false,
        busy: false, pending: false, error: "", AqueousBlur: adapter,
        Qt: {callLater: fn => deferred.push(fn)}, Log: {scoped: () => ({warn() {}})},
        SettingsData: {blurEnabled: true, frameBlurEnabled: false}, BlurService: {compositorSupported: false},
        AqueousConfigService: {
            busy: false,
            requireCapabilities: (result, required) => {
                assert.equal(result.protocol, 1);
                for (const capability of required)
                    assert(result.capabilities.includes(capability), "unsupported capability");
            },
            load: callback => calls.push({operation: "snapshot", callback}),
            apply: (draft, callback) => calls.push({operation: "apply", draft, callback})
        }
    });
    context.root = context;
    const source = readFileSync(new URL("../Services/AqueousBlurService.qml", import.meta.url), "utf8");
    for (const name of ["refresh", "finish", "sync"]) {
        const start = source.indexOf("    function " + name + "(");
        const end = source.indexOf("\n    }", start) + 6;
        vm.runInContext(source.slice(start, end), context);
    }
    const flush = () => {
        for (let n = 0; deferred.length; n++) {
            assert(n < 20, "unexpected retry loop");
            deferred.shift()();
        }
    };
    return {context, calls, flush};
}

{
    const {context: c, calls, flush} = harness();
    c.refresh(); flush();
    calls.shift().callback(snapshot(original), "");
    const apply = calls.shift();
    assert.equal(apply.operation, "apply");
    assert.equal(apply.draft.expected_generation, "generation-1");
    assert.equal(apply.draft.raw_files.rules, enabled);
    assert.equal(apply.draft.changes, undefined, "must not change global blur");
    assert.equal(c.appliedEnabled, false, "must await helper acknowledgement");
    c.SettingsData.blurEnabled = false;
    c.refresh(); flush();
    assert.equal(calls.length, 0, "must serialize mutations");
    apply.callback(snapshot(enabled), ""); flush();
    calls.shift().callback(snapshot(enabled), "");
    const off = calls.shift();
    assert.equal(off.draft.raw_files.rules, disabled, "latest toggle must win");
    off.callback(snapshot(disabled), ""); flush();
    assert.equal(c.appliedEnabled, false);
    assert.equal(c.busy, false);
    assert.equal(calls.length, 0, "settled service must not poll");
    c.refresh(); flush();
    calls.shift().callback(snapshot(disabled), ""); flush();
    assert.equal(calls.length, 0, "matching saved rules must not be rewritten");
}
for (const error of ["external_change", "timeout", "read_only"]) {
    const {context: c, calls, flush} = harness();
    c.refresh(); flush();
    calls.shift().callback(snapshot(original), "");
    calls.shift().callback(null, error); flush();
    assert.equal(c.error, error);
    assert.equal(c.appliedEnabled, false);
    assert.equal(c.busy, false);
    assert.equal(calls.length, 0, "uncertain/failed writes must not retry automatically");
    c.refresh(); flush();
    assert.equal(calls.shift().operation, "snapshot", "explicit retry must obtain a fresh generation");
}
{
    const {context: c, calls, flush} = harness();
    c.AqueousConfigService.busy = true;
    c.refresh(); flush();
    assert.equal(calls.length, 0);
    assert.equal(c.pending, true);
    c.AqueousConfigService.busy = false;
    c.sync();
    calls.shift().callback({...snapshot(original), fields: [{id: "blur.enabled", value: false}]}, "");
    assert.equal(c.globalEnabled, false);
    assert.equal(calls.length, 0, "global blur off must not trigger a global configuration change");
}
{
    const {context: c, calls, flush} = harness();
    c.refresh(); flush();
    calls.shift().callback({...snapshot(original), raw_files: {}}, "");
    assert.match(c.error, /unsupported/);
    assert.equal(c.supported, false);
    assert.equal(calls.length, 0);
}
{
    const {context: c, calls, flush} = harness();
    c.refresh(); flush();
    c.contextKey = "";
    calls.shift().callback(snapshot(original), ""); flush();
    assert.equal(calls.length, 0, "disconnect must prevent writes from stale snapshots");
    assert.equal(c.busy, false);
}
{
    const {context: c, calls, flush} = harness();
    c.refresh(); flush();
    calls.shift().callback(snapshot(original), "");
    calls.shift().callback(snapshot(original), "");
    assert.match(c.error, /did not apply/);
    assert.equal(c.appliedEnabled, false);
}

if (process.env.AQUEOUS_BLUR_TEST_HELPER) {
    const base = mkdtempSync(join(tmpdir(), "dms-aqueous-blur-"));
    const config = join(base, "aqueous");
    mkdirSync(config);
    writeFileSync(join(config, "rules.toml"), original);
    writeFileSync(join(config, "wm.toml"), "[blur]\nenabled = true\n");
    const env = {...process.env, XDG_CONFIG_HOME: base, WAYLAND_DISPLAY: "dms-blur-test-missing-display"};
    function helper(operation, request, success = true) {
        const args = [operation, "--shell", "dms"];
        if (request) args.push("--request", "-");
        const result = spawnSync(process.env.AQUEOUS_BLUR_TEST_HELPER, args, {env, encoding: "utf8", input: request ? JSON.stringify(request) : undefined, timeout: 20000, maxBuffer: 4 * 1024 * 1024});
        assert.equal(result.status, success ? 0 : 1, result.stderr || result.stdout);
        return JSON.parse(result.stdout);
    }
    const before = helper("snapshot");
    const request = {protocol: 1, expected_generation: before.generation, raw_files: {rules: enabled}};
    helper("validate", request);
    assert.equal(readFileSync(join(config, "rules.toml"), "utf8"), original, "validation must not write");
    const after = helper("apply", request);
    assert.equal(after.raw_files.rules, enabled);
    assert.equal(readFileSync(join(config, "rules.toml"), "utf8"), enabled);
    assert.equal(readFileSync(join(config, "wm.toml"), "utf8"), "[blur]\nenabled = true\n");
    assert.equal(helper("apply", request, false).code, "external_change");
    const off = {...request, expected_generation: after.generation, raw_files: {rules: disabled}};
    helper("validate", off);
    const final = helper("apply", off);
    assert.equal(final.raw_files.rules, disabled);
    assert.equal(helper("snapshot").generation, final.generation);
    console.log("PASS: real helper validate/apply, stale generation, global setting and unrelated rules preserved", base);
}
console.log("PASS: Aqueous blur rules, toggle queue, capabilities, failures and lifecycle");
