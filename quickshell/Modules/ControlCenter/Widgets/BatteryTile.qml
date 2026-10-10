import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Services
import qs.Widgets

CcTile {
    id: root

    property bool live: Window.window?.visible ?? false
    property bool batteryRefHeld: false
    readonly property bool available: BatteryService.batteryAvailable
    readonly property bool profileMode: !available && PowerProfileWatcher.available
    readonly property string meterStyle: widgetData?.batteryStyle ?? "icon"
    readonly property bool showsMeter: available && meterStyle !== "icon" && (small || compact) && !docked
    property real meterWidth: 0

    iconName: profileMode ? Theme.getPowerProfileIcon(PowerProfileWatcher.currentProfile) : BatteryService.getBatteryIcon()
    title: {
        if (profileMode)
            return I18n.tr("Power profile");
        return available ? I18n.tr("Battery") : I18n.tr("No battery");
    }
    subtitle: {
        if (profileMode)
            return Theme.getPowerProfileLabel(PowerProfileWatcher.currentProfile);
        if (!available)
            return I18n.tr("Not available");
        if (BatteryService.isCharging)
            return `${BatteryService.batteryLevel}% • ` + I18n.tr("Charging");
        if (BatteryService.isPluggedIn)
            return `${BatteryService.batteryLevel}% • ` + I18n.tr("Plugged in");
        return `${BatteryService.batteryLevel}%`;
    }
    dockedText: available || profileMode ? subtitle : title

    function syncBatteryRef(wanted) {
        if (wanted === batteryRefHeld)
            return;
        batteryRefHeld = wanted;
        if (wanted) {
            BatteryService.addRef();
            return;
        }
        BatteryService.removeRef();
    }

    onLiveChanged: syncBatteryRef(live)
    Component.onCompleted: syncBatteryRef(live)
    Component.onDestruction: syncBatteryRef(false)
    // The meter carries its own charging bolt and would vanish into an active body.
    active: available && (BatteryService.isCharging || BatteryService.isPluggedIn) && !showsMeter
    bodyContent: showsMeter ? meterPill : null
    quickContentWidth: showsMeter ? meterWidth : 0
    opensPage: !profileMode
    showExpand: profileMode

    Component {
        id: meterPill

        Item {
            BatteryMeter {
                id: meter

                anchors.centerIn: parent
                meterStyle: root.meterStyle
                levelColors: true
                thickness: CcMetrics.pillMeterThickness
                scale: Math.min(1, (parent.width - Theme.spacingXS * 2) / Math.max(1, implicitWidth))
            }

            Binding {
                target: root
                property: "meterWidth"
                value: meter.implicitWidth
            }
        }
    }

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

    onClicked: {
        if (!profileMode) {
            expandClicked();
            return;
        }
        PowerProfileWatcher.cycleProfile();
    }
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
