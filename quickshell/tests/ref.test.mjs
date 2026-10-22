import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("../Common/Ref.qml", import.meta.url), "utf8");
const start = source.indexOf("    function _add(");
const end = source.indexOf("    onModulesChanged");
const body = source.slice(start, end);

// Mimics the QML object: assigning `modules` fires the handler like onModulesChanged would.
function make(modules, active) {
    const calls = [];
    const service = {
        refCount: 0,
        addRef(m) { this.refCount++; calls.push(["add", [...m]]); },
        removeRef(m) { this.refCount--; calls.push(["remove", [...m]]); },
    };
    const ctx = vm.createContext({ service, modules, active, _held: false, _heldModules: null, JSON });
    vm.runInContext(body, ctx);
    return {
        service, calls, ctx,
        setActive(v) { ctx.active = v; ctx.sync(v); },
        setModules(v) { ctx.modules = v; ctx._swap(); },
    };
}

test("static list adds and releases the same modules", () => {
    const r = make(["cpu"], false);
    r.setActive(true);
    r.setActive(false);
    assert.deepEqual(r.calls, [["add", ["cpu"]], ["remove", ["cpu"]]]);
    assert.equal(r.service.refCount, 0);
});

test("modules change while held adds new before removing old", () => {
    const r = make(["processes"], false);
    r.setActive(true);
    r.setModules(["processes", "process-gpu"]);
    r.setActive(false);
    assert.deepEqual(r.calls, [["add", ["processes"]], ["add", ["processes", "process-gpu"]], ["remove", ["processes"]], ["remove", ["processes", "process-gpu"]]]);
    assert.equal(r.service.refCount, 0);
});

test("modules change while released does nothing until activated", () => {
    const r = make(["cpu"], false);
    r.setModules(["gpu"]);
    assert.deepEqual(r.calls, []);
    r.setActive(true);
    assert.deepEqual(r.calls, [["add", ["gpu"]]]);
});

test("equal list does not churn", () => {
    const r = make(["cpu"], false);
    r.setActive(true);
    r.setModules(["cpu"]);
    assert.deepEqual(r.calls, [["add", ["cpu"]]]);
});

test("null modules add an empty ref so the service still counts it", () => {
    const r = make(null, false);
    r.setActive(true);
    assert.equal(r.service.refCount, 1);
    r.setActive(false);
    assert.equal(r.service.refCount, 0);
    assert.deepEqual(r.calls, [["add", []], ["remove", []]]);
});

test("a service without addRef only counts references", () => {
    const r = make(["cpu"], false);
    delete r.service.addRef;
    r.setActive(true);
    assert.equal(r.service.refCount, 1);
    r.setActive(false);
    assert.equal(r.service.refCount, 0);
    assert.deepEqual(r.calls, []);
});
