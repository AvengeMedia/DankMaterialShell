import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "myDaemon"

    StringSetting {
        settingKey: "configValue"
        label: "Configuration"
        description: "Value used by the daemon"
        placeholder: "Enter value..."
        defaultValue: ""
    }
}
