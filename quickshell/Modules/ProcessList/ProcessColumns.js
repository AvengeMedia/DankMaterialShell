.pragma library
.import "../../Services/SysmonDevices.js" as Devices
.import "../../Services/ProcessSort.js" as ProcessSort

// width is in Theme.fontSizeSmall units. meter picks the fill bar's maximum (see meterMax).
const COLUMNS = [
    {id: "cpu", sortKey: "cpu", width: 7, meter: "percent"},
    {id: "memory", sortKey: "memory", width: 8, meter: "memory"},
    {id: "gpu", sortKey: "gpu", width: 6, meter: "percent", modules: ["process-gpu"]},
    {id: "vram", sortKey: "vram", width: 7, meter: "vram", modules: ["process-gpu", "gpu-stats"]},
    {id: "gpuVideo", sortKey: "gpuVideo", width: 6, meter: "percent", modules: ["process-gpu"]},
    {id: "diskRead", sortKey: "diskRead", group: "disk", width: 7, meter: "disk", modules: ["process-io", "disk"]},
    {id: "diskWrite", sortKey: "diskWrite", group: "disk", width: 7, meter: "disk", modules: ["process-io", "disk"]},
    {id: "connections", sortKey: "connections", group: "network", width: 5, modules: ["process-net"]},
    {id: "netRx", sortKey: "netRx", group: "network", width: 7, meter: "net", modules: ["process-net", "network"]},
    {id: "netTx", sortKey: "netTx", group: "network", width: 7, meter: "net", modules: ["process-net", "network"]},
    {id: "status", sortKey: "status", width: 7},
    {id: "threads", sortKey: "threads", width: 5},
    {id: "nice", sortKey: "nice", width: 4},
    {id: "cpuTime", sortKey: "cpuTime", width: 6},
    {id: "pid", sortKey: "pid", width: 5},
    {id: "user", sortKey: "user", width: 8}
];

const DEFAULT_COLUMNS = ["cpu", "memory", "gpu", "vram", "diskRead", "diskWrite", "connections", "netRx", "netTx"];
const POPOUT_COLUMNS = ["cpu", "memory", "pid"];

// Rate meters scale to the device peak x1.1, never below these floors (bytes/s).
const DISK_FLOOR = 1024 * 1024;
const NET_FLOOR = 100 * 1024;

function _col(id) {
    return COLUMNS.find(c => c.id === id) || null;
}

function modulesFor(columnIds) {
    const out = [];
    for (const id of columnIds) {
        for (const m of _col(id)?.modules ?? []) {
            if (!out.includes(m))
                out.push(m);
        }
    }
    return out;
}

function rawValue(id, row) {
    return ProcessSort.rawValue(id, row);
}
const compare = ProcessSort.compare;

// Peak of one or more history series x1.1, at least floor.
function peakMax(seriesList, floor) {
    let peak = 0;
    for (const s of seriesList)
        for (const v of s ?? [])
            if (typeof v === "number" && v > peak)
                peak = v;
    return Math.max(floor, peak * 1.1);
}

// maxes: {memory: total KB, vram: bytes, disk: bytes/s, net: bytes/s}.
function meterMax(id, maxes) {
    switch (_col(id)?.meter) {
    case "percent": return 100;
    case "memory": return maxes.memory || 0;
    case "vram": return maxes.vram || 0;
    case "disk": return Math.max(DISK_FLOOR, maxes.disk || 0);
    case "net": return Math.max(NET_FLOOR, maxes.net || 0);
    }
    return 0;
}

// Fill of the meter bar, 0..1; vram is compared in bytes.
function meterRatio(id, row, maxes) {
    const max = meterMax(id, maxes);
    let v = rawValue(id, row);
    if (!max || v === null)
        return 0;
    if (id === "vram")
        v *= 1024;
    return Math.max(0, Math.min(1, v / max));
}

function formatDuration(seconds) {
    const s = Math.floor(seconds);
    const pad = n => String(n).padStart(2, "0");
    const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60;
    return h > 0 ? h + ":" + pad(m) + ":" + pad(s % 60) : m + ":" + pad(s % 60);
}

// null means absent: the caller shows an em dash. status stays the raw letter.
function formatCell(id, row, bits) {
    const v = rawValue(id, row);
    if (v === null)
        return null;
    switch (id) {
    case "cpu": return v.toFixed(1) + "%";
    case "gpu":
    case "gpuVideo": return v.toFixed(0) + "%";
    case "memory":
    case "vram": return Devices.formatBytes(v * 1024);
    case "diskRead":
    case "diskWrite":
    case "netRx":
    case "netTx": return Devices.formatRate(v, bits);
    case "cpuTime": return formatDuration(v);
    case "connections":
    case "threads":
    case "nice":
    case "pid": return String(v);
    case "status":
    case "user": return v;
    }
    return null;
}

// Why a cell is absent: a GPU the user doesn't monitor, or a process we can't read.
function absentReason(id, row) {
    return (id === "gpu" || id === "vram" || id === "gpuVideo") && row?.gpuUnmonitored === true ? "unmonitored" : "unreadable";
}
