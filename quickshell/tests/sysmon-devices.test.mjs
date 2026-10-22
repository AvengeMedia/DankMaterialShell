import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const lib = loadScript(new URL("../Services/SysmonDevices.js", import.meta.url));
const plain = value => JSON.parse(JSON.stringify(value));

test("isWholeDisk accepts physical disks and rejects partitions and virtual devices", () => {
    for (const name of ["nvme0n1", "nvme12n3", "sda", "sdab", "vda", "xvda", "hda", "mmcblk0"])
        assert.equal(lib.isWholeDisk(name), true, name);
    for (const name of ["nvme0n1p2", "sda1", "mmcblk0p1", "dm-0", "md0", "loop3", "zram0", "sr0", "ram0", "", undefined])
        assert.equal(lib.isWholeDisk(name), false, String(name));
});

test("interfaceKind classifies names and hides loopback and virtual by default", () => {
    const table = {
        enp6s0: "ethernet", eth0: "ethernet", wlan0: "wifi", wlp3s0: "wifi", lo: "loopback",
        tailscale0: "vpn", wg0: "vpn", tun0: "vpn", proton0: "vpn", nordlynx: "vpn", ipv6leakintrf0: "vpn",
        docker0: "virtual", "br-4cbeaee1e7ab": "virtual", veth64f0b52: "virtual", virbr0: "virtual",
        bond0: "other"
    };
    for (const [name, kind] of Object.entries(table))
        assert.equal(lib.interfaceKind(name), kind, name);
    assert.equal(lib.isHiddenByDefault("loopback"), true);
    assert.equal(lib.isHiddenByDefault("virtual"), true);
    assert.equal(lib.isHiddenByDefault("vpn"), false);
    assert.equal(lib.isHiddenByDefault("ethernet"), false);
});

test("sumWholeDisks counts the whole disk once, not partitions or mappings", () => {
    const entries = [
        { name: "nvme0n1", r: 100, w: 10 },
        { name: "nvme0n1p1", r: 100, w: 10 },
        { name: "nvme0n1p2", r: 100, w: 10 },
        { name: "dm-0", r: 100, w: 10 }
    ];
    assert.deepEqual(plain(lib.sumWholeDisks(entries, "r", "w")), { read: 100, write: 10 });
    assert.deepEqual(plain(lib.sumWholeDisks([{ device: "sda", r: 5 }], "r", "w")), { read: 5, write: 0 });
});

test("formatTemp honors the unit and shows a dash when absent", () => {
    assert.equal(lib.formatTemp(52, false), "52 °C");
    assert.equal(lib.formatTemp(52, true), "126 °F");
    assert.equal(lib.formatTemp(0, false), "0 °C");
    assert.equal(lib.formatTemp(null, false), "—");
    assert.equal(lib.formatTemp(undefined, true), "—");
});

test("deviceKey joins type and id", () => {
    assert.equal(lib.deviceKey("disk", "nvme0n1"), "disk:nvme0n1");
});

test("naturalCompare orders numeric runs by value and letters lexically", () => {
    const sort = names => names.slice().sort(lib.naturalCompare);
    assert.deepEqual(sort(["nvme10n1", "nvme2n1"]), ["nvme2n1", "nvme10n1"]);
    assert.deepEqual(sort(["sdaa", "sdb", "sda"]), ["sda", "sdb", "sdaa"]);
});

test("gpuSlot prefers the bus id and falls back to the PCI id", () => {
    assert.equal(lib.gpuSlot({ busId: "0000:01:00.0", pciId: "10de:2684" }), "0000:01:00.0");
    assert.equal(lib.gpuSlot({ pciId: "10de:2684" }), "10de:2684");
});

test("gpuMonitored matches by vendor:device id or PCI bus id, case-insensitively; empty means none", () => {
    assert.equal(lib.gpuMonitored([], "10de:2684", "0000:01:00.0"), false);
    assert.equal(lib.gpuMonitored(undefined, "10de:2684", "0000:01:00.0"), false);
    assert.equal(lib.gpuMonitored(["10DE:2684"], "10de:2684", "0000:01:00.0"), true);
    assert.equal(lib.gpuMonitored(["0000:01:00.0"], "10de:2684", "0000:01:00.0"), true);
    assert.equal(lib.gpuMonitored(["1002:164e"], "10de:2684", "0000:01:00.0"), false);
    assert.equal(lib.gpuMonitored([""], "", ""), false);
});

test("interfaceKind falls back to dgop's link type only for unknown names", () => {
    assert.equal(lib.interfaceKind("ts0", "tunnel"), "vpn");
    assert.equal(lib.interfaceKind("mywifi", "wireless"), "wifi");
    assert.equal(lib.interfaceKind("bond0", "ethernet"), "ethernet");
    assert.equal(lib.interfaceKind("bond0", "other"), "other");
    assert.equal(lib.interfaceKind("docker0", "ethernet"), "virtual");
    assert.equal(lib.interfaceKind("enp6s0", undefined), "ethernet");
});

test("formatLinkSpeed, wifiBand and stripPrefixLength", () => {
    assert.equal(lib.formatLinkSpeed(1000), "1 Gbit/s");
    assert.equal(lib.formatLinkSpeed(2500), "2.5 Gbit/s");
    assert.equal(lib.formatLinkSpeed(100), "100 Mbit/s");
    assert.equal(lib.formatLinkSpeed(undefined), "");
    assert.equal(lib.formatLinkSpeed(-1), "");
    assert.equal(lib.wifiBand(2437), "2.4 GHz");
    assert.equal(lib.wifiBand(5180), "5 GHz");
    assert.equal(lib.wifiBand(5955), "6 GHz");
    assert.equal(lib.wifiBand(0), "");
    assert.equal(lib.stripPrefixLength("192.168.1.4/24"), "192.168.1.4");
    assert.equal(lib.stripPrefixLength("fe80::1"), "fe80::1");
});

test("rateAxisMax is the peak of both series plus 10%, with a floor", () => {
    assert.equal(lib.rateAxisMax([], [], 1024), 1024);
    assert.equal(lib.rateAxisMax([10, 2000], [5000], 1024), 5500);
    assert.equal(lib.rateAxisMax([10], undefined, 1024), 1024);
});

test("memoryModulesSummary totals sizes and lists each type once", () => {
    const g = 1048576;
    assert.equal(lib.memoryModulesSummary([{ size: 16 * g, type: "DDR4" }, { size: 16 * g, type: "DDR4" }]), "32 GiB DDR4");
    assert.equal(lib.memoryModulesSummary([{ size: 8 * g }]), "8 GiB");
    assert.equal(lib.memoryModulesSummary([{ size: 1.5 * g, type: "DDR5" }]), "1.5 GiB DDR5");
    assert.equal(lib.memoryModulesSummary([]), "");
    assert.equal(lib.memoryModulesSummary(null), "");
});
