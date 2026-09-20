import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Services
import qs.Widgets

FocusScope {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string currentPage: ""
    property var parentModal: null

    readonly property bool sessionVisible: parentModal?.shouldBeVisible ?? false
    readonly property list<string> pagePath: (parentModal?.pageHistory ?? []).concat([currentPage])
    readonly property Item currentPageItem: pageStack.currentItem?.item ?? null
    readonly property var pageInfo: SettingsTabs.page(currentPage)
    readonly property bool isPluginPage: SettingsTabs.isPluginPage(currentPage)
    readonly property bool isHubPage: pageInfo?.kind === "hub"
    readonly property bool isCompactMode: parentModal?.isCompactMode ?? false
    readonly property bool menuHidden: isCompactMode && !(parentModal?.menuVisible ?? true)
    readonly property bool showBack: (parentModal?.canGoBack ?? false) || isPluginPage || menuHidden
    readonly property string pageTitle: (pageInfo?.titleFrom ? SettingsUiState[pageInfo.titleFrom] : "") || (pageInfo?.text ?? "")
    readonly property real pageContentMaxWidth: currentPageItem?.contentMaxWidth ?? SettingsMetrics.contentMaxWidth
    readonly property bool animationsEnabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None

    focus: true

    function _focusPage() {
        Qt.callLater(() => {
            if (!sessionVisible || !currentPageItem || parentModal?.searchFocused)
                return;
            currentPageItem.forceActiveFocus();
        });
    }

    function _fileFor(page) {
        if (pageFiles[page])
            return pageFiles[page];
        if (SettingsTabs.isPluginPage(page))
            return "PluginSettingsPage.qml";
        if (SettingsTabs.page(page)?.kind === "hub")
            return "SettingsHubPage.qml";
        return "";
    }

    function _propertiesFor(page) {
        if (SettingsTabs.isPluginPage(page))
            return {
                "parentModal": Qt.binding(() => root.parentModal),
                "pluginId": SettingsTabs.pluginIdOf(page)
            };
        if (!pageFiles[page] && SettingsTabs.page(page)?.kind === "hub")
            return {
                "parentModal": Qt.binding(() => root.parentModal),
                "hubId": page
            };
        const properties = {};
        if (pagesWithParentModal.includes(page))
            properties.parentModal = Qt.binding(() => root.parentModal);
        if (page === "keybinds")
            properties.requestedSearchQuery = Qt.binding(() => root.parentModal?.keybindSearchQuery ?? "");
        return properties;
    }

    function _syncPages() {
        if (!sessionVisible) {
            pageStack.clear(StackView.Immediate);
            return;
        }
        if (!currentPage)
            return;
        let shared = 0;
        while (shared < Math.min(pageStack.depth, pagePath.length) && pageStack.get(shared).page === pagePath[shared])
            shared++;
        if (shared === pagePath.length) {
            if (shared < pageStack.depth)
                pageStack.pop(pageStack.get(shared - 1), animationsEnabled ? StackView.PopTransition : StackView.Immediate);
            return;
        }
        const drillDown = animationsEnabled && shared > 0 && shared === pageStack.depth && shared === pagePath.length - 1;
        let index = shared;
        if (index < pageStack.depth)
            pageStack.replace(pageStack.get(index), pageComponent, {
                page: pagePath[index++]
            }, StackView.Immediate);
        for (; index < pagePath.length; index++)
            pageStack.push(pageComponent, {
                page: pagePath[index]
            }, drillDown ? StackView.PushTransition : StackView.Immediate);
    }

    onPagePathChanged: Qt.callLater(_syncPages)
    onSessionVisibleChanged: Qt.callLater(_syncPages)

    component Slide: Transition {
        id: slide

        property real fromX: 0
        property real toX: 0

        NumberAnimation {
            property: "x"
            from: slide.fromX
            to: slide.toX
            duration: SettingsMetrics.transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.standard
        }
    }

    Component {
        id: pageComponent

        // StackView writes visible and opacity on the element it manages, so the presentation gate lives on the inner Loader
        Item {
            id: host

            required property string page
            readonly property bool pageActive: root.sessionVisible && pageStack.currentItem === host
            readonly property alias item: loader.item
            readonly property int status: loader.status

            property bool presented: false

            enabled: pageActive

            Loader {
                id: loader

                anchors.fill: parent
                asynchronous: true
                opacity: host.presented ? 1 : 0

                Component.onCompleted: {
                    const file = root._fileFor(host.page);
                    if (file)
                        setSource(Qt.resolvedUrl("../../Modules/Settings/" + file), root._propertiesFor(host.page));
                }
                onLoaded: {
                    if (item.pageActive !== undefined)
                        item.pageActive = Qt.binding(() => host.pageActive);
                    root._focusPage();
                }
            }

            FrameAnimation {
                id: settleWatch

                property real lastHeight: -1
                property int stableFrames: 0

                running: loader.status === Loader.Ready && !host.presented
                onTriggered: {
                    if (loader.item?.settling) {
                        stableFrames = 0;
                        return;
                    }
                    const h = loader.item?.contentHeight ?? loader.item?.height ?? 0;
                    if (h === lastHeight)
                        stableFrames++;
                    else {
                        lastHeight = h;
                        stableFrames = 0;
                    }
                    if (stableFrames < SettingsMetrics.pageSettleFrames && elapsedTime * 1000 < SettingsMetrics.pageSettleDeadline)
                        return;
                    host.presented = true;
                }
            }

            onPageActiveChanged: {
                if (pageActive)
                    root._focusPage();
            }
        }
    }

    readonly property var pageFiles: ({
            "wallpaper_cycling": "WallpaperCyclingTab.qml",
            "theme_schedule": "ThemeScheduleTab.qml",
            "surface_shadows": "ShadowsTab.qml",
            "time_weather": "TimeWeatherTab.qml",
            "weather": "WeatherSettingsTab.qml",
            "keybinds": "KeybindsTab.qml",
            "dankbar_widgets": "WidgetsTab.qml",
            "window_rules": "WindowRulesTab.qml",
            "dankbar_settings": "DankBarTab.qml",
            "dankbar_appearance": "DankBarAppearanceTab.qml",
            "dankbar_dot": "DankDotTab.qml",
            "bar_widget": "BarWidgetTab.qml",
            "compositor_layout": "CompositorLayoutTab.qml",
            "dock_general": "DockGeneralTab.qml",
            "dock_widgets": "DockWidgetsTab.qml",
            "dock_appearance": "DockAppearanceTab.qml",
            "dock_advanced": "DockAdvancedTab.qml",
            "display_config": "DisplayConfigTab.qml",
            "display_gamma": "GammaControlTab.qml",
            "display_widgets": "DisplayWidgetsTab.qml",
            "network_status": "NetworkStatusTab.qml",
            "network_ethernet": "NetworkEthernetTab.qml",
            "network_wifi": "NetworkWifiTab.qml",
            "network_vpn": "NetworkVpnTab.qml",
            "network_cellular": "NetworkCellularTab.qml",
            "printers": "PrinterTab.qml",
            "launcher": "LauncherTab.qml",
            "theme": "ThemeColorsTab.qml",
            "theme_apps": "ThemeAppsTab.qml",
            "palette_inject": "PaletteInjectTab.qml",
            "lock_screen": "LockScreenTab.qml",
            "greeter": "GreeterTab.qml",
            "about": "AboutTab.qml",
            "typography": "TypographyMotionTab.qml",
            "sounds": "SoundsTab.qml",
            "media_player": "MediaPlayerTab.qml",
            "notification_rules": "NotificationRulesTab.qml",
            "osd": "OSDTab.qml",
            "default_apps": "DefaultAppsTab.qml",
            "running_apps": "RunningAppsTab.qml",
            "updater": "SystemUpdaterTab.qml",
            "power_sleep": "PowerSleepTab.qml",
            "clipboard": "ClipboardTab.qml",
            "desktop_widgets": "DesktopWidgetsTab.qml",
            "desktop_widget": "DesktopWidgetTab.qml",
            "audio": "AudioTab.qml",
            "locale": "LocaleTab.qml",
            "multiplexers": "MuxTab.qml",
            "users": "UsersTab.qml",
            "user_create": "CreateUserTab.qml",
            "greeter_auth": "GreeterAuthTab.qml",
            "autostart": "AutoStartTab.qml",
            "battery": "BatteryTab.qml",
            "dank_dash": "DankDashTab.qml",
            "mouse_touchpad": "MouseTouchpadTab.qml",
            "keyboard": "KeyboardTab.qml",
            "plugins_manage": "PluginsManageTab.qml"
        })

    readonly property var pagesWithParentModal: ["dankbar_widgets", "window_rules", "display_config", "users", "time_weather", "weather", "lock_screen", "greeter", "dank_dash", "wallpaper_cycling", "theme_schedule", "surface_shadows", "keybinds", "dankbar_settings", "dankbar_appearance", "bar_widget", "dock_general", "dock_widgets", "dock_appearance", "dock_advanced", "launcher", "theme", "theme_apps", "media_player", "desktop_widgets", "autostart", "compositor_layout"]

    Column {
        anchors.fill: parent
        anchors.leftMargin: root.isCompactMode ? Theme.spacingS : SettingsMetrics.scrollGutter
        anchors.rightMargin: root.isCompactMode ? Theme.spacingS : SettingsMetrics.scrollGutter
        spacing: 0

        Item {
            id: pageHeader
            width: Math.min(root.pageContentMaxWidth, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            height: Math.max(SettingsMetrics.pageHeaderHeight, pageHeading.implicitHeight + Theme.spacingM * 2)

            Item {
                id: backSlot

                readonly property real glyphInset: (Theme.iconButtonSize - Theme.iconSize) / 2

                anchors.left: parent.left
                anchors.leftMargin: root.showBack ? -glyphInset : 0
                anchors.verticalCenter: parent.verticalCenter
                width: root.showBack ? Theme.iconButtonSize + Theme.spacingM - glyphInset : 0
                height: Theme.iconButtonSize

                DankActionButton {
                    buttonSize: Theme.iconButtonSize
                    iconName: I18n.isRtl ? "arrow_forward" : "arrow_back"
                    Accessible.name: I18n.tr("Back")
                    iconSize: Theme.iconSize
                    iconColor: Theme.surfaceText
                    visible: root.showBack
                    onClicked: {
                        if (root.menuHidden && !(root.parentModal?.canGoBack ?? false)) {
                            root.parentModal.toggleMenu();
                            return;
                        }
                        root.parentModal?.goBack();
                    }
                }
            }

            StyledText {
                id: pageHeading
                anchors.left: backSlot.right
                anchors.right: parent.right
                wrapMode: Text.WordWrap
                anchors.verticalCenter: parent.verticalCenter
                text: root.pageTitle
                font.pixelSize: Theme.fontSizeXXLarge
                color: Theme.surfaceText
                visible: root.pageTitle !== ""
            }
        }

        StackView {
            id: pageStack
            width: parent.width
            height: parent.height - pageHeader.height
            clip: true

            readonly property real slideOffscreen: I18n.isRtl ? -width : width

            pushEnter: Slide {
                fromX: pageStack.slideOffscreen
            }
            pushExit: Slide {
                toX: -pageStack.slideOffscreen
            }
            popEnter: Slide {
                fromX: -pageStack.slideOffscreen
            }
            popExit: Slide {
                toX: pageStack.slideOffscreen
            }

            DankSpinner {
                id: pageSpinner

                readonly property bool loading: pageStack.currentItem?.presented === false

                anchors.centerIn: parent
                visible: false
                onLoadingChanged: {
                    if (!loading) {
                        spinnerDelay.stop();
                        visible = false;
                        return;
                    }
                    spinnerDelay.restart();
                }

                Timer {
                    id: spinnerDelay
                    interval: SettingsMetrics.pageSettleDeadline + SettingsMetrics.fadeDuration
                    onTriggered: pageSpinner.visible = pageSpinner.loading
                }
            }
        }
    }
}
