import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root
    radius: Theme.cornerRadius

    property var date: null
    property var daily: true
    property var forecastData: null
    property var dense: false

    readonly property bool isCurrent: {
        if (daily) {
            date ? WeatherService.calendarDayDifference(new Date(), date) === 0 : false;
        } else {
            date ? WeatherService.calendarHourDifference(new Date(), date) === 0 : false;
        }
    }

    readonly property string dateText: (daily ? root.forecastData?.day : root.forecastData?.time) ?? "--"

    readonly property var minTemp: WeatherService.formatTemp(root.forecastData?.tempMin)
    readonly property var maxTemp: WeatherService.formatTemp(root.forecastData?.tempMax)
    readonly property string minMaxTempText: (minTemp ?? "--") + "/" + (maxTemp ?? "--")

    readonly property var temp: WeatherService.formatTemp(root.forecastData?.temp)
    readonly property string tempText: temp ?? "--"

    readonly property var feelsLikeTemp: WeatherService.formatTemp(root.forecastData?.feelsLike)
    readonly property string feelsLikeText: feelsLikeTemp ?? "--"

    readonly property var humidity: WeatherService.formatPercent(root.forecastData?.humidity)
    readonly property string humidityText: humidity ?? "--"

    readonly property var wind: WeatherService.formatSpeed(root.forecastData?.wind)
    readonly property string windText: wind ?? "--"

    readonly property var pressure: WeatherService.formatPressure(root.forecastData?.pressure)
    readonly property string pressureText: pressure ?? "--"

    readonly property var precipitation: root.forecastData?.precipitationProbability
    readonly property string precipitationText: precipitation + "%" ?? "--"

    readonly property var visibility: WeatherService.formatVisibility(root.forecastData?.visibility)
    readonly property string visibilityText: visibility ?? "--"

    readonly property var values: daily ? [] : [
        {
            //     'name': "Temperature",
            //     'text': root.tempText,
            //     'icon': "thermometer"
            // }, {
            //     'name': "Feels Like",
            //     'text': root.feelsLikeText,
            //     'icon': "thermostat"
            // }, {
            'name': I18n.tr("Humidity"),
            'text': root.humidityText,
            'icon': "humidity_low"
        },
        {
            'name': I18n.tr("Wind Speed"),
            'text': root.windText,
            'icon': "air"
        },
        {
            'name': I18n.tr("Pressure"),
            'text': root.pressureText,
            'icon': "speed"
        },
        {
            'name': I18n.tr("Precipitation Chance"),
            'text': root.precipitationText,
            'icon': "rainy"
        },
        {
            'name': I18n.tr("Visibility"),
            'text': root.visibilityText,
            'icon': "wb_sunny"
        }
    ]

    color: isCurrent ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    border.color: isCurrent ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : "transparent"
    border.width: isCurrent ? 1 : 0

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        StyledText {
            text: root.forecastData != null ? root.dateText : I18n.tr("Forecast Not Available")
            font.pixelSize: Theme.fontSizeSmall
            color: root.isCurrent ? Theme.primary : (root.forecastData ? Theme.surfaceText : Theme.outline)
            font.weight: root.isCurrent ? Font.Medium : Font.Normal
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingM
            visible: root.forecastData != null

            Column {
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.forecastData ? WeatherService.getWeatherIcon(root.forecastData.wCode || 0, root.forecastData.isDay ?? true) : "cloud"
                    size: Theme.iconSize
                    color: root.isCurrent ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.8)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.daily ? root.minMaxTempText : root.tempText
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.isCurrent ? Theme.primary : Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.feelsLikeText
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.isCurrent ? Theme.primary : Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !root.daily
                }
            }

            Column {
                id: detailsColumn
                spacing: 2
                visible: !root.dense
                width: implicitWidth

                states: [
                    State {
                        name: "dense"
                        when: root.dense
                        PropertyChanges {
                            target: detailsColumn
                            opacity: 0
                            width: 0
                        }
                    }
                ]

                transitions: [
                    Transition {
                        NumberAnimation {
                            properties: "opacity,width"
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                ]

                Repeater {
                    model: root.values.length
                    Row {
                        spacing: 2

                        DankIcon {
                            name: root.values[index].icon
                            size: 8
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: root.values[index].text
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
