import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const source = readFileSync(new URL("../Services/DgopService.qml", import.meta.url), "utf8");

function service(modules) {
    const context = vm.createContext({
        refCount: 1,
        enabledModules: modules,
        availableModules: [],
        gpuPciIds: [],
        fullProcessListRefs: 0,
        noCpu: false,
        diskReadRate: 0,
        diskWriteRate: 0,
        lastDiskStats: null,
        diskHistory: { read: [], write: [] },
        diskRateCursor: "",
        netRateCursor: "",
        diskRates: [],
        netRates: [],
        deviceHistory: {},
        historySize: 60,
        procCursor: "",
        cpuCursor: "",
        cpuSampleCount: 0,
        cpuHistory: [],
        perCoreCpuUsage: [],
        memoryHistory: [],
        memoryInfo: null,
        bios: null,
        primeTimer: { restart() {} },
        statsUpdated() {},
        Format: loadScript(new URL("../Common/Format.js", import.meta.url)),
        SysmonDevices: loadScript(new URL("../Services/SysmonDevices.js", import.meta.url))
    });
    const methods = ["hasModule", "isModuleAvailable", "buildMetaParams", "dgopSort", "parseData", "releaseUnusedData", "removeDeviceHistory", "pushDeviceHistory"];
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

const diskPayload = sectors => ({
    disk: [
        { name: "nvme0n1", read: sectors, write: 0 },
        { name: "nvme0n1p2", read: sectors, write: 0 },
        { name: "dm-0", read: sectors, write: 0 }
    ]
});

test("disk totals count whole disks only", () => {
    const ctx = service(["disk"]);
    ctx.parseData(diskPayload(0));
    ctx.lastDiskStats.time -= 1000;
    ctx.parseData(diskPayload(2048));
    // 2048 sectors * 512 B over ~1 s, nvme0n1 only (not x3)
    assert.ok(ctx.diskReadRate > 0.9 * 1048576 && ctx.diskReadRate < 1.1 * 1048576, String(ctx.diskReadRate));
});

const diskRate = (cursor, readrate) => ({
    diskrate: {
        cursor,
        disks: [
            { device: "nvme0n1", readrate, writerate: 1, readtotal: 10, writetotal: 20 },
            { device: "nvme0n1p2", readrate, writerate: 1, readtotal: 10, writetotal: 20 }
        ]
    }
});

test("rate cursors are forwarded, first sample skipped, partitions get no history", () => {
    const ctx = service(["disk-rate", "net-rate"]);
    assert.equal(ctx.buildMetaParams().diskRateCursor, undefined);
    ctx.parseData(diskRate("c1", 0));
    ctx.parseData({ netrate: { cursor: "n1", interfaces: [{ interface: "enp6s0", rxrate: 0, txrate: 0, rxtotal: 1, txtotal: 2 }] } });
    const params = ctx.buildMetaParams();
    assert.equal(params.diskRateCursor, "c1");
    assert.equal(params.netRateCursor, "n1");
    assert.deepEqual(Object.keys(ctx.deviceHistory), []);
    assert.equal(ctx.diskRates.length, 2);
    assert.equal(ctx.diskRates[0].busy, undefined);
    ctx.parseData(diskRate("c2", 5));
    assert.deepEqual(Array.from(ctx.deviceHistory["disk:nvme0n1"].a), [5]);
    assert.deepEqual(Array.from(ctx.deviceHistory["disk:nvme0n1"].b), [1]);
    assert.equal(ctx.deviceHistory["disk:nvme0n1p2"], undefined);
});

test("busy and responseTime are copied only when present", () => {
    const ctx = service(["disk-rate"]);
    const payload = diskRate("c", 0);
    payload.diskrate.disks[0].busy = 12;
    payload.diskrate.disks[0].responseTime = 0.5;
    ctx.parseData(payload);
    assert.equal(ctx.diskRates[0].busy, 12);
    assert.equal(ctx.diskRates[0].responseTime, 0.5);
    assert.equal("busy" in ctx.diskRates[1], false);
});

test("history is bounded and vanished interfaces are dropped", () => {
    const ctx = service(["net-rate"]);
    ctx.historySize = 3;
    const net = (...names) => ({ netrate: { cursor: "c", interfaces: names.map(n => ({ interface: n, rxrate: 1, txrate: 2 })) } });
    for (let i = 0; i < 6; i++)
        ctx.parseData(net("enp6s0", "wg0"));
    assert.equal(ctx.deviceHistory["net:enp6s0"].a.length, 3);
    ctx.parseData(net("enp6s0"));
    assert.deepEqual(Object.keys(ctx.deviceHistory), ["net:enp6s0"]);
});

test("releaseUnusedData clears disk-rate state only when the module is gone", () => {
    const ctx = service(["disk-rate", "cpu"]);
    ctx.parseData(diskRate("c1", 0));
    ctx.parseData(diskRate("c2", 5));
    ctx.parseData({ cpu: { usage: 10 } });
    ctx.releaseUnusedData();
    assert.ok(ctx.deviceHistory["disk:nvme0n1"]);
    ctx.enabledModules = ["cpu"];
    ctx.releaseUnusedData();
    assert.equal(ctx.diskRates.length, 0);
    assert.equal(ctx.diskRateCursor, "");
    assert.deepEqual(Object.keys(ctx.deviceHistory), ["cpu"]);
});

test("cpu and memory feed their deviceHistory keys and memoryInfo", () => {
    const ctx = service(["cpu", "memory"]);
    const memory = { total: 1000, available: 250, cached: 100 };
    ctx.parseData({ cpu: { usage: 12.34 }, memory });
    ctx.parseData({ cpu: { usage: 20 }, memory });
    assert.deepEqual(Array.from(ctx.deviceHistory.cpu.a), [12.3, 20]);
    assert.deepEqual(Array.from(ctx.deviceHistory.memory.a), [75, 75]);
    assert.equal(ctx.memoryInfo, memory);
    ctx.enabledModules = ["cpu"];
    ctx.releaseUnusedData();
    assert.equal(ctx.memoryInfo, null);
    assert.deepEqual(Object.keys(ctx.deviceHistory), ["cpu"]);
});

test("bios is kept from the hardware payload", () => {
    const ctx = service([]);
    const bios = { vendor: "AMI", version: "1.2", date: "01/01/2026", motherboard: "B650" };
    ctx.parseData({ hardware: { hostname: "h", bios } });
    assert.equal(ctx.bios, bios);
});

test("net-rate rows carry totals", () => {
    const ctx = service(["net-rate"]);
    ctx.parseData({ netrate: { cursor: "n", interfaces: [{ interface: "enp6s0", rxrate: 1, txrate: 2, rxtotal: 300, txtotal: 400 }] } });
    assert.deepEqual({ ...ctx.netRates[0] }, { iface: "enp6s0", rxRate: 1, txRate: 2, rxTotal: 300, txTotal: 400 });
});

test("disk-rate replies without a cursor never reach the history", () => {
    const ctx = service(["disk-rate"]);
    ctx.parseData(diskRate("", 5));
    ctx.parseData(diskRate("", 5));
    assert.equal(ctx.diskRateCursor, "");
    assert.equal(ctx.diskRates.length, 2);
    assert.deepEqual(Object.keys(ctx.deviceHistory), []);
});

test("net-rate link details pass through and stay undefined when absent", () => {
    const ctx = service(["net-rate"]);
    ctx.parseData({ netrate: { cursor: "c", interfaces: [
        { interface: "enp6s0", rxrate: 1, txrate: 2, mtu: 1500, speed: 1000, duplex: "full", linkType: "ethernet", driver: "igb", ipv4: ["192.168.2.1/16"], ipv6: ["fe80::1/64"] },
        { interface: "tailscale0", rxrate: 0, txrate: 0, mtu: 1280, linkType: "tunnel" }
    ] } });
    const [eth, ts] = ctx.netRates;
    assert.equal(eth.speed, 1000);
    assert.equal(eth.driver, "igb");
    assert.deepEqual(Array.from(eth.ipv4), ["192.168.2.1/16"]);
    assert.equal(ts.linkType, "tunnel");
    assert.equal(ts.speed, undefined);
    assert.equal(ts.ipv4, undefined);
});
