import { readFileSync } from "node:fs";
import assert from "node:assert/strict";
import vm from "node:vm";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const ctx = loadScript(new URL("../Modules/ProcessList/ProcessColumns.js", import.meta.url));
const lib = vm.runInContext("({COLUMNS, DEFAULT_COLUMNS, POPOUT_COLUMNS, modulesFor, meterMax, meterRatio, peakMax, formatCell, formatDuration, compare, rawValue, absentReason})", ctx);
const plain = v => JSON.parse(JSON.stringify(v));

test("modulesFor returns the modifier modules the columns need, once", () => {
    assert.deepEqual(plain(lib.modulesFor(["cpu", "gpu", "diskRead"])), ["process-gpu", "process-io", "disk"]);
    assert.deepEqual(plain(lib.modulesFor(["gpu", "vram"])), ["process-gpu", "gpu-stats"]);
    assert.deepEqual(plain(lib.modulesFor(["connections", "netRx", "netTx"])), ["process-net", "network"]);
    assert.deepEqual(plain(lib.modulesFor(lib.POPOUT_COLUMNS)), []);
});

test("default sets only reference defined columns", () => {
    const ids = lib.COLUMNS.map(c => c.id);
    for (const id of [...lib.DEFAULT_COLUMNS, ...lib.POPOUT_COLUMNS])
        assert.ok(ids.includes(id), id);
});

test("compare keeps absent values last in both directions, ties by PID", () => {
    const rows = [{pid: 4}, {pid: 3, gpu: 5}, {pid: 2, gpu: 0}, {pid: 1, gpu: 5}, {pid: 5, gpu: null}];
    const order = asc => plain(rows.slice().sort(lib.compare("gpu", asc)).map(r => r.pid));
    assert.deepEqual(order(false), [1, 3, 2, 4, 5]);
    assert.deepEqual(order(true), [2, 1, 3, 4, 5]);
});

test("formatCell distinguishes absent from zero", () => {
    assert.equal(lib.formatCell("gpu", {pid: 1}, false), null);
    assert.equal(lib.formatCell("gpu", {pid: 1, gpu: 0}, false), "0%");
    assert.equal(lib.formatCell("diskRead", {diskRead: 2048}, false), "2.0 KB/s");
    assert.equal(lib.formatCell("vram", {vramKB: 2048}, false), "2.0 MiB");
    assert.equal(lib.formatCell("user", {username: ""}, false), null);
    assert.equal(lib.formatCell("pid", {pid: 42}, false), "42");
});

test("meterRatio follows the max rules and is clamped", () => {
    const maxes = {memory: 1000, vram: 2048 * 1024, disk: 0, net: 0};
    assert.equal(lib.meterRatio("cpu", {cpu: 50}, maxes), 0.5);
    assert.equal(lib.meterRatio("gpu", {gpu: 150}, maxes), 1);
    assert.equal(lib.meterRatio("gpu", {pid: 1}, maxes), 0);
    assert.equal(lib.meterRatio("memory", {memoryKB: 250}, maxes), 0.25);
    assert.equal(lib.meterRatio("vram", {vramKB: 1024}, maxes), 0.5);
    assert.equal(lib.meterRatio("vram", {vramKB: 1024}, {}), 0);
    assert.equal(lib.meterRatio("diskRead", {diskRead: 512 * 1024}, maxes), 0.5);
    assert.equal(lib.meterRatio("netRx", {netRx: 50 * 1024}, maxes), 0.5);
    assert.equal(lib.meterRatio("netRx", {netRx: 50 * 1024}, {net: 200 * 1024}), 0.25);
    assert.equal(lib.meterRatio("pid", {pid: 5}, maxes), 0);
});

test("peakMax is the history peak x1.1 with a floor, ignoring gaps", () => {
    assert.equal(lib.peakMax([[1, null, 10], [20]], 5), 22);
    assert.equal(lib.peakMax([[], undefined], 5), 5);
});

test("new columns format and sort", () => {
    assert.equal(lib.formatCell("connections", {connections: 0}, false), "0");
    assert.equal(lib.formatCell("netTx", {netTx: 2048}, false), "2.0 KB/s");
    assert.equal(lib.formatCell("cpuTime", {pticks: 3725.4}, false), "1:02:05");
    assert.equal(lib.formatCell("cpuTime", {pticks: 65}, false), "1:05");
    assert.equal(lib.formatCell("nice", {nice: -5}, false), "-5");
    assert.equal(lib.formatCell("status", {status: "S"}, false), "S");
    assert.equal(lib.formatCell("gpuVideo", {pid: 1}, false), null);
    const rows = [{pid: 1, nice: 5}, {pid: 2}, {pid: 3, nice: -5}];
    assert.deepEqual(plain(rows.slice().sort(lib.compare("nice", true)).map(r => r.pid)), [3, 1, 2]);
    assert.equal(lib.absentReason("gpuVideo", {gpuUnmonitored: true}), "unmonitored");
});

test("disk sorts on the sum when only one side is present, absent when both are", () => {
    const rows = [{pid: 1}, {pid: 2, diskRead: 5}, {pid: 3, diskWrite: 9}, {pid: 4, diskRead: 1, diskWrite: 1}];
    const order = asc => plain(rows.slice().sort(lib.compare("disk", asc)).map(r => r.pid));
    assert.deepEqual(order(false), [3, 2, 4, 1]);
    assert.deepEqual(order(true), [4, 2, 3, 1]);
});

test("user sorts as a string with absent last", () => {
    const rows = [{pid: 1, username: "root"}, {pid: 2}, {pid: 3, username: "alice"}, {pid: 4, username: ""}];
    const order = asc => plain(rows.slice().sort(lib.compare("user", asc)).map(r => r.pid));
    assert.deepEqual(order(true), [3, 1, 2, 4]);
    assert.deepEqual(order(false), [1, 3, 2, 4]);
});

test("name sorts case-insensitively on the command", () => {
    const rows = [{pid: 1, command: "b"}, {pid: 2, command: "A"}, {pid: 3, command: "a"}];
    assert.deepEqual(plain(rows.slice().sort(lib.compare("name", true)).map(r => r.pid)), [2, 3, 1]);
});

test("pid is hidden by default but still a pickable column", () => {
    assert.ok(!lib.DEFAULT_COLUMNS.includes("pid"));
    assert.ok(lib.COLUMNS.some(c => c.id === "pid"));
});

test("process search matches pid regardless of visible columns", () => {
    const src = readFileSync(new URL("../Modules/ProcessList/ProcessesView.qml", import.meta.url), "utf8");
    assert.match(src, /pid\.includes\(search\)/);
    assert.ok(!/columns[^\n]*pid\.includes/.test(src));
});

test("absentReason separates measured, unreadable and unmonitored GPU cells", () => {
    assert.equal(lib.formatCell("gpu", {gpu: 3}, false), "3%");
    assert.equal(lib.absentReason("gpu", {pid: 1}), "unreadable");
    assert.equal(lib.absentReason("vram", {gpuUnmonitored: true}), "unmonitored");
    assert.equal(lib.absentReason("cpu", {gpuUnmonitored: true}), "unreadable");
});
