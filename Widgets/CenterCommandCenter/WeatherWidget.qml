import QtQuick
import QtQuick.Controls
import "../../Common"
import "../../Services"

Rectangle {
    id: weatherWidget
    
    property var theme: Theme
    property var weather
    property bool useFahrenheit: false
    
    width: parent.width
    height: 80
    radius: theme.cornerRadius
    color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08)
    border.color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.2)
    border.width: 1
    
    Row {
        anchors.centerIn: parent
        spacing: theme.spacingL
        
        // Weather icon and temp
        Column {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter
            
            Text {
                text: WeatherService.getWeatherIcon(weather.wCode)
                font.family: theme.iconFont
                font.pixelSize: theme.iconSize + 4
                color: theme.primary
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: (useFahrenheit ? weather.tempF : weather.temp) + "°" + (useFahrenheit ? "F" : "C")
                font.pixelSize: theme.fontSizeLarge
                color: theme.surfaceText
                font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: useFahrenheit = !useFahrenheit
                }
            }
            
            Text {
                text: weather.city
                font.pixelSize: theme.fontSizeSmall
                color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
        
        // Weather details grid
        Grid {
            columns: 2
            spacing: theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            
            Row {
                spacing: theme.spacingXS
                Text {
                    text: "humidity_low"
                    font.family: theme.iconFont
                    font.pixelSize: theme.fontSizeSmall
                    color: theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: weather.humidity + "%"
                    font.pixelSize: theme.fontSizeSmall
                    color: theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            Row {
                spacing: theme.spacingXS
                Text {
                    text: "air"
                    font.family: theme.iconFont
                    font.pixelSize: theme.fontSizeSmall
                    color: theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: weather.wind
                    font.pixelSize: theme.fontSizeSmall
                    color: theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            Row {
                spacing: theme.spacingXS
                Text {
                    text: "wb_twilight"
                    font.family: theme.iconFont
                    font.pixelSize: theme.fontSizeSmall
                    color: theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: weather.sunrise
                    font.pixelSize: theme.fontSizeSmall
                    color: theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            Row {
                spacing: theme.spacingXS
                Text {
                    text: "bedtime"
                    font.family: theme.iconFont
                    font.pixelSize: theme.fontSizeSmall
                    color: theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: weather.sunset
                    font.pixelSize: theme.fontSizeSmall
                    color: theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}