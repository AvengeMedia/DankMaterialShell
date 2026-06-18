import QtQuick
import qs.Common
import qs.Modals
import qs.Services

Item {
    id: root

    readonly property bool floating: SettingsData.keybindsFloatingWindow
    readonly property bool shouldBeVisible: floating ? (windowLoader.item ? windowLoader.item.visible : false) : (overlayLoader.item ? overlayLoader.item.shouldBeVisible : false)

    function open() {
        if (floating) {
            windowLoader.active = true;
            windowLoader.item.show();
            return;
        }
        overlayLoader.active = true;
        overlayLoader.item.open();
    }

    function close() {
        if (windowLoader.item)
            windowLoader.item.hide();
        if (overlayLoader.item)
            overlayLoader.item.close();
    }

    function toggle() {
        if (shouldBeVisible)
            close();
        else
            open();
    }

    function _switchFloating(toFloating) {
        if (toFloating) {
            if (overlayLoader.item)
                overlayLoader.item.close();
            SettingsData.keybindsFloatingWindow = true;
            windowLoader.active = true;
            windowLoader.item.show();
            return;
        }
        if (windowLoader.item)
            windowLoader.item.hide();
        SettingsData.keybindsFloatingWindow = false;
        overlayLoader.active = true;
        overlayLoader.item.open();
    }

    Loader {
        id: overlayLoader
        active: false
        asynchronous: false

        sourceComponent: KeybindsModalOverlay {
            onFloatingToggleRequested: root._switchFloating(true)
            onDialogClosed: Qt.callLater(() => {
                if (!shouldBeVisible)
                    overlayLoader.active = false;
            })
        }
    }

    Loader {
        id: windowLoader
        active: false
        asynchronous: false

        sourceComponent: KeybindsModalWindow {
            onFloatingToggleRequested: root._switchFloating(false)
            onVisibleChanged: {
                if (!visible)
                    Qt.callLater(() => windowLoader.active = false);
            }
        }
    }
}
