# DMS Plugin System

DankMaterialShell supports plugins that extend shell functionality. Plugins are stored in `~/.config/DankMaterialShell/plugins/`.

## Plugin Types

### Widget Plugins (`type: "widget"`)

Display UI components in the DankBar.

```json
{
    "id": "myWidget",
    "name": "My Widget",
    "type": "widget",
    "component": "./MyWidget.qml"
}
```

### Daemon Plugins (`type: "daemon"`)

Run invisibly in the background without UI.

```json
{
    "id": "myDaemon",
    "name": "My Daemon",
    "type": "daemon",
    "component": "./MyDaemon.qml"
}
```

### DankDash Tab Plugins (`type: "dashtab"`)

Add custom tabs to DankDash. Tabs appear after builtin tabs (Overview, Media, Wallpapers, etc.) and before the Settings action.

```json
{
    "id": "myTab",
    "name": "My Tab",
    "type": "dashtab",
    "tabName": "My Tab",
    "tabIcon": "star",
    "component": "./MyTab.qml"
}
```

**Manifest Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `tabName` | No | Display name in tab bar (defaults to `name`) |
| `tabIcon` | No | Material icon name (defaults to `icon` or "extension") |
| `tabPosition` | No | "start" or "end" (default: "end") |

**Tab Component:**

```qml
import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    // Plugin ID is injected by PluginService
    property string pluginId: ""

    // Required: Set implicit height for proper sizing
    implicitHeight: 400

    color: "transparent"

    // Your tab content here
    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM

        StyledText {
            text: "My Plugin Tab"
            font.pixelSize: Theme.fontSizeLarge
        }
    }
}
```

### Desktop Widget Plugins (`type: "desktop"`)

Overlay widgets on the desktop background.

### Launcher Plugins (`type: "launcher"` or `capabilities: ["launcher"]`)

Add entries to the application launcher.

## Plugin Manifest

Every plugin requires a `plugin.json` manifest:

```json
{
    "id": "pluginId",
    "name": "Plugin Name",
    "description": "What the plugin does",
    "version": "1.0.0",
    "author": "Author Name",
    "icon": "extension",
    "type": "widget",
    "component": "./Component.qml",
    "settings": "./Settings.qml",
    "permissions": ["settings_read", "settings_write"]
}
```

**Required Fields:**
- `id` - Unique plugin identifier
- `name` - Display name
- `component` - Path to main QML component

**Optional Fields:**
- `description` - Plugin description
- `version` - Semantic version
- `author` - Author name
- `icon` - Material icon name
- `type` - Plugin type (default: "widget")
- `settings` - Path to settings component
- `permissions` - Required permissions
- `capabilities` - Additional capabilities array
- `tabComponent` - Path to DankDash tab component (for widget plugins that also provide a tab)
- `tabName` - Display name in DankDash tab bar
- `tabIcon` - Material icon for the tab

## Widget Plugins with DankDash Tabs

Widget plugins can also provide a DankDash tab by including a `tabComponent` field:

```json
{
    "id": "myWidget",
    "name": "My Widget",
    "type": "widget",
    "component": "./MyWidget.qml",
    "tabComponent": "./MyTab.qml",
    "tabName": "My Tab",
    "tabIcon": "dashboard",
    "settings": "./MySettings.qml"
}
```

This allows a single plugin to provide both a DankBar widget and a DankDash tab.

## Plugin Settings

Plugins can persist settings using the injected `pluginService`:

```qml
// In your plugin component
property var pluginService: null

Component.onCompleted: {
    if (pluginService) {
        var value = pluginService.loadPluginData("myPlugin", "key", defaultValue);
    }
}

function saveSetting(key, value) {
    if (pluginService) {
        pluginService.savePluginData("myPlugin", key, value);
    }
}
```

## Enabling Plugins

1. Create plugin directory: `~/.config/DankMaterialShell/plugins/PluginName/`
2. Add `plugin.json` manifest
3. Add component QML files
4. Open Settings -> Plugins
5. Click "Scan for Plugins"
6. Toggle plugin to enable

## Example: DankDash Tab Plugin

**Directory Structure:**
```
~/.config/DankMaterialShell/plugins/MyTab/
├── plugin.json
└── MyTab.qml
```

**plugin.json:**
```json
{
    "id": "myTab",
    "name": "My Tab",
    "description": "Custom DankDash tab",
    "version": "1.0.0",
    "icon": "dashboard",
    "type": "dashtab",
    "tabName": "My Tab",
    "tabIcon": "dashboard",
    "component": "./MyTab.qml"
}
```

**MyTab.qml:**
```qml
import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root
    property string pluginId: ""
    implicitHeight: 300
    color: "transparent"

    StyledText {
        anchors.centerIn: parent
        text: "Hello from plugin: " + root.pluginId
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceText
    }
}
```

## System Plugins

System-wide plugins can be installed to `/etc/xdg/quickshell/dms-plugins/`. User plugins in `~/.config/DankMaterialShell/plugins/` take precedence over system plugins with the same ID.
