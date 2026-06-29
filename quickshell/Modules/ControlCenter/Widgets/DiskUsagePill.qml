import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    property string mountPath: "/"
    property string instanceId: ""
    property bool showMountPath: true

    iconName: "storage"

    property var selectedMount: {
        if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
            return null;
        }

        const targetMount = DgopService.diskMounts.find(mount => mount.mount === mountPath);
        return targetMount || DgopService.diskMounts.find(mount => mount.mount === "/") || DgopService.diskMounts[0];
    }

    property real usagePercent: {
        if (!selectedMount || !selectedMount.percent) {
            return 0;
        }
        const percentStr = selectedMount.percent.replace("%", "");
        return parseFloat(percentStr) || 0;
    }

    isActive: DgopService.dgopAvailable && selectedMount !== null

    primaryText: {
        if (!DgopService.dgopAvailable) {
            return I18n.tr("Disk Usage");
        }
        if (!selectedMount) {
            return I18n.tr("No disk data");
        }
        if (!showMountPath) {
            return I18n.tr("Disk Usage");
        }
        return selectedMount.mount;
    }

    secondaryText: {
        if (!DgopService.dgopAvailable) {
            return I18n.tr("dgop not available");
        }
        if (!selectedMount) {
            return I18n.tr("No disk data available");
        }
        return `${selectedMount.used} / ${selectedMount.size} (${usagePercent.toFixed(0)}%)`;
    }

    iconColor: {
        if (!DgopService.dgopAvailable || !selectedMount) {
            return Theme.surfaceTextSecondary;
        }
        if (usagePercent > 90) {
            return Theme.error;
        }
        if (usagePercent > 75) {
            return Theme.warning;
        }
        return Theme.surfaceText;
    }

    Component.onCompleted: {
        DgopService.addRef(["diskmounts"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["diskmounts"]);
    }

    onToggled: {
        expandClicked();
    }
}
