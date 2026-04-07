import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services

Item {
    id: root

    readonly property int historySize: 60

    property var cpuHistory: []
    property var memoryHistory: []
    property var networkRxHistory: []
    property var networkTxHistory: []
    property var diskReadHistory: []
    property var diskWriteHistory: []

    function formatBytes(bytes) {
        if (bytes < 1024)
            return bytes.toFixed(0) + " B/s";
        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(1) + " KB/s";
        if (bytes < 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MB/s";
        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB/s";
    }

    function addToHistory(arr, val) {
        const newArr = arr.slice();
        newArr.push(val);
        if (newArr.length > historySize)
            newArr.shift();
        return newArr;
    }

    function sampleData() {
        cpuHistory = addToHistory(cpuHistory, DgopService.cpuUsage);
        memoryHistory = addToHistory(memoryHistory, DgopService.memoryUsage);
        networkRxHistory = addToHistory(networkRxHistory, DgopService.networkRxRate);
        networkTxHistory = addToHistory(networkTxHistory, DgopService.networkTxRate);
        diskReadHistory = addToHistory(diskReadHistory, DgopService.diskReadRate);
        diskWriteHistory = addToHistory(diskWriteHistory, DgopService.diskWriteRate);
    }

    Component.onCompleted: {
        DgopService.addRef(["cpu", "memory", "network", "disk", "diskmounts", "system"]);
    }

    Component.onDestruction: {
        DgopService.removeRef(["cpu", "memory", "network", "disk", "diskmounts", "system"]);
    }

    SystemClock {
        id: sampleClock
        precision: SystemClock.Seconds
        onDateChanged: {
            if (date.getSeconds() % 1 === 0)
                root.sampleData();
        }
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
                historySize: root.historySize
                title: "CPU"
                icon: "memory"
                value: DgopService.cpuUsage.toFixed(1) + "%"
                subtitle: DgopService.cpuModel || (DgopService.cpuCores + " cores")
                accentColor: Theme.primary
                history: root.cpuHistory
                maxValue: 100
                showSecondary: false
                extraInfo: DgopService.cpuTemperature > 0 ? (DgopService.cpuTemperature.toFixed(0) + "°C") : ""
                extraInfoColor: DgopService.cpuTemperature > 80 ? Theme.error : (DgopService.cpuTemperature > 60 ? Theme.warning : Theme.surfaceVariantText)
            }

            PerformanceCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                historySize: root.historySize
                title: I18n.tr("Memory")
                icon: "sd_card"
                value: DgopService.memoryUsage.toFixed(1) + "%"
                subtitle: DgopService.formatSystemMemory(DgopService.usedMemoryKB) + " / " + DgopService.formatSystemMemory(DgopService.totalMemoryKB)
                accentColor: Theme.secondary
                history: root.memoryHistory
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
                historySize: root.historySize
                title: I18n.tr("Network")
                icon: "swap_horiz"
                value: "↓ " + root.formatBytes(DgopService.networkRxRate)
                subtitle: "↑ " + root.formatBytes(DgopService.networkTxRate)
                accentColor: Theme.info
                history: root.networkRxHistory
                history2: root.networkTxHistory
                maxValue: 0
                showSecondary: true
                extraInfo: ""
                extraInfoColor: Theme.surfaceVariantText
            }

            PerformanceCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                historySize: root.historySize
                title: I18n.tr("Disk")
                icon: "storage"
                value: "R: " + root.formatBytes(DgopService.diskReadRate)
                subtitle: "W: " + root.formatBytes(DgopService.diskWriteRate)
                accentColor: Theme.warning
                history: root.diskReadHistory
                history2: root.diskWriteHistory
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
