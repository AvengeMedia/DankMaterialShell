import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    iconName: BatteryService.getBatteryIcon()

    isActive: BatteryService.batteryAvailable && (BatteryService.isCharging || BatteryService.isPluggedIn)

    primaryText: {
        if (!BatteryService.batteryAvailable) {
            return "No battery"
        }
        return "Battery"
    }

    secondaryText: {
        if (!BatteryService.batteryAvailable) {
            return "Not available"
        }
        if (BatteryService.isCharging) {
            return `${BatteryService.batteryLevel}% • Charging`
        }
        if (BatteryService.isPluggedIn) {
            return `${BatteryService.batteryLevel}% • Plugged in`
        }
        return `${BatteryService.batteryLevel}%`
    }

    iconColor: {
        if (BatteryService.isLowBattery && !BatteryService.isCharging) {
            return Theme.error
        }
        if (BatteryService.isCharging || BatteryService.isPluggedIn) {
            return Theme.primary
        }
        return Theme.surfaceText
    }

    onToggled: {
        expandClicked()
    }
}
