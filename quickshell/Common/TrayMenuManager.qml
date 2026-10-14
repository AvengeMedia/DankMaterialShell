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

    function iconSourceFor(trayItem) {
        let icon = trayItem && trayItem.icon;
        if (typeof icon === "string" || icon instanceof String) {
            if (icon === "")
                return "";
            if (icon.includes("?path=")) {
                const split = icon.split("?path=");
                if (split.length !== 2)
                    return icon;
                const name = split[0];
                const path = split[1];
                let fileName = name.substring(name.lastIndexOf("/") + 1);
                if (fileName.startsWith("dropboxstatus"))
                    fileName = `hicolor/16x16/status/${fileName}`;
                return `file://${path}/${fileName}`;
            }
            if (icon.startsWith("/") && !icon.startsWith("file://"))
                return `file://${icon}`;
            return icon;
        }
        return "";
    }

    function callContextMenuFallback(trayItemId, globalX, globalY) {
        const script = ['ITEMS=$(dbus-send --session --print-reply --dest=org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.freedesktop.DBus.Properties.Get string:org.kde.StatusNotifierWatcher string:RegisteredStatusNotifierItems 2>/dev/null)', 'while IFS= read -r line; do', '  line="${line#*\\\"}"', '  line="${line%\\\"*}"', '  [ -z "$line" ] && continue', '  BUS="${line%%/*}"', '  OBJ="/${line#*/}"', '  ID=$(dbus-send --session --print-reply --dest="$BUS" "$OBJ" org.freedesktop.DBus.Properties.Get string:org.kde.StatusNotifierItem string:Id 2>/dev/null | grep -oP "(?<=\\\")(.*?)(?=\\\")" | tail -1)', '  if [ "$ID" = "$1" ]; then', '    dbus-send --session --type=method_call --dest="$BUS" "$OBJ" org.kde.StatusNotifierItem.ContextMenu int32:"$2" int32:"$3"', '    exit 0', '  fi', 'done <<< "$ITEMS"',].join("\n");
        Quickshell.execDetached(["bash", "-c", script, "_", trayItemId, String(Math.round(globalX)), String(Math.round(globalY))]);
    }
}
