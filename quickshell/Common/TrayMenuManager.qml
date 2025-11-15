pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property var activeTrayBars: ({})

    function register(screenName, trayBar) {
        if (!screenName || !trayBar) return
        activeTrayBars[screenName] = trayBar
    }

    function unregister(screenName) {
        if (!screenName) return
        delete activeTrayBars[screenName]
    }

    function closeAllMenus() {
        for (const screenName in activeTrayBars) {
            const trayBar = activeTrayBars[screenName]
            if (!trayBar) continue

            trayBar.menuOpen = false
            if (trayBar.currentTrayMenu) {
                trayBar.currentTrayMenu.showMenu = false
            }
        }
    }
}
