import QtQuick
import QtQuick.Controls

Rectangle {
    property var theme
    property var root
    
    width: 40
    height: 32
    radius: theme.cornerRadius
    color: notificationArea.containsMouse || root.notificationHistoryVisible ? 
           Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16) : 
           Qt.rgba(theme.secondary.r, theme.secondary.g, theme.secondary.b, 0.08)
    anchors.verticalCenter: parent.verticalCenter
    
    property bool hasUnread: root.notificationHistory.count > 0
    
    Text {
        anchors.centerIn: parent
        text: "notifications"
        font.family: theme.iconFont
        font.pixelSize: theme.iconSize - 6
        font.weight: theme.iconFontWeight
        color: notificationArea.containsMouse || root.notificationHistoryVisible ? 
               theme.primary : theme.surfaceText
    }
    
    Rectangle {
        width: 8
        height: 8
        radius: 4
        color: theme.error
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 6
        anchors.topMargin: 6
        visible: parent.hasUnread
    }
    
    MouseArea {
        id: notificationArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            root.notificationHistoryVisible = !root.notificationHistoryVisible
        }
    }
    
    Behavior on color {
        ColorAnimation {
            duration: theme.shortDuration
            easing.type: theme.standardEasing
        }
    }
}