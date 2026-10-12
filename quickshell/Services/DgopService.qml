pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import "SysmonDevices.js" as SysmonDevices
import "ProcessSort.js" as ProcessSort

Singleton {
    id: root
    readonly property var log: Log.scoped("DgopService")

    signal statsUpdated

    property int refCount: 0
    readonly property bool powerSaver: pollingActive && PowerProfileWatcher.currentProfile === PowerProfile.PowerSaver
    property int updateInterval: powerSaver ? 6000 : 3000
    property bool isUpdating: false
    property bool pendingUpdate: false
    property int subscriptionGeneration: 0
    readonly property bool pollingActive: dgopAvailable && refCount > 0 && enabledModules.length > 0
    readonly property bool dgopAvailable: DMSService.isConnected && DMSService.capabilities.includes("dgop")
    property bool sessionGpuIdsSeeded: false
    property bool _metaWanted: false
    property bool _metaLoaded: false

    property var moduleRefCounts: ({})
    property var enabledModules: []
    property var gpuPciIds: []
    property var gpuPciIdRefCounts: ({})
    property int processLimit: 20
    // Views that search processes need every process, not just the top ones by CPU
    property int fullProcessListRefs: 0
    property string processSort: "cpu"
    property bool noCpu: false

    // Cursor data for accurate CPU calculations
    property string cpuCursor: ""
    property string procCursor: ""
    property string diskRateCursor: ""
    property string netRateCursor: ""
    property string gpuStatsCursor: ""
    property int cpuSampleCount: 0

    property real cpuUsage: 0
    property real cpuFrequency: 0
    property real cpuTemperature: 0
    property int cpuCores: 1
    property string cpuModel: ""
    property var perCoreCpuUsage: []

    property real memoryUsage: 0
    property real totalMemoryMB: 0
    property real usedMemoryMB: 0
    property real freeMemoryMB: 0
    property real availableMemoryMB: 0
    property int totalMemoryKB: 0
    property int usedMemoryKB: 0
    property int totalSwapKB: 0
    property int usedSwapKB: 0

    property real networkRxRate: 0
    property real networkTxRate: 0
    property var lastNetworkStats: null
    property var networkInterfaces: []

    property real diskReadRate: 0
    property real diskWriteRate: 0
    property var lastDiskStats: null
    property var diskMounts: []
    property bool diskMountsRequested: false
    property var diskDevices: []
    property var diskRates: []
    property var netRates: []
    property var memoryInfo: null
    property var bios: null
    property var cpuInfo: null
    property var gpuStats: []
    property var sensors: []
    property var memoryModules: null
    property var availableModules: []

    property var processes: []
    property var allProcesses: []
    property string currentSort: "cpu"
    property bool sortAscending: false
    property var availableGpus: []

    property string kernelVersion: ""
    property string distribution: ""
    property string hostname: ""
    property string architecture: ""
    property string loadAverage: ""
    property int processCount: 0
    property int threadCount: 0
    property int openFileCount: 0
    property string initSystem: ""
    property string bootTime: ""
    property string motherboard: ""
    property string biosVersion: ""
    property string uptime: ""
    property string shortUptime: ""

    readonly property int historySize: 60
    property var cpuHistory: []
    property var memoryHistory: []
    property var networkHistory: ({
            "rx": [],
            "tx": []
        })
    property var diskHistory: ({
            "read": [],
            "write": []
        })
    property int deviceHistorySize: 60
    property var deviceHistory: ({})

    function ensureMeta() {
        _metaWanted = true;
        if (_metaLoaded || !dgopAvailable)
            return;
        _metaLoaded = true;
        initializeModules();
        initializeSystemMetadata();
        initializeGpuMetadata();
    }

    function addRef(modules = null) {
        ensureMeta();
        refCount++;
        let modulesChanged = false;

        if (modules) {
            const modulesToAdd = Array.isArray(modules) ? modules : [modules];
            for (const module of modulesToAdd) {
                const currentCount = moduleRefCounts[module] || 0;
                moduleRefCounts[module] = currentCount + 1;

                // Add to enabled modules if not already there
                if (enabledModules.indexOf(module) === -1) {
                    enabledModules.push(module);
                    modulesChanged = true;
                }
            }
        }

        if (modulesChanged)
            subscriptionGeneration++;

        if (hasModule("system"))
            updateUptime();

        if (modulesChanged || refCount === 1) {
            enabledModules = enabledModules.slice(); // Force property change
            moduleRefCounts = Object.assign({}, moduleRefCounts); // Force property change
            updateAllStats();
        } else if (gpuPciIds.length > 0 && refCount > 0) {
            // If we have GPU PCI IDs and active modules, make sure to update
            // This handles the case where PCI IDs were loaded after modules were added
            updateAllStats();
        }
    }

    // Searching only the top processes by CPU makes idle matches appear and
    // vanish between refreshes (#3641), so a search asks for the whole list.
    function requestFullProcessList() {
        fullProcessListRefs++;
        if (fullProcessListRefs === 1)
            updateAllStats();
    }

    function releaseFullProcessList() {
        fullProcessListRefs = Math.max(0, fullProcessListRefs - 1);
    }

    function removeRef(modules = null) {
        refCount = Math.max(0, refCount - 1);
        let modulesChanged = false;

        if (modules) {
            const modulesToRemove = Array.isArray(modules) ? modules : [modules];
            for (const module of modulesToRemove) {
                const currentCount = moduleRefCounts[module] || 0;
                if (currentCount > 1) {
                    moduleRefCounts[module] = currentCount - 1;
                } else if (currentCount === 1) {
                    delete moduleRefCounts[module];
                    const index = enabledModules.indexOf(module);
                    if (index > -1) {
                        enabledModules.splice(index, 1);
                        modulesChanged = true;
                    }
                }
            }
        }

        if (!modulesChanged)
            return;
        subscriptionGeneration++;
        enabledModules = enabledModules.slice();
        moduleRefCounts = Object.assign({}, moduleRefCounts);
        releaseUnusedData();
        pendingUpdate = pollingActive && isUpdating;
        if (!pollingActive)
            primeTimer.stop();
    }

    function hasModule(module) {
        return refCount > 0 && (enabledModules.includes(module) || enabledModules.includes("all"));
    }

    function releaseUnusedData() {
        if (!hasModule("cpu")) {
            cpuCursor = "";
            cpuSampleCount = 0;
            cpuHistory = [];
            perCoreCpuUsage = [];
            cpuInfo = null;
            removeDeviceHistory("cpu");
        }
        if (!hasModule("memory")) {
            memoryHistory = [];
            memoryInfo = null;
            removeDeviceHistory("memory");
        }
        if (!hasModule("disk-rate")) {
            diskRateCursor = "";
            diskRates = [];
            removeDeviceHistory("disk");
        }
        if (!hasModule("net-rate")) {
            netRateCursor = "";
            netRates = [];
            removeDeviceHistory("net");
        }
        if (!hasModule("gpu-stats")) {
            gpuStatsCursor = "";
            gpuStats = [];
            removeDeviceHistory("gpu");
        }
        if (!hasModule("sensors"))
            sensors = [];
        if (!hasModule("memory-modules"))
            memoryModules = null;
        if (!hasModule("network")) {
            networkHistory = {
                rx: [],
                tx: []
            };
            networkInterfaces = [];
            lastNetworkStats = null;
            networkRxRate = 0;
            networkTxRate = 0;
        }
        if (!hasModule("disk")) {
            diskHistory = {
                read: [],
                write: []
            };
            diskDevices = [];
            lastDiskStats = null;
            diskReadRate = 0;
            diskWriteRate = 0;
        }
        if (!hasModule("processes")) {
            procCursor = "";
            allProcesses = [];
            processes = [];
        } else if (!hasModule("process-gpu") || !hasModule("process-io") || !hasModule("process-net")) {
            const noGpu = !hasModule("process-gpu");
            const noIo = !hasModule("process-io");
            const noNet = !hasModule("process-net");
            allProcesses = allProcesses.map(p => Object.assign({}, p, noGpu ? {
                    "gpu": null,
                    "gpuVideo": null,
                    "vramKB": null,
                    "gpuGtt": null,
                    "gpuUnmonitored": true
                } : {}, noIo ? {
                    "diskRead": null,
                    "diskWrite": null
                } : {}, noNet ? {
                    "connections": null,
                    "remotes": [],
                    "netRx": null,
                    "netTx": null
                } : {}));
            applySorting();
        }
    }

    function removeDeviceHistory(prefix) {
        const next = {};
        let changed = false;
        for (const key of Object.keys(deviceHistory)) {
            if (key === prefix || key.startsWith(prefix + ":"))
                changed = true;
            else
                next[key] = deviceHistory[key];
        }
        if (changed)
            deviceHistory = next;
    }

    // Appends one sample per key to `history` in place and drops keys under `prefix` missing from `liveKeys` (null keeps all).
    function pushDeviceHistory(history, prefix, samples, liveKeys) {
        if (liveKeys) {
            for (const key of Object.keys(history)) {
                if (key.startsWith(prefix + ":") && !liveKeys.includes(key))
                    delete history[key];
            }
        }
        for (const sample of samples) {
            const old = history[sample.key] || {
                a: [],
                b: []
            };
            history[sample.key] = {
                a: SysmonDevices.appendHistory(old.a, sample.a, deviceHistorySize),
                b: sample.b === undefined ? old.b : SysmonDevices.appendHistory(old.b, sample.b, deviceHistorySize)
            };
        }
    }

    function setGpuMonitoring(pciId, on) {
        if (!pciId)
            return;
        const ids = SessionData.enabledGpuPciIds ? SessionData.enabledGpuPciIds.slice() : [];
        const idx = ids.indexOf(pciId);
        if (on && idx === -1) {
            ids.push(pciId);
            addGpuPciId(pciId);
        } else if (!on && idx !== -1) {
            ids.splice(idx, 1);
            removeGpuPciId(pciId);
        } else {
            return;
        }
        SessionData.setEnabledGpuPciIds(ids);
        if (refCount > 0)
            updateAllStats();
    }

    function gpuHeldByWidget(pciId) {
        const id = String(pciId).toLowerCase();
        const held = Object.keys(gpuPciIdRefCounts).some(k => k.toLowerCase() === id && gpuPciIdRefCounts[k] > 0);
        return held && !(SessionData.enabledGpuPciIds || []).some(e => String(e).toLowerCase() === id);
    }

    function addGpuPciId(pciId) {
        ensureMeta();
        const currentCount = gpuPciIdRefCounts[pciId] || 0;
        gpuPciIdRefCounts[pciId] = currentCount + 1;

        // Add to gpuPciIds array if not already there
        if (!gpuPciIds.includes(pciId)) {
            gpuPciIds = gpuPciIds.concat([pciId]);
        }

        gpuPciIdRefCounts = Object.assign({}, gpuPciIdRefCounts);
    }

    function removeGpuPciId(pciId) {
        const currentCount = gpuPciIdRefCounts[pciId] || 0;
        if (currentCount > 1) {
            gpuPciIdRefCounts[pciId] = currentCount - 1;
        } else if (currentCount === 1) {
            // Remove completely when count reaches 0
            delete gpuPciIdRefCounts[pciId];
            const index = gpuPciIds.indexOf(pciId);
            if (index > -1) {
                gpuPciIds = gpuPciIds.slice();
                gpuPciIds.splice(index, 1);
            }

            // Clear temperature data for this GPU when no longer monitored
            if (availableGpus && availableGpus.length > 0) {
                const updatedGpus = availableGpus.slice();
                for (var i = 0; i < updatedGpus.length; i++) {
                    if (updatedGpus[i].pciId === pciId) {
                        updatedGpus[i] = Object.assign({}, updatedGpus[i], {
                            "temperature": 0
                        });
                    }
                }
                availableGpus = updatedGpus;
            }
        }

        // Force property change notification
        gpuPciIdRefCounts = Object.assign({}, gpuPciIdRefCounts);
    }

    function updateAllStats() {
        if (!pollingActive) {
            pendingUpdate = false;
            return;
        }
        if (isUpdating) {
            pendingUpdate = true;
            return;
        }

        const params = buildMetaParams();
        if (!params) {
            pendingUpdate = false;
            return;
        }

        isUpdating = true;
        const generation = subscriptionGeneration;
        DMSService.sendRequest("dgop.meta", params, response => {
            if (!response.result) {
                log.warn("dgop.meta failed:", response.error || "empty result");
            } else if (pollingActive && generation === subscriptionGeneration) {
                parseData(response.result);
            }

            isUpdating = false;
            if (pendingUpdate && pollingActive) {
                pendingUpdate = false;
                primeTimer.restart();
            }
        });
    }

    function initializeGpuMetadata() {
        if (!dgopAvailable)
            return;
        DMSService.sendRequest("dgop.gpu", null, response => {
            if (!response.result) {
                log.warn("dgop.gpu failed:", response.error || "empty result");
                return;
            }
            parseData(response.result);
        });
    }

    // On-demand fields of one process (IO totals, swap, open files, systemd unit); callback gets null on failure.
    function fetchProcessDetail(pid, callback) {
        DMSService.sendRequest("dgop.process", {
            "pid": pid
        }, response => callback(response.result ?? null));
    }

    function initializeModules() {
        DMSService.sendRequest("dgop.modules", null, response => {
            if (!response.result) {
                log.warn("dgop.modules failed:", response.error || "empty result");
                return;
            }
            availableModules = response.result.available ?? [];
            if (pollingActive)
                updateAllStats();
        });
    }

    // GetMeta fails the whole call on an unknown module, so never send one dgop didn't list.
    function isModuleAvailable(module) {
        if (availableModules.length > 0)
            return availableModules.includes(module);
        return !["gpu-stats", "sensors", "memory-modules", "process-gpu", "process-io", "process-net"].includes(module);
    }

    function initializeSystemMetadata() {
        if (!dgopAvailable)
            return;
        DMSService.sendRequest("dgop.meta", {
            modules: ["hardware", "system"]
        }, response => {
            if (!response.result) {
                log.warn("Initial system metadata request failed:", response.error || "empty result");
                return;
            }
            parseData(response.result);
        });
    }

    function initializeDiskMounts() {
        if (!dgopAvailable || diskMountsRequested || hasModule("diskmounts"))
            return;
        if (!SettingsData.controlCenterWidgets.some(widget => widget.id === "diskUsage" && widget.enabled !== false))
            return;
        diskMountsRequested = true;
        const previousMounts = diskMounts;
        DMSService.sendRequest("dgop.meta", {
            modules: ["diskmounts"]
        }, response => {
            if (!response.result?.diskmounts) {
                log.warn("Initial disk mounts request failed:", response.error || "empty result");
                return;
            }
            if (diskMounts !== previousMounts)
                return;
            diskMounts = response.result.diskmounts;
        });
    }

    Connections {
        target: SettingsData
        function onControlCenterWidgetsChanged() {
            root.initializeDiskMounts();
        }
    }

    function buildMetaParams() {
        if (enabledModules.length === 0)
            return null;

        // Replace 'gpu' with 'gpu-temp' when we have PCI IDs to monitor
        let finalModules = [];
        for (const module of enabledModules) {
            if (module === "gpu" && gpuPciIds.length > 0) {
                finalModules.push("gpu-temp");
            } else if (module !== "gpu") {
                finalModules.push(module);
            }
        }

        if (hasModule("gpu") && gpuPciIds.length > 0 && finalModules.indexOf("gpu-temp") === -1) {
            finalModules.push("gpu-temp");
        }
        finalModules = finalModules.filter(module => module === "all" || isModuleAvailable(module));

        const params = {};
        if (enabledModules.indexOf("all") !== -1) {
            params.modules = ["all"];
        } else if (finalModules.length > 0) {
            params.modules = finalModules;
        } else {
            return null;
        }

        // Cursor data enables accurate CPU percentages between samples
        if ((enabledModules.includes("cpu") || enabledModules.includes("all")) && cpuCursor) {
            params.cpuCursor = cpuCursor;
        }
        if ((enabledModules.includes("processes") || enabledModules.includes("all")) && procCursor) {
            params.procCursor = procCursor;
        }
        if (enabledModules.includes("disk-rate") && diskRateCursor) {
            params.diskRateCursor = diskRateCursor;
        }
        if (enabledModules.includes("net-rate") && netRateCursor) {
            params.netRateCursor = netRateCursor;
        }
        if (finalModules.includes("net-rate")) {
            params.netRateAllInterfaces = true;
        }
        if (finalModules.includes("gpu-stats") && gpuStatsCursor) {
            params.gpuStatsCursor = gpuStatsCursor;
        }

        // Always sent: a missing key means "all GPUs" to dgop, and [] means none.
        params.gpuPciIds = gpuPciIds;

        if (enabledModules.indexOf("processes") !== -1 || enabledModules.indexOf("all") !== -1) {
            // 0 means no limit in dgop
            params.limit = fullProcessListRefs > 0 ? 0 : 100;
            const mod = currentSort === "gpu" || currentSort === "vram" ? "process-gpu" : currentSort.startsWith("disk") ? "process-io" : "";
            params.sort = mod && enabledModules.includes(mod) && isModuleAvailable(mod) ? (mod === "process-io" ? "disk" : currentSort) : "cpu";
            if (noCpu) {
                params.noCpu = true;
            }
        }

        return params;
    }

    function parseData(data) {
        const sampleTime = Date.now();
        const history = Object.assign({}, deviceHistory);
        let historyChanged = false;
        if (hasModule("cpu") && data.cpu) {
            const cpu = data.cpu;
            cpuSampleCount++;

            cpuUsage = Math.round((cpu.usage || 0) * 10) / 10;
            cpuFrequency = Math.round(cpu.frequency || 0);
            cpuTemperature = Math.round(cpu.temperature || 0);
            cpuCores = cpu.count || 1;
            cpuModel = cpu.model || "";
            perCoreCpuUsage = cpu.coreUsage || [];
            cpuInfo = cpu;
            cpuHistory = appendHistory(cpuHistory, cpuUsage);
            historyChanged = true;
            pushDeviceHistory(history, "cpu", [
                {
                    key: "cpu",
                    a: cpuUsage
                }
            ], null);

            if (cpu.cursor) {
                cpuCursor = cpu.cursor;
            }

            if (cpuSampleCount === 1) {
                primeTimer.restart();
            }
        }

        if (hasModule("memory") && data.memory) {
            const mem = data.memory;
            const totalKB = mem.total || 0;
            const availableKB = mem.available || 0;
            const freeKB = mem.free || 0;
            const usedKB = mem.used !== undefined ? mem.used : (totalKB - availableKB);

            totalMemoryMB = Math.round(totalKB / 1024);
            availableMemoryMB = Math.round(availableKB / 1024);
            freeMemoryMB = Math.round(freeKB / 1024);
            usedMemoryMB = Math.round(usedKB / 1024);
            const rawMemUsage = mem.usedPercent !== undefined ? mem.usedPercent : (totalKB > 0 ? ((totalKB - availableKB) / totalKB) * 100 : 0);
            memoryUsage = Math.round(rawMemUsage * 10) / 10;

            totalMemoryKB = totalKB;
            usedMemoryKB = usedKB;
            totalSwapKB = mem.swaptotal || 0;
            usedSwapKB = (mem.swaptotal || 0) - (mem.swapfree || 0);

            memoryHistory = appendHistory(memoryHistory, memoryUsage);
            memoryInfo = mem;
            historyChanged = true;
            pushDeviceHistory(history, "memory", [
                {
                    key: "memory",
                    a: memoryUsage
                }
            ], null);
        }

        if (hasModule("network") && data.network && Array.isArray(data.network)) {
            networkInterfaces = data.network;

            let totalRx = 0;
            let totalTx = 0;
            for (const iface of data.network) {
                totalRx += iface.rx || 0;
                totalTx += iface.tx || 0;
            }

            if (lastNetworkStats) {
                const timeDiff = Math.max(1, sampleTime - lastNetworkStats.time) / 1000;
                const rxDiff = totalRx - lastNetworkStats.rx;
                const txDiff = totalTx - lastNetworkStats.tx;
                networkRxRate = Math.max(0, rxDiff / timeDiff);
                networkTxRate = Math.max(0, txDiff / timeDiff);
                networkHistory = {
                    rx: appendHistory(networkHistory.rx, networkRxRate / 1024),
                    tx: appendHistory(networkHistory.tx, networkTxRate / 1024)
                };
            }
            lastNetworkStats = {
                "time": sampleTime,
                "rx": totalRx,
                "tx": totalTx
            };
        }

        if (hasModule("disk") && data.disk && Array.isArray(data.disk)) {
            diskDevices = data.disk;

            const wholeDisks = SysmonDevices.sumWholeDisks(data.disk, "read", "write");
            const totalRead = wholeDisks.read * 512;
            const totalWrite = wholeDisks.write * 512;

            if (lastDiskStats) {
                const timeDiff = Math.max(1, sampleTime - lastDiskStats.time) / 1000;
                const readDiff = totalRead - lastDiskStats.read;
                const writeDiff = totalWrite - lastDiskStats.write;
                diskReadRate = Math.max(0, readDiff / timeDiff);
                diskWriteRate = Math.max(0, writeDiff / timeDiff);
                diskHistory = {
                    read: appendHistory(diskHistory.read, diskReadRate / (1024 * 1024)),
                    write: appendHistory(diskHistory.write, diskWriteRate / (1024 * 1024))
                };
            }
            lastDiskStats = {
                "time": sampleTime,
                "read": totalRead,
                "write": totalWrite
            };
        }

        if (hasModule("disk-rate") && data.diskrate && Array.isArray(data.diskrate.disks)) {
            const hadCursor = diskRateCursor !== "";
            const rates = [];
            for (const d of data.diskrate.disks) {
                const entry = {
                    device: d.device,
                    readRate: d.readrate,
                    writeRate: d.writerate,
                    readTotal: d.readtotal,
                    writeTotal: d.writetotal
                };
                if (d.busy !== undefined)
                    entry.busy = d.busy;
                if (d.responseTime !== undefined)
                    entry.responseTime = d.responseTime;
                rates.push(entry);
            }
            diskRates = rates;
            if (data.diskrate.cursor)
                diskRateCursor = data.diskrate.cursor;
            const whole = rates.filter(r => SysmonDevices.isWholeDisk(r.device));
            const samples = hadCursor ? whole.map(r => ({
                        key: SysmonDevices.deviceKey("disk", r.device),
                        a: r.readRate || 0,
                        b: r.writeRate || 0
                    })) : [];
            historyChanged = true;
            pushDeviceHistory(history, "disk", samples, whole.map(r => SysmonDevices.deviceKey("disk", r.device)));
        }

        if (hasModule("net-rate") && data.netrate && Array.isArray(data.netrate.interfaces)) {
            const hadCursor = netRateCursor !== "";
            const rates = data.netrate.interfaces.map(i => {
                const entry = {
                    iface: i.interface,
                    rxRate: i.rxrate,
                    txRate: i.txrate,
                    rxTotal: i.rxtotal,
                    txTotal: i.txtotal
                };
                for (const key of ["mtu", "speed", "duplex", "linkType", "driver", "ipv4", "ipv6"]) {
                    if (i[key] !== undefined)
                        entry[key] = i[key];
                }
                return entry;
            });
            netRates = rates;
            if (data.netrate.cursor)
                netRateCursor = data.netrate.cursor;
            const samples = hadCursor ? rates.map(r => ({
                        key: SysmonDevices.deviceKey("net", r.iface),
                        a: r.rxRate || 0,
                        b: r.txRate || 0
                    })) : [];
            historyChanged = true;
            pushDeviceHistory(history, "net", samples, rates.map(r => SysmonDevices.deviceKey("net", r.iface)));
        }

        if (hasModule("gpu-stats") && data.gpustats && Array.isArray(data.gpustats.gpus)) {
            const gpus = data.gpustats.gpus;
            gpuStats = gpus;
            if (data.gpustats.cursor)
                gpuStatsCursor = data.gpustats.cursor;
            const samples = [];
            for (const g of gpus) {
                if (g.usage === undefined)
                    continue;
                const vram = g.vramUsed !== undefined && g.vramTotal > 0 ? g.vramUsed / g.vramTotal * 100 : undefined;
                samples.push({
                    key: SysmonDevices.deviceKey("gpu", g.pciSlot),
                    a: g.usage,
                    b: vram
                });
            }
            historyChanged = true;
            pushDeviceHistory(history, "gpu", samples, gpus.map(g => SysmonDevices.deviceKey("gpu", g.pciSlot)));
        }

        if (hasModule("sensors") && data.sensors && Array.isArray(data.sensors.sensors))
            sensors = data.sensors.sensors;

        if (hasModule("memory-modules") && data.memorymodules)
            memoryModules = data.memorymodules;

        if (historyChanged)
            deviceHistory = history;

        if (hasModule("diskmounts") && data.diskmounts) {
            diskMountsRequested = true;
            diskMounts = data.diskmounts || [];
        }

        if (hasModule("processes") && data.processes && Array.isArray(data.processes)) {
            if (data.cursor) {
                procCursor = data.cursor;
            }

            const newProcesses = [];
            for (const proc of data.processes) {
                newProcesses.push({
                    "pid": proc.pid || 0,
                    "ppid": proc.ppid || 0,
                    "cpu": proc.cpu || 0,
                    "memoryPercent": proc.memoryPercent || proc.pssPercent || 0,
                    "memoryKB": proc.memoryKB || proc.pssKB || 0,
                    "command": proc.command || "",
                    "fullCommand": proc.fullCommand || "",
                    "username": proc.username || "",
                    "childCount": proc.childCount || 0,
                    "pticks": proc.pticks || 0,
                    "status": proc.status || "",
                    "threads": proc.threads ?? null,
                    "nice": proc.nice ?? null,
                    "startTime": proc.startTime ?? null,
                    "gpu": gpuPciIds.length > 0 ? (proc.gpu ?? null) : null,
                    "gpuVideo": gpuPciIds.length > 0 ? (proc.gpuVideo ?? null) : null,
                    "vramKB": gpuPciIds.length > 0 ? (proc.vramKB ?? null) : null,
                    "gpuGtt": gpuPciIds.length > 0 ? (proc.gpuGtt ?? null) : null,
                    "gpuUnmonitored": gpuPciIds.length > 0 ? (proc.gpuUnmonitored ?? false) : true,
                    "diskRead": proc.diskRead ?? null,
                    "diskWrite": proc.diskWrite ?? null,
                    "connections": proc.connections ?? null,
                    "remotes": proc.remotes ?? [],
                    "netRx": proc.netRx ?? null,
                    "netTx": proc.netTx ?? null,
                    "displayName": (proc.command && proc.command.length > 15) ? proc.command.substring(0, 15) + "..." : (proc.command || "")
                });
            }
            allProcesses = newProcesses;
            applySorting();
        }

        const gpuData = (data.gpu && data.gpu.gpus) || data.gpus;
        if (gpuData && Array.isArray(gpuData)) {
            // Check if this is temperature update data (has PCI IDs being monitored)
            if (gpuPciIds.length > 0 && availableGpus && availableGpus.length > 0) {
                // This is temperature data - merge with existing GPU metadata
                const updatedGpus = availableGpus.slice();
                for (var i = 0; i < updatedGpus.length; i++) {
                    const existingGpu = updatedGpus[i];
                    const tempGpu = gpuData.find(g => g.pciId === existingGpu.pciId);
                    // Only update temperature if this GPU's PCI ID is being monitored
                    if (tempGpu && gpuPciIds.includes(existingGpu.pciId)) {
                        updatedGpus[i] = Object.assign({}, existingGpu, {
                            "temperature": tempGpu.temperature || 0
                        });
                    }
                }
                availableGpus = updatedGpus;
            } else {
                // This is initial GPU metadata - set the full list
                const gpuList = [];
                for (const gpu of gpuData) {
                    let displayName = gpu.displayName || gpu.name || "Unknown GPU";
                    let fullName = gpu.fullName || gpu.name || "Unknown GPU";

                    gpuList.push({
                        "driver": gpu.driver || "",
                        "vendor": gpu.vendor || "",
                        "displayName": displayName,
                        "fullName": fullName,
                        "pciId": gpu.pciId || "",
                        "temperature": gpu.temperature || 0
                    });
                }
                availableGpus = gpuList;
            }
        }

        if (data.system?.boottime) {
            bootTime = data.system.boottime;
            updateUptime();
        }

        if (hasModule("system") && data.system) {
            const sys = data.system;
            loadAverage = sys.loadavg || "";
            processCount = sys.processes || 0;
            threadCount = sys.threads || 0;
            openFileCount = sys.openFileCount || 0;
        }

        const hwData = data.hardware || ((data.hostname || data.kernel || data.distro || data.arch) ? data : null);
        if (hwData) {
            hostname = hwData.hostname || "";
            kernelVersion = hwData.kernel || "";
            distribution = hwData.distro || "";
            architecture = hwData.arch || "";
            initSystem = hwData.initSystem || "";
            motherboard = (hwData.bios && hwData.bios.motherboard) || "";
            biosVersion = (hwData.bios && hwData.bios.version) || "";
            bios = hwData.bios ?? null;
        }

        statsUpdated();
    }

    function appendHistory(history, value) {
        const next = history.concat([value]);
        return next.length > historySize ? next.slice(next.length - historySize) : next;
    }

    function formatSystemMemory(memoryKB) {
        const mem = memoryKB || 0;
        if (mem === 0) {
            return "--";
        }
        if (mem < 1024 * 1024) {
            return (mem / 1024).toFixed(0) + " MB";
        } else {
            return (mem / (1024 * 1024)).toFixed(1) + " GB";
        }
    }

    function updateUptime() {
        if (!bootTime) {
            uptime = "";
            shortUptime = "";
            return;
        }

        const bootDate = new Date(bootTime.replace(" ", "T"));
        if (isNaN(bootDate.getTime())) {
            uptime = "";
            shortUptime = "";
            return;
        }

        const now = new Date();
        const seconds = Math.floor((now - bootDate) / 1000);
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);

        const parts = [];
        if (days > 0)
            parts.push(`${days} day${days === 1 ? "" : "s"}`);
        if (hours > 0)
            parts.push(`${hours} hour${hours === 1 ? "" : "s"}`);
        if (minutes > 0)
            parts.push(`${minutes} minute${minutes === 1 ? "" : "s"}`);

        uptime = parts.length > 0 ? `up ${parts.join(", ")}` : `up ${seconds} seconds`;

        var shortStr = "up";
        if (days > 0)
            shortStr += ` ${days}d`;
        if (hours > 0)
            shortStr += ` ${hours}h`;
        if (minutes > 0)
            shortStr += ` ${minutes}m`;
        shortUptime = shortStr;
    }

    function setSortBy(newSortBy) {
        if (newSortBy !== currentSort) {
            currentSort = newSortBy;
            sortAscending = false;
            applySorting();
        }
    }

    function toggleSort(column) {
        if (column === currentSort) {
            sortAscending = !sortAscending;
        } else {
            currentSort = column;
            sortAscending = false;
        }
        applySorting();
    }

    // Name and PID read ascending by default, so sortAscending inverts for them.
    function processComparator() {
        const naturallyAscending = currentSort === "name" || currentSort === "pid";
        return ProcessSort.compare(currentSort, sortAscending !== naturallyAscending);
    }

    function applySorting() {
        if (!allProcesses || allProcesses.length === 0)
            return;

        const sorted = allProcesses.slice().sort(processComparator());
        processes = sorted.slice(0, processLimit);
    }

    Timer {
        id: primeTimer
        interval: 1000
        onTriggered: root.updateAllStats()
    }

    Timer {
        id: updateTimer
        interval: root.updateInterval
        running: root.pollingActive
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateAllStats()
    }

    onDgopAvailableChanged: {
        if (!dgopAvailable) {
            availableModules = [];
            _metaLoaded = false;
            return;
        }

        if (_metaWanted)
            ensureMeta();
        initializeDiskMounts();

        if (!sessionGpuIdsSeeded && SessionData.enabledGpuPciIds && SessionData.enabledGpuPciIds.length > 0) {
            sessionGpuIdsSeeded = true;
            for (const pciId of SessionData.enabledGpuPciIds) {
                addGpuPciId(pciId);
            }
        }
    }
}
