import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

DankPopout {
    id: root

    layerNamespace: "dms:dash"

    property bool dashVisible: false
    property var triggerScreen: null
    property int currentTabIndex: 0

    popupWidth: 700
    popupHeight: contentLoader.item ? contentLoader.item.implicitHeight : 500
    triggerWidth: 80
    screen: triggerScreen
    shouldBeVisible: dashVisible

    property bool __focusArmed: false
    property bool __contentReady: false

    property var __mediaTabRef: null

    property int __dropdownType: 0
    property point __dropdownAnchor: Qt.point(0, 0)
    property bool __dropdownRightEdge: false
    property var __dropdownPlayer: null
    property var __dropdownPlayers: []

    function __showVolumeDropdown(pos, rightEdge, player, players) {
        __dropdownAnchor = pos;
        __dropdownRightEdge = rightEdge;
        __dropdownPlayer = player;
        __dropdownPlayers = players;
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
        __dropdownPlayer = player;
        __dropdownPlayers = players;
        __dropdownType = 3;
    }

    function __hideDropdowns() {
        __volumeCloseTimer.stop();
        __dropdownType = 0;
        __mediaTabRef?.resetDropdownStates();
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
            if (__dropdownType === 1) {
                __hideDropdowns();
            }
        }
    }

    overlayContent: Component {
        MediaDropdownOverlay {
            dropdownType: root.__dropdownType
            anchorPos: root.__dropdownAnchor
            isRightEdge: root.__dropdownRightEdge
            activePlayer: root.__dropdownPlayer
            allPlayers: root.__dropdownPlayers
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
                MprisController.activePlayer = player;
                root.__hideDropdowns();
            }
            onDeviceSelected: device => {
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

            implicitHeight: contentColumn.height + Theme.spacingM * 2
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            focus: true

            Component.onCompleted: {
                if (root.shouldBeVisible) {
                    mainContainer.forceActiveFocus();
                }
            }

            Connections {
                target: root
                function onShouldBeVisibleChanged() {
                    if (root.shouldBeVisible) {
                        Qt.callLater(function () {
                            mainContainer.forceActiveFocus();
                        });
                    }
                }
            }

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Escape) {
                    root.dashVisible = false;
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) {
                    let nextIndex = root.currentTabIndex + 1;
                    while (nextIndex < tabBar.model.length && tabBar.model[nextIndex] && tabBar.model[nextIndex].isAction) {
                        nextIndex++;
                    }
                    if (nextIndex >= tabBar.model.length) {
                        nextIndex = 0;
                    }
                    root.currentTabIndex = nextIndex;
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    let prevIndex = root.currentTabIndex - 1;
                    while (prevIndex >= 0 && tabBar.model[prevIndex] && tabBar.model[prevIndex].isAction) {
                        prevIndex--;
                    }
                    if (prevIndex < 0) {
                        prevIndex = tabBar.model.length - 1;
                        while (prevIndex >= 0 && tabBar.model[prevIndex] && tabBar.model[prevIndex].isAction) {
                            prevIndex--;
                        }
                    }
                    if (prevIndex >= 0) {
                        root.currentTabIndex = prevIndex;
                    }
                    event.accepted = true;
                    return;
                }

                if (root.currentTabIndex === 2 && wallpaperLoader.item?.handleKeyEvent) {
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

                    width: parent.width
                    height: 48
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

                    model: {
                        let tabs = [
                            {
                                "icon": "dashboard",
                                "text": I18n.tr("Overview")
                            },
                            {
                                "icon": "music_note",
                                "text": I18n.tr("Media")
                            },
                            {
                                "icon": "wallpaper",
                                "text": I18n.tr("Wallpapers")
                            }
                        ];

                        if (SettingsData.weatherEnabled) {
                            tabs.push({
                                "icon": "wb_sunny",
                                "text": I18n.tr("Weather")
                            });
                        }

                        tabs.push({
                            "icon": "settings",
                            "text": I18n.tr("Settings"),
                            "isAction": true
                        });
                        return tabs;
                    }

                    onTabClicked: function (index) {
                        root.currentTabIndex = index;
                    }

                    onActionTriggered: function (index) {
                        let settingsIndex = SettingsData.weatherEnabled ? 4 : 3;
                        if (index === settingsIndex) {
                            dashVisible = false;
                            PopoutService.focusOrToggleSettings();
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Theme.spacingXS
                }

                StackLayout {
                    id: pages
                    width: parent.width
                    implicitHeight: {
                        if (currentIndex === 0)
                            return overviewLoader.item?.implicitHeight ?? 410;
                        if (currentIndex === 1)
                            return mediaLoader.item?.implicitHeight ?? 410;
                        if (currentIndex === 2)
                            return wallpaperLoader.item?.implicitHeight ?? 410;
                        if (SettingsData.weatherEnabled && currentIndex === 3)
                            return weatherLoader.item?.implicitHeight ?? 410;
                        return 410;
                    }
                    currentIndex: root.currentTabIndex

                    Loader {
                        id: overviewLoader
                        active: root.currentTabIndex === 0
                        sourceComponent: Component {
                            OverviewTab {
                                onCloseDash: root.dashVisible = false
                                onSwitchToWeatherTab: {
                                    if (SettingsData.weatherEnabled) {
                                        tabBar.currentIndex = 3;
                                        tabBar.tabClicked(3);
                                    }
                                }
                                onSwitchToMediaTab: {
                                    tabBar.currentIndex = 1;
                                    tabBar.tabClicked(1);
                                }
                            }
                        }
                    }

                    Loader {
                        id: mediaLoader
                        active: root.currentTabIndex === 1
                        sourceComponent: Component {
                            MediaPlayerTab {
                                targetScreen: root.screen
                                popoutX: root.alignedX
                                popoutY: root.alignedY
                                popoutWidth: root.alignedWidth
                                popoutHeight: root.alignedHeight
                                contentOffsetY: Theme.spacingM + 48 + Theme.spacingS + Theme.spacingXS
                                Component.onCompleted: root.__mediaTabRef = this
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
                                onVolumeButtonExited: root.__startCloseTimer()
                            }
                        }
                    }

                    Loader {
                        id: wallpaperLoader
                        active: root.currentTabIndex === 2
                        sourceComponent: Component {
                            WallpaperTab {
                                active: true
                                tabBarItem: tabBar
                                keyForwardTarget: mainContainer
                                targetScreen: root.triggerScreen
                                parentPopout: root
                            }
                        }
                    }

                    Loader {
                        id: weatherLoader
                        active: SettingsData.weatherEnabled && root.currentTabIndex === 3
                        sourceComponent: Component {
                            WeatherTab {}
                        }
                    }
                }
            }
        }
    }
}
