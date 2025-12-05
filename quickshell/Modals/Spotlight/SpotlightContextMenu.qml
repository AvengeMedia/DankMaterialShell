import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modals.Spotlight

PanelWindow {
    id: root

    WlrLayershell.namespace: "dms:spotlight-context-menu"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var appLauncher: null
    property var parentHandler: null
    property var parentModal: null
    property real menuPositionX: 0
    property real menuPositionY: 0
    
    readonly property real shadowBuffer: 5
    
    screen: parentModal?.effectiveScreen

    function show(x, y, app, fromKeyboard) {
        fromKeyboard = fromKeyboard || false;
        menuContent.currentApp = app;
        
        let screenX = x;
        let screenY = y;
        
        if (parentModal) {
            if (fromKeyboard) {
                screenX = x + parentModal.alignedX;
                screenY = y + parentModal.alignedY;
            } else {
                screenX = x + (parentModal.alignedX - shadowBuffer);
                screenY = y + (parentModal.alignedY - shadowBuffer);
            }
        }
        
        menuPositionX = screenX;
        menuPositionY = screenY;
        
        menuContent.selectedMenuIndex = fromKeyboard ? 0 : -1;
        menuContent.keyboardNavigation = true;
        visible = true;
        
        if (parentHandler) {
            parentHandler.enabled = false;
        }
        Qt.callLater(() => {
            menuContent.keyboardHandler.forceActiveFocus();
        });
    }

    function hide() {
        if (parentHandler) {
            parentHandler.enabled = true;
        }
        visible = false;
    }

    visible: false
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    onVisibleChanged: {
        if (!visible && parentHandler) {
            parentHandler.enabled = true;
        }
    }

    SpotlightContextMenuContent {
        id: menuContent

        x: {
            const left = 10;
            const right = root.width - width - 10;
            const want = menuPositionX;
            return Math.max(left, Math.min(right, want));
        }
        y: {
            const top = 10;
            const bottom = root.height - height - 10;
            const want = menuPositionY;
            return Math.max(top, Math.min(bottom, want));
        }

        appLauncher: root.appLauncher

        opacity: root.visible ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        onHideRequested: root.hide()
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.hide()
    }
}
