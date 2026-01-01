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
    implicitWidth: 900
    implicitHeight: screen ? Math.min(940, screen.height - 100) : 940
    color: Theme.surfaceContainer
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
                sidebar.focusSearch();
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

        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        anchors.fill: parent
        focus: true

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

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    spacing: Theme.spacingXS

                    DankActionButton {
                        visible: windowControls.supported
                        circular: false
                        iconName: settingsModal.maximized ? "fullscreen_exit" : "fullscreen"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: windowControls.tryToggleMaximize()
                    }

                    DankActionButton {
                        circular: false
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: settingsModal.hide()
                    }
                }
            }

            Rectangle {
                id: readOnlyBanner

                property bool showBanner: (SettingsData._isReadOnly && SettingsData._hasUnsavedChanges) || (SessionData._isReadOnly && SessionData._hasUnsavedChanges)

                width: parent.width
                height: showBanner ? bannerContent.implicitHeight + Theme.spacingM * 2 : 0
                color: Theme.surfaceContainerHigh
                visible: showBanner
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Row {
                    id: bannerContent

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingM
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "info"
                        size: Theme.iconSize
                        color: Theme.warning
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        id: bannerText

                        text: I18n.tr("Settings are read-only. Changes will not persist.", "read-only settings warning for NixOS home-manager users")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(100, parent.width - (copySettingsButton.visible ? copySettingsButton.width + Theme.spacingM : 0) - (copySessionButton.visible ? copySessionButton.width + Theme.spacingM : 0) - Theme.spacingM * 2 - Theme.iconSize)
                        wrapMode: Text.WordWrap
                    }

                    DankButton {
                        id: copySettingsButton

                        visible: SettingsData._isReadOnly && SettingsData._hasUnsavedChanges
                        text: "settings.json"
                        iconName: "content_copy"
                        backgroundColor: Theme.primary
                        textColor: Theme.primaryText
                        buttonHeight: 32
                        horizontalPadding: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            Quickshell.execDetached(["dms", "cl", "copy", SettingsData.getCurrentSettingsJson()]);
                            ToastService.showInfo(I18n.tr("Copied to clipboard"));
                        }
                    }

                    DankButton {
                        id: copySessionButton

                        visible: SessionData._isReadOnly && SessionData._hasUnsavedChanges
                        text: "session.json"
                        iconName: "content_copy"
                        backgroundColor: Theme.primary
                        textColor: Theme.primaryText
                        buttonHeight: 32
                        horizontalPadding: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            Quickshell.execDetached(["dms", "cl", "copy", SessionData.getCurrentSessionJson()]);
                            ToastService.showInfo(I18n.tr("Copied to clipboard"));
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - 48 - readOnlyBanner.height
                clip: true

                SettingsSidebar {
                    id: sidebar

                    anchors.left: parent.left
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
                    anchors.left: settingsModal.isCompactMode ? (settingsModal.menuVisible ? sidebar.right : parent.left) : sidebar.right
                    anchors.right: parent.right
                    height: parent.height
                    clip: true

                    SettingsContent {
                        id: content

                        anchors.fill: parent
                        parentModal: settingsModal
                        currentIndex: settingsModal.currentTabIndex
                    }
                }
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: settingsModal
    }
}
