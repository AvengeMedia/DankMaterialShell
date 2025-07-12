import QtQuick
import QtQuick.Controls
import "../Common"

Rectangle {
    id: archLauncher
    
    property var root
    
    width: 40
    height: 32
    radius: Theme.cornerRadius
    color: launcherArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.12) : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
    anchors.verticalCenter: parent.verticalCenter
    
    Text {
        anchors.centerIn: parent
        text: root.osLogo || "apps"
        font.family: root.osLogo ? "NerdFont" : Theme.iconFont
        font.pixelSize: root.osLogo ? Theme.iconSize - 2 : Theme.iconSize - 2
        font.weight: Theme.iconFontWeight
        color: Theme.surfaceText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    
    MouseArea {
        id: launcherArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            root.appLauncher.toggle()
        }
    }
    
    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}