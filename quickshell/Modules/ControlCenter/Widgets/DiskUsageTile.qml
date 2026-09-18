import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Services
import qs.Widgets

CcTile {
    id: root

    readonly property string mountPath: widgetData.mountPath || "/"
    readonly property bool showMountPath: widgetData.showMountPath !== false

    readonly property var selectedMount: {
        const mounts = DgopService.diskMounts || [];
        if (mounts.length === 0)
            return null;
        return mounts.find(mount => mount.mount === mountPath) || mounts.find(mount => mount.mount === "/") || mounts[0];
    }
    readonly property real usagePercent: selectedMount?.percent ? (parseFloat(selectedMount.percent.replace("%", "")) || 0) : 0

    iconName: "storage"
    title: {
        if (!DgopService.dgopAvailable || !showMountPath)
            return I18n.tr("Disk usage");
        return selectedMount ? selectedMount.mount : I18n.tr("No disk data");
    }
    subtitle: {
        if (!DgopService.dgopAvailable)
            return I18n.tr("DMS_SOCKET not available");
        if (!selectedMount)
            return I18n.tr("No disk data available");
        return `${selectedMount.used} / ${selectedMount.size} (${usagePercent.toFixed(0)}%)`;
    }
    active: false
    opensPage: true
    enabled: DgopService.dgopAvailable
    tallContent: Component {
        Item {
            DankRingGauge {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width, parent.height)
                height: width
                value: root.selectedMount ? root.usagePercent / 100 : -1
                ringColor: {
                    if (root.usagePercent >= CcMetrics.diskCriticalPercent)
                        return Theme.error;
                    return root.usagePercent >= CcMetrics.diskWarnPercent ? Theme.warning : Theme.primary;
                }

                StyledText {
                    anchors.centerIn: parent
                    text: root.selectedMount ? Math.round(root.usagePercent) + "%" : "--"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: root.contentColor
                }
            }
        }
    }

    Ref {
        service: DgopService
        modules: ["diskmounts"]
        active: root.live && root.visible && (root.Window.window?.visible ?? false)
    }

    onClicked: expandClicked()
    expandedContent: Component {
        Item {
            DankRingGauge {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                value: root.selectedMount ? root.usagePercent / 100 : -1
                ringColor: root.usagePercent >= CcMetrics.diskCriticalPercent ? Theme.error : root.usagePercent >= CcMetrics.diskWarnPercent ? Theme.warning : Theme.primary
                trackGap: Theme.spacingXS
                strokeWidth: Theme.spacingS

                StyledText {
                    anchors.centerIn: parent
                    text: root.selectedMount ? Math.round(root.usagePercent) + "%" : "--"
                    font.pixelSize: Theme.fontSizeXXLarge
                    font.weight: Theme.fontWeightMedium
                    color: root.contentColor
                }
            }
        }
    }
}
