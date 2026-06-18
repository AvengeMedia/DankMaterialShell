# Settings Components Reference

All plugin settings use the `PluginSettings` wrapper. Setting components auto-save on change and auto-load on creation.

## PluginSettings Wrapper

```qml
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "yourPlugin"  // Required: must match plugin.json id

    // Setting components go here
}
```

**Important:** The plugin must declare `"permissions": ["settings_write"]` in plugin.json for the settings UI to render. Without it, users see an error.

**PluginSettings provides to children:**
- `saveValue(key, value)` - save a setting value
- `loadValue(key, defaultValue)` - load a setting value
- `saveState(key, value)` - save plugin state (separate file)
- `loadState(key, defaultValue)` - load plugin state
- `clearState()` - clear all plugin state
- Variant management functions (for variant plugins)

## StringSetting

Text input field.

```qml
StringSetting {
    settingKey: "apiKey"        // Required: storage key
    label: "API Key"            // Required: display label
    description: "Your API key" // Optional: help text
    placeholder: "sk-..."      // Optional: input placeholder
    defaultValue: ""            // Optional: default (default: "")
}
```

**Layout:** Vertical stack - label, description, input field.

## ToggleSetting

Boolean toggle switch.

```qml
ToggleSetting {
    settingKey: "notifications"    // Required: storage key
    label: "Enable Notifications"  // Required: display label
    description: "Show alerts"     // Optional: help text
    defaultValue: true             // Optional: default (default: false)
}
```

**Layout:** Horizontal - label/description on left, toggle on right.

## SelectionSetting

Dropdown menu.

```qml
SelectionSetting {
    settingKey: "theme"           // Required: storage key
    label: "Theme"                // Required: display label
    description: "Color scheme"   // Optional: help text
    options: [                    // Required: array of options
        { label: "Dark", value: "dark" },
        { label: "Light", value: "light" },
        { label: "Auto", value: "auto" }
    ]
    defaultValue: "dark"          // Optional: default value
}
```

Options can be `{ label, value }` objects or simple strings. Stores the `value` field, displays the `label` field.

**Layout:** Horizontal - label/description on left, dropdown on right.

**Reacting to changes:**
```qml
SelectionSetting {
    settingKey: "updateInterval"
    label: "Update Interval"
    options: [
        { label: "1 minute", value: "60" },
        { label: "5 minutes", value: "300" }
    ]
    defaultValue: "300"
    onValueChanged: (newValue) => {
        console.log("Interval changed to:", newValue)
    }
}
```

## SliderSetting

Numeric slider with min/max.

```qml
SliderSetting {
    settingKey: "opacity"      // Required: storage key
    label: "Opacity"           // Required: display label
    description: "Background"  // Optional: help text
    defaultValue: 85           // Optional: default value
    minimum: 0                 // Required: min value
    maximum: 100               // Required: max value
    unit: "%"                  // Optional: unit label shown after value
    leftIcon: "dark_mode"      // Optional: Material icon on left
    rightIcon: "light_mode"    // Optional: Material icon on right
}
```

## ColorSetting

Color picker.

```qml
ColorSetting {
    settingKey: "accentColor"      // Required: storage key
    label: "Accent Color"          // Required: display label
    description: "Custom accent"   // Optional: help text
    defaultValue: "#ff5722"        // Optional: default hex color
}
```

Displays a color swatch that opens a color picker dialog.

## ListSetting

Manage a list of items with manual add/remove. Use when you need custom UI for adding items.

```qml
ListSetting {
    id: itemList
    settingKey: "items"           // Required: storage key
    label: "Saved Items"          // Required: display label
    description: "Your items"     // Optional: help text
    defaultValue: []              // Optional: default array
    delegate: Component {         // Optional: custom item display
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
```

**Methods:**
- `addItem(item)` - add an item to the list
- `removeItem(index)` - remove item at index

## ListSettingWithInput

Complete list management with built-in form. Best for collecting structured data.

```qml
ListSettingWithInput {
    settingKey: "locations"        // Required: storage key
    label: "Locations"             // Required: display label
    description: "Track zones"     // Optional: help text
    defaultValue: []               // Optional: default array
    fields: [                      // Required: field definitions
        {
            id: "name",            // Required: key in saved object
            label: "Name",         // Required: column header
            placeholder: "Home",   // Optional: input placeholder
            width: 150,            // Optional: column width (default: 200)
            required: true         // Optional: must have value to add
        },
        {
            id: "timezone",
            label: "Timezone",
            placeholder: "America/New_York",
            width: 200,
            required: true
        }
    ]
}
```

Automatically generates: column headers, input fields, add button with validation, list display, remove buttons.

## Mixing Custom UI with Settings

You can interleave regular QML elements with setting components:

```qml
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
        settingKey: "name"
        label: "Display Name"
    }

    StyledText {
        width: parent.width
        text: "Advanced Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingL
    }

    ToggleSetting {
        settingKey: "debug"
        label: "Debug Mode"
        defaultValue: false
    }
}
```

## Default Values

Define sensible defaults in every setting component. The default is used when no saved value exists:

```qml
StringSetting { settingKey: "text"; defaultValue: "Hello" }
ToggleSetting { settingKey: "enabled"; defaultValue: true }
SelectionSetting { settingKey: "mode"; defaultValue: "auto" }
SliderSetting { settingKey: "opacity"; defaultValue: 85 }
ColorSetting { settingKey: "color"; defaultValue: "#ff5722" }
ListSetting { settingKey: "items"; defaultValue: [] }
ListSettingWithInput { settingKey: "data"; defaultValue: [] }
```
