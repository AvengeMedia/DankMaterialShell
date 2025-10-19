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


    onDashVisibleChanged: {
        if (dashVisible) {
            open()
        } else {
            close()
        }
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
                    forceActiveFocus()
                }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.dashVisible = false
                    event.accepted = true
                }
            }

            Connections {
                function onShouldBeVisibleChanged() {
                    if (root.shouldBeVisible) {
                        Qt.callLater(function() {
                            mainContainer.forceActiveFocus()
                        })
                    }
                }
                target: root
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

                    model: {
                        let tabs = [
                            { icon: "dashboard", text: I18n.tr("Overview") },
                            { icon: "music_note", text: I18n.tr("Media") }
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
                        let settingsIndex = SettingsData.weatherEnabled ? 3 : 2
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
                        if (SettingsData.weatherEnabled && currentIndex === 2) return weatherTab.implicitHeight
                        return overviewTab.implicitHeight
                    }
                    currentIndex: root.currentTabIndex

                    OverviewTab {
                        id: overviewTab

                        onSwitchToWeatherTab: {
                            if (SettingsData.weatherEnabled) {
                                tabBar.currentIndex = 2
                                tabBar.tabClicked(2)
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

                    WeatherTab {
                        id: weatherTab
                        visible: SettingsData.weatherEnabled && root.currentTabIndex === 2
                    }
                }
            }
        }
    }
}