import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

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

    component PerformanceCard: Rectangle {
        id: card

        property string title: ""
        property string icon: ""
        property string value: ""
        property string subtitle: ""
        property color accentColor: Theme.primary
        property var history: []
        property var history2: null
        property real maxValue: 100
        property bool showSecondary: false
        property string extraInfo: ""
        property color extraInfoColor: Theme.surfaceVariantText

        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
        border.color: Theme.outlineLight
        border.width: 1

        Canvas {
            id: graphCanvas
            anchors.fill: parent
            anchors.margins: 4
            renderStrategy: Canvas.Cooperative

            property var hist: card.history
            property var hist2: card.history2

            onHistChanged: requestPaint()
            onHist2Changed: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);

                if (!hist || hist.length < 2)
                    return;

                let max = card.maxValue;
                if (max <= 0) {
                    max = 1;
                    for (let k = 0; k < hist.length; k++)
                        max = Math.max(max, hist[k]);
                    if (hist2) {
                        for (let l = 0; l < hist2.length; l++)
                            max = Math.max(max, hist2[l]);
                    }
                    max *= 1.1;
                }

                const c = card.accentColor;
                const grad = ctx.createLinearGradient(0, 0, 0, height);
                grad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.25));
                grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.02));

                ctx.fillStyle = grad;
                ctx.beginPath();
                ctx.moveTo(0, height);
                for (let i = 0; i < hist.length; i++) {
                    const x = (width / (root.historySize - 1)) * i;
                    const y = height - (hist[i] / max) * height * 0.8;
                    ctx.lineTo(x, y);
                }
                ctx.lineTo((width / (root.historySize - 1)) * (hist.length - 1), height);
                ctx.closePath();
                ctx.fill();

                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.8);
                ctx.lineWidth = 2;
                ctx.beginPath();
                for (let j = 0; j < hist.length; j++) {
                    const px = (width / (root.historySize - 1)) * j;
                    const py = height - (hist[j] / max) * height * 0.8;
                    j === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
                }
                ctx.stroke();

                if (hist2 && hist2.length >= 2 && card.showSecondary) {
                    ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.4);
                    ctx.lineWidth = 1.5;
                    ctx.setLineDash([4, 4]);
                    ctx.beginPath();
                    for (let m = 0; m < hist2.length; m++) {
                        const sx = (width / (root.historySize - 1)) * m;
                        const sy = height - (hist2[m] / max) * height * 0.8;
                        m === 0 ? ctx.moveTo(sx, sy) : ctx.lineTo(sx, sy);
                    }
                    ctx.stroke();
                    ctx.setLineDash([]);
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingXS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                DankIcon {
                    name: card.icon
                    size: Theme.iconSize
                    color: card.accentColor
                }

                StyledText {
                    text: card.title
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: card.extraInfo
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: SettingsData.monoFontFamily
                    color: card.extraInfoColor
                    visible: card.extraInfo.length > 0
                }
            }

            Item {
                Layout.fillHeight: true
            }

            StyledText {
                text: card.value
                font.pixelSize: Theme.fontSizeXLarge
                font.family: SettingsData.monoFontFamily
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            StyledText {
                text: card.subtitle
                font.pixelSize: Theme.fontSizeSmall
                font.family: SettingsData.monoFontFamily
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}
