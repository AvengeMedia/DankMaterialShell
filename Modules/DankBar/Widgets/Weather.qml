import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    visible: SettingsData.weatherEnabled

    Ref {
        service: WeatherService
    }

    content: Component {
        Item {
            implicitWidth: {
                if (!SettingsData.weatherEnabled) return 0
                if (root.isVerticalOrientation) return root.widgetThickness - root.horizontalPadding * 2
                return Math.min(100 - root.horizontalPadding * 2, weatherRow.implicitWidth)
            }
            implicitHeight: root.isVerticalOrientation ? weatherColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: weatherColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                    size: Theme.barIconSize(root.barThickness, -6)
                    color: Theme.primary
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        const temp = SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp;
                        if (temp === undefined || temp === null || temp === 0) {
                            return "--";
                        }
                        return temp;
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness)
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: weatherRow
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                    size: Theme.barIconSize(root.barThickness, -6)
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: {
                        const temp = SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp;
                        if (temp === undefined || temp === null || temp === 0) {
                            return "--°" + (SettingsData.useFahrenheit ? "F" : "C");
                        }

                        return temp + "°" + (SettingsData.useFahrenheit ? "F" : "C");
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness)
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
