import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    required property string pluginId
    property var pluginService: null
    default property alias content: settingsColumn.children

    signal settingChanged()

    property var variants: []

    implicitHeight: hasPermission ? settingsColumn.implicitHeight : errorText.implicitHeight
    height: implicitHeight

    readonly property bool hasPermission: pluginService && pluginService.hasPermission ? pluginService.hasPermission(pluginId, "settings_write") : true

    Component.onCompleted: {
        loadVariants()
    }

    onPluginServiceChanged: {
        if (pluginService) {
            loadVariants()
            for (let i = 0; i < settingsColumn.children.length; i++) {
                const child = settingsColumn.children[i]
                if (child.loadValue) {
                    child.loadValue()
                }
            }
        }
    }

    Connections {
        target: pluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === pluginId) {
                loadVariants()
            }
        }
    }

    function loadVariants() {
        if (!pluginService || !pluginId) {
            variants = []
            return
        }
        variants = pluginService.getPluginVariants(pluginId)
    }

    function createVariant(variantName, variantConfig) {
        if (!pluginService || !pluginId) {
            return null
        }
        return pluginService.createPluginVariant(pluginId, variantName, variantConfig)
    }

    function removeVariant(variantId) {
        if (!pluginService || !pluginId) {
            return
        }
        pluginService.removePluginVariant(pluginId, variantId)
    }

    function updateVariant(variantId, variantConfig) {
        if (!pluginService || !pluginId) {
            return
        }
        pluginService.updatePluginVariant(pluginId, variantId, variantConfig)
    }

    function saveValue(key, value) {
        if (!pluginService) {
            return
        }
        if (!hasPermission) {
            console.warn("PluginSettings: Plugin", pluginId, "does not have settings_write permission")
            return
        }
        if (pluginService.savePluginData) {
            pluginService.savePluginData(pluginId, key, value)
            settingChanged()
        }
    }

    function loadValue(key, defaultValue) {
        if (pluginService && pluginService.loadPluginData) {
            return pluginService.loadPluginData(pluginId, key, defaultValue)
        }
        return defaultValue
    }

    StyledText {
        id: errorText
        visible: pluginService && !root.hasPermission
        anchors.fill: parent
        text: qsTr("This plugin does not have 'settings_write' permission.\n\nAdd \"permissions\": [\"settings_read\", \"settings_write\"] to plugin.json")
        color: Theme.error
        font.pixelSize: Theme.fontSizeMedium
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Column {
        id: settingsColumn
        visible: root.hasPermission
        width: parent.width
        spacing: Theme.spacingM
    }
}
