import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    implicitWidth: 700
    implicitHeight: 410

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingL
        visible: !WeatherService.weather.available || WeatherService.weather.temp === 0

        DankIcon {
            name: "cloud_off"
            size: Theme.iconSize * 2
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: I18n.tr("No Weather Data Available")
            font.pixelSize: Theme.fontSizeLarge
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spacingM
        visible: WeatherService.weather.available && WeatherService.weather.temp !== 0

        Item {
            width: parent.width
            height: 70

            DankIcon {
                id: refreshButton
                name: "refresh"
                size: Theme.iconSize - 4
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                anchors.right: parent.right
                anchors.top: parent.top

                property bool isRefreshing: false
                enabled: !isRefreshing

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: {
                        refreshButton.isRefreshing = true
                        WeatherService.forceRefresh()
                        refreshTimer.restart()
                    }
                    enabled: parent.enabled
                }

                Timer {
                    id: refreshTimer
                    interval: 2000
                    onTriggered: refreshButton.isRefreshing = false
                }

                NumberAnimation on rotation {
                    running: refreshButton.isRefreshing
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: weatherIcon.width + tempColumn.width + sunriseColumn.width + Theme.spacingM * 2
                height: 70

                DankIcon {
                    id: weatherIcon
                    name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                    size: Theme.iconSize * 1.5
                    color: Theme.primary
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 4
                        shadowBlur: 0.8
                        shadowColor: Qt.rgba(0, 0, 0, 0.2)
                        shadowOpacity: 0.2
                    }
                }

                Column {
                    id: tempColumn
                    spacing: Theme.spacingXS
                    anchors.left: weatherIcon.right
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width: tempText.width + unitText.width + Theme.spacingXS
                        height: tempText.height

                        StyledText {
                            id: tempText
                            text: (SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°"
                            font.pixelSize: Theme.fontSizeLarge + 4
                            color: Theme.surfaceText
                            font.weight: Font.Light
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            id: unitText
                            text: SettingsData.useFahrenheit ? "F" : "C"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            anchors.left: tempText.right
                            anchors.leftMargin: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (WeatherService.weather.available) {
                                        SettingsData.setTemperatureUnit(!SettingsData.useFahrenheit)
                                    }
                                }
                                enabled: WeatherService.weather.available
                            }
                        }
                    }

                    StyledText {
                        text: WeatherService.weather.city || ""
                        font.pixelSize: Theme.fontSizeMedium
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                        visible: text.length > 0
                    }
                }

                Column {
                    id: sunriseColumn
                    spacing: Theme.spacingXS
                    anchors.left: tempColumn.right
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    visible: WeatherService.weather.sunrise && WeatherService.weather.sunset

                    Item {
                        width: sunriseIcon.width + sunriseText.width + Theme.spacingXS
                        height: sunriseIcon.height

                        DankIcon {
                            id: sunriseIcon
                            name: "wb_twilight"
                            size: Theme.iconSize - 6
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            id: sunriseText
                            text: WeatherService.weather.sunrise || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                            anchors.left: sunriseIcon.right
                            anchors.leftMargin: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item {
                        width: sunsetIcon.width + sunsetText.width + Theme.spacingXS
                        height: sunsetIcon.height

                        DankIcon {
                            id: sunsetIcon
                            name: "bedtime"
                            size: Theme.iconSize - 6
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            id: sunsetText
                            text: WeatherService.weather.sunset || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                            anchors.left: sunsetIcon.right
                            anchors.leftMargin: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
        }

        GridLayout {
            width: parent.width
            height: 95
            columns: 6
            columnSpacing: Theme.spacingS
            rowSpacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                        anchors.horizontalCenter: parent.horizontalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "device_thermostat"
                            size: Theme.iconSize - 4
                            color: Theme.primary
                        }
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        StyledText {
                            text: I18n.tr("Feels Like")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: (SettingsData.useFahrenheit ? (WeatherService.weather.feelsLikeF || WeatherService.weather.tempF) : (WeatherService.weather.feelsLike || WeatherService.weather.temp)) + "°"
                            font.pixelSize: Theme.fontSizeSmall + 1
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                        anchors.horizontalCenter: parent.horizontalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "humidity_low"
                            size: Theme.iconSize - 4
                            color: Theme.primary
                        }
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        StyledText {
                            text: I18n.tr("Humidity")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: WeatherService.weather.humidity ? WeatherService.weather.humidity + "%" : "--"
                            font.pixelSize: Theme.fontSizeSmall + 1
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                        anchors.horizontalCenter: parent.horizontalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "air"
                            size: Theme.iconSize - 4
                            color: Theme.primary
                        }
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        StyledText {
                            text: I18n.tr("Wind")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: WeatherService.weather.wind || "--"
                            font.pixelSize: Theme.fontSizeSmall + 1
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                        anchors.horizontalCenter: parent.horizontalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "speed"
                            size: Theme.iconSize - 4
                            color: Theme.primary
                        }
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        StyledText {
                            text: I18n.tr("Pressure")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: WeatherService.weather.pressure ? WeatherService.weather.pressure + " hPa" : "--"
                            font.pixelSize: Theme.fontSizeSmall + 1
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                        anchors.horizontalCenter: parent.horizontalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "rainy"
                            size: Theme.iconSize - 4
                            color: Theme.primary
                        }
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        StyledText {
                            text: I18n.tr("Rain Chance")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: WeatherService.weather.precipitationProbability ? WeatherService.weather.precipitationProbability + "%" : "0%"
                            font.pixelSize: Theme.fontSizeSmall + 1
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                        anchors.horizontalCenter: parent.horizontalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "wb_sunny"
                            size: Theme.iconSize - 4
                            color: Theme.primary
                        }
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        StyledText {
                            text: I18n.tr("Visibility")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: I18n.tr("Good")
                            font.pixelSize: Theme.fontSizeSmall + 1
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
        }

        Column {
            width: parent.width
            height: parent.height - 70 - 95 - Theme.spacingM * 3 - 2
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("7-Day Forecast")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
            }

            Row {
                width: parent.width
                height: parent.height - Theme.fontSizeMedium - Theme.spacingS - Theme.spacingL
                spacing: Theme.spacingXS

                Repeater {
                    model: 7

                    Rectangle {
                        width: (parent.width - Theme.spacingXS * 6) / 7
                        height: parent.height
                        radius: Theme.cornerRadius

                        property var dayDate: {
                            const date = new Date()
                            date.setDate(date.getDate() + index)
                            return date
                        }
                        property bool isToday: index === 0
                        property var forecastData: {
                            if (WeatherService.weather.forecast && WeatherService.weather.forecast.length > index) {
                                return WeatherService.weather.forecast[index]
                            }
                            return null
                        }

                        color: isToday ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Theme.surfaceContainerHigh
                        border.color: isToday ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : "transparent"
                        border.width: isToday ? 1 : 0

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            StyledText {
                                text: Qt.locale().dayName(dayDate.getDay(), Locale.ShortFormat)
                                font.pixelSize: Theme.fontSizeSmall
                                color: isToday ? Theme.primary : Theme.surfaceText
                                font.weight: isToday ? Font.Medium : Font.Normal
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            DankIcon {
                                name: forecastData ? WeatherService.getWeatherIcon(forecastData.wCode || 0) : "cloud"
                                size: Theme.iconSize
                                color: isToday ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.8)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Column {
                                spacing: 2
                                anchors.horizontalCenter: parent.horizontalCenter

                                StyledText {
                                    text: forecastData ? (SettingsData.useFahrenheit ? (forecastData.tempMaxF || forecastData.tempMax) : (forecastData.tempMax || 0)) + "°/" + (SettingsData.useFahrenheit ? (forecastData.tempMinF || forecastData.tempMin) : (forecastData.tempMin || 0)) + "°" : "--/--"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: isToday ? Theme.primary : Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Column {
                                    spacing: 1
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: forecastData && forecastData.sunrise && forecastData.sunset

                                    Row {
                                        spacing: 2
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        DankIcon {
                                            name: "wb_twilight"
                                            size: 8
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: forecastData ? forecastData.sunrise : ""
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Row {
                                        spacing: 2
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        DankIcon {
                                            name: "bedtime"
                                            size: 8
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: forecastData ? forecastData.sunset : ""
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
            }
        }
    }
}