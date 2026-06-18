import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    iconName: BatteryService.getBatteryIcon()

    isActive: BatteryService.batteryAvailable && (BatteryService.isCharging || BatteryService.isPluggedIn)

    primaryText: {
        if (!BatteryService.batteryAvailable) {
            return I18n.tr("No battery");
        }
        return I18n.tr("Battery");
    }

    secondaryText: {
        if (!BatteryService.batteryAvailable) {
            return I18n.tr("Not available");
        }
        if (BatteryService.isCharging) {
            return `${BatteryService.batteryLevel}% • ` + I18n.tr("Charging");
        }
        if (BatteryService.isPluggedIn) {
            return `${BatteryService.batteryLevel}% • ` + I18n.tr("Plugged In");
        }
        return `${BatteryService.batteryLevel}%`;
    }

    iconColor: {
        if (BatteryService.isLowBattery && !BatteryService.isCharging) {
            return Theme.error;
        }
        if (BatteryService.isCharging || BatteryService.isPluggedIn) {
            return Theme.primary;
        }
        return Theme.surfaceText;
    }

    onToggled: {
        expandClicked();
    }
}
