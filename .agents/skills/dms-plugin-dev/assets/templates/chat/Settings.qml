import QtQuick
import qs.Modules.Plugins

// Provider settings, shown under Settings -> Chats.
//
// Whatever these save reaches the bridge as the `settings` object in its
// `configure` call, and again on every change. The bridge never reads this file
// or the shell's settings on disk.
//
// Do not put credentials here -- plugin settings are stored in plain text.
PluginSettings {
    id: root

    pluginId: "myChat"

    StringSetting {
        settingKey: "accountName"
        label: "Account"
        description: "The account this provider signs in as"
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "syncHistory"
        label: "Sync message history"
        description: "Fetch older messages on first sign-in"
        defaultValue: true
    }
}
