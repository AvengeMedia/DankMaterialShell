import QtQuick
import "../../Common"
import "../../Services"

Rectangle {
    id: root
    
    width: Math.max(contentRow.implicitWidth + Theme.spacingS * 2, 60)
    height: 30
    radius: Theme.cornerRadius
    color: mouseArea.containsMouse ? 
           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) :
           Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
    
    visible: FocusedWindowService.niriAvailable && (FocusedWindowService.focusedAppName || FocusedWindowService.focusedWindowTitle)
    
    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
    
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.spacingS
        
        Text {
            id: appText
            text: FocusedWindowService.focusedAppName || ""
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            
            // Limit app name width
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, 120)
        }
        
        Text {
            text: "•"
            font.pixelSize: Theme.fontSizeMedium
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.verticalCenter: parent.verticalCenter
            visible: appText.text && titleText.text
        }
        
        Text {
            id: titleText
            text: FocusedWindowService.focusedWindowTitle || ""
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            
            // Limit title width - increased for longer titles
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, 350)
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        
        // Non-interactive widget - just provides hover state for visual feedback
    }
    
    // Smooth width animation when the text changes
    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}