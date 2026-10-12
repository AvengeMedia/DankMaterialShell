import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const S = loadScript(new URL("../Modules/ProcessList/SystemInfo.js", import.meta.url));
const plain = v => JSON.parse(JSON.stringify(v));
const names = { cpu: "CPU", gpu: "GPU", memory: "Memory" };

test("storageSummary adds the kind only when all drives share it", () => {
    assert.equal(S.storageSummary([{ size: 2000398934016, kind: "nvme" }, { size: 4000787030016, kind: "nvme" }]), "2 TB + 4 TB NVMe");
    assert.equal(S.storageSummary([{ size: 2e12, kind: "nvme" }, { size: 4e12, kind: "hdd" }]), "2 TB + 4 TB");
    assert.equal(S.storageSummary([]), "");
});

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
    const gpus = [{ pciSlot: "0000:0c:00.0", name: "RX 7900 XTX" }, { pciSlot: "0000:01:00.0", name: "RTX 3060" }];
    assert.equal(S.sensorRows(s, [], gpus, names, false)[0].name, "RX 7900 XTX (edge)");
    assert.equal(S.sensorRows(s, [], gpus.slice(0, 1), names, false)[0].name, "GPU (edge)");
    assert.equal(S.sensorRows(s, [], [], names, true)[0].value, "118 °F");
});

test("plainText skips empty values", () => {
    const text = S.plainText("rog", [{ title: "Software", rows: [{ label: "Kernel", value: "7.2" }, { label: "Init", value: "" }] }]);
    assert.equal(text, "rog\n\nSoftware\nKernel: 7.2");
});
