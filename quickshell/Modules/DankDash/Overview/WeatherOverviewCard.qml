import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Card {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    signal clicked

    Component.onCompleted: WeatherService.addRef()
    Component.onDestruction: WeatherService.removeRef()

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingS
        visible: !WeatherService.weather.available
        z: 1

        DankSpinner {
            size: 24
            visible: WeatherService.weather.loading
            anchors.horizontalCenter: parent.horizontalCenter
        }

        DankIcon {
            name: "cloud_off"
            size: 24
            color: Theme.surfaceTextSecondary
            visible: !WeatherService.weather.loading
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: I18n.tr("No Weather")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            visible: !WeatherService.weather.loading
            anchors.horizontalCenter: parent.horizontalCenter
        }

        DankButton {
            text: I18n.tr("Refresh")
            buttonHeight: 32
            visible: !WeatherService.weather.loading
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: WeatherService.forceRefresh()
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingL
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingL
        visible: WeatherService.weather.available

        DankIcon {
            name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
            size: 48
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            spacing: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                anchors.left: parent.left
                text: {
                    const temp = SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp;
                    if (temp === undefined || temp === null)
                        return "--°" + (SettingsData.useFahrenheit ? "F" : "C");
                    return temp + "°" + (SettingsData.useFahrenheit ? "F" : "C");
                }
                font.pixelSize: Theme.fontSizeXLarge + 4
                color: Theme.surfaceText
                font.weight: Font.Light
            }

            StyledText {
                text: WeatherService.getWeatherCondition(WeatherService.weather.wCode)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                elide: Text.ElideRight
                width: parent.parent.parent.width - 48 - Theme.spacingL * 2
                horizontalAlignment: Text.AlignLeft
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
