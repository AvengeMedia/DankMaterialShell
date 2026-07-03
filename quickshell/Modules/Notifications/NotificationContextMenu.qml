import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property string appName: ""
    property string desktopEntry: ""
    property point anchorPos: Qt.point(0, 0)

    signal muted
    signal dismissRequested

    readonly property bool isMuted: SettingsData.isAppMuted(appName, desktopEntry)

    function showAt(x, y, targetScreen) {
        if (targetScreen)
            screen = targetScreen;
        anchorPos = Qt.point(x, y);
        visible = true;
    }

    function closeMenu() {
        visible = false;
    }

    function triggerAction(action) {
        switch (action) {
        case "rules":
            SettingsData.addNotificationRuleForNotification(appName, desktopEntry);
            PopoutService.openSettingsWithTab("notifications");
            break;
        case "mute":
            if (isMuted) {
                SettingsData.removeMuteRuleForApp(appName, desktopEntry);
            } else {
                SettingsData.addMuteRuleForApp(appName, desktopEntry);
                muted();
            }
            break;
        case "dismiss":
            dismissRequested();
            break;
        }
        closeMenu();
    }

    WindowBlur {
        targetWindow: root
        blurX: menuRect.x
        blurY: menuRect.y
        blurWidth: root.visible ? menuRect.width : 0
        blurHeight: root.visible ? menuRect.height : 0
        blurRadius: Theme.cornerRadius
    }

    WlrLayershell.namespace: "dms:notification-context-menu"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    visible: false
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    Connections {
        target: PopoutManager

        function onPopoutOpening() {
            root.closeMenu();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.closeMenu()
    }

    Rectangle {
        id: menuRect

        x: Math.max(10, Math.min(root.width - width - 10, root.anchorPos.x))
        y: Math.max(10, Math.min(root.height - height - 10, root.anchorPos.y))
        width: 220
        height: menuColumn.implicitHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        border.color: BlurService.borderColor
        border.width: BlurService.borderWidth

        Column {
            id: menuColumn

            anchors.top: parent.top
            anchors.topMargin: Theme.spacingS
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.spacingS * 2
            spacing: 1

            Repeater {
                model: [
                    {
                        "label": I18n.tr("Set notification rules"),
                        "action": "rules"
                    },
                    {
                        "label": root.isMuted ? I18n.tr("Unmute popups for %1").arg(root.appName || I18n.tr("this app")) : I18n.tr("Mute popups for %1").arg(root.appName || I18n.tr("this app")),
                        "action": "mute"
                    },
                    {
                        "label": I18n.tr("Dismiss"),
                        "action": "dismiss"
                    }
                ]

                Rectangle {
                    id: menuRow

                    required property var modelData

                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius / 2
                    color: rowArea.containsMouse ? Theme.primaryHoverLight : Theme.withAlpha(Theme.primaryHoverLight, 0)

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        text: menuRow.modelData.label
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.triggerAction(menuRow.modelData.action)
                    }
                }
            }
        }
    }
}
