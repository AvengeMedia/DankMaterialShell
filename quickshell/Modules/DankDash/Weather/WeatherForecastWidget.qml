pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankDash

Column {
    id: root

    property bool daily: false
    property bool chartMode: true
    property bool live: false
    readonly property int visibleCount: Math.max(1, Math.min(daily ? DashMetrics.dailyVisibleCount : DashMetrics.chartHourlyCount, Math.floor(width / DashMetrics.gridRowUnit)))
    property int startIndex: daily ? 0 : (WeatherService.weather.currentHourIndex ?? new Date().getHours())
    readonly property var forecasts: (daily ? WeatherService.weather.forecast : WeatherService.weather.hourlyForecast) ?? []
    readonly property int maxStart: Math.max(0, forecasts.length - visibleCount)
    readonly property int start: Math.max(0, Math.min(maxStart, startIndex))

    spacing: Theme.spacingS

    function step(delta) {
        const next = Math.max(0, Math.min(maxStart, start + delta));
        if (next === start)
            return false;
        startIndex = next;
        return true;
    }

    Item {
        width: parent.width
        height: Theme.buttonHeightS

        StyledText {
            anchors.left: parent.left
            anchors.right: actions.left
            anchors.rightMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            text: root.daily ? I18n.tr("Daily") : I18n.tr("Hourly")
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Theme.fontWeightMedium
            color: Theme.onSurface
            elide: Text.ElideRight
        }

        Row {
            id: actions
            anchors.right: parent.right
            spacing: Theme.spacingXS

            DankActionButton {
                buttonSize: Theme.buttonHeightS
                iconName: I18n.isRtl ? "chevron_right" : "chevron_left"
                Accessible.name: I18n.tr("Previous")
                enabled: root.start > 0
                onClicked: root.step(-1)
            }

            DankActionButton {
                buttonSize: Theme.buttonHeightS
                iconName: "today"
                Accessible.name: I18n.tr("Today")
                onClicked: root.startIndex = root.daily ? 0 : (WeatherService.weather.currentHourIndex ?? new Date().getHours())
            }

            DankActionButton {
                buttonSize: Theme.buttonHeightS
                iconName: I18n.isRtl ? "chevron_left" : "chevron_right"
                Accessible.name: I18n.tr("Next")
                enabled: root.start < root.maxStart
                onClicked: root.step(1)
            }
        }
    }

    Loader {
        width: parent.width
        height: Math.max(0, root.height - y)
        active: root.live
        sourceComponent: root.chartMode ? chart : cards
    }

    Component {
        id: chart
        WeatherForecastChart {
            daily: root.daily
            visibleCount: root.visibleCount
            startIndex: root.start
            onPageRequested: delta => root.step(delta)
        }
    }

    Component {
        id: cards
        Item {
            Row {
                id: cardRow
                anchors.fill: parent
                spacing: Theme.spacingS
                Repeater {
                    model: root.forecasts.slice(root.start, root.start + root.visibleCount)
                    WeatherForecastCard {
                        required property var modelData
                        required property int index
                        width: (cardRow.width - cardRow.spacing * (root.visibleCount - 1)) / root.visibleCount
                        height: cardRow.height
                        daily: root.daily
                        dense: true
                        forecastData: modelData
                        isCurrent: root.start + index === (root.daily ? 0 : (WeatherService.weather.currentHourIndex ?? new Date().getHours()))
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.forecasts.length === 0
                text: I18n.tr("Forecast Not Available")
                color: Theme.onSurfaceVariant
            }
        }
    }
}
