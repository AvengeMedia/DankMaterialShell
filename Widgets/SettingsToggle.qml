import QtQuick
import "../Common"

Rectangle {
    id: root
    
    property string text: ""
    property string description: ""
    property bool checked: false
    
    signal toggled(bool checked)
    
    width: parent.width
    height: 60
    radius: Theme.cornerRadius
    color: toggleArea.containsMouse ? 
           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) :
           Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
    
    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
    
    Row {
        anchors.left: parent.left
        anchors.right: toggle.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingXS
        
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS
            
            Text {
                text: root.text
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
            }
            
            Text {
                text: root.description
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: Math.min(implicitWidth, root.width - 120)
                visible: root.description.length > 0
            }
        }
    }
    
    // Toggle switch
    Rectangle {
        id: toggle
        width: 48
        height: 24
        radius: 12
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        
        color: root.checked ? Theme.primary : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
        
        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
        
        Rectangle {
            id: toggleHandle
            width: 20
            height: 20
            radius: 10
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 2 : 2
            color: root.checked ? Theme.onPrimary : Theme.surfaceText
            
            Behavior on x {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
            
            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        }
    }
    
    MouseArea {
        id: toggleArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}