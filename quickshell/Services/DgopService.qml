pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Common
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("DgopService")

    signal statsUpdated

    property int refCount: 0
    readonly property bool powerSaver: PowerProfileWatcher.currentProfile === PowerProfile.PowerSaver
    property int updateInterval: refCount > 0 ? (powerSaver ? 6000 : 3000) : (powerSaver ? 60000 : 30000)
    property bool isUpdating: false
    property bool pendingUpdate: false
    property int subscriptionGeneration: 0
    readonly property bool pollingActive: dgopAvailable && refCount > 0 && enabledModules.length > 0
    readonly property bool dgopAvailable: DMSService.isConnected && DMSService.capabilities.includes("dgop")
    property bool sessionGpuIdsSeeded: false

    property var moduleRefCounts: ({})
    property var enabledModules: []
    property var gpuPciIds: []
    property var gpuPciIdRefCounts: ({})
    property int processLimit: 20
    property string processSort: "cpu"
    property bool noCpu: false

    // Cursor data for accurate CPU calculations
    property string cpuCursor: ""
    property string procCursor: ""
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

    function addRef(modules = null) {
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
        }
        if (!hasModule("memory"))
            memoryHistory = [];
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
        }
    }

    function addGpuPciId(pciId) {
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

    function initializeSystemMetadata() {
        if (!dgopAvailable)
            return;
        DMSService.sendRequest("dgop.hardware", null, response => {
            if (!response.result) {
                log.warn("dgop.hardware failed:", response.error || "empty result");
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
        const finalModules = [];
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

        if (gpuPciIds.length > 0) {
            params.gpuPciIds = gpuPciIds;
        }

        if (enabledModules.indexOf("processes") !== -1 || enabledModules.indexOf("all") !== -1) {
            params.limit = 100; // Get more data for client sorting
            params.sort = "cpu";
            if (noCpu) {
                params.noCpu = true;
            }
        }

        return params;
    }

    function parseData(data) {
        const sampleTime = Date.now();
        if (hasModule("cpu") && data.cpu) {
            const cpu = data.cpu;
            cpuSampleCount++;

            cpuUsage = Math.round((cpu.usage || 0) * 10) / 10;
            cpuFrequency = Math.round(cpu.frequency || 0);
            cpuTemperature = Math.round(cpu.temperature || 0);
            cpuCores = cpu.count || 1;
            cpuModel = cpu.model || "";
            perCoreCpuUsage = cpu.coreUsage || [];
            addToHistory(cpuHistory, cpuUsage);

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

            addToHistory(memoryHistory, memoryUsage);
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
                addToHistory(networkHistory.rx, networkRxRate / 1024);
                addToHistory(networkHistory.tx, networkTxRate / 1024);
            }
            lastNetworkStats = {
                "time": sampleTime,
                "rx": totalRx,
                "tx": totalTx
            };
        }

        if (hasModule("disk") && data.disk && Array.isArray(data.disk)) {
            diskDevices = data.disk;

            let totalRead = 0;
            let totalWrite = 0;
            for (const disk of data.disk) {
                totalRead += (disk.read || 0) * 512;
                totalWrite += (disk.write || 0) * 512;
            }

            if (lastDiskStats) {
                const timeDiff = Math.max(1, sampleTime - lastDiskStats.time) / 1000;
                const readDiff = totalRead - lastDiskStats.read;
                const writeDiff = totalWrite - lastDiskStats.write;
                diskReadRate = Math.max(0, readDiff / timeDiff);
                diskWriteRate = Math.max(0, writeDiff / timeDiff);
                addToHistory(diskHistory.read, diskReadRate / (1024 * 1024));
                addToHistory(diskHistory.write, diskWriteRate / (1024 * 1024));
            }
            lastDiskStats = {
                "time": sampleTime,
                "read": totalRead,
                "write": totalWrite
            };
        }

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

        if (hasModule("system") && data.system) {
            const sys = data.system;
            loadAverage = sys.loadavg || "";
            processCount = sys.processes || 0;
            threadCount = sys.threads || 0;
            bootTime = sys.boottime || "";
            updateUptime();
        }

        const hwData = data.hardware || (data.hostname || data.kernel || data.distro || data.arch) ? data : null;
        if (hwData) {
            hostname = hwData.hostname || "";
            kernelVersion = hwData.kernel || "";
            distribution = hwData.distro || "";
            architecture = hwData.arch || "";
            motherboard = (hwData.bios && hwData.bios.motherboard) || "";
            biosVersion = (hwData.bios && hwData.bios.version) || "";
        }

        statsUpdated();
    }

    function addToHistory(array, value) {
        array.push(value);
        if (array.length > historySize) {
            array.splice(0, array.length - historySize);
        }
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

    function compareProcesses(a, b) {
        let result;
        switch (currentSort) {
        case "cpu":
            result = (b.cpu || 0) - (a.cpu || 0);
            break;
        case "memory":
            result = (b.memoryKB || 0) - (a.memoryKB || 0);
            break;
        case "name":
            result = (a.command || "").toLowerCase().localeCompare((b.command || "").toLowerCase());
            break;
        case "pid":
            result = (a.pid || 0) - (b.pid || 0);
            break;
        default:
            return 0;
        }
        if (result === 0)
            return (a.pid || 0) - (b.pid || 0);
        return sortAscending ? -result : result;
    }

    function applySorting() {
        if (!allProcesses || allProcesses.length === 0)
            return;

        const sorted = allProcesses.slice().sort(compareProcesses);
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
        if (!dgopAvailable)
            return;

        initializeGpuMetadata();
        initializeSystemMetadata();
        initializeDiskMounts();

        if (!sessionGpuIdsSeeded && SessionData.enabledGpuPciIds && SessionData.enabledGpuPciIds.length > 0) {
            sessionGpuIdsSeeded = true;
            for (const pciId of SessionData.enabledGpuPciIds) {
                addGpuPciId(pciId);
            }
        }
    }

    Process {
        id: osReleaseProcess
        command: ["cat", "/etc/os-release"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                log.warn("Failed to read /etc/os-release");
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    try {
                        const lines = text.trim().split('\n');
                        let prettyName = "";
                        let name = "";

                        for (const line of lines) {
                            const trimmedLine = line.trim();
                            if (trimmedLine.startsWith('PRETTY_NAME=')) {
                                prettyName = trimmedLine.substring(12).replace(/^["']|["']$/g, '');
                            } else if (trimmedLine.startsWith('NAME=')) {
                                name = trimmedLine.substring(5).replace(/^["']|["']$/g, '');
                            }
                        }

                        // Prefer PRETTY_NAME, fallback to NAME
                        const distroName = prettyName || name || "Linux";
                        distribution = distroName;
                        log.info("Detected distribution:", distroName);
                    } catch (e) {
                        log.warn("Failed to parse /etc/os-release:", e);
                        distribution = "Linux";
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        osReleaseProcess.running = true;
    }
}
