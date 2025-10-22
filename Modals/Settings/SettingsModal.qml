import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Modals.FileBrowser
import qs.Modules.Settings
import qs.Services
import qs.Widgets

DankModal {
    id: settingsModal

    property Component settingsContent
    property alias profileBrowser: profileBrowser
    property int currentTabIndex: 0

    signal closingModal()

    function show() {
        open();
    }

    function hide() {
        close();
    }

    function toggle() {
        if (shouldBeVisible) {
            hide();
        } else {
            show();
        }
    }

    objectName: "settingsModal"
    width: 800
    height: 800
    visible: false
    onBackgroundClicked: () => {
        return hide();
    }
    content: settingsContent
    onOpened: () => {
        Qt.callLater(() => modalFocusScope.forceActiveFocus())
    }
    modalFocusScope.Keys.onPressed: event => {
        const tabCount = 11
        if (event.key === Qt.Key_Down) {
            currentTabIndex = (currentTabIndex + 1) % tabCount
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            currentTabIndex = (currentTabIndex - 1 + tabCount) % tabCount
            event.accepted = true
        } else if (event.key === Qt.Key_Tab && !event.modifiers) {
            currentTabIndex = (currentTabIndex + 1) % tabCount
            event.accepted = true
        } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && event.modifiers & Qt.ShiftModifier)) {
            currentTabIndex = (currentTabIndex - 1 + tabCount) % tabCount
            event.accepted = true
        }
    }

    IpcHandler {
        function open(): string {
            settingsModal.show();
            return "SETTINGS_OPEN_SUCCESS";
        }

        function close(): string {
            settingsModal.hide();
            return "SETTINGS_CLOSE_SUCCESS";
        }

        function toggle(): string {
            settingsModal.toggle();
            return "SETTINGS_TOGGLE_SUCCESS";
        }

        target: "settings"
    }

    IpcHandler {
        function browse(type: string) {
            if (type === "wallpaper") {
                wallpaperBrowser.allowStacking = false;
                wallpaperBrowser.open();
            } else if (type === "profile") {
                profileBrowser.allowStacking = false;
                profileBrowser.open();
            }
        }

        target: "file"
    }

    FileBrowserModal {
        id: profileBrowser

        allowStacking: true
        parentModal: settingsModal
        browserTitle: "Select Profile Image"
        browserIcon: "person"
        browserType: "profile"
        showHiddenFiles: true
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        onFileSelected: (path) => {
            PortalService.setProfileImage(path);
            close();
        }
        onDialogClosed: () => {
            allowStacking = true;
        }
    }

    FileBrowserModal {
        id: wallpaperBrowser

        allowStacking: true
        parentModal: settingsModal
        browserTitle: "Select Wallpaper"
        browserIcon: "wallpaper"
        browserType: "wallpaper"
        showHiddenFiles: true
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        onFileSelected: (path) => {
            SessionData.setWallpaper(path);
            close();
        }
        onDialogClosed: () => {
            allowStacking = true;
        }
    }

    settingsContent: Component {
        Item {
            id: rootScope
            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                anchors.topMargin: Theme.spacingM
                anchors.bottomMargin: Theme.spacingL
                spacing: 0

                Item {
                    width: parent.width
                    height: 35

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "settings"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Settings")
                            font.pixelSize: Theme.fontSizeXLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                    DankActionButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        circular: false
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: () => {
                            return settingsModal.hide();
                        }
                    }

                }

                Row {
                    width: parent.width
                    height: parent.height - 35
                    spacing: 0

                    SettingsSidebar {
                        id: sidebar

                        parentModal: settingsModal
                        currentIndex: settingsModal.currentTabIndex
                        onCurrentIndexChanged: {
                            settingsModal.currentTabIndex = currentIndex
                        }
                    }

                    SettingsContent {
                        id: content

                        width: parent.width - sidebar.width
                        height: parent.height
                        parentModal: settingsModal
                        currentIndex: settingsModal.currentTabIndex
                    }

                }

            }

        }

    }

}
