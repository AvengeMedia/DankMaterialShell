import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Services
import qs.Widgets

CcTile {
    id: root

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
    opensPage: true
    tallContent: Component {
        Item {
            BatteryMeter {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                thickness: CcMetrics.tallMeterThickness
                levelColors: true
                showNumber: false
                visible: root.available
            }
        }
    }

    onClicked: expandClicked()
    expandedContent: Component {
        CcTileActions {
            actions: PowerProfileWatcher.availableProfiles.map(profile => ({
                        text: Theme.getPowerProfileLabel(profile),
                        icon: Theme.getPowerProfileIcon(profile),
                        active: profile === PowerProfileWatcher.currentProfile,
                        enabled: PowerProfileWatcher.available,
                        trigger: () => {
                            if (!PowerProfileWatcher.applyProfile(profile))
                                ToastService.showError(I18n.tr("Failed to set power profile"));
                        }
                    }))
        }
    }
}
