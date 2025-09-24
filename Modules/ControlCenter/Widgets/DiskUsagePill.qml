import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    iconName: "storage"

    property var primaryMount: {
        if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
            return null
        }
        
        const rootMount = DgopService.diskMounts.find(mount => mount.mount === "/")
        return rootMount || DgopService.diskMounts[0]
    }

    property real usagePercent: {
        if (!primaryMount || !primaryMount.percent) {
            return 0
        }
        const percentStr = primaryMount.percent.replace("%", "")
        return parseFloat(percentStr) || 0
    }

    isActive: DgopService.dgopAvailable && primaryMount !== null

    primaryText: {
        if (!DgopService.dgopAvailable) {
            return "Disk Usage"
        }
        if (!primaryMount) {
            return "No disk data"
        }
        return `Disk Usage • ${primaryMount.mount}`
    }

    secondaryText: {
        if (!DgopService.dgopAvailable) {
            return "dgop not available"
        }
        if (!primaryMount) {
            return "No disk data available"
        }
        return `${primaryMount.used} / ${primaryMount.size} (${usagePercent.toFixed(0)}%)`
    }

    iconColor: {
        if (!DgopService.dgopAvailable || !primaryMount) {
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