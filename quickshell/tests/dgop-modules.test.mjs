import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("../Services/DgopService.qml", import.meta.url), "utf8");
const devicesSource = readFileSync(new URL("../Services/SysmonDevices.js", import.meta.url), "utf8").replace(".pragma library", "");

const pinnedModules = ["cpu", "memory", "network", "net-rate", "disk", "disk-rate", "diskmounts", "processes", "system", "hardware", "gpu", "gpu-temp"];
const newModules = [...pinnedModules, "process-gpu", "process-io", "gpu-stats", "sensors", "memory-modules"];

function service(modules, availableModules = []) {
    const requests = [];
    const context = vm.createContext({
        refCount: 1,
        currentSort: "cpu",
        fullProcessListRefs: 0,
        enabledModules: modules,
        availableModules,
        dgopAvailable: true,
        pollingActive: false,
        DMSService: { sendRequest: (method, params, callback) => requests.push({ method, params, callback }) },
        log: { warn() {} },
        gpuPciIds: [],
        noCpu: false,
        cpuCursor: "",
        procCursor: "",
        diskRateCursor: "",
        netRateCursor: "",
        gpuStatsCursor: "",
        cpuSampleCount: 0,
        cpuHistory: [],
        memoryHistory: [],
        perCoreCpuUsage: [],
        cpuInfo: null,
        memoryInfo: null,
        diskRates: [],
        netRates: [],
        gpuStats: [],
        sensors: [],
        memoryModules: null,
        deviceHistory: {},
        deviceHistorySize: 60,
        primeTimer: { restart() {} },
        statsUpdated() {},
        updateAllStats() {},
        appendHistory: (h, v) => h.concat([v]),
        SysmonDevices: vm.runInContext(`(function(){${devicesSource}\nreturn {isWholeDisk, appendHistory, sumWholeDisks, deviceKey};})()`, vm.createContext({}))
    });
    const methods = ["hasModule", "isModuleAvailable", "initializeModules", "buildMetaParams", "parseData", "releaseUnusedData", "removeDeviceHistory", "pushDeviceHistory"];
    const found = [];
    for (const match of source.matchAll(/^    function (\w+)\([^\n]*\)(?:: \w+)? \{\n[\s\S]*?^    \}/gm)) {
        if (!methods.includes(match[1]))
            continue;
        found.push(match[1]);
        vm.runInContext(match[0], context);
    }
    assert.deepEqual(found.sort(), [...methods].sort());
    return { ctx: context, requests };
}

const gpuStats = (cursor, gpus) => ({ gpustats: { cursor, gpus } });

test("modules missing from dgop.modules are never requested", () => {
    const { ctx } = service(["cpu", "gpu-stats", "sensors"], pinnedModules);
    assert.deepEqual(Array.from(ctx.buildMetaParams().modules), ["cpu"]);
    ctx.availableModules = newModules;
    assert.deepEqual(Array.from(ctx.buildMetaParams().modules), ["cpu", "gpu-stats", "sensors"]);
});

test("before dgop.modules replies only the new modules are held back", () => {
    const { ctx } = service(["processes", "process-gpu", "process-io", "process-net", "memory-modules", "disk-rate"]);
    assert.deepEqual(Array.from(ctx.buildMetaParams().modules), ["processes", "disk-rate"]);
});

test("a request made only of unavailable modules is not sent", () => {
    const { ctx } = service(["gpu-stats"], pinnedModules);
    assert.equal(ctx.buildMetaParams(), null);
});

test("dgop.modules is fetched and stored, failures leave the list empty", () => {
    const { ctx, requests } = service([]);
    ctx.initializeModules();
    assert.equal(requests[0].method, "dgop.modules");
    requests[0].callback({ result: { available: newModules } });
    assert.deepEqual(Array.from(ctx.availableModules), newModules);
    ctx.availableModules = [];
    ctx.initializeModules();
    requests[1].callback({ error: "unknown method" });
    assert.deepEqual(Array.from(ctx.availableModules), []);
});

test("gpu-stats cursor is forwarded and histories keyed by pciSlot", () => {
    const { ctx } = service(["gpu-stats"], newModules);
    assert.equal(ctx.buildMetaParams().gpuStatsCursor, undefined);
    ctx.parseData(gpuStats("g1", [{ pciSlot: "0000:03:00.0", usage: 40, vramUsed: 2, vramTotal: 8 }]));
    assert.equal(ctx.buildMetaParams().gpuStatsCursor, "g1");
    assert.equal(ctx.gpuStats.length, 1);
    assert.deepEqual(Array.from(ctx.deviceHistory["gpu:0000:03:00.0"].a), [40]);
    assert.deepEqual(Array.from(ctx.deviceHistory["gpu:0000:03:00.0"].b), [25]);
});

test("a suspended GPU gets no history sample and VRAM needs both fields", () => {
    const { ctx } = service(["gpu-stats"], newModules);
    ctx.parseData(gpuStats("g1", [
        { pciSlot: "0000:03:00.0", pciId: "1002:744c", name: "dGPU", suspended: true },
        { pciSlot: "0000:0c:00.0", usage: 5, vramUsed: 1 }
    ]));
    assert.equal(ctx.gpuStats.length, 2);
    assert.equal(ctx.deviceHistory["gpu:0000:03:00.0"], undefined);
    assert.deepEqual(Array.from(ctx.deviceHistory["gpu:0000:0c:00.0"].a), [5]);
    assert.deepEqual(Array.from(ctx.deviceHistory["gpu:0000:0c:00.0"].b), []);
});

test("net-rate asks for all interfaces", () => {
    const { ctx } = service(["net-rate"], pinnedModules);
    assert.equal(ctx.buildMetaParams().netRateAllInterfaces, true);
    const { ctx: other } = service(["cpu"], pinnedModules);
    assert.equal(other.buildMetaParams().netRateAllInterfaces, undefined);
});

test("sensors, memory modules and cpu extras are parsed and released", () => {
    const { ctx } = service(["cpu", "sensors", "memory-modules", "gpu-stats"], newModules);
    const cpu = { usage: 10, coreFrequencies: [3000], governor: "powersave" };
    const modules = { slots: 4, modules: [{ locator: "DIMM_A1", size: 17179869184 }] };
    ctx.parseData({
        cpu,
        sensors: { sensors: [{ chip: "k10temp", label: "Tctl", kind: "temperature", value: 50 }] },
        memorymodules: modules,
        gpustats: { cursor: "g", gpus: [{ pciSlot: "s", usage: 1 }] }
    });
    assert.equal(ctx.cpuInfo, cpu);
    assert.equal(ctx.sensors.length, 1);
    assert.equal(ctx.memoryModules, modules);
    ctx.enabledModules = [];
    ctx.releaseUnusedData();
    assert.equal(ctx.cpuInfo, null);
    assert.equal(ctx.sensors.length, 0);
    assert.equal(ctx.memoryModules, null);
    assert.equal(ctx.gpuStats.length, 0);
    assert.equal(ctx.gpuStatsCursor, "");
    assert.deepEqual(Object.keys(ctx.deviceHistory), []);
});

test("deviceHistory is assigned once per poll", () => {
    const { ctx } = service(["cpu", "memory", "net-rate", "gpu-stats"], newModules);
    let assignments = 0;
    let history = {};
    Object.defineProperty(ctx, "deviceHistory", {
        get: () => history,
        set: v => {
            assignments++;
            history = v;
        }
    });
    ctx.parseData({
        cpu: { usage: 1 },
        memory: { total: 100, available: 50 },
        netrate: { cursor: "n", interfaces: [{ interface: "enp6s0", rxrate: 1, txrate: 1 }] },
        gpustats: { cursor: "g", gpus: [{ pciSlot: "s", usage: 1 }] }
    });
    assert.equal(assignments, 1);
    assert.deepEqual(Object.keys(history).sort(), ["cpu", "gpu:s", "memory"]);
});

test("gpuPciIds is always sent so an empty list means no GPU, never all", () => {
    const { ctx } = service(["cpu", "gpu-stats"], newModules);
    assert.deepEqual(Array.from(ctx.buildMetaParams().gpuPciIds), []);
    ctx.gpuPciIds = ["10de:2684"];
    assert.deepEqual(Array.from(ctx.buildMetaParams().gpuPciIds), ["10de:2684"]);
});

function gpuToggleService({ enabled = [], refCount = 0, held = {} } = {}) {
    const calls = [];
    const sessionData = { enabledGpuPciIds: enabled, setEnabledGpuPciIds: ids => { sessionData.enabledGpuPciIds = ids; } };
    const context = vm.createContext({
        refCount, SessionData: sessionData, gpuPciIdRefCounts: { ...held }, calls,
        addGpuPciId: id => calls.push("add:" + id),
        removeGpuPciId: id => calls.push("remove:" + id),
        updateAllStats: () => calls.push("update")
    });
    for (const name of ["setGpuMonitoring", "gpuHeldByWidget"]) {
        const m = source.match(new RegExp(`^    function ${name}\\([^\\n]*\\) \\{\\n[\\s\\S]*?^    \\}`, "m"));
        assert.ok(m, name);
        vm.runInContext(m[0], context);
    }
    return { ctx: context, sessionData, calls };
}

test("setGpuMonitoring adds a GPU to the session list and takes a ref", () => {
    const { ctx, sessionData, calls } = gpuToggleService();
    ctx.setGpuMonitoring("10de:2684", true);
    assert.deepEqual(Array.from(sessionData.enabledGpuPciIds), ["10de:2684"]);
    assert.deepEqual(calls, ["add:10de:2684"]);
});

test("setGpuMonitoring removes a GPU and releases its ref", () => {
    const { ctx, sessionData, calls } = gpuToggleService({ enabled: ["10de:2684", "1002:73bf"] });
    ctx.setGpuMonitoring("10de:2684", false);
    assert.deepEqual(Array.from(sessionData.enabledGpuPciIds), ["1002:73bf"]);
    assert.deepEqual(calls, ["remove:10de:2684"]);
});

test("setGpuMonitoring is a no-op for repeats and empty ids", () => {
    const { ctx, sessionData, calls } = gpuToggleService({ enabled: ["10de:2684"] });
    ctx.setGpuMonitoring("10de:2684", true);
    ctx.setGpuMonitoring("1002:73bf", false);
    ctx.setGpuMonitoring("", true);
    assert.deepEqual(Array.from(sessionData.enabledGpuPciIds), ["10de:2684"]);
    assert.deepEqual(calls, []);
});

test("setGpuMonitoring refreshes stats only while modules are subscribed", () => {
    const active = gpuToggleService({ refCount: 2 });
    active.ctx.setGpuMonitoring("10de:2684", true);
    assert.deepEqual(active.calls, ["add:10de:2684", "update"]);
    const idle = gpuToggleService({ refCount: 0 });
    idle.ctx.setGpuMonitoring("10de:2684", true);
    assert.deepEqual(idle.calls, ["add:10de:2684"]);
});

test("gpuHeldByWidget is true only for refs the session list does not own", () => {
    const { ctx } = gpuToggleService({ held: { a: 1, b: 1 }, enabled: ["b"] });
    assert.equal(ctx.gpuHeldByWidget("a"), true);
    assert.equal(ctx.gpuHeldByWidget("b"), false);
    assert.equal(ctx.gpuHeldByWidget("c"), false);
    const mixed = gpuToggleService({ held: { "10DE:2684": 1 }, enabled: ["1002:73BF"] }).ctx;
    assert.equal(mixed.gpuHeldByWidget("10de:2684"), true);
    const owned = gpuToggleService({ held: { "1002:73bf": 1 }, enabled: ["1002:73BF"] }).ctx;
    assert.equal(owned.gpuHeldByWidget("1002:73bf"), false);
});
