import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import qs.Modules.DankDash

DankPopout {
    id: root

    property bool dashVisible: false
    property var triggerScreen: null
    property int currentTabIndex: 0

    keyboardFocusMode: WlrKeyboardFocus.Exclusive

    function setTriggerPosition(x, y, width, section, screen) {
        triggerSection = section
        triggerScreen = screen
        triggerY = y

        if (section === "center" && (SettingsData.dankBarPosition === SettingsData.Position.Top || SettingsData.dankBarPosition === SettingsData.Position.Bottom)) {
            const screenWidth = screen ? screen.width : Screen.width
            triggerX = (screenWidth - popupWidth) / 2
            triggerWidth = popupWidth
        } else if (section === "center" && (SettingsData.dankBarPosition === SettingsData.Position.Left || SettingsData.dankBarPosition === SettingsData.Position.Right)) {
            const screenHeight = screen ? screen.height : Screen.height
            triggerX = (screenHeight - popupHeight) / 2
            triggerWidth = popupHeight
        } else {
            triggerX = x
            triggerWidth = width
        }
    }

    popupWidth: 700
    popupHeight: contentLoader.item ? contentLoader.item.implicitHeight : 500
    triggerX: Screen.width - 620 - Theme.spacingL
    triggerY: Math.max(26 + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding)) + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap - 2
    triggerWidth: 80
    shouldBeVisible: dashVisible
    visible: shouldBeVisible

    property bool __focusArmed: false
    property bool __contentReady: false

    function __tryFocusOnce() {
        if (!__focusArmed) return
        const win = root.window
        if (!win || !win.visible) return
        if (!contentLoader.item) return

        if (win.requestActivate) win.requestActivate()
        contentLoader.item.forceActiveFocus(Qt.TabFocusReason)

        if (contentLoader.item.activeFocus)
            __focusArmed = false
    }

    onDashVisibleChanged: {
        if (dashVisible) {
            __focusArmed = true
            __contentReady = !!contentLoader.item
            open()
            __tryFocusOnce()
        } else {
            __focusArmed = false
            __contentReady = false
            close()
        }
    }

    Connections {
        target: contentLoader
        function onLoaded() {
            __contentReady = true
            if (__focusArmed) __tryFocusOnce()
        }
    }

    Connections {
        target: root.window ? root.window : null
        enabled: !!root.window
        function onVisibleChanged() { if (__focusArmed) __tryFocusOnce() }
    }

    onBackgroundClicked: {
        dashVisible = false
    }

    content: Component {
        Rectangle {
            id: mainContainer

            implicitHeight: contentColumn.height + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            focus: true

            Component.onCompleted: {
                if (root.shouldBeVisible) {
                    mainContainer.forceActiveFocus()
                }
            }

            Connections {
                target: root
                function onShouldBeVisibleChanged() {
                    if (root.shouldBeVisible) {
                        Qt.callLater(function() {
                            mainContainer.forceActiveFocus()
                        })
                    }
                }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.dashVisible = false
                    event.accepted = true
                    return
                }

                if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) {
                    let nextIndex = root.currentTabIndex + 1
                    while (nextIndex < tabBar.model.length && tabBar.model[nextIndex] && tabBar.model[nextIndex].isAction) {
                        nextIndex++
                    }
                    if (nextIndex >= tabBar.model.length) {
                        nextIndex = 0
                    }
                    root.currentTabIndex = nextIndex
                    event.accepted = true
                    return
                }

                if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    let prevIndex = root.currentTabIndex - 1
                    while (prevIndex >= 0 && tabBar.model[prevIndex] && tabBar.model[prevIndex].isAction) {
                        prevIndex--
                    }
                    if (prevIndex < 0) {
                        prevIndex = tabBar.model.length - 1
                        while (prevIndex >= 0 && tabBar.model[prevIndex] && tabBar.model[prevIndex].isAction) {
                            prevIndex--
                        }
                    }
                    if (prevIndex >= 0) {
                        root.currentTabIndex = prevIndex
                    }
                    event.accepted = true
                    return
                }

                if (root.currentTabIndex === 2 && wallpaperTab.handleKeyEvent) {
                    if (wallpaperTab.handleKeyEvent(event)) {
                        event.accepted = true
                        return
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.surfaceTint.r, Theme.surfaceTint.g, Theme.surfaceTint.b, 0.04)
                radius: parent.radius

                SequentialAnimation on opacity {
                    running: root.shouldBeVisible
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 0.08
                        duration: Theme.extraLongDuration
                        easing.type: Theme.standardEasing
                    }

                    NumberAnimation {
                        to: 0.02
                        duration: Theme.extraLongDuration
                        easing.type: Theme.standardEasing
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
                        const item = pages.currentItem
                        if (!item)
                            return null
                        if (item.focusTarget)
                            return item.focusTarget
                        return item
                    }

                    model: {
                        let tabs = [
                            { icon: "dashboard", text: I18n.tr("Overview") },
                            { icon: "music_note", text: I18n.tr("Media") },
                            { icon: "wallpaper", text: I18n.tr("Wallpapers") }
                        ]

                        if (SettingsData.weatherEnabled) {
                            tabs.push({ icon: "wb_sunny", text: I18n.tr("Weather") })
                        }

                        tabs.push({ icon: "settings", text: I18n.tr("Settings"), isAction: true })
                        return tabs
                    }

                    onTabClicked: function(index) {
                        root.currentTabIndex = index
                    }

                    onActionTriggered: function(index) {
                        let settingsIndex = SettingsData.weatherEnabled ? 4 : 3
                        if (index === settingsIndex) {
                            dashVisible = false
                            settingsModal.show()
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
                        if (currentIndex === 0) return overviewTab.implicitHeight
                        if (currentIndex === 1) return mediaTab.implicitHeight
                        if (currentIndex === 2) return wallpaperTab.implicitHeight
                        if (SettingsData.weatherEnabled && currentIndex === 3) return weatherTab.implicitHeight
                        return overviewTab.implicitHeight
                    }
                    currentIndex: root.currentTabIndex

                    OverviewTab {
                        id: overviewTab

                        onSwitchToWeatherTab: {
                            if (SettingsData.weatherEnabled) {
                                tabBar.currentIndex = 3
                                tabBar.tabClicked(3)
                            }
                        }

                        onSwitchToMediaTab: {
                            tabBar.currentIndex = 1
                            tabBar.tabClicked(1)
                        }
                    }

                    MediaPlayerTab {
                        id: mediaTab
                    }

                    WallpaperTab {
                        id: wallpaperTab
                        active: root.currentTabIndex === 2
                        tabBarItem: tabBar
                        keyForwardTarget: mainContainer
                    }

                    WeatherTab {
                        id: weatherTab
                        visible: SettingsData.weatherEnabled && root.currentTabIndex === 3
                    }
                }
            }
        }
    }
}