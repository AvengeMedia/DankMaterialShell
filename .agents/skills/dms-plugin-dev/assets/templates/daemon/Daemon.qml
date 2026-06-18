import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root
    property var popoutService: null

    // TODO: Read configuration from settings
    property string configValue: pluginData?.configValue || ""

    Connections {
        target: pluginService
        function onPluginDataChanged(changedId) {
            if (changedId !== pluginId) return
            configValue = pluginService.loadPluginData(pluginId, "configValue", "")
        }
    }

    // TODO: Connect to the service events you need
    // Connections {
    //     target: SessionData
    //     function onWallpaperPathChanged() {
    //         console.log("[MyDaemon] Wallpaper changed:", SessionData.wallpaperPath)
    //         handleEvent(SessionData.wallpaperPath)
    //     }
    // }

    function handleEvent(data) {
        Proc.runCommand(
            "myDaemon.handle",
            ["echo", "Event received:", data],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    console.log("[MyDaemon] Output:", stdout)
                } else {
                    console.error("[MyDaemon] Failed:", exitCode)
                    ToastService?.showInfo("Daemon action failed")
                }
            }
        )
    }

    Component.onCompleted: {
        console.log("[MyDaemon] Started")
    }
}
