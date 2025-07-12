import QtQuick
import QtQuick.Controls
import "../Common"

Rectangle {
    id: powerButton
    
    width: 48
    height: 30
    radius: Theme.cornerRadius
    color: powerArea.containsMouse || root.powerMenuVisible ? 
           Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16) : 
           Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
    
    // Power icon
    Text {
        text: "power_settings_new"
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSize - 6
        color: powerArea.containsMouse || root.powerMenuVisible ? Theme.error : Theme.surfaceText
        anchors.centerIn: parent
    }
    
    MouseArea {
        id: powerArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            root.powerMenuVisible = !root.powerMenuVisible
        }
    }
    
    // Tooltip on hover
    Rectangle {
        id: powerTooltip
        width: tooltipText.contentWidth + Theme.spacingM * 2
        height: tooltipText.contentHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        border.width: 1
        visible: powerArea.containsMouse && !root.powerMenuVisible
        
        anchors.bottom: parent.top
        anchors.bottomMargin: Theme.spacingS
        anchors.horizontalCenter: parent.horizontalCenter
        
        opacity: powerArea.containsMouse ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
        
        Text {
            id: tooltipText
            text: "Power Menu"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.centerIn: parent
        }
    }
    
    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}