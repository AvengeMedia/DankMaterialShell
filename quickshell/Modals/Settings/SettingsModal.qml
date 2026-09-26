import QtQuick
import Quickshell
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

DankFloatingWindow {
    id: settingsModal

    property var profileBrowser: profileBrowserLoader.item
    property var wallpaperBrowser: wallpaperBrowserLoader.item

    function openProfileBrowser(allowStacking) {
        profileBrowserLoader.active = true;
        if (!profileBrowserLoader.item)
            return;
        if (allowStacking !== undefined)
            profileBrowserLoader.item.allowStacking = allowStacking;
        profileBrowserLoader.item.open();
    }

    function openWallpaperBrowser(allowStacking) {
        wallpaperBrowserLoader.active = true;
        if (!wallpaperBrowserLoader.item)
            return;
        if (allowStacking !== undefined)
            wallpaperBrowserLoader.item.allowStacking = allowStacking;
        wallpaperBrowserLoader.item.open();
    }
    property alias sidebar: sidebar
    readonly property alias modalFocusScope: contentFocusScope
    property string currentPage: "personalization"
    property var pageHistory: []
    readonly property int currentTabIndex: SettingsTabs.tabIndexForPage(currentPage)
    readonly property string currentParentId: SettingsTabs.parentOf(currentPage)
    readonly property string activeCategoryId: currentParentId || currentPage
    readonly property bool isPluginPage: SettingsTabs.isPluginPage(currentPage)
    readonly property bool canGoBack: pageHistory.length > 0 || (currentParentId !== "" && (isPluginPage || SettingsTabs.visibleLeaves(currentParentId).length > 1 || !!SettingsTabs.page(currentParentId)?.hubHeader))
    property bool shouldHaveFocus: visible
    property bool allowFocusOverride: false
    property alias shouldBeVisible: settingsModal.visible
    readonly property bool searchFocused: sidebar.searchFocused
    property bool isCompactMode: width < SettingsMetrics.compactBreakpoint
    property bool menuVisible: !isCompactMode
    property string keybindSearchQuery: ""

    signal closingModal

    function show() {
        if (visible && !backingWindowVisible) {
            visible = false;
        }
        CompositorService.closeNiriOverviewOnWindowFocus();
        visible = true;
    }

    function hide() {
        visible = false;
    }

    function toggle() {
        if (visible && backingWindowVisible) {
            hide();
            return;
        }
        show();
    }

    function setPage(pageId: string): bool {
        const resolved = SettingsTabs.resolvePage(pageId);
        if (!resolved)
            return false;
        pageHistory = [];
        currentPage = resolved;
        return true;
    }

    function navigateTo(pageId: string): bool {
        const resolved = SettingsTabs.resolvePage(pageId);
        if (!resolved || resolved === currentPage)
            return false;
        pageHistory = pageHistory.concat([currentPage]);
        currentPage = resolved;
        return true;
    }

    function setPageName(name: string): bool {
        return setPage(name);
    }

    function goBack() {
        if (pageHistory.length > 0) {
            const history = pageHistory.slice();
            const target = history.pop();
            pageHistory = history;
            currentPage = target;
            return;
        }
        if (!currentParentId)
            return;
        currentPage = currentParentId;
    }

    function setTabIndex(tabIndex: int) {
        if (tabIndex < 0)
            return;
        setPage(SettingsTabs.pageForTabIndex(tabIndex));
    }

    function showWithTab(tabIndex: int) {
        setTabIndex(tabIndex);
        show();
    }

    function showWithTabName(tabName: string) {
        setPage(tabName);
        show();
    }

    function resolveTabIndex(tabName: string): int {
        return SettingsTabs.tabIndexForPage(SettingsTabs.resolvePage(tabName));
    }

    function showKeybindsSearch(query: string) {
        keybindSearchQuery = query || "";
        showWithTabName("keybinds");
    }

    function openPluginSettings(pluginId: string) {
        if (!pluginId)
            return;
        setPage(SettingsTabs.pluginPrefix + pluginId);
        show();
    }

    function focusCurrentPage() {
        content._focusPage();
    }

    function focusSearch() {
        if (isCompactMode)
            menuVisible = true;
        Qt.callLater(sidebar.focusSearch);
    }

    function toggleMenu() {
        menuVisible = !menuVisible;
        if (menuVisible)
            Qt.callLater(sidebar.focusSearch);
    }

    objectName: "settingsModal"
    title: I18n.tr("Settings", "settings window title")
    minimumSize: Qt.size(SettingsMetrics.windowMinWidth, SettingsMetrics.windowMinHeight)
    implicitWidth: SettingsMetrics.windowWidth
    implicitHeight: screen ? Math.min(SettingsMetrics.windowHeight, screen.height - SettingsMetrics.pagePaddingH * 2 - Theme.spacingL) : SettingsMetrics.windowHeight
    visible: false

    onClosed: hide()

    onIsCompactModeChanged: {
        if (!isCompactMode)
            menuVisible = true;
    }

    onCurrentPageChanged: {
        if (isCompactMode)
            menuVisible = false;
    }

    onVisibleChanged: {
        if (!visible) {
            pageHistory = [];
            closingModal();
        } else if (!isCompactMode || menuVisible) {
            Qt.callLater(() => {
                sidebar.focusSearch();
            });
        }
    }

    Connections {
        target: PluginService

        function onPluginListUpdated() {
            if (!settingsModal.isPluginPage)
                return;
            if (PluginService.availablePluginsList.length === 0)
                return;
            if (PluginService.availablePlugins[SettingsTabs.pluginIdOf(settingsModal.currentPage)])
                return;
            settingsModal.setPage("plugins");
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

    LazyLoader {
        id: profileBrowserLoader
        active: false

        FileBrowserModal {
            id: profileBrowserItem

            allowStacking: true
            parentModal: settingsModal
            browserTitle: I18n.tr("Select Profile Image", "profile image file browser title")
            bucket: "profile"
            showHiddenFiles: true
            filters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr", "*.svg"]
            onAccepted: paths => PortalService.setProfileImage(paths[0])
            onDialogClosed: () => {
                allowStacking = true;
                Qt.callLater(() => profileBrowserLoader.active = false);
            }
        }
    }

    LazyLoader {
        id: wallpaperBrowserLoader
        active: false

        FileBrowserModal {
            id: wallpaperBrowserItem

            allowStacking: true
            parentModal: settingsModal
            browserTitle: I18n.tr("Select Wallpaper", "wallpaper file browser title")
            bucket: "wallpaper"
            showHiddenFiles: true
            filters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr", "*.svg"]
            onAccepted: paths => {
                SessionData.setWallpaper(paths[0]);
                SessionData.wallpaperCyclingFolderPath = "";
                SessionData.saveSettings();
            }
            onDialogClosed: () => {
                allowStacking = true;
                Qt.callLater(() => wallpaperBrowserLoader.active = false);
            }
        }
    }

    FocusScope {
        id: contentFocusScope

        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key !== Qt.Key_F || !(event.modifiers & Qt.ControlModifier))
                return;
            settingsModal.focusSearch();
            event.accepted = true;
        }

        Keys.onBackPressed: event => {
            settingsModal.goBack();
            event.accepted = true;
        }

        Column {
            anchors.fill: parent
            spacing: 0

            DankWindowHeader {
                id: titleBar
                width: parent.width
                z: 10
                controls: windowControls
                title: I18n.tr("Settings")
                onCloseRequested: settingsModal.hide()
            }

            Rectangle {
                id: readOnlyBanner

                property bool showBanner: (SettingsData.isReadOnly) || (SessionData._isReadOnly && SessionData._hasUnsavedChanges)

                width: parent.width
                height: showBanner ? bannerContent.implicitHeight + Theme.spacingM * 2 : 0
                color: Theme.floatingWindowNestedSurface
                border.width: Theme.layerOutlineWidth
                border.color: Theme.outlineMedium
                visible: showBanner
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: SettingsMetrics.fadeDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
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
                        width: Math.max(SettingsMetrics.bannerTextMinWidth, parent.width - (copySettingsButton.visible ? copySettingsButton.width + Theme.spacingM : 0) - (copySessionButton.visible ? copySessionButton.width + Theme.spacingM : 0) - Theme.spacingM * 2 - Theme.iconSize)
                        wrapMode: Text.WordWrap
                    }

                    DankButton {
                        id: copySettingsButton

                        visible: SettingsData.isReadOnly
                        text: "settings.json"
                        iconName: "content_copy"
                        backgroundColor: Theme.primary
                        textColor: Theme.primaryText
                        buttonHeight: Theme.buttonHeightXS
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
                        buttonHeight: Theme.buttonHeightXS
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
                id: body
                width: parent.width
                height: parent.height - titleBar.height - readOnlyBanner.height
                clip: true

                SettingsSidebar {
                    id: sidebar

                    anchors.left: parent.left
                    width: settingsModal.isCompactMode ? parent.width : sidebar.implicitWidth
                    parentModal: settingsModal
                    visible: !settingsModal.isCompactMode || settingsModal.menuVisible
                    currentPage: settingsModal.currentPage
                    activeCategoryId: settingsModal.activeCategoryId
                    onPageRequested: pageId => {
                        settingsModal.setPage(pageId);
                        if (settingsModal.isCompactMode)
                            settingsModal.menuVisible = false;
                    }
                }

                Rectangle {
                    id: contentPane
                    enabled: !settingsModal.isCompactMode || !settingsModal.menuVisible

                    x: {
                        const flip = I18n.isRtl ? -1 : 1;
                        if (settingsModal.isCompactMode)
                            return settingsModal.menuVisible ? body.width * flip : 0;
                        return I18n.isRtl ? 0 : sidebar.width;
                    }
                    width: settingsModal.isCompactMode ? body.width : body.width - sidebar.width
                    height: body.height
                    color: settingsModal.isCompactMode ? Theme.floatingWindowSurface : "transparent"
                    clip: true

                    Behavior on x {
                        enabled: settingsModal.isCompactMode && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
                        NumberAnimation {
                            duration: SettingsMetrics.transitionDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.expressiveCurves.standard
                        }
                    }

                    SettingsContent {
                        id: content

                        anchors.fill: parent
                        parentModal: settingsModal
                        currentPage: settingsModal.currentPage
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
