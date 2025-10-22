import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property string mountPath: (widgetData && widgetData.mountPath !== undefined) ? widgetData.mountPath : "/"

    property var selectedMount: {
        if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
            return null
        }

        const currentMountPath = root.mountPath || "/"

        for (let i = 0; i < DgopService.diskMounts.length; i++) {
            if (DgopService.diskMounts[i].mount === currentMountPath) {
                return DgopService.diskMounts[i]
            }
        }

        for (let i = 0; i < DgopService.diskMounts.length; i++) {
            if (DgopService.diskMounts[i].mount === "/") {
                return DgopService.diskMounts[i]
            }
        }

        return DgopService.diskMounts[0] || null
    }

    property real diskUsagePercent: {
        if (!selectedMount || !selectedMount.percent) {
            return 0
        }
        const percentStr = selectedMount.percent.replace("%", "")
        return parseFloat(percentStr) || 0
    }

    Component.onCompleted: {
        DgopService.addRef(["diskmounts"])
    }
    Component.onDestruction: {
        DgopService.removeRef(["diskmounts"])
    }

    Connections {
        function onWidgetDataChanged() {
            root.mountPath = Qt.binding(() => {
                return (root.widgetData && root.widgetData.mountPath !== undefined) ? root.widgetData.mountPath : "/"
            })

            root.selectedMount = Qt.binding(() => {
                if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
                    return null
                }

                const currentMountPath = root.mountPath || "/"

                for (let i = 0; i < DgopService.diskMounts.length; i++) {
                    if (DgopService.diskMounts[i].mount === currentMountPath) {
                        return DgopService.diskMounts[i]
                    }
                }

                for (let i = 0; i < DgopService.diskMounts.length; i++) {
                    if (DgopService.diskMounts[i].mount === "/") {
                        return DgopService.diskMounts[i]
                    }
                }

                return DgopService.diskMounts[0] || null
            })
        }

        target: SettingsData
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : diskContent.implicitWidth
            implicitHeight: root.isVerticalOrientation ? diskColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: diskColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "storage"
                    size: Theme.barIconSize(root.barThickness)
                    color: {
                        if (root.diskUsagePercent > 90) {
                            return Theme.tempDanger
                        }
                        if (root.diskUsagePercent > 75) {
                            return Theme.tempWarning
                        }
                        return Theme.surfaceText
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (root.diskUsagePercent === undefined || root.diskUsagePercent === null || root.diskUsagePercent === 0) {
                            return "--"
                        }
                        return root.diskUsagePercent.toFixed(0)
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness)
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: diskContent
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 3

                DankIcon {
                    name: "storage"
                    size: Theme.barIconSize(root.barThickness)
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
                        if (!root.selectedMount) {
                            return "--"
                        }
                        return root.selectedMount.mount
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness)
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideNone
                }

                StyledText {
                    text: {
                        if (root.diskUsagePercent === undefined || root.diskUsagePercent === null || root.diskUsagePercent === 0) {
                            return "--%"
                        }
                        return root.diskUsagePercent.toFixed(0) + "%"
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness)
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideNone

                    StyledTextMetrics {
                        id: diskBaseline
                        font.pixelSize: Theme.barTextSize(root.barThickness)
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
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    MouseArea {
        z: 1
        anchors.fill: parent
        hoverEnabled: root.isVerticalOrientation
        onEntered: {
            if (root.isVerticalOrientation && root.selectedMount) {
                tooltipLoader.active = true
                if (tooltipLoader.item) {
                    const globalPos = mapToGlobal(width / 2, height / 2)
                    const currentScreen = root.parentScreen || Screen
                    const screenX = currentScreen ? currentScreen.x : 0
                    const screenY = currentScreen ? currentScreen.y : 0
                    const relativeY = globalPos.y - screenY
                    const tooltipX = root.axis?.edge === "left" ? (Theme.barHeight + SettingsData.dankBarSpacing + Theme.spacingXS) : (currentScreen.width - Theme.barHeight - SettingsData.dankBarSpacing - Theme.spacingXS)
                    const isLeft = root.axis?.edge === "left"
                    tooltipLoader.item.show(root.selectedMount.mount, screenX + tooltipX, relativeY, currentScreen, isLeft, !isLeft)
                }
            }
        }
        onExited: {
            if (tooltipLoader.item) {
                tooltipLoader.item.hide()
            }
            tooltipLoader.active = false
        }
    }
}
