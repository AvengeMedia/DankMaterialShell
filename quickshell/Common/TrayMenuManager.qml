pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property var activeTrayMenus: ({})

    function registerMenu(screenName, menu) {
        if (!screenName || !menu) return
        const newMenus = Object.assign({}, activeTrayMenus)
        newMenus[screenName] = menu
        activeTrayMenus = newMenus
    }

    function unregisterMenu(screenName) {
        if (!screenName) return
        const newMenus = Object.assign({}, activeTrayMenus)
        delete newMenus[screenName]
        activeTrayMenus = newMenus
    }

    function closeAllMenus() {
        for (const screenName in activeTrayMenus) {
            const menu = activeTrayMenus[screenName]
            if (!menu) continue
            if (typeof menu.close === "function") {
                menu.close()
            } else if (menu.showMenu !== undefined) {
                menu.showMenu = false
            }
        }
    }
}
