import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "myLauncher"

    StringSetting {
        settingKey: "trigger"
        label: "Trigger"
        description: "Type this prefix in the launcher to activate the plugin"
        placeholder: "#"
        defaultValue: "#"
    }

    ToggleSetting {
        settingKey: "noTrigger"
        label: "Always Visible"
        description: "Show items alongside regular apps without needing a trigger"
        defaultValue: false
    }
}
