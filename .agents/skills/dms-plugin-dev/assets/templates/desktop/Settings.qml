import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "myDesktopWidget"

    SliderSetting {
        settingKey: "opacity"
        label: "Opacity"
        description: "Widget background opacity"
        defaultValue: 85
        minimum: 10
        maximum: 100
        unit: "%"
    }
}
