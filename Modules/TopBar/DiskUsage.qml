import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool showPercentage: true
    property bool showIcon: true
    property var toggleProcessList
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real barHeight: 48
    property real widgetHeight: 30
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    property real diskUsagePercent: {
        if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
            return 0
        }
        
        const rootMount = DgopService.diskMounts.find(mount => mount.mount === "/")
        if (rootMount && rootMount.percent) {
            const percentStr = rootMount.percent.replace("%", "")
            return parseFloat(percentStr) || 0
        }
        
        return parseFloat(DgopService.diskMounts[0].percent?.replace("%", "") || "0")
    }

    width: diskContent.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent"
        }

        const baseColor = diskArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
    }
    Component.onCompleted: {
        DgopService.addRef(["diskmounts"])
    }
    Component.onDestruction: {
        DgopService.removeRef(["diskmounts"])
    }

    MouseArea {
        id: diskArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                const globalPos = mapToGlobal(0, 0)
                const currentScreen = parentScreen || Screen
                const screenX = currentScreen.x || 0
                const relativeX = globalPos.x - screenX
                popupTarget.setTriggerPosition(relativeX, barHeight + Theme.spacingXS, width, section, currentScreen)
            }
            if (root.toggleProcessList) {
                root.toggleProcessList()
            }
        }
    }

    Row {
        id: diskContent

        anchors.centerIn: parent
        spacing: 3

        DankIcon {
            name: "storage"
            size: Theme.iconSize - 8
            color: {
                if (root.diskUsagePercent > 90) {
                    return Theme.tempDanger
                }
                if (root.diskUsagePercent > 75) {
                    return Theme.tempWarning
                }
                return Theme.surfaceText
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: {
                if (root.diskUsagePercent === undefined || root.diskUsagePercent === null || root.diskUsagePercent === 0) {
                    return "--%"
                }
                return root.diskUsagePercent.toFixed(0) + "%"
            }
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideNone

            StyledTextMetrics {
                id: diskBaseline
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                text: "100%"
            }

            width: Math.max(diskBaseline.width, paintedWidth)

            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}