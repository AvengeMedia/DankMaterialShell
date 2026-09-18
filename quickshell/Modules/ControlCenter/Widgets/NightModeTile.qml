import QtQuick
import qs.Common
import qs.Services

CcTile {

    iconName: NightModeService.nightModeEnabled ? "nightlight" : "dark_mode"
    title: I18n.tr("Night mode")
    active: NightModeService.nightModeEnabled || false
    enabled: NightModeService.automationAvailable

    onClicked: NightModeService.toggleNightMode()
}
