# Plugin System

The DMS shell includes an experimental plugin system that allows extending functionality through self-contained, dynamically-loaded QML components.

## Overview

The plugin system enables developers to create custom widgets that can be displayed in the DankBar alongside built-in widgets. Plugins are discovered, loaded, and managed through the **PluginService**, providing a clean separation between core shell functionality and user extensions.

## Architecture

### Core Components

1. **PluginService** (`Services/PluginService.qml`)
   - Singleton service managing plugin lifecycle
   - Discovers plugins from `$CONFIGPATH/DankMaterialShell/plugins/`
   - Handles loading, unloading, and state management
   - Provides data persistence for plugin settings

2. **PluginsTab** (`Modules/Settings/PluginsTab.qml`)
   - UI for managing available plugins
   - Access plugin settings

3. **PluginsTab Settings** (`Modules/Settings/PluginsTab.qml`)
   - Accordion-style plugin configuration interface
   - Dynamically loads plugin settings components inline
   - Provides consistent settings interface with proper focus handling

4. **DankBar Integration** (`Modules/DankBar/DankBar.qml`)
   - Renders plugin widgets in the bar
   - Merges plugin components with built-in widgets
   - Supports left, center, and right sections

## Plugin Structure

Each plugin must be a directory in `$CONFIGPATH/DankMaterialShell/plugins/` containing:

```
$CONFIGPATH/DankMaterialShell/plugins/YourPlugin/
├── plugin.json          # Required: Plugin manifest
├── YourWidget.qml       # Required: Widget component
├── YourSettings.qml     # Optional: Settings UI
├── qmldir               # Optional: QML module definition
└── *.js                 # Optional: JavaScript utilities
```

### Plugin Manifest (plugin.json)

The manifest file defines plugin metadata and configuration:

```json
{
    "id": "yourPlugin",
    "name": "Your Plugin Name",
    "description": "Brief description of what your plugin does",
    "version": "1.0.0",
    "author": "Your Name",
    "icon": "material_icon_name",
    "component": "./YourWidget.qml",
    "settings": "./YourSettings.qml",
    "dependencies": {
        "libraryName": {
            "url": "https://cdn.example.com/library.js",
            "optional": true
        }
    },
    "settings_schema": {
        "settingKey": {
            "type": "string|number|boolean|array|object",
            "default": "defaultValue"
        }
    },
    "permissions": [
        "settings_read",
        "settings_write"
    ]
}
```

**Required Fields:**
- `id`: Unique plugin identifier (camelCase, no spaces)
- `name`: Human-readable plugin name
- `component`: Relative path to widget QML file

**Optional Fields:**
- `description`: Short description of plugin functionality
- `version`: Semantic version string
- `author`: Plugin creator name
- `icon`: Material Design icon name
- `settings`: Path to settings component
- `dependencies`: External JS libraries
- `settings_schema`: Configuration schema
- `permissions`: Required capabilities

### Widget Component

The main widget component is displayed in the DankBar. It receives several properties from the shell:

```qml
import QtQuick

Rectangle {
    id: root

    // Standard properties provided by DankBar
    property bool compactMode: false
    property string section: "center"       // "left", "center", or "right"
    property var popupTarget: null
    property var parentScreen: null
    property real barHeight: 48
    property real widgetHeight: 30

    // Widget dimensions
    width: content.implicitWidth + horizontalPadding * 2
    height: widgetHeight

    // PluginService is injected by PluginsTab when loading settings
    property var pluginService

    // Access plugin data
    Component.onCompleted: {
        if (pluginService) {
            var savedData = pluginService.loadPluginData("yourPlugin", "dataKey", defaultValue)
        }
    }

    // Save plugin data
    function saveData(key, value) {
        if (pluginService) {
            pluginService.savePluginData("yourPlugin", key, value)
        }
    }
}
```

**Important Properties:**
- `compactMode`: Whether the bar is in compact display mode
- `section`: Which bar section the widget is in
- `barHeight`: Height of the entire bar
- `widgetHeight`: Recommended widget height
- `parentScreen`: Reference to the screen object

### Settings Component

Optional settings UI loaded inline in the PluginsTab accordion interface:

```qml
import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    // PluginService is injected by PluginsTab
    property var pluginService

    spacing: Theme.spacingM

    DankTextField {
        id: settingInput
        width: parent.width
        label: "Setting Label"
        text: pluginService ? pluginService.loadPluginData("yourPlugin", "settingKey", "default") : ""
        onTextChanged: {
            if (pluginService) {
                pluginService.savePluginData("yourPlugin", "settingKey", text)
            }
        }
    }

    DankToggle {
        checked: pluginService ? pluginService.loadPluginData("yourPlugin", "enabled", true) : false
        onToggled: {
            if (pluginService) {
                pluginService.savePluginData("yourPlugin", "enabled", checked)
            }
        }
    }
}
```

## PluginService API

### Properties

```qml
PluginService.pluginDirectory: string
// Path to plugins directory ($CONFIGPATH/DankMaterialShell/plugins)

PluginService.availablePlugins: object
// Map of all discovered plugins {pluginId: pluginInfo}

PluginService.loadedPlugins: object
// Map of currently loaded plugins {pluginId: pluginInfo}

PluginService.pluginWidgetComponents: object
// Map of loaded widget components {pluginId: Component}
```

### Functions

```qml
// Plugin Management
PluginService.loadPlugin(pluginId: string): bool
PluginService.unloadPlugin(pluginId: string): bool
PluginService.reloadPlugin(pluginId: string): bool
PluginService.enablePlugin(pluginId: string): bool
PluginService.disablePlugin(pluginId: string): bool

// Plugin Discovery
PluginService.scanPlugins(): void
PluginService.getAvailablePlugins(): array
PluginService.getLoadedPlugins(): array
PluginService.isPluginLoaded(pluginId: string): bool
PluginService.getWidgetComponents(): object

// Data Persistence
PluginService.savePluginData(pluginId: string, key: string, value: any): bool
PluginService.loadPluginData(pluginId: string, key: string, defaultValue: any): any
```

### Signals

```qml
PluginService.pluginLoaded(pluginId: string)
PluginService.pluginUnloaded(pluginId: string)
PluginService.pluginLoadFailed(pluginId: string, error: string)
```

## Creating a Plugin

### Step 1: Create Plugin Directory

```bash
mkdir -p $CONFIGPATH/DankMaterialShell/plugins/MyPlugin
cd $CONFIGPATH/DankMaterialShell/plugins/MyPlugin
```

### Step 2: Create Manifest

Create `plugin.json`:

```json
{
    "id": "myPlugin",
    "name": "My Plugin",
    "description": "A sample plugin",
    "version": "1.0.0",
    "author": "Your Name",
    "icon": "extension",
    "component": "./MyWidget.qml",
    "settings": "./MySettings.qml",
    "permissions": ["settings_read", "settings_write"]
}
```

### Step 3: Create Widget Component

Create `MyWidget.qml`:

```qml
import QtQuick
import qs.Services

Rectangle {
    id: root

    property bool compactMode: false
    property string section: "center"
    property real widgetHeight: 30
    property string displayText: "Hello World"

    width: textItem.implicitWidth + 16
    height: widgetHeight
    radius: 8
    color: "#20FFFFFF"

    Component.onCompleted: {
        displayText = PluginService.loadPluginData("myPlugin", "text", "Hello World")
    }

    Text {
        id: textItem
        anchors.centerIn: parent
        text: root.displayText
        color: "#FFFFFF"
        font.pixelSize: 13
    }

    MouseArea {
        anchors.fill: parent
        onClicked: console.log("Plugin clicked!")
    }
}
```

### Step 4: Create Settings Component (Optional)

Create `MySettings.qml`:

```qml
import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Column {
    // PluginService is injected by PluginsTab
    property var pluginService

    spacing: Theme.spacingM

    StyledText {
        text: "Plugin Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
    }

    DankTextField {
        width: parent.width
        label: "Display Text"
        text: pluginService ? pluginService.loadPluginData("myPlugin", "text", "Hello World") : ""
        onTextChanged: {
            if (pluginService) {
                pluginService.savePluginData("myPlugin", "text", text)
            }
        }
    }
}
```

### Step 5: Enable Plugin

1. Run the shell: `qs -p $CONFIGPATH/quickshell/dms/shell.qml`
2. Open Settings (Ctrl+,)
3. Navigate to Plugins tab
4. Click "Scan for Plugins"
5. Enable your plugin with the toggle switch
6. Add the plugin to your DankBar configuration

## Adding Plugin to DankBar

After enabling a plugin, add it to the bar:

1. Open Settings → Appearance → DankBar Layout
2. Add a new widget entry with your plugin ID
3. Choose section (left, center, right)
4. Save and reload

Or edit `$CONFIGPATH/quickshell/dms/config.json`:

```json
{
    "dankBarLeftWidgets": [
        {"widgetId": "myPlugin", "enabled": true}
    ]
}
```

## Best Practices

1. **Use Existing Widgets**: Leverage `qs.Widgets` components (DankIcon, DankToggle, etc.) for consistency
2. **Follow Theme**: Use `Theme` singleton for colors, spacing, and fonts
3. **Data Persistence**: Use PluginService data APIs instead of manual file operations
4. **Error Handling**: Gracefully handle missing dependencies and invalid data
5. **Performance**: Keep widgets lightweight, avoid expensive operations
6. **Responsive Design**: Adapt to `compactMode` and different screen sizes
7. **Clean Code**: Follow QML code conventions from CLAUDE.md
8. **Documentation**: Include README.md explaining plugin usage
9. **Versioning**: Use semantic versioning for updates
10. **Dependencies**: Document external library requirements

## Debugging

### Console Logging

View plugin logs:

```bash
qs -v -p $CONFIGPATH/quickshell/dms/shell.qml
```

Look for lines prefixed with:
- `PluginService:` - Service operations
- `PluginsTab:` - UI interactions
- `PluginsTab:` - Settings loading and accordion interface

### Common Issues

1. **Plugin Not Detected**
   - Check plugin.json syntax (use `jq` or JSON validator)
   - Verify directory is in `$CONFIGPATH/DankMaterialShell/plugins/`
   - Click "Scan for Plugins" in Settings

2. **Widget Not Displaying**
   - Ensure plugin is enabled in Settings
   - Add plugin ID to DankBar widget list
   - Check widget width/height properties

3. **Settings Not Loading**
   - Verify `settings` path in plugin.json
   - Check settings component for errors
   - Ensure plugin is enabled and loaded
   - Review PluginsTab console output for injection issues

4. **Data Not Persisting**
   - Confirm pluginService.savePluginData() calls (with injection)
   - Check `$CONFIGPATH/DankMaterialShell/settings.json` for pluginSettings data
   - Verify plugin has settings permissions
   - Ensure PluginService was properly injected into settings component

## Security Considerations

Plugins run with full QML runtime access. Only install plugins from trusted sources.

**Permissions System:**
- `settings_read`: Read plugin configuration
- `settings_write`: Write plugin configuration
- `process`: Execute system commands
- `network`: Network access

Future versions may enforce permission restrictions.

## API Stability

The plugin API is currently **experimental**. Breaking changes may occur in minor version updates. Pin to specific DMS versions for production use.

**Roadmap:**
- Plugin marketplace/repository
- Sandboxed plugin execution
- Enhanced permission system
- Plugin update notifications
- Inter-plugin communication

## Resources

- **Example Plugin**: https://github.com/rochacbruno/WorldClock
- **PluginService**: `Services/PluginService.qml`
- **Settings UI**: `Modules/Settings/PluginsTab.qml`
- **DankBar Integration**: `Modules/DankBar/DankBar.qml`
- **Theme Reference**: `Common/Theme.qml`
- **Widget Library**: `Widgets/`

## Contributing

Share your plugins with the community:

1. Create a public repository with your plugin
2. Include comprehensive README.md
4. Add example screenshots
5. Document dependencies and permissions

For plugin system improvements, submit issues or PRs to the main DMS repository.
