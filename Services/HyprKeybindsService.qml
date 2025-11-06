pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string _configUrl: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
    readonly property string _configDir: Paths.strip(_configUrl)
    property string hyprConfigPath: `${_configDir}/hypr`
    property var keybinds: ({"children": [], "keybinds": []})

    Process {
        id: getKeybinds
        running: false
        command: ["dms", "hyprland", "keybinds", "--path", root.hyprConfigPath]

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.keybinds = JSON.parse(data)
                } catch (e) {
                    console.error("[HyprKeybindsService] Error parsing keybinds:", e)
                }
            }
        }

        onExited: (code) => {
            if (code !== 0) {
                console.warn("[HyprKeybindsService] Process exited with code:", code)
            }
        }
    }

    Component.onCompleted: {
        getKeybinds.running = true
    }

    function reload() {
        getKeybinds.running = false
        Qt.callLater(function() {
            getKeybinds.running = true
        })
    }
}
