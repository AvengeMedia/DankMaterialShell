import QtQuick
import Quickshell
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

FloatingWindow {
    id: settingsModal

    property alias profileBrowser: profileBrowser
    property alias wallpaperBrowser: wallpaperBrowser
    property alias sidebar: sidebar
    property int currentTabIndex: 0
    property bool shouldHaveFocus: visible
    property bool allowFocusOverride: false
    property alias shouldBeVisible: settingsModal.visible
    property bool isCompactMode: width < 700
    property bool menuVisible: !isCompactMode
    property bool enableAnimations: true

    signal closingModal

    function show() {
        visible = true;
    }

    function hide() {
        visible = false;
    }

    function toggle() {
        visible = !visible;
    }

    function showWithTab(tabIndex: int) {
        if (tabIndex >= 0)
            currentTabIndex = tabIndex;
        visible = true;
    }

    function showWithTabName(tabName: string) {
        var idx = sidebar.resolveTabIndex(tabName);
        if (idx >= 0)
            currentTabIndex = idx;
        visible = true;
    }

    function resolveTabIndex(tabName: string): int {
        return sidebar.resolveTabIndex(tabName);
    }

    function toggleMenu() {
        enableAnimations = true;
        menuVisible = !menuVisible;
    }

    objectName: "settingsModal"
    title: I18n.tr("Settings", "settings window title")
    minimumSize: Qt.size(500, 400)
    implicitWidth: 800
    implicitHeight: 940
    color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    visible: false

    onIsCompactModeChanged: {
        enableAnimations = false;
        if (!isCompactMode) {
            menuVisible = true;
        }
        Qt.callLater(() => {
            enableAnimations = true;
        });
    }

    onVisibleChanged: {
        if (!visible) {
            closingModal();
        } else {
            Qt.callLater(() => {
                if (contentFocusScope) {
                    contentFocusScope.forceActiveFocus();
                }
            });
        }
    }

    Loader {
        active: settingsModal.visible
        sourceComponent: Component {
            Ref {
                service: CupsService
            }
        }
    }

    FileBrowserModal {
        id: profileBrowser

        allowStacking: true
        parentModal: settingsModal
        browserTitle: I18n.tr("Select Profile Image", "profile image file browser title")
        browserIcon: "person"
        browserType: "profile"
        showHiddenFiles: true
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        onFileSelected: path => {
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
        browserTitle: I18n.tr("Select Wallpaper", "wallpaper file browser title")
        browserIcon: "wallpaper"
        browserType: "wallpaper"
        showHiddenFiles: true
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        onFileSelected: path => {
            SessionData.setWallpaper(path);
            close();
        }
        onDialogClosed: () => {
            allowStacking = true;
        }
    }

    FocusScope {
        id: contentFocusScope

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                hide();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !event.modifiers)) {
                sidebar.navigateNext();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && event.modifiers & Qt.ShiftModifier)) {
                sidebar.navigatePrevious();
                event.accepted = true;
                return;
            }
        }

        Column {
            anchors.fill: parent
            spacing: 0

            Item {
                width: parent.width
                height: 48
                z: 10

                Rectangle {
                    anchors.fill: parent
                    color: Theme.surfaceContainer
                    opacity: 0.5
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingL
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    DankActionButton {
                        visible: settingsModal.isCompactMode
                        circular: false
                        iconName: "menu"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: () => {
                            settingsModal.toggleMenu();
                        }
                    }

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
                    anchors.rightMargin: Theme.spacingM
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    circular: false
                    iconName: "close"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: () => {
                        settingsModal.hide();
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - 48
                clip: true

                SettingsSidebar {
                    id: sidebar

                    x: 0
                    width: settingsModal.isCompactMode ? parent.width : 270
                    visible: settingsModal.isCompactMode ? settingsModal.menuVisible : true
                    parentModal: settingsModal
                    currentIndex: settingsModal.currentTabIndex
                    onCurrentIndexChanged: {
                        settingsModal.currentTabIndex = currentIndex;
                        if (settingsModal.isCompactMode) {
                            settingsModal.enableAnimations = true;
                            settingsModal.menuVisible = false;
                        }
                    }
                }

                Item {
                    x: settingsModal.isCompactMode ? (settingsModal.menuVisible ? parent.width : 0) : sidebar.width
                    width: settingsModal.isCompactMode ? parent.width : parent.width - sidebar.width
                    height: parent.height
                    clip: true

                    SettingsContent {
                        id: content

                        anchors.fill: parent
                        parentModal: settingsModal
                        currentIndex: settingsModal.currentTabIndex
                    }

                    Behavior on x {
                        enabled: settingsModal.enableAnimations
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                        }
                    }
                }
            }
        }
    }
}
