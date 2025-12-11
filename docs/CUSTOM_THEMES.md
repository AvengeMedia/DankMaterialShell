# Custom Themes

This guide covers creating custom themes for DankMaterialShell. You can define your own color schemes by creating theme files that the shell can load.

## Theme Structure

Themes are defined using the same structure as the built-in themes. Each theme must specify a complete set of Material Design 3 colors that work together harmoniously.

### Required Core Colors

These are the essential colors that define your theme's appearance:

```json
{
  "dark": {
    "name": "Cyberpunk Electric Dark",
    "primary": "#00FFCC",
    "primaryText": "#000000",
    "primaryContainer": "#00CC99",
    "secondary": "#FF4DFF",
    "surface": "#0F0F0F",
    "surfaceText": "#E0FFE0",
    "surfaceVariant": "#1F2F1F",
    "surfaceVariantText": "#CCFFCC",
    "surfaceTint": "#00FFCC",
    "background": "#000000",
    "backgroundText": "#F0FFF0",
    "outline": "#80FF80",
    "surfaceContainer": "#1A2B1A",
    "surfaceContainerHigh": "#264026",
    "surfaceContainerHighest": "#33553F",
    "error": "#FF0066",
    "warning": "#CCFF00",
    "info": "#00FFCC",
    "matugen_type": "scheme-expressive"
  },
  "light": {
    "name": "Cyberpunk Electric Light",
    "primary": "#00B899",
    "primaryText": "#FFFFFF",
    "primaryContainer": "#66FFDD",
    "secondary": "#CC00CC",
    "surface": "#F0FFF0",
    "surfaceText": "#1F2F1F",
    "surfaceVariant": "#E6FFE6",
    "surfaceVariantText": "#2D4D2D",
    "surfaceTint": "#00B899",
    "background": "#FFFFFF",
    "backgroundText": "#000000",
    "outline": "#4DCC4D",
    "surfaceContainer": "#F5FFF5",
    "surfaceContainerHigh": "#EBFFEB",
    "surfaceContainerHighest": "#E1FFE1",
    "error": "#B3004D",
    "warning": "#99CC00",
    "info": "#00B899",
    "matugen_type": "scheme-expressive"
  }
}
```

You can define colors at the top level if you do not want "dark" and "light" variants.

For example:

```json
{
  "name": "Theme name",
  "primary": "#eeeeee",
  ....
}
```

## Example Themes

There are example themes you can start from:

- [Cyberpunk Electric](theme_cyberpunk_electric.json) - Neon green and magenta cyberpunk aesthetic
- [Hotline Miami](theme_hotline_miami.json) - Retro 80s inspired hot pink and blue
- [Miami Vice](theme_miami_vice.json) - Classic teal and pink vice aesthetic
- [Synthwave Electric](theme_synthwave_electric.json) - Electric purple and cyan synthwave vibes

### Color Definitions

**Primary Colors**
- `primary` - Main accent color used for buttons, highlights, and active states
- `primaryText` - Text color that contrasts well with primary background
- `primaryContainer` - Darker/lighter variant of primary for containers

**Secondary Colors**
- `secondary` - Supporting accent color for variety and hierarchy
- `surfaceTint` - Tint color applied to surfaces, usually derived from primary

**Surface Colors**
- `surface` - Default surface color for cards, panels, etc.
- `surfaceText` - Primary text color on surface backgrounds
- `surfaceVariant` - Alternate surface color for subtle differentiation
- `surfaceVariantText` - Text color for surfaceVariant backgrounds
- `surfaceContainer` - Container surface color, slightly different from surface
- `surfaceContainerHigh` - Elevated container color for layered interfaces
- `surfaceContainerHighest` - Highest elevation container color for top-level surfaces

**Background Colors**
- `background` - Main background color for the entire interface
- `backgroundText` - Text color for background areas

**Outline Colors**
- `outline` - Border and divider color for subtle boundaries

## Optional Properties

While the core colors above are required, you can also customize these optional properties:

### Semantic Colors
```json
{
  "error": "#f44336",
  "warning": "#ff9800",
  "info": "#2196f3"
}
```

- `error` - Used for error states, delete buttons, and critical warnings
- `warning` - Used for warning states and caution indicators
- `info` - Used for informational states and neutral indicators

### Matugen Color Scheme Type
```json
{
  "matugen_type": "scheme-monochrome"
}
```

- `matugen_type` - Controls the color scheme algorithm used by matugen for system app theming
- **Default**: `scheme-tonal-spot` (if not specified)
- **Available options**:
  - `scheme-content` - Content-based color extraction
  - `scheme-expressive` - Expressive, vibrant color schemes
  - `scheme-fidelity` - High fidelity to source material
  - `scheme-fruit-salad` - Colorful, fruit salad-like schemes
  - `scheme-monochrome` - Monochromatic color schemes
  - `scheme-neutral` - Neutral, subdued color schemes
  - `scheme-rainbow` - Rainbow-like color schemes
  - `scheme-tonal-spot` - Tonal spot color schemes (default)

## Setting Custom Theme

In settings -> Theme & Colors you can choose "Custom" to choose a path to your theme.

You can also edit `~/.config/DankMaterialShell/settings.json` manually

```json
{
  "currentThemeName": "custom",
  "customThemeFile": "/path/to/mytheme.json"
}
```

### Reactivity

Editing the custom theme file will auto-update the shell if it's the current theme.
