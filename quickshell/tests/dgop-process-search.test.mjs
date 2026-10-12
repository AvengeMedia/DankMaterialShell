import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("../Services/DgopService.qml", import.meta.url), "utf8");

function service() {
    const context = vm.createContext({
        refCount: 1,
        enabledModules: ["processes"],
        gpuPciIds: [],
        cpuCursor: "",
        procCursor: "",
        noCpu: false,
        fullProcessListRefs: 0,
        updates: 0
    });
    vm.runInContext("function updateAllStats() { updates++; }", context);
    const methods = ["buildMetaParams", "hasModule", "requestFullProcessList", "releaseFullProcessList"];
    const found = [];
    for (const match of source.matchAll(/^    function (\w+)\([^\n]*\)(?:: \w+)? \{\n[\s\S]*?^    \}/gm)) {
        if (!methods.includes(match[1]))
            continue;
        found.push(match[1]);
        vm.runInContext(match[0], context);
    }
    assert.deepEqual(found.sort(), [...methods].sort());
    return context;
}

test("process polling keeps the top 100 by CPU when nobody searches", () => {
    const context = service();
    assert.equal(context.buildMetaParams().limit, 100);
});

test("a search gets every process and refreshes right away", () => {
    const context = service();
    context.requestFullProcessList();
    assert.equal(context.buildMetaParams().limit, 0);
    assert.equal(context.updates, 1);
});

test("the full list stays until the last searching view releases it", () => {
    const context = service();
    context.requestFullProcessList();
    context.requestFullProcessList();
    assert.equal(context.updates, 1);
    context.releaseFullProcessList();
    assert.equal(context.buildMetaParams().limit, 0);
    context.releaseFullProcessList();
    assert.equal(context.buildMetaParams().limit, 100);
    context.releaseFullProcessList();
    assert.equal(context.fullProcessListRefs, 0);
});
