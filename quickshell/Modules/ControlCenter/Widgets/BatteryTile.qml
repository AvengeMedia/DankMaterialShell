import QtQuick
import qs.Common
import qs.Services

CcTile {

    readonly property bool available: BatteryService.batteryAvailable

    iconName: BatteryService.getBatteryIcon()
    title: available ? I18n.tr("Battery") : I18n.tr("No battery")
    subtitle: {
        if (!available)
            return I18n.tr("Not available");
        if (BatteryService.isCharging)
            return `${BatteryService.batteryLevel}% • ` + I18n.tr("Charging");
        if (BatteryService.isPluggedIn)
            return `${BatteryService.batteryLevel}% • ` + I18n.tr("Plugged in");
        return `${BatteryService.batteryLevel}%`;
    }
    active: available && (BatteryService.isCharging || BatteryService.isPluggedIn)

    onClicked: expandClicked()
}
