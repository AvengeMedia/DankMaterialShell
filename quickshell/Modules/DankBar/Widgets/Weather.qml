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
                    color: Theme.widgetIconColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (!WeatherService.weather.available) {
                            return "--";
                        }
                        const temp = SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp;
                        return temp;
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
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
                    color: Theme.widgetIconColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: {
                        if (!WeatherService.weather.available) {
                            return "--°" + (SettingsData.useFahrenheit ? "F" : "C");
                        }
                        const temp = SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp;
                        return temp + "°" + (SettingsData.useFahrenheit ? "F" : "C");
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
