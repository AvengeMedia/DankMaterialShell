import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../Common"

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
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        border.width: 1
        
        opacity: root.showNotificationPopup ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: Utils.hideNotificationPopup()
        }
        
        // Close button with cursor pointer
        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            text: "×"
            font.pixelSize: 16
            color: Theme.surfaceText
            
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Utils.hideNotificationPopup()
            }
        }
        
        // Content layout
        Row {
            anchors.fill: parent
            anchors.margins: 12
            anchors.rightMargin: 32
            spacing: 12
            
            // Notification icon using reference pattern
            Rectangle {
                width: 40
                height: 40
                radius: 8
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                anchors.verticalCenter: parent.verticalCenter
                
                // Fallback material icon when no app icon
                Loader {
                    active: !root.activeNotification || root.activeNotification.appIcon === ""
                    anchors.fill: parent
                    sourceComponent: Text {
                        anchors.centerIn: parent
                        text: "notifications"
                        font.family: Theme.iconFont
                        font.pixelSize: 20
                        color: Theme.primary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                // App icon when no notification image
                Loader {
                    active: root.activeNotification && root.activeNotification.appIcon !== "" && (root.activeNotification.image === "" || !root.activeNotification.image)
                    anchors.fill: parent
                    anchors.margins: 4
                    sourceComponent: IconImage {
                        anchors.fill: parent
                        asynchronous: true
                        source: {
                            if (!root.activeNotification) return ""
                            let iconPath = root.activeNotification.appIcon
                            // Skip file:// URLs as they're usually screenshots/images, not icons
                            if (iconPath && iconPath.startsWith("file://")) return ""
                            return iconPath ? Quickshell.iconPath(iconPath, "image-missing") : ""
                        }
                    }
                }
                
                // Notification image with rounded corners
                Loader {
                    active: root.activeNotification && root.activeNotification.image !== ""
                    anchors.fill: parent
                    sourceComponent: Item {
                        anchors.fill: parent
                        clip: true
                        
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: "transparent"
                            clip: true
                            
                            Image {
                                id: notifImage
                                anchors.fill: parent
                                source: root.activeNotification ? root.activeNotification.image : ""
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                                antialiasing: true
                                asynchronous: true
                                smooth: true
                                
                                // Ensure minimum size and proper scaling
                                sourceSize.width: 64
                                sourceSize.height: 64
                                
                                onStatusChanged: {
                                    if (status === Image.Error) {
                                        console.warn("Failed to load notification image:", source)
                                    } else if (status === Image.Ready) {
                                        console.log("Notification image loaded:", source, "size:", sourceSize)
                                    }
                                }
                            }
                        }
                        
                        // Small app icon overlay when showing notification image
                        Loader {
                            active: root.activeNotification && root.activeNotification.appIcon !== ""
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 2
                            sourceComponent: IconImage {
                                width: 16
                                height: 16
                                asynchronous: true
                                source: root.activeNotification ? Quickshell.iconPath(root.activeNotification.appIcon, "image-missing") : ""
                            }
                        }
                    }
                }
            }
            
            // Text content
            Column {
                width: parent.width - 52
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