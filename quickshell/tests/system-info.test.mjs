import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const S = loadScript(new URL("../Modules/ProcessList/SystemInfo.js", import.meta.url));
const plain = v => JSON.parse(JSON.stringify(v));
const names = { cpu: "CPU", gpu: "GPU", memory: "Memory" };

test("modeText formats wlr-output modes", () => {
    assert.equal(S.modeText({ width: 2560, height: 1440, refresh: 164958 }), "2560 × 1440, 165 Hz");
    assert.equal(S.modeText({ width: 1920, height: 1080 }), "1920 × 1080");
    assert.equal(S.modeText(null), "");
});

test("sensorRows names owners, scales bars and orders by kind", () => {
    const sensors = [
        { chip: "amdgpu", device: "0000:0c:00.0", label: "PPT", kind: "power", value: 38.2, max: 327 },
        { chip: "asusec", device: "asus-ec-sensors", label: "CPU_Opt", kind: "fan", value: 812.4 },
        { chip: "jc42", device: "10-001a", label: "temp1", kind: "temperature", value: 40 },
        { chip: "jc42", device: "10-001b", label: "temp1", kind: "temperature", value: 41 },
        { chip: "k10temp", device: "0000:00:18.3", label: "Tctl", kind: "temperature", value: 61 },
        { chip: "nvme", device: "nvme0", label: "Composite", kind: "temperature", value: 42, critical: 84, max: 82 },
        { chip: "nvme", device: "nvme0", label: "Sensor 1", kind: "temperature", value: 50 },
        { chip: "amdgpu", device: "0000:0c:00.0", label: "edge", kind: "temperature", value: 48, critical: 100 }
    ];
    const drives = [{ name: "nvme0n1", model: "Samsung SSD 990 PRO 2TB" }];
    const rows = plain(S.sensorRows(sensors, drives, [], names, false));
    assert.deepEqual(rows.map(r => r.name), ["Memory 1", "Memory 2", "CPU (Tctl)", "Samsung SSD 990 PRO 2TB", "Samsung SSD 990 PRO 2TB (Sensor 1)", "GPU (edge)", "CPU Opt", "GPU (PPT)"]);
    assert.deepEqual(rows.map(r => r.value), ["40 °C", "41 °C", "61 °C", "42 °C", "50 °C", "48 °C", "812 RPM", "38 W"]);
    assert.equal(rows[0].ratio, 0.4);
    assert.equal(rows[3].ratio, 42 / 84);
    assert.equal(rows[6].ratio, null);
    assert.ok(Math.abs(rows[7].ratio - 38.2 / 327) < 1e-9);
});

test("sensorRows uses GPU names only when there are several GPUs", () => {
    const s = [{ chip: "amdgpu", device: "0000:0C:00.0", label: "edge", kind: "temperature", value: 48 }];
    const gpus = [{ busId: "0000:0c:00.0", fullName: "RX 7900 XTX" }, { busId: "0000:01:00.0", fullName: "RTX 3060" }];
    assert.equal(S.sensorRows(s, [], gpus, names, false)[0].name, "RX 7900 XTX (edge)");
    assert.equal(S.sensorRows(s, [], gpus.slice(0, 1), names, false)[0].name, "GPU (edge)");
    assert.equal(S.sensorRows(s, [], [], names, true)[0].value, "118 °F");
});

test("report leaves out private and empty rows and empty sections", () => {
    const text = S.report("System report", [
        { title: "About", rows: [{ label: "Kernel", value: "7.2" }, { label: "Init", value: "" }, { label: "Hostname", value: "rog", private: true }] },
        { title: "Network", rows: [{ label: "Wi-Fi", value: "home", private: true }] }
    ]);
    assert.equal(text, "### System report\n\n**About**\n- Kernel: 7.2");
});

test("summary is one bullet per line", () => {
    assert.equal(S.summary(["DMS 1.7", "", "CachyOS"]), "- DMS 1.7\n- CachyOS");
});

test("version, packages, Mesa, DMI model and chassis", () => {
    assert.equal(S.version("Hyprland 0.56.2 built from branch v0.56.2"), "0.56.2");
    assert.equal(S.version("niri 25.08 (abc)"), "25.08");
    assert.equal(S.packagesText({ "pkg.pacman": "2088", "pkg.rpm": "0", "pkg.flatpak": "17", "qs": "x" }), "2088 pacman, 17 flatpak");
    assert.equal(S.mesaVersion({ "vk.info": "Mesa 26.2.4-arch3.1" }), "26.2.4");
    assert.equal(S.mesaVersion({ gl: "4.6 (Compatibility Profile) Mesa 25.1" }), "25.1");
    assert.equal(S.dmiModel({ "dmi.sys_vendor": "ASUS", "dmi.product_name": "System Product Name" }), "");
    assert.equal(S.dmiModel({ "dmi.sys_vendor": "LENOVO", "dmi.product_name": "ThinkPad X1" }), "LENOVO ThinkPad X1");
    assert.equal(S.chassisKind("3"), "desktop");
    assert.equal(S.chassisKind(10), "laptop");
    assert.equal(S.chassisKind(2), "");
});
