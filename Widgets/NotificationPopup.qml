import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../Common"
import "../Common/Utilities.js" as Utils

PanelWindow {
    id: notificationPopup
    
    visible: root.showNotificationPopup && root.activeNotification
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    
    color: "transparent"
    
    anchors {
        top: true
        right: true
        bottom: true
    }
    
    implicitWidth: 400
    
    Rectangle {
        id: popupContainer
        width: 380
        height: 100
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Theme.barHeight + 16
        anchors.rightMargin: 16
        
        color: Theme.surfaceContainer
        radius: Theme.cornerRadiusLarge
        border.width: 0  // Remove border completely
        
        opacity: root.showNotificationPopup ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }
        
        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: 36  // Don't overlap with close button
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            
            onClicked: {
                console.log("Popup clicked!")
                if (root.activeNotification) {
                    root.handleNotificationClick(root.activeNotification)
                    // Remove notification from history entirely
                    for (let i = 0; i < notificationHistory.count; i++) {
                        if (notificationHistory.get(i).id === root.activeNotification.id) {
                            notificationHistory.remove(i)
                            break
                        }
                    }
                }
                // Always hide popup after click
                Utils.hideNotificationPopup()
            }
        }
        
        // Close button with hover styling
        Rectangle {
            width: 28
            height: 28
            radius: 14
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            color: closeButtonArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"
            
            Text {
                anchors.centerIn: parent
                text: "close"
                font.family: Theme.iconFont
                font.pixelSize: 16
                color: closeButtonArea.containsMouse ? Theme.error : Theme.surfaceText
            }
            
            MouseArea {
                id: closeButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Utils.hideNotificationPopup()
            }
            
            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        }
        
        // Content layout
        Row {
            anchors.fill: parent
            anchors.margins: 12
            anchors.rightMargin: 32
            spacing: 12
            
            // Notification icon based on EXAMPLE NotificationAppIcon pattern
            Rectangle {
                width: 48
                height: 48
                radius: width / 2  // Fully rounded like EXAMPLE
                color: Theme.primaryContainer
                anchors.verticalCenter: parent.verticalCenter
                
                // Material icon fallback (when no app icon)
                Loader {
                    active: !root.activeNotification || !root.activeNotification.appIcon || root.activeNotification.appIcon === ""
                    anchors.fill: parent
                    sourceComponent: Text {
                        anchors.centerIn: parent
                        text: "notifications"
                        font.family: Theme.iconFont
                        font.pixelSize: 20
                        color: Theme.primaryText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                // App icon (when no notification image)
                Loader {
                    active: root.activeNotification && root.activeNotification.appIcon !== "" && (!root.activeNotification.image || root.activeNotification.image === "")
                    anchors.centerIn: parent
                    sourceComponent: IconImage {
                        width: 32
                        height: 32
                        asynchronous: true
                        source: {
                            if (!root.activeNotification || !root.activeNotification.appIcon) return ""
                            let appIcon = root.activeNotification.appIcon
                            // Handle file:// URLs directly
                            if (appIcon.startsWith("file://") || appIcon.startsWith("/")) {
                                return appIcon
                            }
                            // Otherwise treat as icon name
                            return Quickshell.iconPath(appIcon, "image-missing")
                        }
                    }
                }
                
                // Notification image (like Discord user avatar) - PRIORITY
                Loader {
                    active: root.activeNotification && root.activeNotification.image !== ""
                    anchors.fill: parent
                    sourceComponent: Item {
                        anchors.fill: parent
                        
                        Image {
                            id: notifImage
                            anchors.fill: parent
                            readonly property int size: parent.width
                            
                            source: root.activeNotification ? root.activeNotification.image : ""
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                            antialiasing: true
                            asynchronous: true
                            smooth: true
                            
                            // Proper sizing like EXAMPLE
                            width: size
                            height: size
                            sourceSize.width: size
                            sourceSize.height: size
                            
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: notifImage.size
                                    height: notifImage.size
                                    radius: notifImage.size / 2  // Fully rounded
                                }
                            }
                            
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    console.warn("Failed to load notification image:", source)
                                } else if (status === Image.Ready) {
                                    console.log("Notification image loaded:", source, "size:", sourceSize.width + "x" + sourceSize.height)
                                }
                            }
                        }
                        
                        // Small app icon overlay when showing notification image
                        Loader {
                            active: root.activeNotification && root.activeNotification.appIcon !== ""
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            sourceComponent: IconImage {
                                width: 16
                                height: 16
                                asynchronous: true
                                source: {
                                    if (!root.activeNotification || !root.activeNotification.appIcon) return ""
                                    let appIcon = root.activeNotification.appIcon
                                    if (appIcon.startsWith("file://") || appIcon.startsWith("/")) {
                                        return appIcon
                                    }
                                    return Quickshell.iconPath(appIcon, "image-missing")
                                }
                            }
                        }
                    }
                }
            }
            
            // Text content
            Column {
                width: parent.width - 68
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                
                Text {
                    text: root.activeNotification ? (root.activeNotification.summary || "") : ""
                    font.pixelSize: 14
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    width: parent.width
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
                
                Text {
                    text: root.activeNotification ? (root.activeNotification.body || "") : ""
                    font.pixelSize: 12
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }
        }
    }
}