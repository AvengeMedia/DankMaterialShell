import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankPopout {
    id: root

    layerNamespace: "dms:dash"

    property bool dashVisible: false
    property var triggerScreen: null
    property string currentTabId: "overview"

    readonly property var __tabPresentation: ({
            "overview": {
                "icon": "dashboard",
                "text": I18n.tr("Overview")
            },
            "media": {
                "icon": "music_note",
                "text": I18n.tr("Media")
            },
            "wallpaper": {
                "icon": "wallpaper",
                "text": I18n.tr("Wallpapers")
            },
            "weather": {
                "icon": "wb_sunny",
                "text": I18n.tr("Weather")
            },
            "settings": {
                "icon": "settings",
                "text": I18n.tr("Settings"),
                "isAction": true
            }
        })
    readonly property var orderedTabIds: SettingsData.visibleDashTabIds()
    // -1 when the current view's tab is hidden: the view still shows, no tab is highlighted.
    readonly property int currentTabIndex: orderedTabIds.indexOf(currentTabId)

    function __isActionTab(id) {
        return root.__tabPresentation[id]?.isAction === true;
    }

    // Show a view regardless of tab visibility; bar widgets and IPC land here.
    function requestTab(id) {
        const valid = __tabPresentation[id] !== undefined && !__isActionTab(id) && (id !== "weather" || SettingsData.weatherEnabled);
        currentTabId = valid ? id : "overview";
    }

    function __cycleTab(dir) {
        const ids = orderedTabIds.filter(id => !__isActionTab(id));
        if (ids.length === 0)
            return;
        const pos = ids.indexOf(currentTabId);
        const next = pos < 0 ? (dir > 0 ? 0 : ids.length - 1) : (pos + dir + ids.length) % ids.length;
        currentTabId = ids[next];
    }

    Connections {
        target: SettingsData
        function onWeatherEnabledChanged() {
            if (!SettingsData.weatherEnabled && root.currentTabId === "weather")
                root.currentTabId = "overview";
        }
    }

    popupWidth: SettingsData.showWeekNumber ? 736 : 700
    popupHeight: contentLoader.item ? contentLoader.item.implicitHeight : 500
    triggerWidth: 80
    screen: triggerScreen

    property bool __focusArmed: false
    property bool __contentReady: false

    property var __mediaTabRef: null

    property int __dropdownType: 0
    property point __dropdownAnchor: Qt.point(0, 0)
    property bool __dropdownRightEdge: false
    property var __dropdownPlayer: MprisController.activePlayer
    property var __dropdownPlayers: MprisController.availablePlayers

    function __showVolumeDropdown(pos, rightEdge, player, players) {
        __dropdownAnchor = pos;
        __dropdownRightEdge = rightEdge;
        __dropdownPlayer = Qt.binding(() => MprisController.activePlayer);
        __dropdownPlayers = Qt.binding(() => MprisController.availablePlayers);
        __dropdownType = 1;
    }

    function __showAudioDevicesDropdown(pos, rightEdge) {
        __dropdownAnchor = pos;
        __dropdownRightEdge = rightEdge;
        __dropdownType = 2;
    }

    function __showPlayersDropdown(pos, rightEdge, player, players) {
        __dropdownAnchor = pos;
        __dropdownRightEdge = rightEdge;
        __dropdownPlayer = Qt.binding(() => MprisController.activePlayer);
        __dropdownPlayers = Qt.binding(() => MprisController.availablePlayers);
        __dropdownType = 3;
    }

    function __hideDropdowns() {
        __volumeCloseTimer.stop();
        __dropdownType = 0;
        if (__mediaTabRef && typeof __mediaTabRef.resetDropdownStates === "function")
            __mediaTabRef.resetDropdownStates();
    }

    function __startCloseTimer() {
        __volumeCloseTimer.restart();
    }

    function __stopCloseTimer() {
        __volumeCloseTimer.stop();
    }

    Timer {
        id: __volumeCloseTimer
        interval: 400
        onTriggered: {
            if (__dropdownType !== 0) {
                __hideDropdowns();
            }
        }
    }

    overlayContent: shouldBeVisible ? mediaDropdownOverlayComponent : null

    Component {
        id: mediaDropdownOverlayComponent

        MediaDropdownOverlay {
            dropdownType: root.__dropdownType
            anchorPos: root.__dropdownAnchor
            isRightEdge: root.__dropdownRightEdge
            activePlayer: root.__dropdownPlayer
            allPlayers: root.__dropdownPlayers
            targetWindow: root.backgroundWindow
            onCloseRequested: root.__hideDropdowns()
            onPanelEntered: root.__stopCloseTimer()
            onPanelExited: root.__startCloseTimer()
            onVolumeChanged: volume => {
                const player = root.__dropdownPlayer;
                const isChrome = player?.identity?.toLowerCase().includes("chrome") || player?.identity?.toLowerCase().includes("chromium");
                const usePlayerVolume = player && player.volumeSupported && !isChrome;
                if (usePlayerVolume) {
                    player.volume = volume;
                } else if (AudioService.sink?.audio) {
                    AudioService.sink.audio.volume = volume;
                }
            }
            onPlayerSelected: player => {
                const currentPlayer = MprisController.activePlayer;
                if (currentPlayer && currentPlayer !== player && currentPlayer.canPause) {
                    currentPlayer.pause();
                }
                MprisController.setActivePlayer(player);
                root.__hideDropdowns();
            }
        }
    }

    function __tryFocusOnce() {
        if (!__focusArmed)
            return;
        const win = root.window;
        if (!win || !win.visible)
            return;
        if (!contentLoader.item)
            return;
        if (win.requestActivate)
            win.requestActivate();
        contentLoader.item.forceActiveFocus(Qt.TabFocusReason);

        if (contentLoader.item.activeFocus)
            __focusArmed = false;
    }

    onDashVisibleChanged: {
        if (dashVisible) {
            __focusArmed = true;
            __contentReady = !!contentLoader.item;
            open();
            __tryFocusOnce();
        } else {
            __focusArmed = false;
            __contentReady = false;
            __hideDropdowns();
            close();
        }
    }

    Connections {
        target: contentLoader
        function onLoaded() {
            __contentReady = true;
            if (__focusArmed)
                __tryFocusOnce();
        }
    }

    Connections {
        target: root.window ? root.window : null
        enabled: !!root.window
        function onVisibleChanged() {
            if (__focusArmed)
                __tryFocusOnce();
        }
    }

    onBackgroundClicked: {
        dashVisible = false;
    }

    content: Component {
        Rectangle {
            id: mainContainer

            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            MouseArea {
                anchors.fill: parent
                z: -1
                enabled: root.__dropdownType !== 0
                onClicked: root.__hideDropdowns()
            }

            implicitWidth: Math.max(700, pages.implicitWidth + (Theme.spacingM * 2))
            implicitHeight: contentColumn.height + Theme.spacingM * 2
            color: "transparent"
            focus: true

            Component.onCompleted: {
                if (root.shouldBeVisible) {
                    mainContainer.forceActiveFocus();
                }
            }

            Connections {
                target: root
                function onShouldBeVisibleChanged() {
                    if (!root.shouldBeVisible)
                        return;
                    mainContainer.forceActiveFocus();
                    tabBar.snapIndicator();
                }
            }

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Escape) {
                    if (root.currentTabId === "wallpaper" && wallpaperLoader.item?.handleKeyEvent && wallpaperLoader.item.handleKeyEvent(event)) {
                        event.accepted = true;
                        return;
                    }
                    root.dashVisible = false;
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) {
                    root.__cycleTab(1);
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    root.__cycleTab(-1);
                    event.accepted = true;
                    return;
                }

                if (root.currentTabId === "overview" && overviewLoader.item?.handleKeyEvent) {
                    if (overviewLoader.item.handleKeyEvent(event)) {
                        event.accepted = true;
                        return;
                    }
                }

                if (root.currentTabId === "media" && mediaLoader.item?.handleKeyEvent) {
                    if (mediaLoader.item.handleKeyEvent(event)) {
                        event.accepted = true;
                        return;
                    }
                }

                if (root.currentTabId === "wallpaper" && wallpaperLoader.item?.handleKeyEvent) {
                    if (wallpaperLoader.item.handleKeyEvent(event)) {
                        event.accepted = true;
                        return;
                    }
                }
            }

            Column {
                id: contentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                DankTabBar {
                    id: tabBar

                    // Effective visibility is false while the popout window is unmapped, so gating
                    // height on `visible` collapses the bar between opens and resizes the surface
                    // mid-animation. Gate on data only. The bar also hides entirely when the
                    // current view's tab isn't in the visible set (e.g. IPC-opened hidden tab).
                    readonly property bool showTabs: (model?.length ?? 0) > 0 && root.currentTabIndex >= 0
                    width: parent.width
                    height: showTabs ? 48 : 0
                    visible: showTabs
                    currentIndex: root.currentTabIndex
                    spacing: Theme.spacingS
                    equalWidthTabs: true
                    enableArrowNavigation: false
                    focus: false
                    activeFocusOnTab: false
                    nextFocusTarget: {
                        const item = pages.currentItem;
                        if (!item)
                            return null;
                        if (item.focusTarget)
                            return item.focusTarget;
                        return item;
                    }

                    model: root.orderedTabIds.map(id => root.__tabPresentation[id])

                    onTabClicked: function (index) {
                        const id = root.orderedTabIds[index];
                        if (id !== undefined)
                            root.currentTabId = id;
                    }

                    onActionTriggered: function (index) {
                        if (root.orderedTabIds[index] === "settings") {
                            dashVisible = false;
                            PopoutService.focusOrToggleSettings();
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: tabBar.showTabs ? Theme.spacingXS : 0
                    visible: tabBar.showTabs
                }

                Item {
                    id: pages
                    width: parent.width
                    height: implicitHeight
                    implicitWidth: currentItem && currentItem.implicitWidth > 0 ? currentItem.implicitWidth : (700 - Theme.spacingM * 2)
                    implicitHeight: {
                        if (root.currentTabId === "overview")
                            return overviewLoader.item?.implicitHeight ?? 410;
                        if (root.currentTabId === "media")
                            return mediaLoader.item?.implicitHeight ?? 410;
                        if (root.currentTabId === "wallpaper")
                            return wallpaperLoader.item?.implicitHeight ?? 410;
                        if (root.currentTabId === "weather")
                            return weatherLoader.item?.implicitHeight ?? 410;
                        return 410;
                    }

                    readonly property var currentItem: {
                        if (root.currentTabId === "overview")
                            return overviewLoader.item;
                        if (root.currentTabId === "media")
                            return mediaLoader.item;
                        if (root.currentTabId === "wallpaper")
                            return wallpaperLoader.item;
                        if (root.currentTabId === "weather")
                            return weatherLoader.item;
                        return null;
                    }

                    Loader {
                        id: overviewLoader
                        anchors.fill: parent
                        active: root.currentTabId === "overview"
                        visible: active
                        sourceComponent: Component {
                            OverviewTab {
                                onCloseDash: root.dashVisible = false
                                onNavFocusRequested: mainContainer.forceActiveFocus()
                                onSwitchToWeatherTab: {
                                    if (SettingsData.weatherEnabled) {
                                        root.requestTab("weather");
                                    }
                                }
                                onSwitchToMediaTab: {
                                    root.requestTab("media");
                                }
                            }
                        }
                    }

                    Loader {
                        id: mediaLoader
                        anchors.fill: parent
                        active: root.currentTabId === "media"
                        visible: active
                        asynchronous: true
                        sourceComponent: Component {
                            MediaPlayerTab {
                                targetScreen: root.screen
                                popoutX: root.alignedX
                                popoutY: root.alignedY
                                popoutWidth: root.alignedWidth
                                popoutHeight: root.alignedHeight
                                contentOffsetY: Theme.spacingM + (tabBar.showTabs ? 48 + Theme.spacingS + Theme.spacingXS : 0)
                                section: root.triggerSection
                                barPosition: root.effectiveBarPosition
                                Component.onCompleted: root.__mediaTabRef = this
                                Component.onDestruction: {
                                    if (root.__mediaTabRef === this)
                                        root.__mediaTabRef = null;
                                }
                                onShowVolumeDropdown: (pos, screen, rightEdge, player, players) => {
                                    root.__showVolumeDropdown(pos, rightEdge, player, players);
                                }
                                onShowAudioDevicesDropdown: (pos, screen, rightEdge) => {
                                    root.__showAudioDevicesDropdown(pos, rightEdge);
                                }
                                onShowPlayersDropdown: (pos, screen, rightEdge, player, players) => {
                                    root.__showPlayersDropdown(pos, rightEdge, player, players);
                                }
                                onHideDropdowns: root.__hideDropdowns()
                                onDropdownButtonExited: root.__startCloseTimer()
                                onDropdownButtonEntered: root.__stopCloseTimer()
                            }
                        }
                    }

                    Loader {
                        id: wallpaperLoader
                        anchors.fill: parent
                        active: root.currentTabId === "wallpaper"
                        visible: active
                        asynchronous: true
                        sourceComponent: Component {
                            WallpaperTab {
                                active: true
                                tabBarItem: tabBar
                                keyForwardTarget: mainContainer
                                targetScreen: root.screen
                                parentPopout: root
                            }
                        }
                    }

                    DankSpinner {
                        anchors.centerIn: parent
                        size: 40
                        visible: (wallpaperLoader.active && wallpaperLoader.status === Loader.Loading) || (mediaLoader.active && mediaLoader.status === Loader.Loading) || (weatherLoader.active && weatherLoader.status === Loader.Loading)
                    }

                    Loader {
                        id: weatherLoader
                        anchors.fill: parent
                        active: root.currentTabId === "weather"
                        visible: active
                        asynchronous: true
                        sourceComponent: Component {
                            WeatherTab {}
                        }
                    }
                }
            }
        }
    }
}
