import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    WindowBlur {
        targetWindow: root
        blurX: menu.x
        blurY: menu.y
        blurWidth: root.visible ? menu.width : 0
        blurHeight: root.visible ? menu.height : 0
        blurRadius: Theme.cornerRadius
    }

    WlrLayershell.namespace: "dms:idle-inhibit-duration-menu"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    property point anchorPos: Qt.point(0, 0)
    property bool isVertical: false
    property string edge: "top"
    screen: null
    visible: false

    function showAt(x, y, vertical, barEdge, targetScreen) {
        if (targetScreen)
            root.screen = targetScreen;
        anchorPos = Qt.point(x, y);
        isVertical = vertical ?? false;
        edge = barEdge ?? "top";
        visible = true;

        if (root.screen)
            TrayMenuManager.registerMenu(root.screen.name, root);
    }

    function close() {
        if (!visible)
            return;
        visible = false;

        if (root.screen)
            TrayMenuManager.unregisterMenu(root.screen.name);
    }

    Component.onDestruction: {
        if (visible && root.screen)
            TrayMenuManager.unregisterMenu(root.screen.name);
    }

    Connections {
        target: PopoutManager
        function onPopoutOpening() {
            root.close();
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.close()
    }

    IdleInhibitDurationMenu {
        id: menu
        z: 1
        visible: root.visible

        x: {
            if (root.isVertical) {
                if (root.edge === "left")
                    return Math.min(root.width - width - 10, root.anchorPos.x);
                return Math.max(10, root.anchorPos.x - width);
            }
            return Math.max(10, Math.min(root.width - width - 10, root.anchorPos.x - width / 2));
        }
        y: {
            if (root.isVertical)
                return Math.max(10, Math.min(root.height - height - 10, root.anchorPos.y - height / 2));
            if (root.edge === "bottom")
                return Math.max(10, root.anchorPos.y - height);
            return Math.min(root.height - height - 10, root.anchorPos.y);
        }

        onDismissed: root.close()
    }
}
