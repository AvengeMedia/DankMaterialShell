import QtQuick
import "../../Common"

Rectangle {
    id: root
    
    property bool hasUnread: false
    property bool isActive: false
    signal clicked()
    
    width: 40
    height: 32
    radius: Theme.cornerRadius
    color: notificationArea.containsMouse || root.isActive ? 
           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
           Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
    
    Text {
        anchors.centerIn: parent
        text: "notifications"
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSize - 6
        font.weight: Theme.iconFontWeight
        color: notificationArea.containsMouse || root.isActive ? 
               Theme.primary : Theme.surfaceText
    }
    
    // Notification dot indicator
    Rectangle {
        width: 8
        height: 8
        radius: 4
        color: Theme.error
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 6
        anchors.topMargin: 6
        visible: root.hasUnread
    }
    
    MouseArea {
        id: notificationArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            root.clicked()
        }
    }
    
    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}