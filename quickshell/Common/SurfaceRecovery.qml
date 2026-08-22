pragma Singleton

import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root

    readonly property var log: Log.scoped("SurfaceRecovery")
    property var _windows: []

    function track(window) {
        if (!window || _windows.includes(window))
            return;
        _windows = _windows.concat([window]);
    }

    function untrack(window) {
        if (!_windows.includes(window))
            return;
        _windows = _windows.filter(w => w !== window);
    }

    function freeEdge(window) {
        const a = window.anchors;
        if (!a.bottom)
            return "bottom";
        if (!a.top)
            return "top";
        if (!a.right)
            return "right";
        if (!a.left)
            return "left";
        return "";
    }

    // wlr-layer-shell set_margin: "Setting this value for edges you are not anchored to has no effect"
    function refresh(window) {
        if (!window)
            return false;
        const edge = freeEdge(window);
        if (edge === "")
            return false;
        switch (edge) {
        case "bottom":
            window.margins.bottom = window.margins.bottom ? 0 : 1;
            break;
        case "top":
            window.margins.top = window.margins.top ? 0 : 1;
            break;
        case "right":
            window.margins.right = window.margins.right ? 0 : 1;
            break;
        case "left":
            window.margins.left = window.margins.left ? 0 : 1;
            break;
        }
        return true;
    }

    function refreshAll() {
        let refreshed = 0;
        for (const window of _windows) {
            if (refresh(window))
                refreshed++;
        }
        log.info("Refreshed", refreshed, "of", _windows.length, "layer surfaces");
        return refreshed;
    }

    function fitsScreen(window) {
        if (!window?.screen || !window.visible)
            return true;
        if (window.width <= 0 || window.height <= 0)
            return false;
        const a = window.anchors;
        if (a.left && a.right && window.width > window.screen.width)
            return false;
        if (a.top && a.bottom && window.height > window.screen.height)
            return false;
        return true;
    }

    function staleWindows() {
        return _windows.filter(w => !fitsScreen(w));
    }
}
