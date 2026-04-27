import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    WindowBlur {
        targetWindow: root
        blurX: menuContainer.x
        blurY: menuContainer.y
        blurWidth: root.visible ? menuContainer.width : 0
        blurHeight: root.visible ? menuContainer.height : 0
        blurRadius: Theme.cornerRadius
    }

    WlrLayershell.namespace: "dms:dock-trash-context-menu"

    property var anchorItem: null
    property real dockVisibleHeight: 40
    property int margin: 10
    property var dockApps: null

    function showForButton(button, dockHeight, dockScreen, parentDockApps) {
        if (dockScreen) {
            root.screen = dockScreen;
        }

        anchorItem = button;
        dockVisibleHeight = dockHeight || 40;
        dockApps = parentDockApps || null;

        visible = true;
    }
    function close() {
        visible = false;
    }

    screen: null
    visible: false
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

    property point anchorPos: Qt.point(screen ? screen.width / 2 : 0, screen ? screen.height - 100 : 0)

    onAnchorItemChanged: updatePosition()
    onVisibleChanged: {
        if (visible) {
            updatePosition();
        }
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
        let actualDockHeight = root.dockVisibleHeight;

        function findDockBackground(item) {
            if (item.objectName === "dockBackground") {
                return item;
            }
            for (var i = 0; i < item.children.length; i++) {
                const found = findDockBackground(item.children[i]);
                if (found) {
                    return found;
                }
            }
            return null;
        }

        const dockBackground = findDockBackground(dockWindow.contentItem);
        let actualDockWidth = dockWindow.width;
        if (dockBackground) {
            actualDockHeight = dockBackground.height;
            actualDockWidth = dockBackground.width;
        }

        const isVertical = SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right;
        const dockMargin = SettingsData.dockMargin + 16;
        let buttonScreenX, buttonScreenY;

        if (isVertical) {
            const dockContentHeight = dockWindow.height;
            const screenHeight = root.screen.height;
            const dockTopMargin = Math.round((screenHeight - dockContentHeight) / 2);
            buttonScreenY = dockTopMargin + buttonPosInDock.y + anchorItem.height / 2;

            if (SettingsData.dockPosition === SettingsData.Position.Right) {
                buttonScreenX = root.screen.width - actualDockWidth - dockMargin - 20;
            } else {
                buttonScreenX = actualDockWidth + dockMargin + 20;
            }
        } else {
            const isDockAtBottom = SettingsData.dockPosition === SettingsData.Position.Bottom;

            if (isDockAtBottom) {
                buttonScreenY = root.screen.height - actualDockHeight - dockMargin - 20;
            } else {
                buttonScreenY = actualDockHeight + dockMargin + 20;
            }

            const dockContentWidth = dockWindow.width;
            const screenWidth = root.screen.width;
            const dockLeftMargin = Math.round((screenWidth - dockContentWidth) / 2);
            buttonScreenX = dockLeftMargin + buttonPosInDock.x + anchorItem.width / 2;
        }

        anchorPos = Qt.point(buttonScreenX, buttonScreenY);
    }

    Rectangle {
        id: menuContainer

        x: {
            const isVertical = SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right;
            if (isVertical) {
                const isDockAtRight = SettingsData.dockPosition === SettingsData.Position.Right;
                if (isDockAtRight) {
                    return Math.max(10, root.anchorPos.x - width + 30);
                } else {
                    return Math.min(root.width - width - 10, root.anchorPos.x - 30);
                }
            } else {
                const left = 10;
                const right = root.width - width - 10;
                const want = root.anchorPos.x - width / 2;
                return Math.max(left, Math.min(right, want));
            }
        }
        y: {
            const isVertical = SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right;
            if (isVertical) {
                const top = 10;
                const bottom = root.height - height - 10;
                const want = root.anchorPos.y - height / 2;
                return Math.max(top, Math.min(bottom, want));
            } else {
                const isDockAtBottom = SettingsData.dockPosition === SettingsData.Position.Bottom;
                if (isDockAtBottom) {
                    return Math.max(10, root.anchorPos.y - height + 30);
                } else {
                    return Math.min(root.height - height - 10, root.anchorPos.y - 30);
                }
            }
        }

        width: Math.min(400, Math.max(180, menuColumn.implicitWidth + Theme.spacingS * 2))
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

            Rectangle {
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: openArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "folder_open"
                        size: 14
                        color: Theme.surfaceText
                        opacity: 0.7
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Open Trash")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }
                }

                DankRipple {
                    id: openRipple
                    rippleColor: Theme.surfaceText
                    cornerRadius: Theme.cornerRadius
                }

                MouseArea {
                    id: openArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => openRipple.trigger(mouse.x, mouse.y)
                    onClicked: {
                        TrashService.openTrash();
                        root.close();
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                enabled: !TrashService.isEmpty
                opacity: enabled ? 1 : 0.4
                color: emptyArea.containsMouse && enabled ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "delete_forever"
                        size: 14
                        color: emptyArea.containsMouse && parent.parent.enabled ? Theme.error : Theme.surfaceText
                        opacity: 0.7
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: TrashService.isEmpty ? I18n.tr("Empty Trash") : I18n.tr("Empty Trash (%1)").arg(TrashService.count)
                        font.pixelSize: Theme.fontSizeSmall
                        color: emptyArea.containsMouse && parent.parent.enabled ? Theme.error : Theme.surfaceText
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }
                }

                DankRipple {
                    id: emptyRipple
                    rippleColor: Theme.error
                    cornerRadius: Theme.cornerRadius
                }

                MouseArea {
                    id: emptyArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: parent.enabled
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => emptyRipple.trigger(mouse.x, mouse.y)
                    onClicked: {
                        TrashService.requestEmptyTrash();
                        root.close();
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }

            Rectangle {
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: settingsArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "settings"
                        size: 14
                        color: Theme.surfaceText
                        opacity: 0.7
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Settings")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }
                }

                DankRipple {
                    id: settingsRipple
                    rippleColor: Theme.surfaceText
                    cornerRadius: Theme.cornerRadius
                }

                MouseArea {
                    id: settingsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => settingsRipple.trigger(mouse.x, mouse.y)
                    onClicked: {
                        PopoutService.focusOrToggleSettingsWithTab("dock");
                        root.close();
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.close()
    }
}
