import QtQuick
import qs.Common

Item {
    id: root

    property var pluginService: null
    property string pluginId: ""
    property bool editMode: false
    property real widgetWidth: 200
    property real widgetHeight: 200
    property real minWidth: 150
    property real minHeight: 150

    // TODO: Load settings reactively
    property real bgOpacity: {
        if (!pluginService) return 0.85
        var val = pluginService.loadPluginData(pluginId, "opacity", 85)
        return val / 100
    }

    Connections {
        target: pluginService
        function onPluginDataChanged(changedId) {
            if (changedId !== pluginId) return
            var val = pluginService.loadPluginData(pluginId, "opacity", 85)
            bgOpacity = val / 100
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        opacity: root.bgOpacity
        border.color: root.editMode ? Theme.primary : "transparent"
        border.width: root.editMode ? 2 : 0

        // TODO: Add your widget content here
        Text {
            anchors.centerIn: parent
            text: "Desktop Widget"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeLarge
        }
    }
}
