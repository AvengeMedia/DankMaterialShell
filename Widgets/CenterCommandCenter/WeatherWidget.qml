import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Common
import qs.Services

Rectangle {
    id: weatherWidget
    
    property var theme: Theme
    
    width: parent.width
    height: parent.height
    radius: theme.cornerRadiusLarge
    color: Qt.rgba(theme.surfaceContainer.r, theme.surfaceContainer.g, theme.surfaceContainer.b, 0.4)
    border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.08)
    border.width: 1
    
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 2
        shadowBlur: 0.5
        shadowColor: Qt.rgba(0, 0, 0, 0.1)
        shadowOpacity: 0.1
    }
    
    // Placeholder when no weather - centered in entire widget
    Column {
        anchors.centerIn: parent
        spacing: theme.spacingS
        visible: !WeatherService.weather.available || WeatherService.weather.temp === 0
        
        Text {
            text: "cloud_off"
            font.family: theme.iconFont
            font.pixelSize: theme.iconSize + 8
            color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.5)
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        Text {
            text: "No Weather Data"
            font.pixelSize: theme.fontSizeMedium
            color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
    
    // Weather content when available - original Column structure
    Column {
        anchors.fill: parent
        anchors.margins: theme.spacingL
        spacing: theme.spacingS
        visible: WeatherService.weather.available && WeatherService.weather.temp !== 0
        
        // Weather header info
        Item {
            width: parent.width
            height: 60
            
            Row {
                anchors.centerIn: parent
                spacing: theme.spacingL
                
                // Weather icon
                Text {
                    text: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                    font.family: theme.iconFont
                    font.pixelSize: theme.iconSize + 8
                    color: theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Column {
                    spacing: theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        text: (Prefs.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°" + (Prefs.useFahrenheit ? "F" : "C")
                        font.pixelSize: theme.fontSizeXLarge
                        color: theme.surfaceText
                        font.weight: Font.Light
                        
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (WeatherService.weather.available) Prefs.setTemperatureUnit(!Prefs.useFahrenheit)
                            enabled: WeatherService.weather.available
                        }
                    }
                    
                    Text {
                        text: WeatherService.weather.city || ""
                        font.pixelSize: theme.fontSizeMedium
                        color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                        visible: text.length > 0
                    }
                }
            }
        }
        
        // Weather details grid
        Grid {
            columns: 2
            spacing: theme.spacingM
            anchors.horizontalCenter: parent.horizontalCenter
            
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
                    text: WeatherService.weather.humidity ? WeatherService.weather.humidity + "%" : "--"
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
                    text: WeatherService.weather.wind || "--"
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
                    text: WeatherService.weather.sunrise || "--"
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
                    text: WeatherService.weather.sunset || "--"
                    font.pixelSize: theme.fontSizeSmall
                    color: theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}