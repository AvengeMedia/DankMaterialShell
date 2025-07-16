import QtQuick
import Quickshell.Services.SystemTray
import qs.Common

Rectangle {
    id: root
    
    signal menuRequested(var menu, var item, real x, real y)
    
    width: Math.max(40, systemTrayRow.implicitWidth + Theme.spacingS * 2)
    height: 30
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
    visible: systemTrayRow.children.length > 0
    
    Row {
        id: systemTrayRow
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        
        Repeater {
            model: SystemTray.items
            delegate: Rectangle {
                width: 24
                height: 24
                radius: Theme.cornerRadiusSmall
                color: trayItemArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                
                property var trayItem: modelData
                
                Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: {
                        let icon = trayItem?.icon;
                        if (typeof icon === 'string' || icon instanceof String) {
                            if (icon.includes("?path=")) {
                                const [name, path] = icon.split("?path=");
                                const fileName = name.substring(name.lastIndexOf("/") + 1);
                                return `file://${path}/${fileName}`;
                            }
                            return icon;
                        }
                        return ""; // Return empty string if icon is not a string
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
                                customTrayMenu.showMenu(mouse.x, mouse.y)
                            }
                        }
                    }
                }
                
                QtObject {
                    id: customTrayMenu
                    
                    property bool menuVisible: false
                    
                    function showMenu(x, y) {
                        root.menuRequested(customTrayMenu, trayItem, x, y)
                        menuVisible = true
                    }
                    
                    function hideMenu() {
                        menuVisible = false
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