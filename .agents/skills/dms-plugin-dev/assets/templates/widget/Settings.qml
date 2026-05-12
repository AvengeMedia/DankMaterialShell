import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "myWidget"

    StringSetting {
        settingKey: "text"
        label: "Display Text"
        description: "Text shown in the bar widget"
        placeholder: "Hello"
        defaultValue: "Hello"
    }

    ToggleSetting {
        settingKey: "showIcon"
        label: "Show Icon"
        description: "Display an icon next to the text"
        defaultValue: true
    }
}
