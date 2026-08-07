import QtQuick
import Quickshell
import qs.Common
import qs.Modals
import qs.Services
import qs.Widgets

DankFloatingWindow {
    id: win

    property alias shouldBeVisible: win.visible

    signal floatingToggleRequested

    function show() {
        visible = true;
    }

    function hide() {
        visible = false;
    }

    function toggle() {
        visible = !visible;
    }

    objectName: "keybindsModalWindow"
    title: I18n.tr("Keybinds")
    minimumSize: Qt.size(Math.min(560, Screen.width), Math.min(400, Screen.height))
    implicitWidth: 1000
    implicitHeight: screen ? Math.min(820, screen.height - 100) : 820
    visible: false

    onVisibleChanged: {
        if (!visible)
            return;
        if (!Object.keys(KeybindsService.cheatsheet).length && KeybindsService.cheatsheetAvailable)
            KeybindsService.loadCheatsheet();
        Qt.callLater(() => {
            keybindsContent.forceActiveFocus();
            keybindsContent.searchField.forceActiveFocus();
        });
    }

    onClosed: win.visible = false

    Column {
        anchors.fill: parent
        spacing: 0

        Item {
            width: parent.width
            height: 48
            z: 10

            MouseArea {
                anchors.fill: parent
                onPressed: windowControls.tryStartMove()
                onDoubleClicked: windowControls.tryToggleMaximize()
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingL
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM

                DankIcon {
                    name: "keyboard"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: KeybindsService.cheatsheet.title || I18n.tr("Keybinds")
                    font.pixelSize: Theme.fontSizeXLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                DankActionButton {
                    circular: false
                    iconName: "close_fullscreen"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    tooltipText: I18n.tr("Dock window")
                    onClicked: win.floatingToggleRequested()
                }

                DankActionButton {
                    visible: windowControls.canMaximize
                    circular: false
                    iconName: win.maximized ? "fullscreen_exit" : "fullscreen"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: windowControls.tryToggleMaximize()
                }

                DankActionButton {
                    circular: false
                    iconName: "close"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: win.hide()
                }
            }
        }

        KeybindsContent {
            id: keybindsContent
            width: parent.width
            height: parent.height - 48
            showFloatingToggle: false
            floating: true
            onCloseRequested: win.hide()
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: win
    }
}
