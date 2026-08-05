pragma Singleton

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Singleton {
    id: root

    property var activeTrayMenus: ({})
    property var _pendingMenuRequest: null

    signal openTrayMenuRequested

    function requestOpenMenu(itemId, screenName) {
        _pendingMenuRequest = {
            "itemId": itemId,
            "screenName": screenName
        };
        openTrayMenuRequested();
    }

    // Every SystemTrayBar instance receives the signal; the claim ensures
    // exactly one opens the menu, preferring the requested screen
    function claimMenuRequest(instanceScreenName) {
        if (!_pendingMenuRequest)
            return null;
        if (_pendingMenuRequest.screenName && _pendingMenuRequest.screenName !== instanceScreenName)
            return null;
        const request = _pendingMenuRequest;
        _pendingMenuRequest = null;
        return request;
    }

    function findTrayItem(itemId: string): var {
        if (!itemId)
            return null;

        return SystemTray.items.values.find(item => {
            const id = item?.id || "";
            const title = item?.tooltipTitle || "";
            const fullKey = title ? `${id}::${title}` : id;
            return fullKey === itemId || id === itemId;
        });
    }

    function registerMenu(screenName, menu) {
        if (!screenName || !menu)
            return;
        const newMenus = Object.assign({}, activeTrayMenus);
        newMenus[screenName] = menu;
        activeTrayMenus = newMenus;
    }

    function unregisterMenu(screenName) {
        if (!screenName)
            return;
        const newMenus = Object.assign({}, activeTrayMenus);
        delete newMenus[screenName];
        activeTrayMenus = newMenus;
    }

    function closeHoverMenus() {
        for (const screenName in activeTrayMenus) {
            const menu = activeTrayMenus[screenName]
            if (!menu || menu.openedByHover !== true) continue
            if (typeof menu.close === "function") {
                menu.close()
            } else if (menu.showMenu !== undefined) {
                menu.showMenu = false
            }
        }
    }

    function closeAllMenus() {
        for (const screenName in activeTrayMenus) {
            const menu = activeTrayMenus[screenName];
            if (!menu)
                continue;
            if (typeof menu.close === "function") {
                menu.close();
            } else if (menu.showMenu !== undefined) {
                menu.showMenu = false;
            }
        }
    }
}
