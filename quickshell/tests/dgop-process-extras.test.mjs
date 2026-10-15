import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const source = readFileSync(new URL("../Services/DgopService.qml", import.meta.url), "utf8");
const devicesSource = readFileSync(new URL("../Services/SysmonDevices.js", import.meta.url), "utf8").replace(".pragma library", "");

function service(modules, availableModules = ["processes", "process-gpu", "process-io"], currentSort = "cpu") {
    const context = vm.createContext({
        refCount: 1,
        enabledModules: modules,
        availableModules,
        currentSort,
        sortAscending: false,
        allProcesses: [],
        processes: [],
        processLimit: 50,
        fullProcessListRefs: 0,
        gpuPciIds: [],
        noCpu: false,
        procCursor: "",
        deviceHistory: {},
        deviceHistorySize: 3,
        cpuSampleCount: 0,
        statsUpdated() {},
        ProcessSort: loadScript(new URL("../Services/ProcessSort.js", import.meta.url)),
        SysmonDevices: vm.runInContext(`(function(){${devicesSource}\nreturn {appendHistory};})()`, vm.createContext({}))
    });
    const methods = ["hasModule", "isModuleAvailable", "buildMetaParams", "dgopSort", "parseData", "processComparator", "applySorting"];
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

const mods = ["processes", "process-gpu", "process-io"];

test("absent gpu stays null, zero stays zero, startTime/childCount copied", () => {
    const s = service(mods);
    s.gpuPciIds = ["10de:2684"];
    s.parseData({ processes: [{ pid: 1, command: "a", startTime: 99, childCount: 2 }, { pid: 2, command: "b", gpu: 0, vramKB: 0, diskRead: 0 }] });
    const [a, b] = s.allProcesses;
    assert.equal(a.gpu, null);
    assert.equal(a.vramKB, null);
    assert.equal(a.diskRead, null);
    assert.equal(a.diskWrite, null);
    assert.equal(a.startTime, 99);
    assert.equal(a.childCount, 2);
    assert.equal(b.gpu, 0);
    assert.equal(b.vramKB, 0);
    assert.equal(b.diskRead, 0);
    assert.equal(b.diskWrite, null);
    assert.equal(b.startTime, null);
});

test("sorting by gpu/vram/disk puts absent last in both directions", () => {
    const rows = [
        { pid: 1, gpu: null, vramKB: null, diskRead: null, diskWrite: null },
        { pid: 2, gpu: 5, vramKB: 10, diskRead: 1, diskWrite: 1 },
        { pid: 3, gpu: 0, vramKB: 0, diskRead: 0, diskWrite: 0 },
        { pid: 4, gpu: 9, vramKB: 20, diskRead: null, diskWrite: 30 }
    ];
    const expected = { gpu: [4, 2, 3, 1], vram: [4, 2, 3, 1], disk: [4, 2, 3, 1] };
    for (const key of ["gpu", "vram", "disk"]) {
        const s = service(mods, undefined, key);
        assert.deepEqual(rows.slice().sort(s.processComparator()).map(p => p.pid), expected[key], key);
        s.sortAscending = true;
        assert.deepEqual(rows.slice().sort(s.processComparator()).map(p => p.pid), [3, 2, 4, 1], key + " asc");
    }
});

test("name and pid sort ascending by default and descending after toggle", () => {
    const rows = [
        { pid: 3, command: "b" },
        { pid: 1, command: "c" },
        { pid: 2, command: "a" }
    ];
    const expected = { name: [2, 3, 1], pid: [1, 2, 3] };
    for (const key of ["name", "pid"]) {
        const s = service(mods, undefined, key);
        assert.deepEqual(rows.slice().sort(s.processComparator()).map(p => p.pid), expected[key], key);
        s.sortAscending = true;
        assert.deepEqual(rows.slice().sort(s.processComparator()).map(p => p.pid), expected[key].slice().reverse(), key + " toggled");
    }
});

test("the limit applies only when dgop sorts like the table; otherwise every process is fetched", () => {
    const params = (m, avail, key, ascending = false) => {
        const s = service(m, avail, key);
        s.sortAscending = ascending;
        const p = s.buildMetaParams();
        return p.sort + ":" + p.limit;
    };
    for (const key of ["cpu", "memory", "pid", "gpu", "vram"])
        assert.equal(params(mods, mods, key), key + ":100", key);
    for (const key of ["name", "diskRead", "disk", "netRx", "connections", "threads", "user", "gpuVideo"])
        assert.equal(params(mods, mods, key), "cpu:0", key);
    assert.equal(params(mods, mods, "memory", true), "cpu:0");
    assert.equal(params(mods, ["processes", "process-io"], "gpu"), "cpu:0");
    assert.equal(params(["processes", "process-io"], mods, "vram"), "cpu:0");
});

test("no extras requested when only processes is enabled", () => {
    const p = service(["processes"]).buildMetaParams();
    assert.equal(p.modules.join(), "processes");
});

test("process gpu and vram are unknown, not zero, while no GPU is monitored", () => {
    const s = service(mods);
    const rows = { processes: [{ pid: 1, command: "a", gpu: 0, vramKB: 0 }] };
    s.parseData(rows);
    assert.equal(s.allProcesses[0].gpu, null);
    assert.equal(s.allProcesses[0].vramKB, null);
    assert.equal(s.allProcesses[0].gpuUnmonitored, true);
    s.gpuPciIds = ["10de:2684"];
    s.parseData(rows);
    assert.equal(s.allProcesses[0].gpu, 0);
    assert.equal(s.allProcesses[0].vramKB, 0);
    assert.equal(s.allProcesses[0].gpuUnmonitored, false);
    s.parseData({ processes: [{ pid: 1, command: "a", gpuUnmonitored: true }] });
    assert.equal(s.allProcesses[0].gpuUnmonitored, true);
});

test("stat, gpu split and net fields pass through; absent stays null", () => {
    const s = service([...mods, "process-net"], [...mods, "process-net"]);
    s.gpuPciIds = ["1002:744c"];
    s.parseData({ processes: [
        { pid: 1, command: "a", pticks: 12.5, status: "S", threads: 27, nice: -4, gpuVideo: 3, gpuGttKB: 2048, connections: 2, localConnections: 1, remotes: [{ protocol: "tcp", remote: "1.2.3.4:443" }], netRx: 10, netTx: 0, netPartial: true },
        { pid: 2, command: "b", nice: 0 }
    ] });
    const [a, b] = s.allProcesses;
    assert.equal(a.pticks, 12.5);
    assert.equal(a.status, "S");
    assert.equal(a.threads, 27);
    assert.equal(a.nice, -4);
    assert.equal(a.gpuVideo, 3);
    assert.equal(a.gpuGttKB, 2048);
    assert.equal(a.connections, 2);
    assert.equal(a.localConnections, 1);
    assert.equal(a.netPartial, true);
    assert.equal(b.netPartial, false);
    assert.equal(b.localConnections, null);
    assert.equal(a.remotes.length, 1);
    assert.equal(a.netTx, 0);
    assert.equal(b.nice, 0);
    assert.equal(b.threads, null);
    assert.equal(b.gpuVideo, null);
    assert.equal(b.connections, null);
    assert.equal(b.netRx, null);
    assert.equal(b.remotes.length, 0);
});

test("openFileCount and initSystem are parsed from system and hardware", () => {
    const s = service(["system"], ["system"]);
    s.parseData({ system: { processes: 600, threads: 1900, openFiles: 9890 }, hardware: { hostname: "h", initSystem: "systemd" } });
    assert.equal(s.openFileCount, 9890);
    assert.equal(s.threadCount, 1900);
    assert.equal(s.initSystem, "systemd");
});
