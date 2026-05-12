---
name: dms-plugin-dev
description: >
  Develop plugins for DankMaterialShell (DMS), a QML-based Linux desktop shell built on
  Quickshell. Supports four plugin types: widget (bar + Control Center), daemon (background
  service), launcher (search + actions), and desktop (draggable desktop widgets). Covers
  manifest creation, QML component development, settings UI, data persistence, theme
  integration, PopoutService usage, and external command execution. Use when the user wants
  to create, modify, or debug a DMS plugin, or asks about the DMS plugin API.
compatibility: Designed for Claude Code (or similar products)
metadata:
  author: DankMaterialShell
  version: "1.0"
  domain: qml-desktop-development
  framework: DankMaterialShell
  languages: qml, javascript
allowed-tools: Bash Read Write Edit
---

# DankMaterialShell Plugin Development

## Overview

DMS plugins extend the desktop shell with custom widgets, background services, launcher
integrations, and desktop widgets. Plugins are QML components discovered from
`~/.config/DankMaterialShell/plugins/`.

**Minimum plugin structure:**

```
~/.config/DankMaterialShell/plugins/YourPlugin/
  plugin.json        # Required: manifest with metadata
  YourComponent.qml  # Required: main QML component
  YourSettings.qml   # Optional: settings UI
  *.js               # Optional: JavaScript utilities
```

**Plugin registry:** Community plugins are available at https://plugins.danklinux.com/

**Four plugin types:**

| Type       | Purpose                        | Base Component             | Bar pills | CC integration |
|------------|--------------------------------|----------------------------|-----------|----------------|
| `widget`   | Bar widget + popout            | `PluginComponent`          | Yes       | Yes            |
| `daemon`   | Background service             | `PluginComponent` (no UI)  | No        | Optional       |
| `launcher` | Searchable items in launcher   | `Item`                     | No        | No             |
| `desktop`  | Draggable desktop widget       | `DesktopPluginComponent`   | No        | No             |

## Step 1: Determine Plugin Type

Choose the type based on what the plugin does:

- **Shows in the bar?** - Use `widget`. Displays a pill in DankBar, optionally opens a popout,
  optionally integrates with Control Center.
- **Runs in background only?** - Use `daemon`. No visible UI, reacts to events (wallpaper
  changes, notifications, battery level, etc.).
- **Provides searchable/actionable items?** - Use `launcher`. Items appear in the DMS launcher
  with trigger-based filtering (e.g., type `=` for calculator, `:` for emoji).
- **Shows on the desktop background?** - Use `desktop`. Draggable, resizable widget on the
  desktop layer.

## Step 2: Create the Manifest

Create `plugin.json` in your plugin directory. See [plugin-manifest-reference.md](references/plugin-manifest-reference.md) for the full schema.

**Minimal manifest:**

```json
{
    "id": "yourPlugin",
    "name": "Your Plugin Name",
    "description": "Brief description of what your plugin does",
    "version": "1.0.0",
    "author": "Your Name",
    "type": "widget",
    "capabilities": ["your-capability"],
    "component": "./YourWidget.qml"
}
```

**With settings and permissions:**

```json
{
    "id": "yourPlugin",
    "name": "Your Plugin Name",
    "description": "Brief description",
    "version": "1.0.0",
    "author": "Your Name",
    "type": "widget",
    "capabilities": ["your-capability"],
    "component": "./YourWidget.qml",
    "icon": "extension",
    "settings": "./Settings.qml",
    "requires_dms": ">=0.1.0",
    "permissions": ["settings_read", "settings_write"]
}
```

**Key rules:**
- `id` must be camelCase, matching pattern `^[a-zA-Z][a-zA-Z0-9]*$`
- `version` must be semver (e.g., `1.0.0`)
- `component` must start with `./` and end with `.qml`
- `type: "launcher"` requires a `trigger` field
- `settings_write` permission is **required** if the plugin has a settings component

## Step 3: Create the Main Component

### Widget

```qml
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    property var popoutService: null

    horizontalBarPill: Component {
        StyledRect {
            width: label.implicitWidth + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            StyledText {
                id: label
                anchors.centerIn: parent
                text: "Hello"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }

    verticalBarPill: Component {
        StyledRect {
            width: parent.widgetThickness
            height: label.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            StyledText {
                id: label
                anchors.centerIn: parent
                text: "Hi"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                rotation: 90
            }
        }
    }
}
```

See [widget-plugin-guide.md](references/widget-plugin-guide.md) for popouts, CC integration, and advanced features.

### Launcher

```qml
import QtQuick
import qs.Services

Item {
    id: root

    property var pluginService: null
    property string trigger: "#"

    signal itemsChanged()

    function getItems(query) {
        const items = [
            { name: "Item One", icon: "material:star", comment: "Description",
              action: "toast:Hello!", categories: ["MyPlugin"] }
        ]
        if (!query) return items
        const q = query.toLowerCase()
        return items.filter(i => i.name.toLowerCase().includes(q))
    }

    function executeItem(item) {
        const [type, ...rest] = item.action.split(":")
        const data = rest.join(":")
        if (type === "toast") ToastService?.showInfo(data)
        else if (type === "copy") Quickshell.execDetached(["dms", "cl", "copy", data])
    }
}
```

See [launcher-plugin-guide.md](references/launcher-plugin-guide.md) for triggers, icon types, context menus, and image tiles.

### Desktop

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
        border.color: root.editMode ? Theme.primary : "transparent"
        border.width: root.editMode ? 2 : 0

        Text {
            anchors.centerIn: parent
            text: "Desktop Widget"
            color: Theme.surfaceText
        }
    }
}
```

See [desktop-plugin-guide.md](references/desktop-plugin-guide.md) for sizing, persistence, and edit mode.

### Daemon

```qml
import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    property var popoutService: null

    Connections {
        target: SessionData
        function onSomeSignal() {
            console.log("Event received")
        }
    }
}
```

See [daemon-plugin-guide.md](references/daemon-plugin-guide.md) for event-driven patterns and process execution.

## Step 4: Add Settings (Optional)

Wrap settings in `PluginSettings` with your `pluginId`. All settings auto-save and auto-load.

```qml
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "yourPlugin"

    StringSetting {
        settingKey: "apiKey"
        label: "API Key"
        description: "Your API key"
        placeholder: "sk-..."
    }

    ToggleSetting {
        settingKey: "enabled"
        label: "Enable Feature"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "interval"
        label: "Refresh Interval"
        options: [
            { label: "1 min", value: "60" },
            { label: "5 min", value: "300" }
        ]
        defaultValue: "300"
    }
}
```

**Available setting components:** StringSetting, ToggleSetting, SelectionSetting, SliderSetting, ColorSetting, ListSetting, ListSettingWithInput.

See [settings-components-reference.md](references/settings-components-reference.md) for full property lists.

**Important:** Your plugin must declare `"permissions": ["settings_write"]` in plugin.json, or the settings UI will show an error.

## Step 5: Use Data Persistence

Three tiers of persistence:

| API | Persisted | Use case |
|-----|-----------|----------|
| `pluginService.savePluginData(id, key, val)` / `loadPluginData(id, key, default)` | Yes (settings.json) | User preferences, config |
| `pluginService.savePluginState(id, key, val)` / `loadPluginState(id, key, default)` | Yes (separate state file) | Runtime state, history, cache |
| `PluginGlobalVar { varName; defaultValue; value; set() }` | No (runtime only) | Cross-instance shared state |

- `pluginData` is a reactive property on PluginComponent, auto-loaded from settings
- React to settings changes with `Connections { target: pluginService; function onPluginDataChanged(id) { ... } }`
- Global vars sync across all instances (multi-monitor, multiple bar sections)

See [data-persistence-guide.md](references/data-persistence-guide.md) for details and examples.

## Step 6: Theme Integration

Always use `Theme.*` properties from `qs.Common` - never hardcode colors or sizes.

**Essential properties:**
- Colors: `Theme.surfaceContainerHigh`, `Theme.surfaceText`, `Theme.primary`, `Theme.onPrimary`
- Fonts: `Theme.fontSizeSmall` (12), `Theme.fontSizeMedium` (14), `Theme.fontSizeLarge` (16), `Theme.fontSizeXLarge` (20)
- Spacing: `Theme.spacingXS`, `Theme.spacingS`, `Theme.spacingM`, `Theme.spacingL`, `Theme.spacingXL`
- Radius: `Theme.cornerRadius`, `Theme.cornerRadiusSmall`, `Theme.cornerRadiusLarge`
- Icons: `Theme.iconSizeSmall` (16), `Theme.iconSize` (24), `Theme.iconSizeLarge` (32)

**Common widgets from `qs.Widgets`:** `StyledText`, `StyledRect`, `DankIcon`, `DankButton`, `DankToggle`, `DankTextField`, `DankSlider`, `DankGridView`, `CachingImage`.

See [theme-reference.md](references/theme-reference.md) for the complete property list.

## Step 7: Add Popout Content (Widgets Only)

Add a popout that opens when the bar pill is clicked:

```qml
PluginComponent {
    popoutWidth: 400
    popoutHeight: 300

    popoutContent: Component {
        PopoutComponent {
            headerText: "My Plugin"
            detailsText: "Optional subtitle"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    text: "Content here"
                    color: Theme.surfaceText
                }
            }
        }
    }

    horizontalBarPill: Component { /* ... */ }
    verticalBarPill: Component { /* ... */ }
}
```

**PopoutComponent properties:** `headerText`, `detailsText`, `showCloseButton`, `closePopout()` (auto-injected), `headerHeight` (readonly), `detailsHeight` (readonly).

Calculate available content height: `popoutHeight - headerHeight - detailsHeight - spacing`

## Step 8: Control Center Integration (Widgets Only)

Add your widget to the Control Center grid:

```qml
PluginComponent {
    ccWidgetIcon: "toggle_on"
    ccWidgetPrimaryText: "My Feature"
    ccWidgetSecondaryText: isActive ? "On" : "Off"
    ccWidgetIsActive: isActive

    onCcWidgetToggled: {
        isActive = !isActive
        pluginService?.savePluginData(pluginId, "active", isActive)
    }

    // Optional: expandable detail panel (for CompoundPill)
    ccDetailContent: Component {
        Rectangle {
            implicitHeight: 200
            color: Theme.surfaceContainerHigh
            radius: Theme.cornerRadius
        }
    }
}
```

**CC sizing:** 25% width = SmallToggleButton (icon only), 50% width = ToggleButton or CompoundPill (if ccDetailContent is defined).

## Step 9: External Commands and Clipboard

**Run commands and capture output:**

```qml
import qs.Common

Proc.runCommand(
    "myPlugin.fetch",
    ["curl", "-s", "https://api.example.com/data"],
    (stdout, exitCode) => {
        if (exitCode === 0) processData(stdout)
    },
    500  // debounce ms
)
```

**Fire-and-forget (clipboard, notifications):**

```qml
import Quickshell

Quickshell.execDetached(["dms", "cl", "copy", textToCopy])
```

**Long-running processes:** Use the `Process` QML component from `Quickshell.Io` with `StdioCollector`.

**Shell commands with pipes:** `["sh", "-c", "ps aux | grep foo"]`

**Do NOT use** `globalThis.clipboard` or browser JavaScript APIs - they don't exist in the QML runtime.

## Step 10: Validate and Test

1. Validate `plugin.json` against the schema at [assets/plugin-schema.json](assets/plugin-schema.json)
2. Run the shell with verbose output: `qs -v -p $CONFIGPATH/quickshell/dms/shell.qml`
3. Open Settings > Plugins > Scan for Plugins
4. Enable your plugin and add it to the DankBar layout

**Common issues:**
- Plugin not detected: check plugin.json syntax with `jq . plugin.json`
- Widget not showing: ensure it's enabled AND added to a DankBar section
- Settings error: verify `settings_write` permission is declared
- Data not persisting: check pluginService injection and permissions

## Common Mistakes

1. **Missing `settings_write` permission** - Settings UI shows error without it
2. **Missing `property var popoutService: null`** - Must declare for injection to work
3. **Missing vertical bar pill** - Widget disappears when bar is on left/right edge
4. **Hardcoded colors** - Use `Theme.*` properties, not hex values
5. **Using `globalThis.clipboard`** - Does not exist; use `Quickshell.execDetached(["dms", "cl", "copy", text])`
6. **Wrong Theme property names** - `Theme.fontSizeS` does not exist, use `Theme.fontSizeSmall`
7. **Wrong import for Quickshell** - Use `import Quickshell` (not `import QtQuick` for execDetached)
8. **Forgetting `categories` in launcher items** - Items won't display without it
9. **Not handling null pluginService** - Always use optional chaining or null checks
10. **Using `PluginComponent` for launchers** - Launchers use plain `Item`, not `PluginComponent`

## Quick Reference: Imports

**Widget / Daemon:**
```qml
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
```

**Launcher:**
```qml
import QtQuick
import qs.Services
```

**Desktop:**
```qml
import QtQuick
import qs.Common
```

**For clipboard/exec:** `import Quickshell`
**For processes:** `import Quickshell.Io`
**For networking:** `import Quickshell.Networking`
**For toast notifications:** access `ToastService` from `qs.Services`

## Quick Reference: File Naming

- **Directory name:** PascalCase (e.g., `MyAwesomePlugin/`)
- **Plugin ID:** camelCase (e.g., `myAwesomePlugin`)
- **QML files:** PascalCase (e.g., `MyWidget.qml`, `Settings.qml`)
- **Component paths in manifest:** relative with `./` prefix (e.g., `"./MyWidget.qml"`)
- **JS utility files:** camelCase (e.g., `utils.js`, `apiAdapter.js`)

## Reference Files

Load these on demand for detailed API documentation:

- [plugin-manifest-reference.md](references/plugin-manifest-reference.md) - Complete plugin.json field reference and JSON schema
- [widget-plugin-guide.md](references/widget-plugin-guide.md) - PluginComponent, bar pills, popouts, click actions, CC integration
- [launcher-plugin-guide.md](references/launcher-plugin-guide.md) - getItems/executeItem, triggers, icon types, context menus, tile view
- [desktop-plugin-guide.md](references/desktop-plugin-guide.md) - DesktopPluginComponent, sizing, edit mode, position persistence
- [daemon-plugin-guide.md](references/daemon-plugin-guide.md) - Event-driven background services, process execution
- [settings-components-reference.md](references/settings-components-reference.md) - All 7 setting components with complete property lists
- [theme-reference.md](references/theme-reference.md) - Theme colors, spacing, fonts, radii, common patterns
- [data-persistence-guide.md](references/data-persistence-guide.md) - pluginData, state API, global variables
- [popout-service-reference.md](references/popout-service-reference.md) - PopoutService API for controlling shell popouts and modals
- [advanced-patterns.md](references/advanced-patterns.md) - Variants, JS utilities, qmldir, IPC, multi-file plugins
