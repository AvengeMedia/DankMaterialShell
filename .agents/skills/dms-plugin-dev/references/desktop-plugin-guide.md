# Desktop Plugin Guide

Desktop plugins are widgets that appear on the desktop background layer. They support drag-and-drop positioning and resize via corner handles.

## Base Component

Desktop widgets use a plain `Item` with injected properties:

```qml
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

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        opacity: 0.85

        // Your content here
    }
}
```

## Injected Properties

These are set automatically by the DesktopPluginWrapper:

| Property | Type | Description |
|----------|------|-------------|
| `pluginService` | object | PluginService reference for data persistence |
| `pluginId` | string | Plugin's unique identifier |
| `editMode` | bool | `true` when user is dragging/resizing |
| `widgetWidth` | real | Current widget container width |
| `widgetHeight` | real | Current widget container height |

## Optional Properties

Define these on your root item to customize behavior:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `minWidth` | real | 100 | Minimum allowed width during resize |
| `minHeight` | real | 100 | Minimum allowed height during resize |

## Position and Size Persistence

Position (`desktopX`, `desktopY`) and size (`desktopWidth`, `desktopHeight`) are automatically managed by the DesktopPluginWrapper. You do not need to handle persistence for positioning.

## Edit Mode

When `editMode` is true, the user is repositioning or resizing. Use this to:
- Show visual indicators (borders, handles)
- Disable interactive elements to prevent accidental actions
- Display additional controls

```qml
Rectangle {
    anchors.fill: parent
    border.color: root.editMode ? Theme.primary : "transparent"
    border.width: root.editMode ? 2 : 0

    MouseArea {
        anchors.fill: parent
        enabled: !root.editMode
        onClicked: doSomething()
    }
}
```

## Loading and Saving Data

Use the injected `pluginService` for data persistence:

```qml
property string displayMode: {
    if (!pluginService) return "default"
    return pluginService.loadPluginData(pluginId, "displayMode", "default")
}

Connections {
    target: pluginService
    function onPluginDataChanged(changedId) {
        if (changedId !== pluginId) return
        root.displayMode = pluginService.loadPluginData(pluginId, "displayMode", "default")
    }
}

function saveMode(mode) {
    pluginService?.savePluginData(pluginId, "displayMode", mode)
}
```

## Settings Component

Desktop plugin settings use the same `PluginSettings` wrapper as other types:

```qml
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

    SelectionSetting {
        settingKey: "style"
        label: "Display Style"
        options: [
            { label: "Compact", value: "compact" },
            { label: "Expanded", value: "expanded" }
        ]
        defaultValue: "compact"
    }
}
```

## User Interaction

Desktop widgets support:
1. **Drag** - click and drag anywhere (in edit mode)
2. **Resize** - drag bottom-right corner handle (in edit mode)
3. **Edit mode toggle** - via the desktop edit button

## Complete Example

Based on the ExampleDesktopClock pattern:

```qml
import QtQuick
import qs.Common

Item {
    id: root

    property var pluginService: null
    property string pluginId: ""
    property bool editMode: false
    property real widgetWidth: 250
    property real widgetHeight: 250
    property real minWidth: 150
    property real minHeight: 150

    property string clockStyle: {
        if (!pluginService) return "digital"
        return pluginService.loadPluginData(pluginId, "clockStyle", "digital")
    }

    property real bgOpacity: {
        if (!pluginService) return 0.85
        var val = pluginService.loadPluginData(pluginId, "opacity", 85)
        return val / 100
    }

    Connections {
        target: pluginService
        function onPluginDataChanged(changedId) {
            if (changedId !== pluginId) return
            clockStyle = pluginService.loadPluginData(pluginId, "clockStyle", "digital")
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

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(new Date(), "hh:mm:ss")
                color: Theme.surfaceText
                font.pixelSize: root.widgetWidth * 0.15
                font.weight: Font.Bold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(new Date(), "ddd, MMM d")
                color: Theme.onSurfaceVariant
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.widgetWidth = root.widgetWidth // force update
    }
}
```

## Manifest Example

```json
{
    "id": "myDesktopClock",
    "name": "Desktop Clock",
    "description": "Analog and digital clock for the desktop",
    "version": "1.0.0",
    "author": "Developer",
    "type": "desktop",
    "capabilities": ["desktop-widget"],
    "component": "./ClockWidget.qml",
    "icon": "schedule",
    "settings": "./Settings.qml",
    "permissions": ["settings_read", "settings_write"]
}
```
