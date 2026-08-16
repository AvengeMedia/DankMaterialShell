import QtQuick
import qs.Modules.Plugins

// Provider settings shown under Settings -> Chats.
//
// Whatever these save is delivered to the bridge as the `settings` object in
// its `configure` call, and again whenever the user changes something. The
// bridge never reads this file or the shell's settings on disk.
PluginSettings {
    id: root

    pluginId: "echoChat"

    StringSetting {
        settingKey: "peerName"
        label: "Contact name"
        description: "Who the echo appears to come from"
        defaultValue: "Ada Lovelace"
    }

    StringSetting {
        settingKey: "echoPrefix"
        label: "Echo prefix"
        description: "Prepended to whatever you send"
        defaultValue: "You said: "
    }
}
