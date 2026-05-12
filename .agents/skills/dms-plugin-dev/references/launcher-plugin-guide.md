# Launcher Plugin Guide

Launcher plugins extend the DMS launcher with custom searchable items and actions. They use trigger-based filtering and integrate directly into the app drawer.

## Base Component

Launchers use a plain `Item` (not PluginComponent):

```qml
import QtQuick
import qs.Services

Item {
    id: root

    property var pluginService: null
    property string trigger: "#"

    signal itemsChanged()

    function getItems(query) {
        // Return array of items
        return []
    }

    function executeItem(item) {
        // Handle item selection
    }
}
```

## Required Interface

| Member | Type | Description |
|--------|------|-------------|
| `pluginService` | property | Injected PluginService reference (declare as `null`) |
| `trigger` | property | Trigger string for activation |
| `itemsChanged` | signal | Emit when item list changes (triggers UI refresh) |
| `getItems(query)` | function | Return array of items matching query |
| `executeItem(item)` | function | Handle item selection |

## Item Structure

Each item returned by `getItems()`:

```javascript
{
    name: "Item Display Name",       // Required: shown in launcher
    icon: "material:star",           // Optional: icon specification
    comment: "Description text",     // Required: subtitle text
    action: "type:data",             // Required: action identifier
    categories: ["MyPlugin"],        // Required: array with plugin category
    imageUrl: "https://..."          // Optional: image for tile view
}
```

## Icon Types

### 1. Material Design Icons

```javascript
{ icon: "material:lightbulb" }
{ icon: "material:terminal" }
{ icon: "material:translate" }
```

Uses the Material Symbols Rounded font.

### 2. Unicode / Emoji Icons

```javascript
{ icon: "unicode:smile_face" }
```

Rendered at 70-80% of icon size with theming.

### 3. Desktop Theme Icons

```javascript
{ icon: "firefox" }
{ icon: "folder" }
```

Uses the user's installed icon theme.

### 4. No Icon

Omit the `icon` field entirely. The launcher hides the icon area and gives full width to the item name.

## Trigger System

**Custom trigger** (items only appear when trigger is typed):

```json
{ "trigger": "#" }
```

- Type `#` alone: shows all plugin items
- Type `# query`: filters plugin items by query
- The query string (without trigger) is passed to `getItems(query)`

**No trigger** (items always visible alongside regular apps):

```json
{ "trigger": "" }
```

Save empty trigger at runtime:
```qml
Component.onCompleted: {
    trigger = pluginService?.loadPluginData(pluginId, "trigger", "#") ?? "#"
}
```

## Action Execution

Parse action strings in `executeItem()`:

```qml
function executeItem(item) {
    const actionParts = item.action.split(":")
    const actionType = actionParts[0]
    const actionData = actionParts.slice(1).join(":")

    switch (actionType) {
        case "toast":
            ToastService?.showInfo(actionData)
            break
        case "copy":
            Quickshell.execDetached(["dms", "cl", "copy", actionData])
            ToastService?.showInfo("Copied to clipboard")
            break
        case "exec":
            Quickshell.execDetached(actionData.split(" "))
            break
        case "url":
            Quickshell.execDetached(["xdg-open", actionData])
            break
        default:
            console.warn("Unknown action type:", actionType)
    }
}
```

## Search / Filtering

The `query` parameter in `getItems()` contains the user's search text (without the trigger prefix).

```qml
function getItems(query) {
    const allItems = [
        { name: "Calculator", icon: "material:calculate",
          comment: "Open calculator", action: "exec:gnome-calculator",
          categories: ["Tools"] },
        { name: "Terminal", icon: "material:terminal",
          comment: "Open terminal", action: "exec:alacritty",
          categories: ["Tools"] }
    ]

    if (!query || query.length === 0) return allItems

    const q = query.toLowerCase()
    return allItems.filter(item =>
        item.name.toLowerCase().includes(q) ||
        item.comment.toLowerCase().includes(q)
    )
}
```

## Context Menu Actions

Add right-click actions to launcher items:

```qml
function getContextMenuActions(item) {
    return [
        { name: "Copy", icon: "material:content_copy",
          action: "copy:" + item.name },
        { name: "Open in Browser", icon: "material:open_in_new",
          action: "url:" + item.url }
    ]
}
```

Context menu actions use the same `executeItem()` handler.

## Image Tile View

For image-heavy launchers (GIF search, sticker pickers), use tile view:

In `plugin.json`:
```json
{
    "viewMode": "tile",
    "viewModeEnforced": true
}
```

In items:
```javascript
{
    name: "Image Title",
    imageUrl: "https://example.com/image.png",
    comment: "Description",
    action: "copy:https://example.com/image.png",
    categories: ["MyPlugin"]
}
```

## State Persistence

For plugins with persistent state (notes, history, favorites):

```qml
property var notes: []

Component.onCompleted: {
    const saved = pluginService?.loadPluginState(pluginId, "notes", [])
    if (saved) notes = saved
}

function addNote(text) {
    notes.push({ text: text, timestamp: Date.now() })
    pluginService?.savePluginState(pluginId, "notes", notes)
    itemsChanged()
}
```

Use `savePluginState/loadPluginState` for runtime data and `savePluginData/loadPluginData` for user preferences.

## Settings for Trigger Configuration

Provide a PluginSettings component for trigger customization:

```qml
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "myLauncher"

    StringSetting {
        settingKey: "trigger"
        label: "Trigger"
        description: "Type this prefix to activate the launcher plugin"
        placeholder: "#"
        defaultValue: "#"
    }

    ToggleSetting {
        settingKey: "noTrigger"
        label: "Always Visible"
        description: "Show items alongside regular apps (no trigger needed)"
        defaultValue: false
    }
}
```

## Complete Example

```qml
import QtQuick
import Quickshell
import qs.Services

Item {
    id: root

    property var pluginService: null
    property string trigger: "!"

    signal itemsChanged()

    property var commands: [
        { name: "Lock Screen", icon: "material:lock",
          comment: "Lock the session", action: "exec:loginctl lock-session" },
        { name: "Screenshot", icon: "material:screenshot_monitor",
          comment: "Take a screenshot", action: "exec:grim" },
        { name: "File Manager", icon: "material:folder",
          comment: "Open file manager", action: "exec:nautilus" }
    ]

    function getItems(query) {
        if (!query) return commands
        const q = query.toLowerCase()
        return commands.filter(c =>
            c.name.toLowerCase().includes(q) ||
            c.comment.toLowerCase().includes(q)
        )
    }

    function executeItem(item) {
        const [type, ...rest] = item.action.split(":")
        const data = rest.join(":")
        if (type === "exec") {
            Quickshell.execDetached(data.split(" "))
        }
    }

    Component.onCompleted: {
        if (pluginService) {
            trigger = pluginService.loadPluginData("quickCommands", "trigger", "!")
        }
    }
}
```
