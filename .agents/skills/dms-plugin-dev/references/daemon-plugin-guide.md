# Daemon Plugin Guide

Daemon plugins are invisible background services that react to events and execute actions. They have no bar pills or desktop presence.

## Base Component

Daemons use `PluginComponent` with no bar pills:

```qml
import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root
    property var popoutService: null

    // Event-driven logic goes here
}
```

## When to Use Daemons

- Monitor system events (wallpaper changes, battery level, notifications)
- Run periodic background tasks (polling APIs, checking system state)
- Execute scripts in response to events
- Control shell UI via PopoutService based on conditions

## Event-Driven Pattern

Use `Connections` to react to service signals:

```qml
PluginComponent {
    property var popoutService: null

    Connections {
        target: SessionData
        function onWallpaperPathChanged() {
            console.log("Wallpaper changed to:", SessionData.wallpaperPath)
            runScript(SessionData.wallpaperPath)
        }
    }

    Connections {
        target: BatteryService
        function onPercentageChanged() {
            if (BatteryService.percentage < 10 && !BatteryService.isCharging) {
                popoutService?.openBattery()
            }
        }
    }
}
```

## Available Services

Common services daemons can connect to:

| Service | Signals/Properties | Description |
|---------|-------------------|-------------|
| `SessionData` | `wallpaperPath`, `onWallpaperPathChanged` | Desktop session state |
| `BatteryService` | `percentage`, `isCharging`, `batteryAvailable` | Battery status |
| `NotificationService` | `onNotificationReceived(notification)` | Desktop notifications |
| `PluginService` | `onPluginLoaded`, `onGlobalVarChanged` | Plugin lifecycle |

Import services from `qs.Services`.

## Process Execution

### Simple command with Proc

```qml
import qs.Common

PluginComponent {
    function runScript(arg) {
        Proc.runCommand(
            "myDaemon.script",
            ["bash", "-c", "echo 'Processing: " + arg + "'"],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    console.log("Script output:", stdout)
                } else {
                    ToastService?.showInfo("Script failed: exit " + exitCode)
                }
            }
        )
    }
}
```

### Long-running process with Process component

```qml
import Quickshell.Io

PluginComponent {
    property string scriptPath: ""

    Process {
        id: proc
        command: ["bash", scriptPath]
        running: false

        stdout: StdioCollector {
            onTextReceived: (text) => {
                console.log("stdout:", text)
            }
        }

        stderr: StdioCollector {
            onTextReceived: (text) => {
                console.error("stderr:", text)
            }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                ToastService?.showInfo("Process failed: exit " + exitCode)
            }
        }
    }

    function startProcess() {
        if (scriptPath && !proc.running) {
            proc.running = true
        }
    }
}
```

## Timer-Based Polling

```qml
PluginComponent {
    Timer {
        interval: 60000  // every minute
        running: true
        repeat: true
        onTriggered: checkStatus()
    }

    function checkStatus() {
        Proc.runCommand(
            "myDaemon.check",
            ["sh", "-c", "systemctl is-active myservice"],
            (stdout, exitCode) => {
                const active = stdout.trim() === "active"
                PluginService.setGlobalVar("myDaemon", "serviceActive", active)
            }
        )
    }
}
```

## Data Persistence

Daemons access PluginService directly (it's injected via PluginComponent):

```qml
PluginComponent {
    property string configuredScript: pluginData?.scriptPath || ""

    Connections {
        target: pluginService
        function onPluginDataChanged(changedId) {
            if (changedId === pluginId) {
                configuredScript = pluginService.loadPluginData(pluginId, "scriptPath", "")
            }
        }
    }
}
```

## PopoutService Usage

Daemons can control shell UI via the injected popoutService:

```qml
PluginComponent {
    property var popoutService: null

    function showAlert() {
        popoutService?.openNotificationCenter()
    }

    function openSettings() {
        popoutService?.openSettings()
    }
}
```

See [popout-service-reference.md](popout-service-reference.md) for the full API.

## Complete Example

Based on the WallpaperWatcherDaemon:

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root
    property var popoutService: null

    property string scriptPath: pluginData?.scriptPath || ""

    Connections {
        target: pluginService
        function onPluginDataChanged(changedId) {
            if (changedId === pluginId) {
                scriptPath = pluginService.loadPluginData(pluginId, "scriptPath", "")
            }
        }
    }

    Connections {
        target: SessionData
        function onWallpaperPathChanged() {
            if (scriptPath) {
                runWallpaperScript(SessionData.wallpaperPath)
            }
        }
    }

    function runWallpaperScript(wallpaperPath) {
        console.log("[WallpaperWatcher] Running script:", scriptPath, wallpaperPath)

        Proc.runCommand(
            "wallpaperWatcher.run",
            ["bash", scriptPath, wallpaperPath],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    console.log("[WallpaperWatcher] Script output:", stdout)
                } else {
                    console.error("[WallpaperWatcher] Script failed:", exitCode)
                    ToastService?.showInfo("Wallpaper script failed")
                }
            }
        )
    }

    Component.onCompleted: {
        console.log("[WallpaperWatcher] Daemon started")
    }
}
```

## Manifest Example

```json
{
    "id": "wallpaperWatcher",
    "name": "Wallpaper Watcher",
    "description": "Runs a script when the wallpaper changes",
    "version": "1.0.0",
    "author": "Developer",
    "type": "daemon",
    "capabilities": ["wallpaper-automation"],
    "component": "./WallpaperWatcher.qml",
    "icon": "wallpaper",
    "settings": "./Settings.qml",
    "permissions": ["settings_read", "settings_write", "process"]
}
```
