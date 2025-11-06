import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Column {
    function formatNetworkSpeed(bytesPerSec) {
        if (bytesPerSec < 1024) {
            return bytesPerSec.toFixed(0) + " B/s";
        } else if (bytesPerSec < 1024 * 1024) {
            return (bytesPerSec / 1024).toFixed(1) + " KB/s";
        } else if (bytesPerSec < 1024 * 1024 * 1024) {
            return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s";
        } else {
            return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(1) + " GB/s";
        }
    }

    function formatDiskSpeed(bytesPerSec) {
        if (bytesPerSec < 1024 * 1024) {
            return (bytesPerSec / 1024).toFixed(1) + " KB/s";
        } else if (bytesPerSec < 1024 * 1024 * 1024) {
            return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s";
        } else {
            return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(1) + " GB/s";
        }
    }

    anchors.fill: parent
    spacing: Theme.spacingM
    Component.onCompleted: {
        DgopService.addRef(["cpu", "memory", "network", "disk"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["cpu", "memory", "network", "disk"]);
    }

    Rectangle {
        width: parent.width
        height: 200
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            Row {
                width: parent.width
                height: 32
                spacing: Theme.spacingM

                StyledText {
                    text: "CPU"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 80
                    height: 24
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: `${DgopService.cpuUsage.toFixed(1)}%`
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: Theme.primary
                        anchors.centerIn: parent
                    }

                }

                Item {
                    width: parent.width - 280
                    height: 1
                }

                StyledText {
                    text: `${DgopService.cpuCores} cores`
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }

            }

            DankFlickable {
                clip: true
                width: parent.width
                height: parent.height - 40
                contentHeight: coreUsageColumn.implicitHeight

                Column {
                    id: coreUsageColumn

                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: DgopService.perCoreCpuUsage

                        Row {
                            width: parent.width
                            height: 20
                            spacing: Theme.spacingS

                            StyledText {
                                text: `C${index}`
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: 24
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                width: parent.width - 80
                                height: 6
                                radius: 3
                                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    width: parent.width * Math.min(1, modelData / 100)
                                    height: parent.height
                                    radius: parent.radius
                                    color: {
                                        const usage = modelData;
                                        if (usage > 80) {
                                            return Theme.error;
                                        }
                                        if (usage > 60) {
                                            return Theme.warning;
                                        }
                                        return Theme.primary;
                                    }

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                        }

                                    }

                                }

                            }

                            StyledText {
                                text: modelData ? `${modelData.toFixed(0)}%` : "0%"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                width: 32
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                    }

                }

            }

        }

    }

    Rectangle {
        width: parent.width
        height: 80
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
        border.width: 1

        Row {
            anchors.centerIn: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                StyledText {
                    text: I18n.tr("Memory")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                StyledText {
                    text: `${DgopService.formatSystemMemory(DgopService.usedMemoryKB)} / ${DgopService.formatSystemMemory(DgopService.totalMemoryKB)}`
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

            }

            Item {
                width: Theme.spacingL
                height: 1
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                width: 200

                Rectangle {
                    width: parent.width
                    height: 16
                    radius: 8
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)

                    Rectangle {
                        width: DgopService.totalMemoryKB > 0 ? parent.width * (DgopService.usedMemoryKB / DgopService.totalMemoryKB) : 0
                        height: parent.height
                        radius: parent.radius
                        color: {
                            const usage = DgopService.totalMemoryKB > 0 ? (DgopService.usedMemoryKB / DgopService.totalMemoryKB) : 0;
                            if (usage > 0.9) {
                                return Theme.error;
                            }
                            if (usage > 0.7) {
                                return Theme.warning;
                            }
                            return Theme.secondary;
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                            }

                        }

                    }

                }

                StyledText {
                    text: DgopService.totalMemoryKB > 0 ? `${((DgopService.usedMemoryKB / DgopService.totalMemoryKB) * 100).toFixed(1)}% used` : "No data"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

            }

            Item {
                width: Theme.spacingL
                height: 1
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                StyledText {
                    text: I18n.tr("Swap")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                StyledText {
                    text: DgopService.totalSwapKB > 0 ? `${DgopService.formatSystemMemory(DgopService.usedSwapKB)} / ${DgopService.formatSystemMemory(DgopService.totalSwapKB)}` : "No swap configured"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

            }

            Item {
                width: Theme.spacingL
                height: 1
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                width: 200

                Rectangle {
                    width: parent.width
                    height: 16
                    radius: 8
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)

                    Rectangle {
                        width: DgopService.totalSwapKB > 0 ? parent.width * (DgopService.usedSwapKB / DgopService.totalSwapKB) : 0
                        height: parent.height
                        radius: parent.radius
                        color: {
                            if (!DgopService.totalSwapKB) {
                                return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3);
                            }
                            const usage = DgopService.usedSwapKB / DgopService.totalSwapKB;
                            if (usage > 0.9) {
                                return Theme.error;
                            }
                            if (usage > 0.7) {
                                return Theme.warning;
                            }
                            return Theme.info;
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                            }

                        }

                    }

                }

                StyledText {
                    text: DgopService.totalSwapKB > 0 ? `${((DgopService.usedSwapKB / DgopService.totalSwapKB) * 100).toFixed(1)}% used` : "Not available"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

            }

        }

    }

    Row {
        width: parent.width
        height: 80
        spacing: Theme.spacingM

        Rectangle {
            width: (parent.width - Theme.spacingM) / 2
            height: 80
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Network")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        spacing: 4

                        StyledText {
                            text: "↓"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.info
                        }

                        StyledText {
                            text: DgopService.networkRxRate > 0 ? formatNetworkSpeed(DgopService.networkRxRate) : "0 B/s"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                    }

                    Row {
                        spacing: 4

                        StyledText {
                            text: "↑"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.error
                        }

                        StyledText {
                            text: DgopService.networkTxRate > 0 ? formatNetworkSpeed(DgopService.networkTxRate) : "0 B/s"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                    }

                }

            }

        }

        Rectangle {
            width: (parent.width - Theme.spacingM) / 2
            height: 80
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Disk")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        spacing: 4

                        StyledText {
                            text: "R"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                        }

                        StyledText {
                            text: formatDiskSpeed(DgopService.diskReadRate)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                    }

                    Row {
                        spacing: 4

                        StyledText {
                            text: "W"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.warning
                        }

                        StyledText {
                            text: formatDiskSpeed(DgopService.diskWriteRate)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                    }

                }

            }

        }

    }

}
