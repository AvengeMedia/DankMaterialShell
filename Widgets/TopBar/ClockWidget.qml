import QtQuick
import Quickshell.Services.Mpris
import "../../Common"
import "../../Services"

Rectangle {
    id: root
    
    property bool hasActiveMedia: false
    property var activePlayer: null
    property bool weatherAvailable: false
    property string weatherCode: ""
    property int weatherTemp: 0
    property int weatherTempF: 0
    property bool useFahrenheit: false
    property date currentDate: new Date()
    
    signal clockClicked()
    
    width: {
        let baseWidth = 200
        if (root.hasActiveMedia) {
            let mediaWidth = 24 + Theme.spacingXS + mediaTitleText.implicitWidth + Theme.spacingM + 180
            return Math.min(Math.max(mediaWidth, 300), parent.width - Theme.spacingL * 2)
        } else if (root.weatherAvailable) {
            return Math.min(280, parent.width - Theme.spacingL * 2)
        } else {
            return Math.min(baseWidth, parent.width - Theme.spacingL * 2)
        }
    }
    height: 30
    radius: Theme.cornerRadius
    color: clockMouseArea.containsMouse ? 
           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) :
           Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
    
    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
    
    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingM
        
        // Media info or Weather info
        Row {
            spacing: Theme.spacingXS
            visible: root.hasActiveMedia || root.weatherAvailable
            anchors.verticalCenter: parent.verticalCenter
            
            // Audio visualization placeholder - will be replaced by parent
            Item {
                id: audioVisualizationPlaceholder
                width: 20
                height: Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hasActiveMedia
            }
            
            // Song title when media is playing
            Text {
                id: mediaTitleText
                text: root.activePlayer?.trackTitle || "Unknown Track"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hasActiveMedia
                width: Math.min(implicitWidth, root.width - 100)
                elide: Text.ElideRight
            }
            
            // Weather icon when no media but weather available
            Text {
                text: WeatherService.getWeatherIcon(root.weatherCode)
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize - 2
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.hasActiveMedia && root.weatherAvailable
            }
            
            // Weather temp when no media but weather available
            Text {
                text: (root.useFahrenheit ? root.weatherTempF : root.weatherTemp) + "°" + (root.useFahrenheit ? "F" : "C")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.hasActiveMedia && root.weatherAvailable
            }
        }
        
        // Separator
        Text {
            text: "•"
            font.pixelSize: Theme.fontSizeMedium
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasActiveMedia || root.weatherAvailable
        }
        
        // Time and date
        Row {
            spacing: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            
            Text {
                text: Qt.formatTime(root.currentDate, "h:mm AP")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: "•"
                font.pixelSize: Theme.fontSizeMedium
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: Qt.formatDate(root.currentDate, "ddd d")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.currentDate = new Date()
        }
    }
    
    MouseArea {
        id: clockMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            root.clockClicked()
        }
    }
}