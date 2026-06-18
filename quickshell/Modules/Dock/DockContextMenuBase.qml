import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    default property alias content: menuColumn.children

    property var anchorItem: null
    property real dockVisibleHeight: 40
    property int margin: 10
    property string layerNamespace: "dms:dock-context-menu"
    property real menuMaxWidth: 400
    property real menuMinWidth: 180

    property point anchorPos: Qt.point(screen ? screen.width / 2 : 0, screen ? screen.height - 100 : 0)

    function show(button, dockHeight, dockScreen) {
        if (dockScreen)
            screen = dockScreen;
        anchorItem = button;
        dockVisibleHeight = dockHeight || 40;
        visible = true;
    }

    function close() {
        visible = false;
    }

    function findDockBackground(item) {
        if (!item)
            return null;
        if (item.objectName === "dockBackground")
            return item;
        for (let i = 0; i < item.children.length; i++) {
            const found = findDockBackground(item.children[i]);
            if (found)
                return found;
        }
        return null;
    }

    function updatePosition() {
        if (!anchorItem || !screen) {
            anchorPos = Qt.point(screen ? screen.width / 2 : 0, screen ? screen.height - 100 : 0);
            return;
        }

        const dockWindow = anchorItem.Window.window;
        if (!dockWindow) {
            anchorPos = Qt.point(screen.width / 2, screen.height - 100);
            return;
        }

        const buttonPosInDock = anchorItem.mapToItem(dockWindow.contentItem, 0, 0);
        const dockBackground = findDockBackground(dockWindow.contentItem);
        const actualDockHeight = dockBackground ? dockBackground.height : root.dockVisibleHeight;
        const actualDockWidth = dockBackground ? dockBackground.width : dockWindow.width;
        const dockMargin = SettingsData.dockMargin + 16;
        let x = 0;
        let y = 0;

        switch (SettingsData.dockPosition) {
        case SettingsData.Position.Left:
            {
                const dockTopMargin = Math.round((screen.height - dockWindow.height) / 2);
                x = actualDockWidth + dockMargin + 20;
                y = dockTopMargin + buttonPosInDock.y + anchorItem.height / 2;
                break;
            }
        case SettingsData.Position.Right:
            {
                const dockTopMargin = Math.round((screen.height - dockWindow.height) / 2);
                x = screen.width - actualDockWidth - dockMargin - 20;
                y = dockTopMargin + buttonPosInDock.y + anchorItem.height / 2;
                break;
            }
        case SettingsData.Position.Top:
            {
                const dockLeftMargin = Math.round((screen.width - dockWindow.width) / 2);
                x = dockLeftMargin + buttonPosInDock.x + anchorItem.width / 2;
                y = actualDockHeight + dockMargin + 20;
                break;
            }
        case SettingsData.Position.Bottom:
        default:
            {
                const dockLeftMargin = Math.round((screen.width - dockWindow.width) / 2);
                x = dockLeftMargin + buttonPosInDock.x + anchorItem.width / 2;
                y = screen.height - actualDockHeight - dockMargin - 20;
                break;
            }
        }

        anchorPos = Qt.point(x, y);
    }

    onAnchorItemChanged: updatePosition()
    onVisibleChanged: {
        if (visible)
            updatePosition();
    }

    WindowBlur {
        targetWindow: root
        blurX: menuContainer.x
        blurY: menuContainer.y
        blurWidth: root.visible ? menuContainer.width : 0
        blurHeight: root.visible ? menuContainer.height : 0
        blurRadius: Theme.cornerRadius
    }

    WlrLayershell.namespace: root.layerNamespace
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    screen: null
    visible: false
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    Rectangle {
        id: menuContainer

        readonly property bool isVertical: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right

        x: {
            if (!isVertical) {
                const want = root.anchorPos.x - width / 2;
                return Math.max(10, Math.min(root.width - width - 10, want));
            }
            if (SettingsData.dockPosition === SettingsData.Position.Right)
                return Math.max(10, root.anchorPos.x - width + 30);
            return Math.min(root.width - width - 10, root.anchorPos.x - 30);
        }
        y: {
            if (isVertical) {
                const want = root.anchorPos.y - height / 2;
                return Math.max(10, Math.min(root.height - height - 10, want));
            }
            if (SettingsData.dockPosition === SettingsData.Position.Bottom)
                return Math.max(10, root.anchorPos.y - height + 30);
            return Math.min(root.height - height - 10, root.anchorPos.y - 30);
        }

        width: Math.min(root.menuMaxWidth, Math.max(root.menuMinWidth, menuColumn.implicitWidth + Theme.spacingS * 2))
        height: menuColumn.implicitHeight + Theme.spacingS * 2
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        radius: Theme.cornerRadius
        border.color: BlurService.enabled ? BlurService.borderColor : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: BlurService.enabled ? BlurService.borderWidth : 1

        opacity: root.visible ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: -1
        }

        Column {
            id: menuColumn
            width: parent.width - Theme.spacingS * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingS
            spacing: 1
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.close()
    }
}
