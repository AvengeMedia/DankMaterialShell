import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray

Rectangle {
    property var theme
    property var root
    
    width: Math.max(40, systemTrayRow.implicitWidth + theme.spacingS * 2)
    height: 32
    radius: theme.cornerRadius
    color: Qt.rgba(theme.secondary.r, theme.secondary.g, theme.secondary.b, 0.08)
    anchors.verticalCenter: parent.verticalCenter
    visible: systemTrayRow.children.length > 0
    
    Row {
        id: systemTrayRow
        anchors.centerIn: parent
        spacing: theme.spacingXS
        
        Repeater {
            model: SystemTray.items
            delegate: Rectangle {
                width: 24
                height: 24
                radius: theme.cornerRadiusSmall
                color: trayItemArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : "transparent"
                
                property var trayItem: modelData
                
                Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: {
                        let icon = trayItem?.icon || "";
                        if (!icon) return "";
                        
                        if (icon.includes("?path=")) {
                            const [name, path] = icon.split("?path=");
                            const fileName = name.substring(name.lastIndexOf("/") + 1);
                            return `file://${path}/${fileName}`;
                        }
                        return icon;
                    }
                    asynchronous: true
                    smooth: true
                    fillMode: Image.PreserveAspectFit
                }
                
                MouseArea {
                    id: trayItemArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: (mouse) => {
                        if (!trayItem) return;
                        
                        if (mouse.button === Qt.LeftButton) {
                            if (!trayItem.onlyMenu) {
                                trayItem.activate()
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            if (trayItem.hasMenu) {
                                console.log("Right-click detected, showing menu for:", trayItem.title || "Unknown")
                                customTrayMenu.showMenu(mouse.x, mouse.y)
                            } else {
                                console.log("No menu available for:", trayItem.title || "Unknown")
                            }
                        }
                    }
                }
                
                QtObject {
                    id: customTrayMenu
                    
                    property bool menuVisible: false
                    
                    function showMenu(x, y) {
                        root.currentTrayMenu = customTrayMenu
                        root.currentTrayItem = trayItem
                        
                        root.trayMenuX = parent.parent.parent.parent.x + parent.parent.parent.parent.width - 180 - theme.spacingL
                        root.trayMenuY = theme.barHeight + theme.spacingS
                        
                        console.log("Showing menu at:", root.trayMenuX, root.trayMenuY)
                        menuVisible = true
                        root.showTrayMenu = true
                    }
                    
                    function hideMenu() {
                        menuVisible = false
                        root.showTrayMenu = false
                        root.currentTrayMenu = null
                        root.currentTrayItem = null
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