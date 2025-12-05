import QtQuick
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    property int currentProfile: 0
    property string profileIcon: "settings"

    osdWidth: Theme.iconSize + Theme.spacingS * 2
    osdHeight: Theme.iconSize + Theme.spacingS * 2
    autoHideInterval: 2000
    enableMouseInteraction: false

    Connections {
        target: PowerProfileWatcher

        function onProfileChanged(profile) {
            if (SettingsData.osdPowerProfileEnabled) {
                root.currentProfile = profile;
                root.profileIcon = Theme.getPowerProfileIcon(profile);
                root.show();
            }
        }
    }

    Component.onCompleted: {
        if (SettingsData.osdPowerProfileEnabled && typeof PowerProfileWatcher !== "undefined") {
            root.currentProfile = PowerProfileWatcher.currentProfile;
            root.profileIcon = Theme.getPowerProfileIcon(PowerProfileWatcher.currentProfile);
        }
    }

    content: DankIcon {
        anchors.centerIn: parent
        name: root.profileIcon
        size: Theme.iconSize
        color: Theme.primary
    }
}
