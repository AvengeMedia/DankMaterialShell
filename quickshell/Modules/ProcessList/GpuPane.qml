import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets
import "../../Services/SysmonDevices.js" as Devices

DevicePane {
    id: root

    property string slot: ""

    readonly property var stat: (DgopService.gpuStats ?? []).find(g => g.pciSlot === slot) ?? null
    // Used when gpu-stats is unavailable: the slot is then the device's pciId.
    readonly property var fallback: stat ? null : ((DgopService.availableGpus ?? []).find(g => g.pciId === slot) ?? null)
    readonly property bool monitored: stat !== null && Devices.gpuMonitored(DgopService.gpuPciIds, stat.pciId, stat.pciSlot)
    readonly property bool off: stat !== null && !monitored
    readonly property bool suspended: stat?.suspended === true
    readonly property bool live: stat !== null && !off && !suspended
    readonly property var history: DgopService.deviceHistory[Devices.deviceKey("gpu", slot)] ?? ({})

    // allProcesses holds the top 100 by CPU, so a GPU-heavy process with low CPU use can be missing.
    // Per-process GPU use is not per device, so it is only meaningful with a single GPU.
    readonly property bool singleGpu: (DgopService.gpuStats ?? []).length === 1
    readonly property var topProcess: {
        if (!singleGpu || !live)
            return null;
        let best = null;
        for (const p of DgopService.allProcesses ?? []) {
            if (typeof p.gpu === "number" && p.gpu > 0 && (best === null || p.gpu > best.gpu))
                best = p;
        }
        return best;
    }

    Ref {
        service: DgopService
        modules: ["processes", "process-gpu"]
        active: root.visible && root.live && root.singleGpu
    }

    function num(v, unit) {
        return v === null || v === undefined ? null : Math.round(v) + " " + unit;
    }

    function pct(v) {
        return v === null || v === undefined ? null : Math.round(v) + "%";
    }

    function temp(v) {
        return v === null || v === undefined ? null : Devices.formatTemp(v, SettingsData.useFahrenheit);
    }

    function usedOf(used, total) {
        return used === null || used === undefined || !(total > 0) ? null : Devices.formatBytes(used) + " / " + Devices.formatBytes(total);
    }

    function withMax(max, unit) {
        return max === null || max === undefined ? "" : I18n.tr("Max clock") + ": " + num(max, unit);
    }

    title: stat?.name ?? fallback?.displayName ?? slot
    titleTooltip: title
    subtitle: stat?.driver ?? fallback?.driver ?? ""
    subtitle2: stat?.vramTotal > 0 ? I18n.tr("%1 VRAM", "GPU memory size, e.g. 24 GiB VRAM").arg(Devices.formatBytes(stat.vramTotal)) : ""
    showChart: live
    chartLabel: I18n.tr("Usage", "chart legend: CPU or GPU utilization")
    chartValue: pct(stat?.usage) ?? "—"
    chartSecondaryLabel: (history.b ?? []).length > 0 ? I18n.tr("VRAM") : ""
    chartSecondaryValue: stat?.vramTotal > 0 && stat?.vramUsed != null ? Math.round(stat.vramUsed / stat.vramTotal * 100) + "%" : ""
    values: live ? (history.a ?? []) : []
    secondaryValues: live ? (history.b ?? []) : []
    maximum: 100
    maximumText: "100%"

    leftStats: live ? [
        {
            label: I18n.tr("VRAM"),
            value: root.usedOf(stat.vramUsed, stat.vramTotal)
        },
        {
            label: I18n.tr("Shared memory", "GPU memory borrowed from system RAM (GTT)"),
            value: root.usedOf(stat.gttUsed, stat.gttTotal)
        },
        {
            label: I18n.tr("Memory controller", "GPU memory controller busy percentage"),
            value: root.pct(stat.memoryBusy)
        },
        {
            label: I18n.tr("Core clock"),
            value: root.num(stat.coreClock, "MHz"),
            tooltip: root.withMax(stat.coreClockMax, "MHz")
        },
        {
            label: I18n.tr("Memory clock"),
            value: root.num(stat.memClock, "MHz"),
            tooltip: root.withMax(stat.memClockMax, "MHz")
        },
        {
            label: I18n.tr("Video encode", "GPU video encoder busy percentage"),
            value: root.pct(stat.encoderUsage)
        },
        {
            label: I18n.tr("Video decode", "GPU video decoder busy percentage"),
            value: root.pct(stat.decoderUsage)
        }
    ] : []

    rightStats: live ? [
        {
            label: I18n.tr("Temperature"),
            value: root.temp(stat.temperature)
        },
        {
            label: I18n.tr("Hotspot", "GPU hotspot temperature", true),
            value: root.temp(stat.hotspot)
        },
        {
            label: I18n.tr("Power", "battery stat label, charge or discharge rate in watts", true),
            value: root.num(stat.power, "W"),
            tooltip: stat.powerLimit != null ? I18n.tr("Power limit") + ": " + root.num(stat.powerLimit, "W") : ""
        },
        {
            label: I18n.tr("Fan"),
            value: stat.fanRpm != null ? stat.fanRpm + " rpm" : root.pct(stat.fanPercent)
        },
        {
            label: I18n.tr("Top process"),
            value: root.topProcess ? root.topProcess.command : null,
            tooltip: root.topProcess ? Math.round(root.topProcess.gpu) + "%" : ""
        }
    ] : []

    StyledText {
        visible: root.off || root.suspended
        width: parent.width
        text: root.off ? I18n.tr("Monitoring off") : I18n.tr("Idle", "adjective, printer state", true)
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceVariantText
    }

    SettingsGroup {
        visible: root.stat !== null
        width: parent.width

        DToggle {
            readonly property bool heldByWidget: root.stat !== null && DgopService.gpuHeldByWidget(root.stat.pciId)
            text: I18n.tr("GPU Monitoring")
            checked: root.monitored || heldByWidget
            enabled: !heldByWidget
            description: heldByWidget ? I18n.tr("Bar widgets") : ""
            onToggled: on => DgopService.setGpuMonitoring(root.stat.pciId, on)
        }
    }
}
