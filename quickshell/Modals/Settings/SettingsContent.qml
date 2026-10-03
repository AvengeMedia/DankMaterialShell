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
    readonly property bool currentPageSettled: pageStack.currentItem?.settled ?? false
    readonly property var pageInfo: SettingsTabs.page(currentPage)
    readonly property bool isPluginPage: SettingsTabs.isPluginPage(currentPage)
    readonly property bool isHubPage: pageInfo?.kind === "hub"
    readonly property bool isCompactMode: parentModal?.isCompactMode ?? false
    readonly property bool menuHidden: isCompactMode && !(parentModal?.menuVisible ?? true)
    readonly property bool showBack: (parentModal?.canGoBack ?? false) || isPluginPage || menuHidden
    readonly property string pageTitle: (pageInfo?.titleFrom ? SettingsUiState[pageInfo.titleFrom] : "") || (pageInfo?.text ?? "")
    readonly property real pageContentMaxWidth: currentPageItem?.contentMaxWidth ?? SettingsMetrics.contentMaxWidth
    readonly property bool animationsEnabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
    // Mouse navigation lands parked; only keyboard navigation highlights a control on the page
    property bool keyboardNavigation: true

    focus: true

    function rememberFocus() {
        const item = Window.activeFocusItem;
        if (pageStack.currentItem && item !== currentPageItem && _contains(currentPageItem, item))
            pageStack.currentItem.rememberedFocus = item;
    }

    function _validRemembered() {
        const remembered = pageStack.currentItem?.rememberedFocus;
        return remembered?.visible && remembered.enabled && _contains(currentPageItem, remembered) ? remembered : null;
    }

    function _focusPage() {
        const revision = parentModal?.modalFocusScope?.focusRevision;
        Qt.callLater(() => {
            if (revision !== parentModal?.modalFocusScope?.focusRevision)
                return;
            if (parentModal?.modalFocusScope?.transientOwnsFocus())
                return;
            if (!sessionVisible || !currentPageItem || !pageStack.currentItem.presented)
                return;
            if (parentModal?.focusPane === "sidebar")
                return;
            if (!keyboardNavigation) {
                if (!_contains(currentPageItem, Window.activeFocusItem))
                    parkFocus();
                return;
            }
            const remembered = _validRemembered();
            if (remembered) {
                remembered.forceActiveFocus(Qt.TabFocusReason);
                _reveal(remembered);
                return;
            }
            let item = currentPageItem;
            do {
                item = item.nextItemInFocusChain(true);
                if (!item || item === currentPageItem || !_contains(currentPageItem, item)) {
                    currentPageItem.forceActiveFocus(Qt.TabFocusReason);
                    return;
                }
            } while (!item.visible || !item.enabled || !_inViewport(item))
            item.forceActiveFocus(Qt.TabFocusReason);
        });
    }

    function goBack(keyboard) {
        if (!showBack)
            return false;
        if (menuHidden && !(parentModal?.canGoBack ?? false)) {
            parentModal.toggleMenu();
            return true;
        }
        parentModal?.goBack(keyboard);
        return true;
    }

    function _contains(ancestor, item) {
        for (let p = item; p; p = p.parent) {
            if (p === ancestor)
                return true;
        }
        return false;
    }

    // Parked focus highlights nothing until a key resumes from rememberedFocus
    function parkFocus() {
        focusAnchor.forceActiveFocus(Qt.MouseFocusReason);
    }

    Item {
        id: focusAnchor
    }

    function _moveFocus(forward) {
        const page = currentPageItem;
        let start = Window.activeFocusItem;
        if (!page || (start !== focusAnchor && !_contains(page, start)))
            return false;
        if (start === focusAnchor) {
            const remembered = _validRemembered();
            if (remembered) {
                remembered.forceActiveFocus(Qt.TabFocusReason);
                _reveal(remembered);
                return true;
            }
            start = page;
        }
        let item = start;
        do {
            item = item.nextItemInFocusChain(forward);
            if (!item || item === start || !_contains(page, item))
                return false;
        } while (!item.visible || !item.enabled)
        item.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
        _reveal(item);
        return true;
    }

    function _inViewport(item) {
        for (let f = item.parent; f; f = f.parent) {
            if (typeof f.flick !== "function")
                continue;
            const y = item.mapToItem(f.contentItem, 0, 0).y;
            const top = Math.max(f.originY, y - Theme.spacingL);
            const bottom = Math.min(f.originY + f.contentHeight, y + item.height + Theme.spacingL);
            if (top < f.contentY || bottom > f.contentY + f.height)
                return false;
        }
        return true;
    }

    function _reveal(item) {
        for (let f = item.parent; f; f = f.parent) {
            if (typeof f.flick !== "function" || f.contentHeight <= f.height)
                continue;
            const top = item.mapToItem(f.contentItem, 0, 0).y - Theme.spacingL;
            const bottom = top + item.height + Theme.spacingL * 2;
            if (top < f.contentY)
                f.contentY = Math.max(f.originY, top);
            else if (bottom > f.contentY + f.height)
                f.contentY = Math.min(f.originY + f.contentHeight - f.height, bottom - f.height);
            return;
        }
    }

    // Keys bubble up from the focused control, so a control that uses an arrow itself (text, lists, open menus) keeps it
    Keys.onPressed: event => {
        const mods = event.modifiers & ~Qt.KeypadModifier;
        const backKey = I18n.isRtl ? Qt.Key_Right : Qt.Key_Left;
        if ((event.key === Qt.Key_Up || event.key === Qt.Key_Down) && mods === Qt.NoModifier) {
            event.accepted = _moveFocus(event.key === Qt.Key_Down);
            return;
        }
        if ((event.key === backKey && mods === Qt.AltModifier) || (event.key === Qt.Key_Backspace && mods === Qt.NoModifier)) {
            event.accepted = goBack(true);
            return;
        }
        if (event.key !== Qt.Key_Escape || mods !== Qt.NoModifier)
            return;
        const focused = Window.activeFocusItem;
        if (focused && focused !== currentPageItem && focused.cursorPosition !== undefined)
            currentPageItem?.forceActiveFocus();
        else if (!goBack(true))
            parentModal?.focusSidebar();
        event.accepted = true;
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
        const deferred = parentModal?.visible ?? false;
        let index = shared;
        if (index < pageStack.depth)
            pageStack.replace(pageStack.get(index), pageComponent, {
                page: pagePath[index++]
            }, StackView.Immediate).load(deferred);
        for (; index < pagePath.length; index++)
            pageStack.push(pageComponent, {
                page: pagePath[index]
            }, drillDown ? StackView.PushTransition : StackView.Immediate).load(deferred);
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

    function _scrollerOf(item) {
        if (typeof item.flick === "function")
            return item;
        for (const child of item.children) {
            const found = _scrollerOf(child);
            if (found)
                return found;
        }
        return null;
    }

    // A page's Flickable accepts every press inside it before the pane handler sees it, so the scroller carries its own.
    // Handlers die with their parent, so one per page.
    Component {
        id: scrollerTap

        TapHandler {
            onPressedChanged: {
                if (pressed)
                    root.parentModal?.modalFocusScope?.pointerFocus("content");
            }
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
            readonly property bool settled: !pending && loader.status !== Loader.Loading && (presented || loader.status !== Loader.Ready)

            property Item rememberedFocus: null
            property bool pending: true
            property bool presented: false

            enabled: pageActive

            function load(deferred) {
                const file = root._fileFor(page);
                if (file) {
                    loader.asynchronous = deferred;
                    presented = !deferred;
                    loader.setSource(Qt.resolvedUrl("../../Modules/Settings/" + file), root._propertiesFor(page));
                }
                pending = false;
            }

            Loader {
                id: loader

                anchors.fill: parent
                opacity: host.presented ? 1 : 0
                enabled: host.presented

                onLoaded: {
                    if (item.pageActive !== undefined)
                        item.pageActive = Qt.binding(() => host.pageActive);
                    const scroller = root._scrollerOf(item);
                    if (scroller)
                        scrollerTap.createObject(scroller, {
                            "parent": scroller
                        });
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

            onPresentedChanged: {
                if (presented && pageActive)
                    root._focusPage();
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
            "updater": "SoftwareUpdatesTab.qml",
            "updater_changelog": "ChangelogTab.qml",
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
            "wellbeing": "DigitalWellbeingTab.qml",
            "mouse_touchpad": "MouseTouchpadTab.qml",
            "keyboard": "KeyboardTab.qml",
            "plugins_manage": "PluginsManageTab.qml"
        })

    readonly property var pagesWithParentModal: ["dankbar_widgets", "window_rules", "notification_rules", "display_config", "users", "time_weather", "weather", "lock_screen", "greeter", "dank_dash", "wallpaper_cycling", "theme_schedule", "surface_shadows", "keybinds", "dankbar_settings", "dankbar_appearance", "bar_widget", "dock_general", "dock_widgets", "dock_appearance", "dock_advanced", "launcher", "theme", "theme_apps", "media_player", "desktop_widgets", "autostart", "compositor_layout", "updater"]

    Column {
        anchors.fill: parent
        anchors.leftMargin: SettingsMetrics.panePadding
        anchors.rightMargin: SettingsMetrics.panePadding
        spacing: 0

        Item {
            id: pageHeader
            width: Math.min(root.pageContentMaxWidth, parent.width)
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
                    onClicked: root.goBack()
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
