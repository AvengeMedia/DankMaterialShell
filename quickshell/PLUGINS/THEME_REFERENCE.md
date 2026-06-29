# Theme Property Reference for Plugins

Quick reference for commonly used Theme properties in plugin development.

## Font Sizes

```qml
Theme.fontSizeSmall     // 12px (scaled)
Theme.fontSizeMedium    // 14px (scaled)
Theme.fontSizeLarge     // 16px (scaled)
Theme.fontSizeXLarge    // 20px (scaled)
```

**Note**: These are scaled by `SettingsData.fontScale`

## Icon Sizes

```qml
Theme.iconSizeSmall     // 16px
Theme.iconSize          // 24px (default)
Theme.iconSizeLarge     // 32px
```

## Spacing

```qml
Theme.spacingXS         // Extra small
Theme.spacingS          // Small
Theme.spacingM          // Medium
Theme.spacingL          // Large
Theme.spacingXL         // Extra large
```

## Border Radius

```qml
Theme.cornerRadius      // Standard corner radius
Theme.cornerRadiusSmall // Smaller radius
Theme.cornerRadiusLarge // Larger radius
```

## Colors

### Surface Colors
```qml
Theme.surface
Theme.surfaceContainerLowest   // matugen-only (see note)
Theme.surfaceContainerLow      // matugen-only (see note)
Theme.surfaceContainer
Theme.surfaceContainerHigh
Theme.surfaceContainerHighest
```

> **Note:** Not every theme color is consumed by DMS's own UI. `surfaceContainerLowest`,
> `surfaceContainerLow`, and `backgroundText` are currently unused by DMS components — they
> exist to complete the Material palette and are exported to matugen templates (VS Code,
> KDE, Firefox, Zed, etc.). They're still safe to reference in plugins; they just aren't
> relied on internally.

### Text Colors
```qml
Theme.onSurface         // Primary text on surface
Theme.onSurfaceVariant  // Secondary text on surface
Theme.outline           // Border/divider color
```

### Semantic Colors
```qml
Theme.primary
Theme.onPrimary
Theme.secondary
Theme.onSecondary
Theme.error
Theme.warning
Theme.success
```

### Special Functions
```qml
Theme.popupBackground()  // Popup background with opacity
```

## Common Patterns

### Icon with Text
```qml
DankIcon {
    name: "icon_name"
    color: Theme.onSurface
    font.pixelSize: Theme.iconSize
}

StyledText {
    text: "Label"
    color: Theme.onSurface
    font.pixelSize: Theme.fontSizeMedium
}
```

### Container with Border
```qml
Rectangle {
    color: Theme.surfaceContainerHigh
    radius: Theme.cornerRadius
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1
}
```

### Hover Effect
```qml
MouseArea {
    hoverEnabled: true
    onEntered: parent.color = Qt.lighter(Theme.surfaceContainerHigh, 1.1)
    onExited: parent.color = Theme.surfaceContainerHigh
}
```

## Common Mistakes

❌ **Wrong**:
```qml
font.pixelSize: Theme.fontSizeS      // Property doesn't exist
font.pixelSize: Theme.iconSizeS       // Property doesn't exist
```

✅ **Correct**:
```qml
font.pixelSize: Theme.fontSizeSmall   // Use full name
font.pixelSize: Theme.iconSizeSmall   // Use full name
```

## Checking Available Properties

To see all available Theme properties, check `Common/Theme.qml` or use:

```bash
grep "property" Common/Theme.qml
```
