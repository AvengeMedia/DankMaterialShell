import QtQuick
import qs.Common
import qs.Modules.DankDash.Overview
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property int overviewGridHeight: 410
    readonly property int dankConnectCardHeight: 124

    implicitWidth: SettingsData.showWeekNumber ? 736 : 700
    implicitHeight: overviewGridHeight + Theme.spacingM + dankConnectCardHeight

    signal switchToWeatherTab
    signal switchToMediaTab
    signal closeDash
    signal navFocusRequested

    function handleKeyEvent(event) {
        return calendarLoader.item ? calendarLoader.item.handleKeyEvent(event) : false;
    }

    Item {
        anchors.fill: parent
        // Clock - top left (narrower and shorter)
        ClockCard {
            x: 0
            y: 0
            width: parent.width * 0.2 - Theme.spacingM * 2
            height: 180
        }

        // Weather - top middle-left (narrower)
        WeatherOverviewCard {
            x: SettingsData.weatherEnabled ? parent.width * 0.2 - Theme.spacingM : 0
            y: 0
            width: SettingsData.weatherEnabled ? parent.width * 0.3 : 0
            height: 100
            visible: SettingsData.weatherEnabled

            onClicked: root.switchToWeatherTab()
        }

        // UserInfo - top middle-right (extend when weather disabled)
        UserInfoCard {
            x: SettingsData.weatherEnabled ? parent.width * 0.5 : parent.width * 0.2 - Theme.spacingM
            y: 0
            width: SettingsData.weatherEnabled ? parent.width * 0.5 : parent.width * 0.8
            height: 100
        }

        // SystemMonitor - middle left (narrow and shorter)
        SystemMonitorCard {
            x: 0
            y: 180 + Theme.spacingM
            width: parent.width * 0.2 - Theme.spacingM * 2
            height: 220
        }

        // Calendar - bottom middle; deferred so the grid stays off the emerge frame.
        Loader {
            id: calendarLoader
            x: parent.width * 0.2 - Theme.spacingM
            y: 100 + Theme.spacingM
            width: parent.width * 0.6
            height: 300
            asynchronous: true
            sourceComponent: Component {
                CalendarOverviewCard {
                    onCloseDash: root.closeDash()
                    onNavFocusRequested: root.navFocusRequested()
                }
            }

            DankSpinner {
                anchors.centerIn: parent
                size: 32
                visible: calendarLoader.status === Loader.Loading
            }
        }

        // Media - bottom right (narrow and taller)
        MediaOverviewCard {
            x: parent.width * 0.8
            y: 100 + Theme.spacingM
            width: parent.width * 0.2
            height: 300

            onClicked: root.switchToMediaTab()
        }

        DankConnectOverviewCard {
            x: 0
            y: root.overviewGridHeight + Theme.spacingM
            width: parent.width
            height: root.dankConnectCardHeight
        }
    }
}
