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

`Theme.radiusStrength` ranges from 0 to 100, with the Material baseline at 50. `Theme.cornerRadius` aliases `Theme.cornerRadiusM`. Small and large aliases use S and L.

```qml
Theme.cornerRadiusXS
Theme.cornerRadiusS
Theme.cornerRadiusM
Theme.cornerRadiusL
Theme.cornerRadiusLIncreased
Theme.cornerRadiusXL
Theme.cornerRadiusXLIncreased
Theme.cornerRadiusXXL
Theme.fullRadius(width, height)
Theme.buttonRadius(width, height, buttonHeight, pressed, true)
```

Use `fullRadius()` for pills and round controls so lower strength values reduce their rounding. `cornerRadiusFull` remains available for compatibility. See the shared [shape reference](../../dank-qml-common/SHAPES.md) for component baselines.

## Colors

### Surface Colors
```qml
Theme.surface
Theme.surfaceContainerLowest
Theme.surfaceContainerLow
Theme.surfaceContainer
Theme.surfaceContainerHigh
Theme.surfaceContainerHighest
```

Use `Theme.foregroundColor(Theme.surfaceContainerHigh, Theme.isFloatingWindow(root))` for a nested fill that follows the foreground toggle and opacity. Outer floating windows use `Theme.floatingWindowSurface`. Pass raw surface colors to shared text fields; those widgets apply foreground opacity themselves.

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
Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
Theme.foregroundColor(Theme.surfaceContainerHigh, Theme.isFloatingWindow(root))
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
