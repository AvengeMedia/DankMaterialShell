import QtQuick
import "../Common"

Column {
    id: root
    
    property string title: ""
    property string iconName: ""
    property alias content: contentLoader.sourceComponent
    
    width: parent.width
    spacing: Theme.spacingM
    
    // Section header
    Row {
        width: parent.width
        spacing: Theme.spacingS
        
        Text {
            text: iconName
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize - 2
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }
        
        Text {
            text: title
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    
    // Divider
    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
    }
    
    // Content
    Loader {
        id: contentLoader
        width: parent.width
    }
}