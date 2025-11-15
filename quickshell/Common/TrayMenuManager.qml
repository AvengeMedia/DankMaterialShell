pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property var activeOverflowMenus: ({})
    property var activeTrayMenus: ({})

    function registerOverflowMenu(screenName, menuOpenBinding) {
        if (!screenName) return
        activeOverflowMenus[screenName] = menuOpenBinding
    }

    function unregisterOverflowMenu(screenName) {
        if (!screenName) return
        delete activeOverflowMenus[screenName]
    }

    function registerTrayMenu(screenName, closeCallback) {
        if (!screenName) return
        activeTrayMenus[screenName] = closeCallback
    }

    function unregisterTrayMenu(screenName) {
        if (!screenName) return
        delete activeTrayMenus[screenName]
    }

    function closeOverflowMenus() {
        for (const screenName in activeOverflowMenus) {
            const menuBinding = activeOverflowMenus[screenName]
            if (menuBinding && menuBinding.close) {
                menuBinding.close()
            }
        }
    }

    function closeTrayMenus() {
        for (const screenName in activeTrayMenus) {
            const closeCallback = activeTrayMenus[screenName]
            if (closeCallback) {
                closeCallback()
            }
        }
    }

    function closeAllMenus() {
        closeOverflowMenus()
        closeTrayMenus()
    }
}
