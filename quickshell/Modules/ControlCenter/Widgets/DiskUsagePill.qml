import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    property string mountPath: "/"
    property string instanceId: ""

    iconName: "storage"

    property var selectedMount: {
        if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
            return null
        }

        const targetMount = DgopService.diskMounts.find(mount => mount.mount === mountPath)
        return targetMount || DgopService.diskMounts.find(mount => mount.mount === "/") || DgopService.diskMounts[0]
    }

    property real usagePercent: {
        if (!selectedMount || !selectedMount.percent) {
            return 0
        }
        const percentStr = selectedMount.percent.replace("%", "")
        return parseFloat(percentStr) || 0
    }

    isActive: DgopService.dgopAvailable && selectedMount !== null

    primaryText: {
        if (!DgopService.dgopAvailable) {
            return "Disk Usage"
        }
        if (!selectedMount) {
            return "No disk data"
        }
        return selectedMount.mount
    }

    secondaryText: {
        if (!DgopService.dgopAvailable) {
            return "dgop not available"
        }
        if (!selectedMount) {
            return "No disk data available"
        }
        return `${selectedMount.used} / ${selectedMount.size} (${usagePercent.toFixed(0)}%)`
    }

    iconColor: {
        if (!DgopService.dgopAvailable || !selectedMount) {
            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
        }
        if (usagePercent > 90) {
            return Theme.error
        }
        if (usagePercent > 75) {
            return Theme.warning
        }
        return Theme.surfaceText
    }

    Component.onCompleted: {
        DgopService.addRef(["diskmounts"])
    }
    Component.onDestruction: {
        DgopService.removeRef(["diskmounts"])
    }

    onToggled: {
        expandClicked()
    }
}
