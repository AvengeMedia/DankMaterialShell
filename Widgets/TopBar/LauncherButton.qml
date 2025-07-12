import QtQuick
import "../../Common"
import "../../Services"

Rectangle {
    id: root
    
    width: 40
    height: 32
    radius: Theme.cornerRadius
    color: launcherArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.12) : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
    
    property string osLogo: ""
    
    Text {
        anchors.centerIn: parent
        text: root.osLogo || "apps"
        font.family: root.osLogo ? "NerdFont" : Theme.iconFont
        font.pixelSize: Theme.iconSize - 6
        font.weight: Theme.iconFontWeight
        color: Theme.surfaceText
    }
    
    MouseArea {
        id: launcherArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            LauncherService.toggleAppLauncher()
        }
    }
    
    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}