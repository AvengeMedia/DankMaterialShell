import QtQuick
import "../../Common"
import "../../Services"

Rectangle {
    id: root
    
    property bool weatherAvailable: false
    property string weatherCode: ""
    property int weatherTemp: 0
    property int weatherTempF: 0
    
    signal clicked()
    
    visible: weatherAvailable
    width: weatherAvailable ? Math.min(100, weatherRow.implicitWidth + Theme.spacingS) : 0
    height: 30
    radius: Theme.cornerRadius
    color: weatherArea.containsMouse ? 
           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) :
           Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
    
    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
    
    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
    
    Row {
        id: weatherRow
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        
        Text {
            text: WeatherService.getWeatherIcon(weatherCode)
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize - 4
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }
        
        Text {
            text: (Prefs.useFahrenheit ? weatherTempF : weatherTemp) + "°" + (Prefs.useFahrenheit ? "F" : "C")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    
    MouseArea {
        id: weatherArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: root.clicked()
    }
}