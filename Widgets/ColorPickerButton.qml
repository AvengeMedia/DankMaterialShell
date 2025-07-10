import QtQuick
import QtQuick.Controls

Rectangle {
    property var theme
    property var root
    
    width: 40
    height: 32
    radius: theme.cornerRadius
    color: colorPickerArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : Qt.rgba(theme.secondary.r, theme.secondary.g, theme.secondary.b, 0.08)
    anchors.verticalCenter: parent.verticalCenter
    
    Text {
        anchors.centerIn: parent
        text: "colorize"
        font.family: theme.iconFont
        font.pixelSize: theme.iconSize - 6
        font.weight: theme.iconFontWeight
        color: theme.surfaceText
    }
    
    MouseArea {
        id: colorPickerArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            root.colorPickerProcess.running = true
        }
    }
    
    Behavior on color {
        ColorAnimation {
            duration: theme.shortDuration
            easing.type: theme.standardEasing
        }
    }
}