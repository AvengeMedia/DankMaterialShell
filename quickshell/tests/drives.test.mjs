import assert from "node:assert/strict";
import vm from "node:vm";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const ctx = loadScript(new URL("../Modules/ProcessList/Drives.js", import.meta.url));
const D = vm.runInContext("({summaryRows, warnRows, healthLevel, healthWord, rootMostMount, spaceUsedRatio, partitionStrip, driveFor, driveByMount, parseReport, formatCapacity, driveSubtitle, maxThroughput})", ctx);
const plain = v => JSON.parse(JSON.stringify(v));
const ids = rows => plain(rows).map(r => r.id);
const GiB = 1024 ** 3;

const nvme = { name: "nvme0n1", kind: "nvme", health: "warning", nvme: { criticalWarning: [""], availableSpare: 5, spareThreshold: 10, percentUsed: 3, mediaErrors: 0, dataRead: 2 * 1024 ** 4, powerOnHours: 5000, selftestStatus: "success" } };
const hdd = { name: "sda", kind: "hdd", health: "ok", ata: { reallocatedSectors: 2, pendingSectors: 0, powerOnHours: 20, startStopCount: 10, spinUpTimeMs: 4000 } };

test("NVMe summary rows: ordered, absent fields skipped, warnings flagged", () => {
    const rows = plain(D.summaryRows(nvme));
    assert.deepEqual(ids(rows), ["criticalWarning", "spare", "wear", "mediaErrors", "dataRead", "powerOnTime", "selftest"]);
    assert.equal(rows[0].value, "none");
    assert.deepEqual(rows[1], { id: "spare", value: "5%", warn: true });
    assert.equal(rows[4].value, "2.0 TiB");
    assert.deepEqual([rows[5].value, rows[5].unit], ["208", "days"]);
    assert.equal(rows[6].value, "ok");
    assert.equal(D.warnRows(nvme).length, 1);
});

test("HDD summary rows and power-on units", () => {
    const rows = plain(D.summaryRows(hdd));
    assert.deepEqual(ids(rows), ["reallocated", "pending", "powerOnTime", "startStop", "spinUp"]);
    assert.equal(rows[0].warn, true);
    assert.deepEqual([rows[2].value, rows[2].unit], ["20", "hours"]);
    assert.equal(rows[4].value, "4000 ms");
    assert.equal(plain(D.summaryRows({ kind: "ssd", ata: { powerOnHours: 40000 } }))[0].unit, "years");
    assert.deepEqual(D.summaryRows({ kind: "hdd" }).length, 0);
});

test("healthLevel maps health and ATA failing, empty without SMART", () => {
    assert.equal(D.healthLevel(nvme), "warning");
    assert.equal(D.healthLevel(hdd), "healthy");
    assert.equal(D.healthLevel({ health: "ok", ata: { failing: true } }), "failing");
    assert.equal(D.healthLevel({ kind: "ssd" }), "");
});

test("partitionStrip keeps a tiny EFI partition at the minimum and matches mounts", () => {
    const drive = { partitions: [{ device: "/dev/nvme0n1p1", size: 4 * GiB, mountPoint: "/boot" }, { device: "/dev/nvme0n1p2", size: 1843 * GiB, mountPoint: "/", encrypted: true }, { device: "/dev/nvme0n1p3", size: 100 * GiB }] };
    const strip = plain(D.partitionStrip(drive, [{ mount: "/", percent: "24%" }]));
    assert.ok(strip[0].weight >= 0.04 - 1e-9);
    assert.ok(Math.abs(strip.reduce((s, p) => s + p.weight, 0) - 1) < 1e-9);
    assert.ok(strip[1].weight > strip[2].weight);
    assert.deepEqual(strip.map(s => s.label), ["/boot", "/", "nvme0n1p3"]);
    assert.deepEqual(strip.map(s => s.usedRatio), [null, 0.24, null]);
});

test("partitionStrip enforces the minimum for several tiny and near-threshold partitions", () => {
    const strip = sizes => plain(D.partitionStrip({ partitions: sizes.map((size, i) => ({ device: "/dev/p" + i, size })) }, []));
    for (const sizes of [[3, 3, 4.05, 89.95], [1, 1, 1, 1, 96], [0, 50, 50], [10, 10, 10]]) {
        const w = strip(sizes).map(s => s.weight);
        assert.ok(w.every(x => x >= 0.04 - 1e-9), JSON.stringify(w));
        assert.ok(Math.abs(w.reduce((a, b) => a + b, 0) - 1) < 1e-9);
    }
    assert.deepEqual(strip([0, 0]).map(s => s.weight), [0.5, 0.5]);
    assert.deepEqual(strip([undefined, 100, NaN]).map(s => s.weight).map(x => +x.toFixed(2)), [0.04, 0.92, 0.04]);
    const many = strip(Array(30).fill(1)).map(s => s.weight);
    assert.ok(many.every(x => Math.abs(x - 1 / 30) < 1e-9));
});

test("warn flags follow the health rules only", () => {
    const warn = d => plain(D.summaryRows(d)).filter(r => r.warn).map(r => r.id);
    assert.deepEqual(warn({ nvme: { criticalWarning: [""], percentUsed: 95, mediaErrors: 5, availableSpare: 50, spareThreshold: 10 } }), []);
    assert.deepEqual(warn({ nvme: { criticalWarning: ["spare"] } }), ["criticalWarning"]);
    assert.deepEqual(warn({ ata: { crcErrors: 9, selftestStatus: "failed", reallocatedSectors: 1, pendingSectors: 1, offlineUncorrectable: 1 } }), ["reallocated", "pending", "uncorrectable"]);
});

test("selftest row is omitted for unknown or empty status", () => {
    for (const st of ["", "unknown", null, undefined])
        assert.ok(!ids(D.summaryRows({ ata: { selftestStatus: st, powerOnHours: 1 } })).includes("selftest"), String(st));
    const row = D.summaryRows({ ata: { selftestStatus: "failed" } })[0];
    assert.equal(row.value, "error");
    assert.equal(D.summaryRows({ ata: { selftestStatus: "in progress" } })[0].value, "running");
});

test("parseReport lists NVMe error entries once and skips unnamed attributes", () => {
    const r = plain(D.parseReport(JSON.stringify({ nvme_smart_health_information_log: { temperature: 45, num_err_log_entries: 2 }, ata_smart_attributes: { table: [{ value: 1, worst: 1, thresh: 1 }, null, { name: "A", value: 1, worst: 1, thresh: 1 }] } })));
    const all = r.sections.flatMap(s => s.rows.map(x => x.key));
    assert.equal(all.filter(k => k === "num_err_log_entries").length, 1);
    assert.deepEqual(r.sections.find(s => s.id === "attributes").rows.map(x => x.key), ["A"]);
});

test("driveFor and driveByMount", () => {
    const drives = [nvme, { name: "sda", device: "/dev/sda", partitions: [{ mountPoint: "/data" }] }];
    assert.equal(D.driveFor("sda", drives).device, "/dev/sda");
    assert.equal(D.driveFor("/dev/sda", drives).name, "sda");
    assert.equal(D.driveFor("zzz", drives), null);
    assert.equal(D.driveByMount("/data", drives).name, "sda");
    assert.equal(D.driveByMount("/nope", drives), null);
});

test("parseReport: NVMe and ATA fixtures, tolerant of missing sections", () => {
    const n = plain(D.parseReport(JSON.stringify({ nvme_smart_health_information_log: { temperature: 45, percentage_used: 3, num_err_log_entries: 0 }, nvme_self_test_log: { table: [{ self_test_code: { string: "Short" }, self_test_result: { string: "Completed without error" }, power_on_hours: 100 }] } })));
    assert.equal(n.error, "");
    assert.deepEqual(n.sections.map(s => s.id), ["health", "selftest", "errors"]);
    assert.deepEqual(n.sections[0].rows[0], { key: "temperature", value: "45" });
    assert.equal(n.sections[1].rows[0].value, "Completed without error @ 100 h");

    const a = plain(D.parseReport(JSON.stringify({ ata_smart_attributes: { table: [{ name: "Reallocated_Sector_Ct", value: 100, worst: 100, thresh: 10, raw: { string: "0" } }] }, ata_smart_self_test_log: { standard: { table: [{ type: { string: "Short offline" }, status: { string: "Completed" }, lifetime_hours: 7 }] } }, ata_smart_error_log: { summary: { count: 0 } } })));
    assert.deepEqual(a.sections.map(s => s.id), ["attributes", "selftest", "errors"]);
    assert.equal(a.sections[0].rows[0].value, "100 / 100 / 10  0");
    assert.equal(a.sections[2].rows[0].value, "0");

    assert.deepEqual(plain(D.parseReport("{}")), { sections: [], error: "" });
});

test("parseReport: garbage and smartctl error messages surface as error", () => {
    assert.notEqual(D.parseReport("not json").error, "");
    assert.notEqual(D.parseReport("[1]").error, "");
    assert.equal(D.parseReport(JSON.stringify({ smartctl: { messages: [{ string: "Permission denied", severity: "error" }, { string: "x", severity: "information" }] } })).error, "Permission denied");
});

test("healthWord maps levels to label ids", () => {
    assert.deepEqual(["healthy", "warning", "failing", "", undefined].map(D.healthWord), ["ok", "warning", "critical", "", ""]);
});

test("rootMostMount prefers / then the shortest path", () => {
    const mk = (...m) => ({ partitions: m.map(mountPoint => ({ mountPoint })) });
    assert.equal(D.rootMostMount(mk("/boot", "/", "/home")), "/");
    assert.equal(D.rootMostMount(mk("/mnt/data/x", "/mnt/a", undefined)), "/mnt/a");
    assert.equal(D.rootMostMount(mk(undefined)), "");
    assert.equal(D.rootMostMount(null), "");
});

test("spaceUsedRatio weights mounted partitions by size", () => {
    const drive = { partitions: [{ mountPoint: "/", size: 300 }, { mountPoint: "/home", size: 100 }, { size: 500 }, { mountPoint: "/x", size: 100 }] };
    const mounts = [{ mount: "/", percent: "10%" }, { mount: "/home", percent: "50%" }];
    assert.equal(D.spaceUsedRatio(drive, mounts), 80 / 400);
    assert.equal(D.spaceUsedRatio(drive, []), -1);
    assert.equal(D.spaceUsedRatio(null, mounts), -1);
});

test("selftest status maps udisks SmartSelftestStatus values", () => {
    const v = st => D.summaryRows({ ata: { selftestStatus: st } })[0].value;
    assert.deepEqual(["success", "inprogress", "aborted", "fatal", "error_read"].map(v), ["ok", "running", "error", "error", "error"]);
});

test("formatCapacity uses decimal units like drive labels", () => {
    assert.deepEqual([2000398934016, 4000787030016, 500107862016, 256060514304, 1800000000000, 0, 512].map(D.formatCapacity), ["2 TB", "4 TB", "500 GB", "256 GB", "1.8 TB", "0 B", "512 B"]);
});

test("driveSubtitle joins kind, capacity and link, skipping what is missing", () => {
    assert.equal(D.driveSubtitle({ kind: "nvme", size: 2000398934016, pcieLink: "PCIe 4.0 x4" }), "NVMe SSD, 2 TB, PCIe 4.0 x4");
    assert.equal(D.driveSubtitle({ kind: "other", size: 0 }), "");
    assert.equal(D.driveSubtitle(null), "");
});

test("partitionStrip marks swap partitions and keeps sizes", () => {
    const strip = plain(D.partitionStrip({ partitions: [{ device: "/dev/sda1", size: 8, swap: true }, { device: "/dev/sda2", size: 92, fsType: "swap" }, { device: "/dev/sda3", size: 100, mountPoint: "/" }] }, []));
    assert.deepEqual(strip.map(s => [s.swap, s.mounted, s.size]), [[true, false, 8], [true, false, 92], [false, true, 100]]);
});

test("maxThroughput: PCIe lanes, else drive kind", () => {
    assert.equal(Math.round(D.maxThroughput({ kind: "nvme", pcieLink: "PCIe 4.0 x4" }) / 1e6), 7876);
    assert.equal(Math.round(D.maxThroughput({ kind: "nvme", pcieLink: "PCIe 3.0 x2" }) / 1e6), 1970);
    assert.equal(D.maxThroughput({ kind: "nvme" }), 3.5e9);
    assert.equal(D.maxThroughput({ kind: "ssd" }), 550e6);
    assert.equal(D.maxThroughput({ kind: "hdd" }), 250e6);
    assert.equal(D.maxThroughput(null), 550e6);
});
