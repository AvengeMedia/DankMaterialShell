import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Modules.ProcessList
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property int availableWidth: 400
    readonly property int baseWidth: contentRow.implicitWidth + Theme.spacingS * 2
    readonly property int maxNormalWidth: 456
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

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

    width: contentRow.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = networkArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    Component.onCompleted: {
        DgopService.addRef(["network"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["network"]);
    }

    MouseArea {
        id: networkArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        DankIcon {
            name: "network_check"
            size: Theme.iconSize - 8
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            StyledText {
                text: "↓"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.info
            }

            StyledText {
                text: DgopService.networkRxRate > 0 ? formatNetworkSpeed(DgopService.networkRxRate) : "0 B/s"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideNone
                wrapMode: Text.NoWrap

                StyledTextMetrics {
                    id: rxBaseline
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    text: "88.8 MB/s"
                }

                width: Math.max(rxBaseline.width, paintedWidth)

                Behavior on width {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            StyledText {
                text: "↑"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
            }

            StyledText {
                text: DgopService.networkTxRate > 0 ? formatNetworkSpeed(DgopService.networkTxRate) : "0 B/s"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideNone
                wrapMode: Text.NoWrap

                StyledTextMetrics {
                    id: txBaseline
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    text: "88.8 MB/s"
                }

                width: Math.max(txBaseline.width, paintedWidth)

                Behavior on width {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

        }

    }


}
