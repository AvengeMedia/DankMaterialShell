import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

SettingsFabBar {
    id: root

    property bool blocked: false

    shown: SessionData.greeterSyncPending && GreeterService.binaryExists

    DankFab {
        text: I18n.tr("Revert")
        iconName: "undo"
        colorRole: "secondaryContainer"
        enabled: !GreeterService.syncing
        onClicked: SettingsData.revertGreeterSyncPending()
    }

    DankFab {
        text: GreeterService.syncing ? I18n.tr("Syncing...", "greeter settings status while sync is running") : I18n.tr("Apply changes")
        iconName: "check"
        colorRole: "primary"
        busy: GreeterService.syncing
        enabled: !GreeterService.syncing && !root.blocked
        onClicked: GreeterService.sync()
    }
}
