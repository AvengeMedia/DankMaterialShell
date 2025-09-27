import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var widgetData: null
    property real widgetHeight: 30
    property string mountPath: (widgetData && widgetData.mountPath !== undefined) ? widgetData.mountPath : "/"
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    property var selectedMount: {
        if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
            return null
        }

        // Force re-evaluation when mountPath changes
        const currentMountPath = root.mountPath || "/"

        // First try to find exact match
        for (let i = 0; i < DgopService.diskMounts.length; i++) {
            if (DgopService.diskMounts[i].mount === currentMountPath) {
                return DgopService.diskMounts[i]
            }
        }

        // Fallback to root
        for (let i = 0; i < DgopService.diskMounts.length; i++) {
            if (DgopService.diskMounts[i].mount === "/") {
                return DgopService.diskMounts[i]
            }
        }

        // Last resort - first mount
        return DgopService.diskMounts[0] || null
    }

    property real diskUsagePercent: {
        if (!selectedMount || !selectedMount.percent) {
            return 0
        }
        const percentStr = selectedMount.percent.replace("%", "")
        return parseFloat(percentStr) || 0
    }

    width: diskContent.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent"
        }

        const baseColor = Theme.widgetBaseBackgroundColor
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
    }
    Component.onCompleted: {
        DgopService.addRef(["diskmounts"])
    }
    Component.onDestruction: {
        DgopService.removeRef(["diskmounts"])
    }

    Connections {
        function onWidgetDataChanged() {
            // Force property re-evaluation by triggering change detection
            root.mountPath = Qt.binding(() => {
                return (root.widgetData && root.widgetData.mountPath !== undefined) ? root.widgetData.mountPath : "/"
            })

            root.selectedMount = Qt.binding(() => {
                if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
                    return null
                }

                const currentMountPath = root.mountPath || "/"

                // First try to find exact match
                for (let i = 0; i < DgopService.diskMounts.length; i++) {
                    if (DgopService.diskMounts[i].mount === currentMountPath) {
                        return DgopService.diskMounts[i]
                    }
                }

                // Fallback to root
                for (let i = 0; i < DgopService.diskMounts.length; i++) {
                    if (DgopService.diskMounts[i].mount === "/") {
                        return DgopService.diskMounts[i]
                    }
                }

                // Last resort - first mount
                return DgopService.diskMounts[0] || null
            })
        }

        target: SettingsData
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
                if (!root.selectedMount) {
                    return "--"
                }
                return root.selectedMount.mount
            }
            font.pixelSize: Theme.fontSizeSmall
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