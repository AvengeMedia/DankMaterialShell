import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string section: "center"
    property var popupTarget: null
    property var parentScreen: null
    property real barHeight: 48
    property real widgetHeight: 30
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 2 : Theme.spacingS

    signal clicked()

    visible: SettingsData.weatherEnabled
    width: visible ? Math.min(100, weatherRow.implicitWidth + horizontalPadding * 2) : 0
    height: widgetHeight
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = weatherArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    Ref {
        service: WeatherService
    }

    Row {
        id: weatherRow

        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
            size: Theme.iconSize - 4
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
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

    }

    MouseArea {
        id: weatherArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                const globalPos = mapToGlobal(0, 0);
                const currentScreen = parentScreen || Screen;
                const screenX = currentScreen.x || 0;
                const relativeX = globalPos.x - screenX;
                popupTarget.setTriggerPosition(relativeX, SettingsData.getPopupYPosition(barHeight), width, section, currentScreen);
            }
            root.clicked();
        }
    }


    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }

    }

}
