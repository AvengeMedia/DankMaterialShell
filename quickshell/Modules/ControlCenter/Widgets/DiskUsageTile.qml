import QtQuick
import qs.Common
import qs.Services

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
    enabled: DgopService.dgopAvailable

    Ref {
        service: DgopService
        modules: ["diskmounts"]
        active: root.live && root.visible && (root.Window.window?.visible ?? false)
    }

    onClicked: expandClicked()
}
