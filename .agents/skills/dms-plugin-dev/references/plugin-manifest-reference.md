# Plugin Manifest Reference (plugin.json)

## Required Fields

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| `id` | string | Unique plugin identifier | camelCase, pattern `^[a-zA-Z][a-zA-Z0-9]*$` |
| `name` | string | Human-readable name | Non-empty |
| `description` | string | Short description (shown in UI) | Non-empty |
| `version` | string | Semantic version | Pattern `^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$` |
| `author` | string | Creator name or email | Non-empty |
| `type` | string | Plugin type | One of: `widget`, `daemon`, `launcher`, `desktop` |
| `capabilities` | array | Plugin capabilities | At least 1 string item |
| `component` | string | Path to main QML file | Must start with `./`, end with `.qml` |

## Conditional Requirements

| Condition | Required Field | Description |
|-----------|---------------|-------------|
| `type: "launcher"` | `trigger` | Trigger string for launcher activation (e.g., `=`, `#`, `!`) |

## Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `icon` | string | Material Design icon name (displayed in plugin list UI) |
| `settings` | string | Path to settings QML file (must start with `./`, end with `.qml`) |
| `requires_dms` | string | Minimum DMS version (e.g., `>=0.1.18`), pattern `^(>=?\|<=?\|=\|>\|<)\d+\.\d+\.\d+$` |
| `requires` | array | System tool dependencies (e.g., `["curl", "jq"]`) |
| `permissions` | array | Required permissions |
| `trigger` | string | Launcher trigger string (required for launcher type) |

## Permissions

| Permission | Description | Enforced |
|------------|-------------|----------|
| `settings_read` | Read plugin configuration | No (not currently enforced) |
| `settings_write` | Write plugin configuration / use PluginSettings | **Yes** |
| `process` | Execute system commands | No (not currently enforced) |
| `network` | Network access | No (not currently enforced) |

If your plugin has a `settings` component but does not declare `settings_write`, users will see an error instead of the settings UI.

## Capabilities

Capabilities are free-form strings that describe what the plugin does. Common values:

- `dankbar-widget` - general bar widget
- `control-center` - integrates with Control Center
- `monitoring` - system/service monitoring
- `launcher` - launcher search provider
- `desktop-widget` - desktop background widget
- `ai` - AI/LLM integration
- `slideout` - uses slideout panel

## Complete Example

```json
{
    "id": "myPlugin",
    "name": "My Plugin",
    "description": "A sample plugin demonstrating all fields",
    "version": "1.0.0",
    "author": "Developer Name",
    "type": "widget",
    "capabilities": ["dankbar-widget", "control-center"],
    "component": "./MyWidget.qml",
    "icon": "extension",
    "settings": "./Settings.qml",
    "requires_dms": ">=0.1.18",
    "requires": ["curl", "jq"],
    "permissions": ["settings_read", "settings_write", "process", "network"]
}
```

## Launcher Example

```json
{
    "id": "myLauncher",
    "name": "My Launcher",
    "description": "Search and execute custom actions",
    "version": "1.0.0",
    "author": "Developer Name",
    "type": "launcher",
    "capabilities": ["launcher"],
    "component": "./MyLauncher.qml",
    "trigger": "#",
    "icon": "search",
    "settings": "./Settings.qml",
    "requires_dms": ">=0.1.18",
    "permissions": ["settings_read", "settings_write"]
}
```

## JSON Schema

The complete JSON schema is available at `assets/plugin-schema.json` in this skill. Validate with:

```bash
# Using python
python3 -c "
import json, jsonschema
schema = json.load(open('path/to/plugin-schema.json'))
manifest = json.load(open('plugin.json'))
jsonschema.validate(manifest, schema)
print('Valid!')
"

# Using jq (syntax check only)
jq . plugin.json
```

## Additional Properties

The schema allows additional properties (`"additionalProperties": true`), so plugins can include custom fields. Common custom fields seen in production plugins:

- `viewMode` - launcher display mode (`"tile"` for image grids)
- `viewModeEnforced` - lock launcher to specific view mode (`true`/`false`)
