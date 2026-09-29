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
        iconName: "close"
        colorRole: "secondaryContainer"
        Accessible.name: I18n.tr("Dismiss")
        onClicked: SettingsData.revertGreeterSyncPending()
    }

    DankFab {
        text: GreeterService.syncing ? I18n.tr("Syncing...", "greeter settings status while sync is running") : I18n.tr("Sync to apply")
        iconName: "sync"
        colorRole: "primary"
        busy: GreeterService.syncing
        enabled: !GreeterService.syncing && !root.blocked
        onClicked: GreeterService.sync()
    }
}
