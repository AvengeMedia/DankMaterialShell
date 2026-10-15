.pragma library
.import "../../Services/SysmonDevices.js" as Devices
.import "Drives.js" as Drives

const CPU_CHIPS = ["k10temp", "coretemp", "zenpower", "cpu_thermal"];
const GPU_CHIPS = ["amdgpu", "radeon", "nouveau", "nvidia", "i915", "xe"];
const MEMORY_CHIPS = ["jc42", "spd5118"];
const KIND_ORDER = ["temperature", "fan", "power"];
const FALLBACK_TEMP_LIMIT = 100;

// "2 TB + 4 TB NVMe"; the kind is added only when every drive shares it.
function storageSummary(drives) {
    const list = (drives || []).filter(d => d.size > 0);
    if (!list.length)
        return "";
    const sizes = list.map(d => Drives.formatCapacity(d.size)).join(" + ");
    const kinds = [...new Set(list.map(d => d.kind))];
    const kind = kinds.length === 1 ? ({ nvme: "NVMe", ssd: "SSD", hdd: "HDD" })[kinds[0]] : "";
    return kind ? sizes + " " + kind : sizes;
}

// wlr-output mode {width, height, refresh (mHz)} -> "2560 × 1440, 165 Hz".
function modeText(mode) {
    if (!mode || !(mode.width > 0))
        return "";
    const size = mode.width + " × " + mode.height;
    return mode.refresh > 0 ? size + ", " + Math.round(mode.refresh / 1000) + " Hz" : size;
}

// Sensor owner name: names = {cpu, gpu, memory} (translated), drives from DriveService, gpus = DgopService.availableGpus.
function sensorOwner(sensor, drives, gpus, names, memoryIndex) {
    const chip = sensor.chip || "";
    if (CPU_CHIPS.includes(chip))
        return names.cpu;
    if (GPU_CHIPS.includes(chip)) {
        const list = gpus || [];
        const gpu = list.length > 1 ? list.find(g => String(g.busId).toLowerCase() === String(sensor.device).toLowerCase()) : null;
        return (gpu && gpu.fullName) || names.gpu;
    }
    if (chip === "nvme") {
        const drive = (drives || []).find(d => String(d.name).startsWith(sensor.device + "n"));
        return (drive && drive.model) || sensor.device || chip;
    }
    if (MEMORY_CHIPS.includes(chip))
        return names.memory + " " + memoryIndex;
    return "";
}

// Display rows for dgop sensors: {name, kind, value, ratio}; ratio is null when there is no limit to scale against.
function sensorRows(sensors, drives, gpus, names, fahrenheit) {
    const memoryDevices = [];
    // -40 °C or below is an unconnected header probe (e.g. a board's T_Sensor or Water_In), not a reading.
    const rows = (sensors || []).filter(s => !(s.kind === "temperature" && s.value <= -40)).map(s => {
        if (MEMORY_CHIPS.includes(s.chip) && !memoryDevices.includes(s.device))
            memoryDevices.push(s.device);
        const owner = sensorOwner(s, drives, gpus, names, memoryDevices.indexOf(s.device) + 1);
        const generic = /^(temp|fan|power)\d+$/.test(s.label || "") || (s.chip === "nvme" && s.label === "Composite");
        const detail = generic && owner ? "" : String(s.label || s.chip || "").replace(/_/g, " ");
        const name = owner && detail ? owner + " (" + detail + ")" : owner || detail;
        let limit = s.critical > 0 ? s.critical : s.max > 0 ? s.max : null;
        let value;
        if (s.kind === "temperature") {
            limit = limit || FALLBACK_TEMP_LIMIT;
            value = Devices.formatTemp(s.value, fahrenheit);
        } else if (s.kind === "fan") {
            value = Math.round(s.value) + " RPM";
        } else {
            value = (s.value < 10 ? s.value.toFixed(1) : Math.round(s.value)) + " W";
        }
        return {
            name: name,
            kind: s.kind,
            value: value,
            ratio: limit ? Math.max(0, Math.min(1, s.value / limit)) : null
        };
    });
    const rank = k => KIND_ORDER.includes(k) ? KIND_ORDER.indexOf(k) : KIND_ORDER.length;
    return rows.map((r, i) => [r, i]).sort((a, b) => rank(a[0].kind) - rank(b[0].kind) || a[1] - b[1]).map(x => x[0]);
}

// Plain-text copy: one "Label: value" line per row, sections separated by a blank line.
function plainText(title, sections) {
    const blocks = sections.map(s => [s.title].concat(s.rows.filter(r => r.value).map(r => r.label + ": " + r.value)).join("\n"));
    return [title].concat(blocks).filter(b => b).join("\n\n");
}
