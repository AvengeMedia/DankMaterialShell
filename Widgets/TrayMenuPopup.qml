import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../Common"

PanelWindow {
    id: trayMenuPopup
    
    visible: root.showTrayMenu
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    
    color: "transparent"
    
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    Rectangle {
        id: menuContainer
        x: root.trayMenuX
        y: root.trayMenuY
        width: Math.max(180, Math.min(300, menuList.maxTextWidth + Theme.spacingL * 2))
        height: Math.max(60, menuList.contentHeight + Theme.spacingS * 2)
        color: Theme.surfaceContainer
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        border.width: 1
        
        // Material 3 drop shadow
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: parent.z - 1
        }
        
        // Material 3 animations
        opacity: root.showTrayMenu ? 1.0 : 0.0
        scale: root.showTrayMenu ? 1.0 : 0.85
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
        
        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
        
        Item {
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            
            QsMenuOpener {
                id: menuOpener
                menu: root.currentTrayItem?.menu
            }
            
            // Custom menu styling using ListView
            ListView {
                id: menuList
                anchors.fill: parent
                spacing: 1
                
                // Calculate maximum text width for dynamic menu sizing
                property real maxTextWidth: {
                    let maxWidth = 0
                    if (model && model.values) {
                        for (let i = 0; i < model.values.length; i++) {
                            const item = model.values[i]
                            if (item && item.text) {
                                const textWidth = textMetrics.advanceWidth * item.text.length * 0.6
                                maxWidth = Math.max(maxWidth, textWidth)
                            }
                        }
                    }
                    return Math.min(maxWidth, 280) // Cap at reasonable width
                }
                
                TextMetrics {
                    id: textMetrics
                    font.pixelSize: Theme.fontSizeSmall
                    text: "M"
                }
                model: ScriptModel {
                    values: menuOpener.children ? [...menuOpener.children.values].filter(item => {
                        // Filter out empty items and separators
                        return item && item.text && item.text.trim().length > 0 && !item.isSeparator
                    }) : []
                }
                
                delegate: Rectangle {
                    width: ListView.view.width
                    height: modelData.isSeparator ? 5 : 28
                    radius: modelData.isSeparator ? 0 : Theme.cornerRadiusSmall
                    color: modelData.isSeparator ? "transparent" : 
                           (menuItemArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent")
                    
                    // Separator line
                    Rectangle {
                        visible: modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingS * 2
                        height: 1
                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    }
                    
                    // Menu item content
                    Row {
                        visible: !modelData.isSeparator
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS
                        
                        Text {
                            text: modelData.text || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                    
                    MouseArea {
                        id: menuItemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: modelData.isSeparator ? Qt.ArrowCursor : Qt.PointingHandCursor
                        enabled: !modelData.isSeparator
                        
                        onClicked: {
                            if (modelData.triggered) {
                                modelData.triggered()
                            }
                            root.showTrayMenu = false
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
        }
    }
    
    // Click outside to close
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            root.showTrayMenu = false
        }
    }
}