import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankActionButton {
    property string settingsTab: ""

    buttonSize: Theme.iconButtonSize
    iconSize: Theme.iconSize
    iconName: "settings"
    iconColor: Theme.surfaceText
    Accessible.name: I18n.tr("Settings")
    onClicked: {
        PopoutService.closeControlCenter();
        PopoutService.openSettingsWithTab(settingsTab);
    }
}
