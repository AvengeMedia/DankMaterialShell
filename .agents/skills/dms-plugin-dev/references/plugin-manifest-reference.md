# Plugin Manifest Reference (plugin.json)

## Required Fields

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| `id` | string | Unique plugin identifier | camelCase, pattern `^[a-zA-Z][a-zA-Z0-9]*$` |
| `name` | string | Human-readable name | Non-empty |
| `description` | string | Short description (shown in UI) | Non-empty |
| `version` | string | Semantic version | Pattern `^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$` |
| `author` | string | Creator name or email | Non-empty |
| `type` | string | Plugin type | One of: `widget`, `daemon`, `launcher`, `desktop`, `composite` |
| `capabilities` | array | Plugin capabilities | At least 1 string item |

One of `component` or `components` is required (not both):

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| `component` | string | Path to main QML file (single-surface plugins) | Must start with `./`, end with `.qml` |
| `components` | object | Map of surface name to QML path (multi-surface plugins) | At least 1 entry; keys: `widget`, `desktop`, `daemon`, `launcher` |

## Conditional Requirements

| Condition | Required Field | Description |
|-----------|---------------|-------------|
| `type: "launcher"` | `trigger` | Trigger string for launcher activation (e.g., `=`, `#`, `!`) |
| `components` has `launcher` key | `trigger` | Same requirement applies to composite plugins with a launcher surface |

## Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `icon` | string | Material Design icon name (displayed in plugin list UI) |
| `settings` | string | Path to settings QML file (must start with `./`, end with `.qml`) |
| `startupCheck` | string | Path to a QtObject component that gates plugin activation via a `check(done)` function (must start with `./`, end with `.qml`). See Startup Check section below. |
| `requires_dms` | string | Minimum DMS version (e.g., `>=0.1.18`), pattern `^(>=?\|<=?\|=\|>\|<)\d+\.\d+\.\d+$` |
| `dependencies` | array | System tool dependencies (e.g., `["curl", "jq"]`). Registry metadata. |
| `requires` | array | Deprecated alias for `dependencies` |
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

## Startup Check

The `startupCheck` field points to a non-visual `QtObject` component that gates plugin activation on dependency checks. The component must expose a `check(done)` function:

```qml
import QtQuick
import qs.Common

QtObject {
    function check(done) {
        Proc.runCommand("myPlugin.depCheck", ["sh", "-c", "command -v mytool"], (stdout, exitCode) => {
            if (exitCode === 0) {
                done(null);
                return;
            }
            done({
                "title": I18n.tr("mytool is required"),
                "details": I18n.tr("Install 'mytool' and re-enable this plugin.")
            });
        });
    }
}
```

The `done` callback accepts:
- `null` - allow activation
- A string - block with a short error message
- `{ title, details }` - block with a title and expandable details

A synchronous variant (no `done` parameter, return the result directly) is also supported.

Failed startup checks show a toast error and store the error in `pluginService.pluginLoadErrors`.

## Components (Composite Plugins)

The `components` field maps surface names to QML paths, allowing a single plugin to register multiple surfaces:

```json
{
    "id": "myComposite",
    "name": "My Composite Plugin",
    "description": "Daemon + widget + desktop from one plugin",
    "version": "1.0.0",
    "author": "Developer Name",
    "type": "composite",
    "capabilities": ["daemon", "dankbar-widget", "desktop-widget"],
    "icon": "extension",
    "components": {
        "daemon": "./MyDaemon.qml",
        "widget": "./MyBarWidget.qml",
        "desktop": "./MyDesktopWidget.qml"
    },
    "settings": "./Settings.qml",
    "permissions": ["settings_read", "settings_write"]
}
```

Valid surface keys: `widget`, `desktop`, `daemon`, `launcher`. Provide any subset. Each surface is loaded independently in the appropriate registry.

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
    "startupCheck": "./StartupCheck.qml",
    "requires_dms": ">=0.1.18",
    "dependencies": ["curl", "jq"],
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
