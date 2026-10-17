import QtQuick
import qs.Common
import qs.Services
import "../../Services/SysmonDevices.js" as SysmonDevices
import "Drives.js" as Drives

DevicePane {
    id: root

    property string deviceName: ""

    readonly property var history: DgopService.deviceHistory[SysmonDevices.deviceKey("disk", deviceName)] ?? ({})
    readonly property var rates: (DgopService.diskRates ?? []).find(d => d.device === deviceName) ?? null
    readonly property real axisMax: SysmonDevices.rateAxisMax(history.a, history.b, 1048576)

    readonly property var drive: Drives.driveFor(deviceName, DriveService.drives)
    readonly property var kindNames: ({
            nvme: "NVMe",
            ssd: "SSD",
            hdd: "HDD"
        })
    readonly property string health: Drives.healthLevel(drive)
    readonly property var healthText: {
        const w = Drives.healthWord(health);
        return w === "" ? null : w === "ok" ? I18n.tr("Healthy", "drive health status") : w === "warning" ? I18n.tr("Warning") : I18n.tr("Critical", "drive health");
    }

    function rate(v) {
        return v === null || v === undefined ? "—" : SysmonDevices.formatRate(v, false);
    }

    function total(v) {
        return v === null || v === undefined ? null : SysmonDevices.formatBytes(v);
    }

    loaded: (history.a ?? []).length > 0
    title: drive?.model || deviceName
    titleTooltip: drive?.model ? deviceName : ""
    subtitle: drive ? [kindNames[drive.kind] ?? drive.kind ?? "", drive.pcieLink ?? ""].filter(x => x).join(", ") : ""
    subtitle2: Drives.rootMostMount(drive)
    chartLabel: I18n.tr("Read")
    chartValue: rate(rates?.readRate)
    chartSecondaryLabel: I18n.tr("Write")
    chartSecondaryValue: rate(rates?.writeRate)
    values: history.a ?? []
    secondaryValues: history.b ?? []
    maximum: axisMax
    maximumText: SysmonDevices.formatRate(axisMax, false)

    leftStats: [
        {
            label: I18n.tr("Busy"),
            value: root.rates?.busy != null ? Math.round(root.rates.busy) + "%" : root.rates ? "—" : null
        },
        {
            advanced: true,
            label: I18n.tr("Response time"),
            value: root.rates?.responseTime != null ? root.rates.responseTime.toFixed(2) + " ms" : root.rates ? "—" : null
        },
        {
            label: I18n.tr("Capacity"),
            value: root.drive?.size > 0 ? SysmonDevices.formatBytes(root.drive.size) : null
        }
    ]

    rightStats: [
        {
            label: I18n.tr("Temperature"),
            value: root.drive?.temperature != null ? SysmonDevices.formatTemp(root.drive.temperature, SettingsData.useFahrenheit) : null
        },
        {
            label: I18n.tr("Health"),
            value: root.healthText
        },
        {
            advanced: true,
            label: I18n.tr("Read since boot"),
            value: root.total(root.rates?.readTotal)
        },
        {
            advanced: true,
            label: I18n.tr("Written since boot"),
            value: root.total(root.rates?.writeTotal)
        }
    ]

    PartitionStrip {
        width: parent.width
        drive: root.drive
        mounts: DgopService.diskMounts ?? []
    }
}
