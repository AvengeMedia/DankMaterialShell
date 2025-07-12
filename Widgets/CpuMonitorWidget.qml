import QtQuick
import QtQuick.Controls
import "../Common"
import "../Services"

Rectangle {
    id: cpuWidget
    
    property bool showPercentage: true
    property bool showIcon: true
    
    width: 55
    height: 30
    radius: Theme.cornerRadius
    color: cpuArea.containsMouse ? 
           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
           Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
    
    Component.onCompleted: {
        // CPU widget initialized
    }
    
    MouseArea {
        id: cpuArea
        anchors.fill: parent
        hoverEnabled: true
        
        onClicked: {
            // CPU widget clicked
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 3
        
        // CPU icon
        Text {
            text: "memory"  // Material Design memory icon (swapped from RAM widget)
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize - 8
            font.weight: Theme.iconFontWeight
            color: {
                if (SystemMonitorService.cpuUsage > 80) return Theme.error
                if (SystemMonitorService.cpuUsage > 60) return Theme.warning
                return Theme.surfaceText
            }
            anchors.verticalCenter: parent.verticalCenter
        }
        
        // Percentage text
        Text {
            text: (SystemMonitorService.cpuUsage || 0).toFixed(0) + "%"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
