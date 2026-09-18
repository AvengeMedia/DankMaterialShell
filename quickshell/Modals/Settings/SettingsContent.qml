import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Services
import qs.Widgets

FocusScope {
    id: root

    Connections {
        target: root.parentModal
        function onShouldBeVisibleChanged() {
            if (root.parentModal.shouldBeVisible)
                return;
            widgetsLoader.loadedOnce = false;
            windowRulesLoader.loadedOnce = false;
        }
    }

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string currentPage: ""
    property var parentModal: null
    property string _loadedPage: ""
    property int _frontIndex: 0

    readonly property var pageInfo: SettingsTabs.page(currentPage)
    readonly property bool isPluginPage: SettingsTabs.isPluginPage(currentPage)
    readonly property bool isHubPage: pageInfo?.kind === "hub"
    readonly property bool isCompactMode: parentModal?.isCompactMode ?? false
    readonly property bool menuHidden: isCompactMode && !(parentModal?.menuVisible ?? true)
    readonly property bool showBack: (parentModal?.canGoBack ?? false) || isPluginPage || menuHidden
    readonly property string pageTitle: (pageInfo?.titleFrom ? SettingsUiState[pageInfo.titleFrom] : "") || (pageInfo?.text ?? "")
    readonly property real pageContentMaxWidth: (currentPage === "window_rules" ? windowRulesLoader.item?.contentMaxWidth : _front().item?.contentMaxWidth) ?? SettingsMetrics.contentMaxWidth
    readonly property bool animationsEnabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None

    focus: true

    function _focusPage() {
        Qt.callLater(() => {
            let loader = _front();
            switch (currentPage) {
            case "dankbar_widgets":
                loader = widgetsLoader;
                break;
            case "window_rules":
                loader = windowRulesLoader;
                break;
            }
            if (!loader.item || !loader.visible)
                return;
            loader.item.forceActiveFocus();
        });
    }

    function _front() {
        return _frontIndex === 0 ? loaderA : loaderB;
    }

    function _back() {
        return _frontIndex === 0 ? loaderB : loaderA;
    }

    function _fileFor(page) {
        if (SettingsTabs.isPluginPage(page))
            return "PluginSettingsPage.qml";
        if (SettingsTabs.page(page)?.kind === "hub")
            return "SettingsHubPage.qml";
        return pageFiles[page] ?? "";
    }

    function _propertiesFor(page) {
        if (SettingsTabs.isPluginPage(page))
            return {
                "parentModal": Qt.binding(() => root.parentModal),
                "pluginId": SettingsTabs.pluginIdOf(page)
            };
        if (SettingsTabs.page(page)?.kind === "hub")
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

    function _direction(from, to) {
        if (!from || !to)
            return "switch";
        if (SettingsTabs.parentOf(to) === from)
            return "forward";
        if (SettingsTabs.parentOf(from) === to)
            return "back";
        return "switch";
    }

    function _showPage(page) {
        if (page === _loadedPage)
            return;
        const outgoing = _front();
        const incoming = _back();
        _loadedPage = page;
        incoming.stopMotion();
        outgoing.stopMotion();
        incoming.source = "";
        incoming.page = page;
        incoming.direction = _direction(outgoing.page, page);
        _frontIndex = 1 - _frontIndex;
        if (keepAlivePages[page]) {
            outgoing.source = "";
            return;
        }
        const file = _fileFor(page);
        if (!file)
            return;
        incoming.setSource(Qt.resolvedUrl("../../Modules/Settings/" + file), _propertiesFor(page));
    }

    function _presentPage(incoming) {
        if (_front() !== incoming)
            return;
        const outgoing = _back();
        _focusPage();
        if (!animationsEnabled || outgoing.source.toString() === "") {
            incoming.z = 1;
            outgoing.z = 0;
            incoming.snap(0, 1);
            outgoing.source = "";
            return;
        }
        const offscreen = I18n.isRtl ? -width : width;
        switch (incoming.direction) {
        case "forward":
            incoming.z = 1;
            outgoing.z = 0;
            incoming.slide(offscreen, 0, 1, 1);
            outgoing.fade(1, 1);
            break;
        case "back":
            incoming.z = 0;
            outgoing.z = 1;
            incoming.snap(0, 1);
            outgoing.slide(0, offscreen, 1, 1);
            break;
        default:
            incoming.z = 1;
            outgoing.z = 0;
            incoming.slide(0, 0, 0, 1);
            outgoing.fade(1, 0);
            break;
        }
    }

    onCurrentPageChanged: _showPage(currentPage)
    Component.onCompleted: _showPage(currentPage)

    component PageHost: Loader {
        id: host

        property string page: ""
        property string direction: "switch"

        function stopMotion() {
            xAnim.stop();
            fadeAnim.stop();
            if (root._front() !== host)
                source = "";
        }

        function unloadIfIdle() {
            if (xAnim.running || fadeAnim.running || root._front() === host)
                return;
            source = "";
        }

        function snap(toX, toOpacity) {
            x = toX;
            opacity = toOpacity;
        }

        function slide(fromX, toX, fromOpacity, toOpacity) {
            x = fromX;
            opacity = fromOpacity;
            xAnim.from = fromX;
            xAnim.to = toX;
            fadeAnim.from = fromOpacity;
            fadeAnim.to = toOpacity;
            xAnim.restart();
            fadeAnim.restart();
        }

        function fade(fromOpacity, toOpacity) {
            opacity = fromOpacity;
            fadeAnim.from = fromOpacity;
            fadeAnim.to = toOpacity;
            fadeAnim.restart();
        }

        width: parent.width
        height: parent.height
        visible: status === Loader.Ready
        enabled: root._front() === host && page === root.currentPage
        focus: visible && enabled

        onLoaded: root._presentPage(host)

        NumberAnimation {
            id: xAnim
            target: host
            property: "x"
            duration: SettingsMetrics.transitionDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.standard
            onFinished: host.unloadIfIdle()
        }

        NumberAnimation {
            id: fadeAnim
            target: host
            property: "opacity"
            duration: SettingsMetrics.fadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            onFinished: host.unloadIfIdle()
        }
    }

    readonly property var pageFiles: ({
            "wallpaper_cycling": "WallpaperCyclingTab.qml",
            "theme_schedule": "ThemeScheduleTab.qml",
            "surface_shadows": "ShadowsTab.qml",
            "time_weather": "TimeWeatherTab.qml",
            "weather": "WeatherSettingsTab.qml",
            "keybinds": "KeybindsTab.qml",
            "dankbar_settings": "DankBarTab.qml",
            "dankbar_appearance": "DankBarAppearanceTab.qml",
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
            "audio": "AudioTab.qml",
            "locale": "LocaleTab.qml",
            "multiplexers": "MuxTab.qml",
            "frame": "FrameTab.qml",
            "dank_island": "DankIslandTab.qml",
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

    readonly property var pagesWithParentModal: ["display_config", "users", "time_weather", "weather", "lock_screen", "greeter", "dank_dash", "wallpaper_cycling", "theme_schedule", "surface_shadows", "keybinds", "dankbar_settings", "dankbar_appearance", "bar_widget", "dock_general", "dock_widgets", "dock_appearance", "dock_advanced", "launcher", "theme", "theme_apps", "media_player", "desktop_widgets", "dank_island", "autostart", "compositor_layout"]

    readonly property var keepAlivePages: ({
            "dankbar_widgets": true,
            "window_rules": true
        })

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
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.showBack ? Theme.iconButtonSize + Theme.spacingL : 0
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

        Item {
            id: pageStack
            width: parent.width
            height: parent.height - pageHeader.height
            clip: true

            PageHost {
                id: loaderA
            }

            PageHost {
                id: loaderB
            }

            DankSpinner {
                anchors.centerIn: parent
                visible: root._front().status === Loader.Loading
            }

            Loader {
                id: widgetsLoader

                property bool loadedOnce: false

                anchors.fill: parent
                active: (root.currentPage === "dankbar_widgets" || loadedOnce) && root.parentModal?.shouldBeVisible === true
                opacity: root.currentPage === "dankbar_widgets" && status === Loader.Ready ? 1 : 0
                visible: opacity > 0
                focus: visible
                asynchronous: true

                Behavior on opacity {
                    enabled: root.animationsEnabled
                    NumberAnimation {
                        duration: SettingsMetrics.fadeDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                    }
                }

                source: active ? Qt.resolvedUrl("../../Modules/Settings/WidgetsTab.qml") : ""

                onLoaded: {
                    item.parentModal = Qt.binding(() => root.parentModal);
                    loadedOnce = true;
                    if (visible && item)
                        Qt.callLater(() => item.forceActiveFocus());
                }
                onVisibleChanged: {
                    if (visible && item)
                        Qt.callLater(() => item.forceActiveFocus());
                }
            }

            DankSpinner {
                anchors.centerIn: parent
                visible: root.currentPage === "dankbar_widgets" && widgetsLoader.status === Loader.Loading
            }

            Loader {
                id: windowRulesLoader

                property bool loadedOnce: false

                anchors.fill: parent
                active: (root.currentPage === "window_rules" || loadedOnce) && root.parentModal?.shouldBeVisible === true
                opacity: root.currentPage === "window_rules" && status === Loader.Ready ? 1 : 0
                visible: opacity > 0
                focus: visible
                asynchronous: true

                Behavior on opacity {
                    enabled: root.animationsEnabled
                    NumberAnimation {
                        duration: SettingsMetrics.fadeDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                    }
                }

                source: active ? Qt.resolvedUrl("../../Modules/Settings/WindowRulesTab.qml") : ""

                onLoaded: {
                    item.pageActive = Qt.binding(() => root.currentPage === "window_rules");
                    loadedOnce = true;
                    if (visible && item)
                        Qt.callLater(() => item.forceActiveFocus());
                }
                onVisibleChanged: {
                    if (visible && item)
                        Qt.callLater(() => item.forceActiveFocus());
                }
            }

            DankSpinner {
                anchors.centerIn: parent
                visible: root.currentPage === "window_rules" && windowRulesLoader.status === Loader.Loading
            }
        }
    }
}
