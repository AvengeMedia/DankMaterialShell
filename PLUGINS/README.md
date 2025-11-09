# Plugin System

Create widgets for DankBar and Control Center using dynamically-loaded QML components.

## Plugin Registry

Browse and discover community plugins at **https://plugins.danklinux.com/**

## Overview

Plugins let you add custom widgets to DankBar and Control Center. They're discovered from `~/.config/DankMaterialShell/plugins/` and managed via PluginService.

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
   - Supports any dankbar position (top/left/right/bottom)

## Plugin Structure

Each plugin must be a directory in `$CONFIGPATH/DankMaterialShell/plugins/` containing:

```
$CONFIGPATH/DankMaterialShell/plugins/YourPlugin/
├── plugin.json          # Required: Plugin manifest
├── YourWidget.qml       # Required: Widget component
├── YourSettings.qml     # Optional: Settings UI
└── *.js                 # Optional: JavaScript utilities
```

### Plugin Manifest (plugin.json)

The manifest file defines plugin metadata and configuration.

**JSON Schema:** See `plugin-schema.json` for the complete specification and validation schema.

```json
{
    "id": "yourPlugin",
    "name": "Your Plugin Name",
    "description": "Brief description of what your plugin does",
    "version": "1.0.0",
    "author": "Your Name",
    "type": "widget",
    "capabilities": ["thing-my-plugin-does"],
    "component": "./YourWidget.qml",
    "icon": "material_icon_name",
    "settings": "./YourSettings.qml",
    "requires_dms": ">=0.1.0",
    "requires": ["some-system-tool"],
    "permissions": [
        "settings_read",
        "settings_write"
    ]
}
```

**Required Fields:**
- `id`: Unique plugin identifier (camelCase, no spaces)
- `name`: Human-readable plugin name
- `description`: Short description of plugin functionality (displayed in UI)
- `version`: Semantic version string (e.g., "1.0.0")
- `author`: Plugin creator name or email
- `type`: Plugin type - "widget", "daemon", or "launcher"
- `capabilities`: Array of plugin capabilities  (e.g., ["dankbar-widget"], ["control-center"], ["monitoring"])
- `component`: Relative path to main QML component file

**Required for Launcher Type:**
- `trigger`: Trigger string for launcher activation (e.g., "=", "#", "!")

**Optional Fields:**
- `icon`: Material Design icon name (displayed in UI)
- `settings`: Path to settings component (enables settings UI)
- `requires_dms`: Minimum DMS version requirement (e.g., ">=0.1.18", ">0.1.0")
- `requires`: Array of required system tools/dependencies (e.g., ["wl-copy", "curl"])
- `permissions`: Required DMS permissions (e.g., ["settings_read", "settings_write"])

**Permissions:**

The plugin system enforces permissions when settings are accessed:
- `settings_read`: Required to read plugin settings (currently not enforced)
- `settings_write`: **Required** to use PluginSettings component and save settings

If your plugin includes a settings component but doesn't declare `settings_write` permission, users will see an error message instead of the settings UI.

### Widget Component

The main widget component uses the **PluginComponent** wrapper which provides automatic property injection and bar integration:

```qml
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    // Define horizontal bar pill, for top and bottom DankBar positions (optional)
    horizontalBarPill: Component {
        StyledRect {
            width: content.implicitWidth + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            StyledText {
                id: content
                anchors.centerIn: parent
                text: "Hello World"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }

    // Define vertical bar pill, for left and right DankBar positions (optional)
    verticalBarPill: Component {
        // Same as horizontal but optimized for vertical layout
    }

    // Define popout content, opens when clicking the bar pill (optional)
    popoutContent: Component {
        PopoutComponent {
            headerText: "My Plugin"
            detailsText: "Optional description text goes here"
            showCloseButton: true

            // Your popout content goes here
            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    text: "Popout Content"
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                }
            }
        }
    }

    // Popout dimensions (required if popoutContent is set)
    popoutWidth: 400
    popoutHeight: 300
}
```

**PluginComponent Properties (automatically injected):**
- `axis`: Bar axis information (horizontal/vertical)
- `section`: Bar section ("left", "center", "right")
- `parentScreen`: Screen reference for multi-monitor support
- `widgetThickness`: Recommended widget size perpendicular to bar
- `barThickness`: Bar thickness parallel to edge

**Component Options:**
- `horizontalBarPill`: Component shown in horizontal bars
- `verticalBarPill`: Component shown in vertical bars
- `popoutContent`: Optional popout window content
- `popoutWidth`: Popout window width
- `popoutHeight`: Popout window height
- `pillClickAction`: Custom click handler function (overrides popout)
- `pillRightClickAction`: Custom right click handler function

### Control Center Integration

Add your plugin to Control Center by defining CC properties:

```qml
PluginComponent {
    ccWidgetIcon: "toggle_on"
    ccWidgetPrimaryText: "My Feature"
    ccWidgetSecondaryText: isEnabled ? "Active" : "Inactive"
    ccWidgetIsActive: isEnabled

    onCcWidgetToggled: {
        isEnabled = !isEnabled
        if (pluginService) {
            pluginService.savePluginData("myPlugin", "isEnabled", isEnabled)
        }
    }

    ccDetailContent: Component {
        Rectangle {
            implicitHeight: 200
            color: Theme.surfaceContainerHigh
            radius: Theme.cornerRadius
            // Your detail UI here
        }
    }

    horizontalBarPill: Component { /* ... */ }
}
```

**CC Properties:**
- `ccWidgetIcon`: Material icon name
- `ccWidgetPrimaryText`: Main label
- `ccWidgetSecondaryText`: Subtitle/status
- `ccWidgetIsActive`: Active state styling
- `ccDetailContent`: Optional dropdown panel (use for CompoundPill)

**Signals:**
- `ccWidgetToggled()`: Fired when icon clicked
- `ccWidgetExpanded()`: Fired when expand area clicked (CompoundPill only)

**Widget Sizing:**
- 25% width → SmallToggleButton (icon only)
- 50% width → ToggleButton (no detail) or CompoundPill (with detail)
- Users can resize in edit mode

**Custom Click Actions:**

Override default popout with `pillClickAction` and `pillRightClickAction`:

```qml
pillClickAction: () => {
    Process.exec("bash", ["-c", "notify-send 'Clicked!'"])
}

// Or with position params: (x, y, width, section, screen)
pillClickAction: (x, y, width, section, screen) => {
    popoutService?.toggleControlCenter(x, y, width, section, screen)
}

pillRightClickAction: () => {
    Process.exec("bash", ["-c", "notify-send 'Right clicked!'"])
}

pillRightClickAction: (x, y, width, section, screen) => {
    popoutService?.toggleControlCenter(x, y, width, section, screen)
}
```

The PluginComponent automatically handles:
- Bar orientation detection
- Click handlers for popouts
- Proper positioning and anchoring
- Theme integration

### PopoutComponent

PopoutComponent provides a consistent header/content layout for plugin popouts:

```qml
import qs.Modules.Plugins

PopoutComponent {
    headerText: "Header Title"        // Main header text (bold, large)
    detailsText: "Description text"   // Optional description (smaller, gray)
    showCloseButton: true             // Show X button in top-right

    // Access to exposed properties for dynamic sizing
    readonly property int headerHeight    // Height of header area
    readonly property int detailsHeight   // Height of description area

    // Your content here - use parent.width for full width
    // Calculate available height: root.popoutHeight - headerHeight - detailsHeight - spacing
    DankGridView {
        width: parent.width
        height: parent.height
        // ...
    }
}
```

**PopoutComponent Properties:**
- `headerText`: Main header text (optional, hidden if empty)
- `detailsText`: Description text below header (optional, hidden if empty)
- `showCloseButton`: Show close button in header (default: false)
- `closePopout`: Function to close popout (auto-injected by PluginPopout)
- `headerHeight`: Readonly height of header (0 if not visible)
- `detailsHeight`: Readonly height of description (0 if not visible)

The component automatically handles spacing and layout. Content children are rendered below the description with proper padding.

### Settings Component

Optional settings UI loaded inline in the PluginsTab accordion interface. Use the simplified settings API with auto-storage components:

```qml
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "yourPlugin"

    StringSetting {
        settingKey: "apiKey"
        label: "API Key"
        description: "Your API key for accessing the service"
        placeholder: "Enter API key..."
    }

    ToggleSetting {
        settingKey: "notifications"
        label: "Enable Notifications"
        description: "Show desktop notifications for updates"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "updateInterval"
        label: "Update Interval"
        description: "How often to refresh data"
        options: [
            {label: "1 minute", value: "60"},
            {label: "5 minutes", value: "300"},
            {label: "15 minutes", value: "900"}
        ]
        defaultValue: "300"
    }

    ListSetting {
        id: itemList
        settingKey: "items"
        label: "Saved Items"
        description: "List of configured items"
        delegate: Component {
            StyledRect {
                width: parent.width
                height: 40
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    color: Theme.surfaceText
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    height: 28
                    color: removeArea.containsMouse ? Theme.errorHover : Theme.error
                    radius: Theme.cornerRadius

                    StyledText {
                        anchors.centerIn: parent
                        text: "Remove"
                        color: Theme.errorText
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: removeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: itemList.removeItem(index)
                    }
                }
            }
        }
    }
}
```

**Available Setting Components:**

All settings automatically save on change and load on component creation.

**How Default Values Work:**

Each setting component has a `defaultValue` property that is used when no saved value exists. Define sensible defaults in your settings UI:

```qml
StringSetting {
    settingKey: "apiKey"
    defaultValue: ""  // Empty string if no key saved
}

ToggleSetting {
    settingKey: "enabled"
    defaultValue: true  // Enabled by default
}

ListSettingWithInput {
    settingKey: "locations"
    defaultValue: []  // Empty array if no locations saved
}
```

1. **PluginSettings** - Root wrapper for all plugin settings
   - `pluginId`: Your plugin ID (required)
   - Auto-handles storage and provides saveValue/loadValue to children
   - Place all other setting components inside this wrapper

2. **StringSetting** - Text input field
   - `settingKey`: Storage key (required)
   - `label`: Display label (required)
   - `description`: Help text (optional)
   - `placeholder`: Input placeholder (optional)
   - `defaultValue`: Default value (optional, default: `""`)
   - Layout: Vertical stack (label, description, input field)

3. **ToggleSetting** - Boolean toggle switch
   - `settingKey`: Storage key (required)
   - `label`: Display label (required)
   - `description`: Help text (optional)
   - `defaultValue`: Default boolean (optional, default: `false`)
   - Layout: Horizontal (label/description left, toggle right)

4. **SelectionSetting** - Dropdown menu
   - `settingKey`: Storage key (required)
   - `label`: Display label (required)
   - `description`: Help text (optional)
   - `options`: Array of `{label, value}` objects or simple strings (required)
   - `defaultValue`: Default value (optional, default: `""`)
   - Layout: Horizontal (label/description left, dropdown right)
   - Stores the `value` field, displays the `label` field

5. **ListSetting** - Manage list of items (manual add/remove)
   - `settingKey`: Storage key (required)
   - `label`: Display label (required)
   - `description`: Help text (optional)
   - `defaultValue`: Default array (optional, default: `[]`)
   - `delegate`: Custom item delegate Component (optional)
   - `addItem(item)`: Add item to list
   - `removeItem(index)`: Remove item from list
   - Use when you need custom UI for adding items

6. **ListSettingWithInput** - Complete list management with built-in form
   - `settingKey`: Storage key (required)
   - `label`: Display label (required)
   - `description`: Help text (optional)
   - `defaultValue`: Default array (optional, default: `[]`)
   - `fields`: Array of field definitions (required)
     - `id`: Field ID in saved object (required)
     - `label`: Column header text (required)
     - `placeholder`: Input placeholder (optional)
     - `width`: Column width in pixels (optional, default 200)
     - `required`: Must have value to add (optional, default false)
     - `default`: Default value if empty (optional)
   - Automatically generates:
     - Column headers from field labels
     - Input fields with placeholders
     - Add button with validation
     - List display showing all field values
     - Remove buttons for each item
   - Best for collecting structured data (servers, locations, etc.)

**Complete Settings Example:**

```qml
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "myPlugin"

    StyledText {
        width: parent.width
        text: "General Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "apiKey"
        label: "API Key"
        description: "Your service API key"
        placeholder: "sk-..."
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "enabled"
        label: "Enable Feature"
        description: "Turn this feature on or off"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "theme"
        label: "Theme"
        description: "Choose your preferred theme"
        options: [
            {label: "Dark", value: "dark"},
            {label: "Light", value: "light"},
            {label: "Auto", value: "auto"}
        ]
        defaultValue: "dark"
    }

    ListSettingWithInput {
        settingKey: "locations"
        label: "Locations"
        description: "Track multiple locations"
        defaultValue: []
        fields: [
            {id: "name", label: "Name", placeholder: "Home", width: 150, required: true},
            {id: "timezone", label: "Timezone", placeholder: "America/New_York", width: 200, required: true}
        ]
    }
}
```

**Key Benefits:**
- Zero boilerplate - just define your settings
- Automatic persistence to `settings.json`
- Clean, consistent UI across all plugins
- No manual `pluginService` calls needed
- Proper layout and spacing handled automatically

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

// Global Variables - Shared state across all plugin instances
PluginService.getGlobalVar(pluginId: string, varName: string, defaultValue: any): any
PluginService.setGlobalVar(pluginId: string, varName: string, value: any): void
```

### Signals

```qml
PluginService.pluginLoaded(pluginId: string)
PluginService.pluginUnloaded(pluginId: string)
PluginService.pluginLoadFailed(pluginId: string, error: string)
PluginService.globalVarChanged(pluginId: string, varName: string)
```

## Plugin Global Variables

Plugins can share state across multiple instances using global variables. This is useful when you have the same widget displayed on multiple monitors or multiple instances of the same widget on different bars.

### Why Use Global Variables?

Unlike regular properties which are scoped to each component instance, global variables are synchronized across all instances of your plugin. This enables:

- **Multi-monitor consistency**: Same data displayed across all monitors
- **Multi-instance widgets**: Multiple instances of the same widget sharing state
- **Cross-component communication**: Share data between widget and settings components

### Using PluginGlobalVar

The `PluginGlobalVar` helper component provides reactive global variable access:

```qml
import QtQuick
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    PluginGlobalVar {
        id: globalCounter
        varName: "counter"
        defaultValue: 0
    }

    horizontalBarPill: Component {
        StyledRect {
            width: content.implicitWidth + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            StyledText {
                id: content
                anchors.centerIn: parent
                text: "Count: " + globalCounter.value
                color: Theme.surfaceText
            }

            MouseArea {
                anchors.fill: parent
                onClicked: globalCounter.set(globalCounter.value + 1)
            }
        }
    }
}
```

**PluginGlobalVar Properties:**
- `varName` (required): Name of the global variable
- `defaultValue` (optional): Default value if not set
- `value` (readonly): Current value of the global variable

**PluginGlobalVar Methods:**
- `set(newValue)`: Update the global variable (triggers reactivity across all instances)

### Using PluginService API Directly

For more control, use the PluginService API directly:

```qml
import QtQuick
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    property int counter: PluginService.getGlobalVar("myPlugin", "counter", 0)

    Connections {
        target: PluginService
        function onGlobalVarChanged(pluginId, varName) {
            if (pluginId === "myPlugin" && varName === "counter") {
                counter = PluginService.getGlobalVar("myPlugin", "counter", 0)
            }
        }
    }

    horizontalBarPill: Component {
        StyledRect {
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    const current = PluginService.getGlobalVar("myPlugin", "counter", 0)
                    PluginService.setGlobalVar("myPlugin", "counter", current + 1)
                }
            }
        }
    }
}
```

### Global Variables vs Settings

**Global Variables** (`getGlobalVar`/`setGlobalVar`):
- Runtime state only (not persisted to disk)
- Synchronized across all plugin instances
- Changes trigger `globalVarChanged` signal for reactivity
- Use for: counters, current selection, temporary UI state

**Settings** (`savePluginData`/`loadPluginData`):
- Persisted to `settings.json` across sessions
- Loaded once per plugin instance
- Use for: user preferences, API keys, configuration

### Important Notes

1. **Reactivity**: Global variables are reactive - all instances update when a value changes
2. **Namespacing**: Variables are namespaced by plugin ID to avoid conflicts
3. **Type Safety**: Values can be any QML/JavaScript type (numbers, strings, objects, arrays)
4. **Not Persistent**: Global variables are cleared when the shell restarts (use settings for persistence)
5. **Performance**: Efficient for frequent updates - changes only trigger updates for the specific variable

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
    "type": "widget",
    "capabilities": ["my-functionality"],
    "component": "./MyWidget.qml",
    "icon": "extension",
    "settings": "./MySettings.qml",
    "requires_dms": ">=0.1.0",
    "permissions": ["settings_read", "settings_write"]
}
```

### Step 3: Create Widget Component

Create `MyWidget.qml`:

```qml
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    horizontalBarPill: Component {
        StyledRect {
            width: textItem.implicitWidth + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            StyledText {
                id: textItem
                anchors.centerIn: parent
                text: "Hello World"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }

    verticalBarPill: Component {
        StyledRect {
            width: parent.widgetThickness
            height: textItem.implicitWidth + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            StyledText {
                id: textItem
                anchors.centerIn: parent
                text: "Hello"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                rotation: 90
            }
        }
    }
}
```

**Note:** Use `PluginComponent` wrapper for automatic property injection and bar integration. Define separate components for horizontal and vertical orientations.

### Step 4: Create Settings Component (Optional)

Create `MySettings.qml`:

```qml
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "myPlugin"

    StyledText {
        width: parent.width
        text: "Configure your plugin settings"
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "text"
        label: "Display Text"
        description: "Text shown in the bar widget"
        placeholder: "Hello World"
        defaultValue: "Hello World"
    }

    ToggleSetting {
        settingKey: "showIcon"
        label: "Show Icon"
        description: "Display an icon next to the text"
        defaultValue: true
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
5. **Performance**: Keep widgets lightweight, avoid long operations that block the UI loop
6. **Responsive Design**: Adapt to `compactMode` and different screen sizes
7. **Documentation**: Include README.md explaining plugin usage
8. **Versioning**: Use semantic versioning for updates
9. **Dependencies**: Document external library requirements

## Clipboard Access

Plugins that need to copy text to the clipboard **must** use the Wayland clipboard utility `wl-copy` through Quickshell's `execDetached` function.

### Correct Method

Import Quickshell and use `execDetached` with `wl-copy`:

```qml
import QtQuick
import Quickshell

Item {
    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c", "echo -n '" + text + "' | wl-copy"])
    }
}
```

### Example Usage

From the ExampleEmojiPlugin (EmojiWidget.qml:136):

```qml
MouseArea {
    onClicked: {
        Quickshell.execDetached(["sh", "-c", "echo -n '" + modelData + "' | wl-copy"])
        ToastService.showInfo("Copied " + modelData + " to clipboard")
        popoutColumn.closePopout()
    }
}
```

### Important Notes

1. **Do NOT** use `globalThis.clipboard` or similar JavaScript APIs - they don't exist in the QML runtime
2. **Always** import `Quickshell` at the top of your QML file
3. **Use** `echo -n` to prevent adding a trailing newline to the clipboard content
4. The `-c` flag for `sh` is required to execute the pipe command properly
5. Consider showing a toast notification to confirm the copy action to users

### Dependencies

This method requires `wl-copy` from the `wl-clipboard` package, which is standard on Wayland systems.

## Running External Commands

Plugins that need to execute external commands and capture their output should use the `Proc` singleton, which provides debounced command execution with automatic cleanup.

### Correct Method

Import the `Proc` singleton from `qs.Common` and use `runCommand`:

```qml
import QtQuick
import qs.Common

Item {
    function fetchData() {
        Proc.runCommand(
            "myPlugin.fetchData",
            ["curl", "-s", "https://api.example.com/data"],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    console.log("Success:", stdout)
                    processData(stdout)
                } else {
                    console.error("Command failed with exit code:", exitCode)
                }
            },
            100
        )
    }
}
```

### Function Signature

```qml
Proc.runCommand(id, command, callback, debounceMs)
```

**Parameters:**
- `id` (string): Unique identifier for this command. Used for debouncing - multiple calls with the same ID within the debounce window will only execute the last one
- `command` (array): Command and arguments as an array (e.g., `["sh", "-c", "echo hello"]`)
- `callback` (function): Callback function receiving `(stdout, exitCode)` when the command completes
  - `stdout` (string): Captured standard output from the command
  - `exitCode` (number): Exit code of the process (0 typically means success)
- `debounceMs` (number, optional): Debounce delay in milliseconds. Defaults to 50ms if not specified

### Key Features

1. **Automatic Cleanup**: Process objects are automatically destroyed after completion
2. **Debouncing**: Rapid successive calls with the same ID are debounced, only executing the last one
3. **Output Capture**: Automatically captures stdout for processing
4. **Error Handling**: Exit codes are passed to the callback for error detection

### Example Usage

#### Simple Command Execution

```qml
import QtQuick
import qs.Common

Item {
    function checkNetwork() {
        Proc.runCommand(
            "myPlugin.ping",
            ["ping", "-c", "1", "8.8.8.8"],
            (output, exitCode) => {
                if (exitCode === 0) {
                    console.log("Network is up")
                } else {
                    console.log("Network is down")
                }
            }
        )
    }
}
```

#### Parsing Command Output

```qml
import QtQuick
import qs.Common

Item {
    property var diskUsage: ({})

    function updateDiskUsage() {
        Proc.runCommand(
            "myPlugin.df",
            ["df", "-h", "/home"],
            (output, exitCode) => {
                if (exitCode === 0) {
                    const lines = output.trim().split("\n")
                    if (lines.length > 1) {
                        const parts = lines[1].split(/\s+/)
                        diskUsage = {
                            total: parts[1],
                            used: parts[2],
                            available: parts[3],
                            percent: parts[4]
                        }
                    }
                }
            }
        )
    }
}
```

#### Shell Commands with Pipes

```qml
import QtQuick
import qs.Common

Item {
    function getTopProcess() {
        Proc.runCommand(
            "myPlugin.topProcess",
            ["sh", "-c", "ps aux | sort -nrk 3,3 | head -n 1"],
            (output, exitCode) => {
                if (exitCode === 0) {
                    console.log("Top process:", output)
                }
            }
        )
    }
}
```

#### Debouncing Rapid Updates

```qml
import QtQuick
import qs.Common
import qs.Widgets

Item {
    DankTextField {
        id: searchField
        placeholderText: "Search files..."

        onTextChanged: {
            Proc.runCommand(
                "myPlugin.search",
                ["find", "/home", "-name", "*" + text + "*"],
                (output, exitCode) => {
                    if (exitCode === 0) {
                        updateSearchResults(output)
                    }
                },
                500
            )
        }
    }
}
```

### Important Notes

1. **Unique IDs**: Use descriptive, namespaced IDs (e.g., `"myPlugin.actionName"`) to avoid conflicts
2. **Debouncing**: Use appropriate debounce delays for your use case:
   - Fast updates (50-100ms): System monitoring, real-time data
   - User input (300-500ms): Search fields, text input processing
   - Network requests (500-1000ms): API calls, web scraping
3. **Error Handling**: Always check the exit code in your callback before processing output
4. **Shell Commands**: Use `["sh", "-c", "command"]` for complex shell commands with pipes or redirects
5. **Security**: Sanitize user input before passing to commands to prevent command injection
6. **Performance**: Avoid running expensive commands too frequently - use debouncing wisely

### Comparison with Other Methods

**Proc.runCommand** vs **Quickshell.execDetached**:
- Use `Proc.runCommand` when you need to capture output or check exit codes
- Use `Quickshell.execDetached` for fire-and-forget operations (like clipboard copy)

**Proc.runCommand** vs **Process component**:
- Use `Proc.runCommand` for simple, one-off command executions with automatic cleanup
- Use `Process` component for long-running processes or when you need fine-grained control

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
- `settings_read`: Read plugin configuration (not currently enforced)
- `settings_write`: **Required** to use PluginSettings - write plugin configuration (enforced)
- `process`: Execute system commands (not currently enforced)
- `network`: Network access (not currently enforced)

Currently, only `settings_write` is enforced by the PluginSettings component.

## API Stability

The plugin API is currently **experimental**. Breaking changes may occur in minor version updates. Pin to specific DMS versions for production use.

**Roadmap:**
- Plugin marketplace/repository
- Sandboxed plugin execution
- Enhanced permission system
- Plugin update notifications
- Inter-plugin communication

## Launcher Plugins

Launcher plugins extend the DMS application launcher by adding custom searchable items with trigger-based filtering.

### Overview

Launcher plugins enable you to:
- Add custom items to the launcher/app drawer
- Use trigger strings for quick filtering (e.g., `!`, `#`, `@`)
- Execute custom actions when items are selected
- Provide searchable, categorized content
- Integrate seamlessly with the existing launcher

### Plugin Type Configuration

To create a launcher plugin, set the plugin type in `plugin.json`:

```json
{
    "id": "myLauncher",
    "name": "My Launcher Plugin",
    "description": "A custom launcher plugin for quick actions",
    "version": "1.0.0",
    "author": "Your Name",
    "type": "launcher",
    "capabilities": ["show-thing"],
    "component": "./MyLauncher.qml",
    "trigger": "#",
    "icon": "search",
    "settings": "./MySettings.qml",
    "requires_dms": ">=0.1.18",
    "permissions": ["settings_read", "settings_write"]
}
```

### Launcher Component Contract

Create `MyLauncher.qml` with the following interface:

```qml
import QtQuick
import qs.Services

Item {
    id: root

    // Required properties
    property var pluginService: null
    property string trigger: "#"

    // Required signals
    signal itemsChanged()

    // Required: Return array of launcher items
    function getItems(query) {
        return [
            {
                name: "Item Name",
                icon: "icon_name",
                comment: "Description",
                action: "type:data",
                categories: ["MyLauncher"]
            }
        ]
    }

    // Required: Execute item action
    function executeItem(item) {
        const [type, data] = item.action.split(":", 2)
        // Handle action based on type
    }

    Component.onCompleted: {
        if (pluginService) {
            trigger = pluginService.loadPluginData("myLauncher", "trigger", "#")
        }
    }
}
```

### Item Structure

Each item returned by `getItems()` must include:

- `name` (string): Display name shown in launcher
- `icon` (string, optional): Icon specification (see Icon Types below)
- `comment` (string): Description/subtitle text
- `action` (string): Action identifier in `type:data` format
- `categories` (array): Array containing your plugin name

### Icon Types

The `icon` field supports four formats:

**1. Material Design Icons** - Use the `material:` prefix:
```javascript
{
    name: "My Item",
    icon: "material:lightbulb",  // Material Symbols Rounded font
    comment: "Uses Material Design icon",
    action: "toast:Hello!",
    categories: ["MyPlugin"]
}
```
Available icons: Any icon from Material Symbols font (e.g., `lightbulb`, `star`, `favorite`, `settings`, `terminal`, `translate`, `sentiment_satisfied`)

**2. Unicode/Emoji Icons** - Use the `unicode:` prefix:
```javascript
{
    name: "Grinning Face",
    icon: "unicode:😀",  // Unicode character or emoji
    comment: "Copy emoji to clipboard",
    action: "copy:😀",
    categories: ["MyPlugin"]
}
```
Display any Unicode character or emoji as the icon. The character is rendered at 70-80% of the icon size with proper theming. Perfect for emoji pickers, symbol selectors, or character libraries.

**3. Desktop Theme Icons** - Use icon name directly:
```javascript
{
    name: "Firefox",
    icon: "firefox",  // Uses system icon theme
    comment: "Launches Firefox browser",
    action: "exec:firefox",
    categories: ["MyPlugin"]
}
```
Uses the user's installed icon theme. Common examples: `firefox`, `chrome`, `folder`, `text-editor`

**4. No Icon** - Omit the `icon` field entirely:
```javascript
{
    name: "😀  Grinning Face",
    // No icon field - emoji/unicode in name displays without icon area
    comment: "Copy emoji to clipboard",
    action: "copy:😀",
    categories: ["MyPlugin"]
}
```
When `icon` is omitted, the launcher hides the icon area and displays only the text, giving full width to the item name. Useful when you want emojis or symbols to be part of the item name itself.

### Trigger System

Triggers control when your plugin's items appear in the launcher:

**Empty Trigger Mode** (No trigger):
- Items always visible alongside regular apps
- Search includes your items automatically
- Configure by saving empty trigger: `trigger: ""`

**Custom Trigger Mode**:
- Items only appear when trigger is typed
- Example: Type `#` to show only your plugin's items
- Type `# query` to search within your plugin
- Configure any string: `#`, `!`, `@`, `!custom`, etc.

### Trigger Configuration in Settings

Provide a settings component with trigger configuration:

```qml
import QtQuick
import QtQuick.Controls
import qs.Widgets

FocusScope {
    id: root

    property var pluginService: null

    Column {
        spacing: 12

        CheckBox {
            id: noTriggerToggle
            text: "No trigger (always show)"
            checked: loadSettings("noTrigger", false)

            onCheckedChanged: {
                saveSettings("noTrigger", checked)
                if (checked) {
                    saveSettings("trigger", "")
                } else {
                    saveSettings("trigger", triggerField.text || "#")
                }
            }
        }

        DankTextField {
            id: triggerField
            visible: !noTriggerToggle.checked
            text: loadSettings("trigger", "#")
            placeholderText: "#"

            onTextEdited: {
                saveSettings("trigger", text || "#")
            }
        }
    }

    function saveSettings(key, value) {
        if (pluginService) {
            pluginService.savePluginData("myLauncher", key, value)
        }
    }

    function loadSettings(key, defaultValue) {
        if (pluginService) {
            return pluginService.loadPluginData("myLauncher", key, defaultValue)
        }
        return defaultValue
    }
}
```

### Action Execution

Handle different action types in `executeItem()`:

```qml
function executeItem(item) {
    const actionParts = item.action.split(":")
    const actionType = actionParts[0]
    const actionData = actionParts.slice(1).join(":")

    switch (actionType) {
        case "toast":
            if (typeof ToastService !== "undefined") {
                ToastService.showInfo("Plugin", actionData)
            }
            break
        case "copy":
            // Copy to clipboard
            break
        case "script":
            // Execute command
            break
        default:
            console.warn("Unknown action:", actionType)
    }
}
```

### Search and Filtering

The launcher automatically handles search when:

**With empty trigger**:
- Your items appear in all searches
- No prefix needed

**With custom trigger**:
- Type trigger alone: Shows all your items
- Type trigger + query: Filters your items by query
- The query parameter is passed to your `getItems(query)` function

Example `getItems()` implementation:

```qml
function getItems(query) {
    const allItems = [
        {name: "Item 1", ...},
        {name: "Item 2", ...},
        {name: "Test Item", ...}
    ]

    if (!query || query.length === 0) {
        return allItems
    }

    const lowerQuery = query.toLowerCase()
    return allItems.filter(item => {
        return item.name.toLowerCase().includes(lowerQuery) ||
               item.comment.toLowerCase().includes(lowerQuery)
    })
}
```

### Integration Flow

1. User opens launcher
2. If empty trigger: Your items appear alongside apps
3. If custom trigger: User types trigger (e.g., `#`)
4. Launcher calls `getItems(query)` on your plugin
5. Your items displayed with your plugin's category
6. User selects item and presses Enter
7. Launcher calls `executeItem(item)` on your plugin

### Best Practices

1. **Unique Triggers**: Choose non-conflicting trigger strings
2. **Fast Response**: Return results quickly from `getItems()`
3. **Clear Names**: Use descriptive item names and comments
4. **Error Handling**: Gracefully handle failures in `executeItem()`
5. **Cleanup**: Destroy temporary objects after use
6. **Empty Trigger Support**: Consider if your plugin benefits from always being visible

### Example Plugin

See `PLUGINS/LauncherExample/` for a complete working example demonstrating:
- Trigger configuration (including empty trigger mode)
- Multiple action types (toast, copy, script)
- Search/filtering implementation
- Settings integration
- Proper error handling

## Resources

- **Plugin Schema**: `plugin-schema.json` - JSON Schema for validation
- **Example Plugins**:
  - [Emoji Picker](./ExampleEmojiPlugin/)
  - [WorldClock](https://github.com/rochacbruno/WorldClock)
  - [LauncherExample](./LauncherExample/)
  - [Calculator](https://github.com/rochacbruno/DankCalculator)
- **PluginService**: `Services/PluginService.qml`
- **Settings UI**: `Modules/Settings/PluginsTab.qml`
- **DankBar Integration**: `Modules/DankBar/DankBar.qml`
- **Launcher Integration**: `Modules/AppDrawer/AppLauncher.qml`
- **Theme Reference**: `Common/Theme.qml`
- **Widget Library**: `Widgets/`

## Contributing

Share your plugins with the community:

1. Create a public repository with your plugin
2. Validate your `plugin.json` against `plugin-schema.json`
3. Include comprehensive README.md
4. Add example screenshots
5. Document dependencies and permissions

For plugin system improvements, submit issues or PRs to the main DMS repository.
