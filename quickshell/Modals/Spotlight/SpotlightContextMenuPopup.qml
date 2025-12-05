import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Modals.Spotlight

Popup {
    id: root

    property var appLauncher: null
    property var parentHandler: null
    property var searchField: null

    function show(x, y, app, fromKeyboard) {
        fromKeyboard = fromKeyboard || false;
        menuContent.currentApp = app;
        
        root.x = x + 4;
        root.y = y + 4;
        
        menuContent.selectedMenuIndex = fromKeyboard ? 0 : -1;
        menuContent.keyboardNavigation = true;
        
        if (parentHandler) {
            parentHandler.enabled = false;
        }
        
        open();
    }
    
    onOpened: {
        Qt.callLater(() => {
            menuContent.keyboardHandler.forceActiveFocus();
        });
    }

    function hide() {
        if (parentHandler) {
            parentHandler.enabled = true;
        }
        close();
    }

    width: menuContent.implicitWidth
    height: menuContent.implicitHeight
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    modal: true
    dim: false
    background: Item {}

    onClosed: {
        if (parentHandler) {
            parentHandler.enabled = true;
        }
        if (searchField) {
            Qt.callLater(() => {
                searchField.forceActiveFocus();
            });
        }
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.shortDuration
            easing.type: Theme.emphasizedEasing
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: Theme.shortDuration
            easing.type: Theme.emphasizedEasing
        }
    }

    contentItem: SpotlightContextMenuContent {
        id: menuContent
        appLauncher: root.appLauncher
        onHideRequested: root.hide()
    }
}
