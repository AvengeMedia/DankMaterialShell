import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import "."

Rectangle {
    id: ramWidget
    
    property bool showPercentage: true
    property bool showIcon: true
    property var processDropdown: null
    
    width: 55
    height: 30
    radius: Theme.cornerRadius
    color: ramArea.containsMouse ? 
           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
           Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
    
    Component.onCompleted: {
        // RAM widget initialized
    }
    
    MouseArea {
        id: ramArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            if (processDropdown) {
                ProcessMonitorService.setSortBy("memory")
                processDropdown.toggle()
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 3
        
        // RAM icon
        Text {
            text: "developer_board"  // Material Design CPU/processor icon (swapped from CPU widget)
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize - 8
            font.weight: Theme.iconFontWeight
            color: {
                if (SystemMonitorService.memoryUsage > 90) return Theme.error
                if (SystemMonitorService.memoryUsage > 75) return Theme.warning
                return Theme.surfaceText
            }
            anchors.verticalCenter: parent.verticalCenter
        }
        
        // Percentage text
        Text {
            text: (SystemMonitorService.memoryUsage || 0).toFixed(0) + "%"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
