import QtQuick
import QtQuick.Controls

Rectangle {
    id: archLauncher
    
    property var theme
    property var root
    
    width: 40
    height: 32
    radius: theme.cornerRadius
    color: launcherArea.containsMouse ? Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.12) : Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.08)
    anchors.verticalCenter: parent.verticalCenter
    
    Text {
        anchors.centerIn: parent
        text: root.osLogo || "apps"
        font.family: root.osLogo ? "NerdFont" : theme.iconFont
        font.pixelSize: root.osLogo ? theme.iconSize - 2 : theme.iconSize - 2
        font.weight: theme.iconFontWeight
        color: theme.surfaceText
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
            duration: theme.shortDuration
            easing.type: theme.standardEasing
        }
    }
}