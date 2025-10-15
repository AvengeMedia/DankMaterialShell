pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string shellDir: Paths.strip(Qt.resolvedUrl(".").toString()).replace("/Services/", "")
    property string scriptPath: `${shellDir}/scripts/hyprland_keybinds.py`
    readonly property string _configUrl: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
    readonly property string _configDir: Paths.strip(_configUrl)
    property string hyprConfigPath: `${_configDir}/hypr`
    property var keybinds: ({"children": [], "keybinds": []})

    Process {
        id: getKeybinds
        running: true
        command: [root.scriptPath, "--path", root.hyprConfigPath]

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.keybinds = JSON.parse(data)
                } catch (e) {
                    console.error("[HyprKeybindsService] Error parsing keybinds:", e)
                }
            }
        }
    }

    function reload() {
        getKeybinds.running = true
    }
}
