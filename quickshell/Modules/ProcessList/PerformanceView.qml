import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import "../../Common/Format.js" as Format

Item {
    id: root

    Ref {
        service: DgopService
        modules: ["cpu", "memory", "network", "disk", "diskmounts", "system"]
        active: root.visible
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingM

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: (root.height - Theme.spacingM * 2) / 2
            spacing: Theme.spacingM

            PerformanceCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "CPU"
                icon: "memory"
                value: DgopService.cpuUsage.toFixed(1) + "%"
                subtitle: DgopService.cpuModel || (DgopService.cpuCores + " cores")
                accentColor: Theme.primary
                history: DgopService.cpuHistory
                maxValue: 100
                showSecondary: false
                extraInfo: DgopService.cpuTemperature > 0 ? (DgopService.cpuTemperature.toFixed(0) + "°C") : ""
                extraInfoColor: DgopService.cpuTemperature > 80 ? Theme.error : (DgopService.cpuTemperature > 60 ? Theme.warning : Theme.surfaceVariantText)
            }

            PerformanceCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: I18n.tr("Memory", "system RAM label in system monitor")
                icon: "sd_card"
                value: DgopService.memoryUsage.toFixed(1) + "%"
                subtitle: DgopService.formatSystemMemory(DgopService.usedMemoryKB) + " / " + DgopService.formatSystemMemory(DgopService.totalMemoryKB)
                accentColor: Theme.secondary
                history: DgopService.memoryHistory
                maxValue: 100
                showSecondary: false
                extraInfo: DgopService.totalSwapKB > 0 ? ("Swap: " + DgopService.formatSystemMemory(DgopService.usedSwapKB)) : ""
                extraInfoColor: Theme.surfaceVariantText
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: (root.height - Theme.spacingM * 2) / 2
            spacing: Theme.spacingM

            PerformanceCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: I18n.tr("Network")
                icon: "swap_horiz"
                value: "↓ " + Format.formatRate(DgopService.networkRxRate)
                subtitle: "↑ " + Format.formatRate(DgopService.networkTxRate)
                accentColor: Theme.info
                history: DgopService.networkHistory.rx
                history2: DgopService.networkHistory.tx
                maxValue: 0
                showSecondary: true
                extraInfo: ""
                extraInfoColor: Theme.surfaceVariantText
            }

            PerformanceCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: I18n.tr("Disk", "noun, storage disk label in system monitor")
                icon: "storage"
                value: "R: " + Format.formatRate(DgopService.diskReadRate)
                subtitle: "W: " + Format.formatRate(DgopService.diskWriteRate)
                accentColor: Theme.warning
                history: DgopService.diskHistory.read
                history2: DgopService.diskHistory.write
                maxValue: 0
                showSecondary: true
                extraInfo: {
                    const rootMount = DgopService.diskMounts.find(m => m.mountpoint === "/");
                    if (rootMount) {
                        const usedPct = ((rootMount.used || 0) / Math.max(1, rootMount.total || 1) * 100).toFixed(0);
                        return "/ " + usedPct + "% used";
                    }
                    return "";
                }
                extraInfoColor: Theme.surfaceVariantText
            }
        }
    }
}
