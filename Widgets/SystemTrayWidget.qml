import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    property var theme
    
    height: 32
    implicitWidth: trayRow.implicitWidth
    visible: trayRow.children.length > 0
    
    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: theme.spacingXS
        
        Repeater {
            model: SystemTray.items
            
            delegate: Rectangle {
                required property SystemTrayItem modelData
                
                width: 24
                height: 24
                radius: theme.cornerRadiusSmall
                color: trayItemArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : "transparent"
                
                IconImage {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: parent.modelData.icon
                    smooth: true
                }
                
                MouseArea {
                    id: trayItemArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            parent.modelData.activate()
                        } else if (mouse.button === Qt.RightButton) {
                            menuHandler.showMenu()
                        }
                    }
                }
                
                // Simple menu handling for now
                QtObject {
                    id: menuHandler
                    
                    function showMenu() {
                        if (parent.modelData.hasMenu) {
                            console.log("Right-click menu for:", parent.modelData.title || "Unknown")
                            // TODO: Implement proper menu positioning
                        }
                    }
                }
                
                Behavior on color {
                    ColorAnimation {
                        duration: theme.shortDuration
                        easing.type: theme.standardEasing
                    }
                }
            }
        }
    }
}