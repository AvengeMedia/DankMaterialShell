import QtQuick
import "../../Common"

Rectangle {
    id: root
    
    property date currentDate: new Date()
    
    signal clockClicked()
    
    width: clockRow.implicitWidth + Theme.spacingM
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
        id: clockRow
        anchors.centerIn: parent
        spacing: Theme.spacingS
        
        Text {
            text: Prefs.use24HourClock ? Qt.formatTime(root.currentDate, "H:mm") : Qt.formatTime(root.currentDate, "h:mm AP")
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