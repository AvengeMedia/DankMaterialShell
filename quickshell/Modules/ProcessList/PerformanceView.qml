import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import "../../Services/SysmonDevices.js" as Devices
import "Drives.js" as Drives

Item {
    id: root

    readonly property bool isFloatingWindowSurface: true

    property string currentKey: "cpu"
    property bool showHidden: false

    readonly property var netKindOrder: ["ethernet", "wifi", "vpn", "other", "virtual", "loopback"]
    readonly property var netKindNames: ({
            ethernet: I18n.tr("Ethernet"),
            wifi: I18n.tr("Wi-Fi"),
            vpn: I18n.tr("VPN")
        })

    function history(key) {
        return DgopService.deviceHistory[key] ?? ({});
    }

    // Bar widgets keep cpu/memory history while this page is closed; use it so the chart starts full.
    function longer(a, b) {
        return (a ?? []).length >= (b ?? []).length ? (a ?? []) : b;
    }

    function rate(value) {
        return value === null || value === undefined ? "—" : Devices.formatRate(value, false);
    }

    function pairTotal(a, b) {
        return a === null || a === undefined || b === null || b === undefined ? "—" : Devices.formatRate(a + b, false);
    }

    readonly property var nets: {
        const kindRank = kind => {
            const i = netKindOrder.indexOf(kind);
            return i < 0 ? netKindOrder.length : i;
        };
        return (DgopService.netRates ?? []).map(n => ({
                    net: n,
                    kind: Devices.interfaceKind(n.iface, n.linkType)
                })).sort((a, b) => kindRank(a.kind) - kindRank(b.kind) || Devices.naturalCompare(a.net.iface, b.net.iface));
    }
    readonly property int hiddenCount: nets.filter(n => Devices.isHiddenByDefault(n.kind)).length

    readonly property var railModel: {
        const processor = I18n.tr("Processor", "system monitor device group: CPU and memory");
        const items = [
            {
                key: "cpu",
                group: processor,
                name: I18n.tr("CPU", "processor label in system monitor"),
                value: DgopService.cpuSampleCount === 0 ? "—" : DgopService.cpuUsage.toFixed(0) + "%",
                values: longer(history("cpu").a, DgopService.cpuHistory),
                maximum: 100
            },
            {
                key: "memory",
                group: processor,
                name: I18n.tr("Memory", "system RAM label in system monitor"),
                value: DgopService.memoryInfo === null ? "—" : Devices.formatBytes(DgopService.usedMemoryKB * 1024) + " / " + Devices.formatBytes(DgopService.totalMemoryKB * 1024),
                values: longer(history("memory").a, DgopService.memoryHistory),
                maximum: 100
            }
        ];

        const gpus = (DgopService.gpuStats ?? []).map(g => ({
                    slot: g.pciSlot,
                    name: g.name,
                    stat: g
                }));
        if (!DgopService.isModuleAvailable("gpu-stats"))
            for (const g of (DgopService.availableGpus ?? []))
                gpus.push({
                    slot: g.pciId,
                    name: g.displayName,
                    stat: null
                });
        for (const g of gpus) {
            const key = Devices.deviceKey("gpu", g.slot);
            const suspended = g.stat?.suspended === true;
            const off = g.stat !== null && !Devices.gpuMonitored(DgopService.gpuPciIds, g.stat.pciId, g.stat.pciSlot);
            items.push({
                key: key,
                group: I18n.tr("Graphics"),
                name: g.name,
                value: off ? I18n.tr("Monitoring off") : suspended ? I18n.tr("Idle", "adjective, printer state", true) : (g.stat?.usage != null ? Math.round(g.stat.usage) + "%" : "—"),
                values: suspended || off ? [] : (history(key).a ?? []),
                maximum: 100
            });
        }

        const disks = (DgopService.diskRates ?? []).filter(d => Devices.isWholeDisk(d.device)).slice().sort((a, b) => Devices.naturalCompare(a.device, b.device));
        for (const d of disks) {
            const key = Devices.deviceKey("disk", d.device);
            items.push({
                key: key,
                group: I18n.tr("Storage", "system monitor device group: disks"),
                name: Drives.driveFor(d.device, DriveService.drives)?.model || d.device,
                value: pairTotal(d.readRate, d.writeRate),
                valueTooltip: I18n.tr("Read") + ": " + rate(d.readRate) + "\n" + I18n.tr("Write") + ": " + rate(d.writeRate),
                values: history(key).a ?? [],
                secondaryValues: history(key).b ?? []
            });
        }

        const shown = nets.filter(n => root.showHidden || !Devices.isHiddenByDefault(n.kind));
        for (const {net, kind} of shown) {
            const key = Devices.deviceKey("net", net.iface);
            const sameKind = shown.filter(n => n.kind === kind).length;
            items.push({
                key: key,
                group: I18n.tr("Network"),
                name: sameKind === 1 && netKindNames[kind] ? netKindNames[kind] : net.iface,
                value: pairTotal(net.rxRate, net.txRate),
                valueTooltip: I18n.tr("Down", "network direction") + ": " + rate(net.rxRate) + "\n" + I18n.tr("Up", "network direction") + ": " + rate(net.txRate),
                values: history(key).a ?? [],
                secondaryValues: history(key).b ?? []
            });
        }
        return items;
    }

    readonly property var activeEntry: railModel.find(e => e.key === currentKey) ?? railModel[0]
    readonly property string activeKey: activeEntry.key

    Ref {
        service: DgopService
        modules: ["cpu", "memory", "system", "disk-rate", "net-rate", "diskmounts", "gpu-stats", "memory-modules"]
        active: root.visible
    }

    Ref {
        service: DriveService
        active: root.visible
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingXL

        DeviceRail {
            Layout.preferredWidth: Theme.navigationRailWidth * 3
            Layout.fillHeight: true
            model: root.railModel
            currentKey: root.activeKey
            historyLength: DgopService.deviceHistorySize
            hiddenCount: root.hiddenCount
            showHidden: root.showHidden
            onSelected: key => root.currentKey = key
            onShowHiddenToggled: root.showHidden = !root.showHidden
        }

        Loader {
            id: pane
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: {
                const prefix = root.activeKey.split(":")[0];
                return prefix === "disk" ? diskPane : prefix === "net" ? netPane : prefix === "memory" ? memoryPane : prefix === "gpu" ? gpuPane : cpuPane;
            }
        }
    }

    Component {
        id: cpuPane
        CpuPane {
            values: root.railModel[0].values
        }
    }

    Component {
        id: memoryPane
        MemoryPane {
            values: root.railModel[1].values
        }
    }

    Component {
        id: diskPane
        DiskPane {
            deviceName: root.activeKey.slice(root.activeKey.indexOf(":") + 1)
        }
    }

    Component {
        id: gpuPane
        GpuPane {
            slot: root.activeKey.slice(root.activeKey.indexOf(":") + 1)
        }
    }

    Component {
        id: netPane
        NetworkPane {
            deviceName: root.activeKey.slice(root.activeKey.indexOf(":") + 1)
            title: root.activeEntry.name
        }
    }
}
