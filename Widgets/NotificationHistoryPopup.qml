import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../Common"

PanelWindow {
    id: notificationHistoryPopup
    
    visible: root.notificationHistoryVisible
    
    implicitWidth: 400
    implicitHeight: 500
    
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
        width: 400
        height: 500
        x: parent.width - width - Theme.spacingL
        y: Theme.barHeight + Theme.spacingS
        color: Theme.surfaceContainer
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        border.width: 1
        
        opacity: root.notificationHistoryVisible ? 1.0 : 0.0
        scale: root.notificationHistoryVisible ? 1.0 : 0.85
        
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
        
        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM
            
            // Header
            Column {
                width: parent.width
                spacing: Theme.spacingM
                
                Row {
                    width: parent.width
                    height: 32
                    
                    Text {
                        text: "Notifications"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Item { width: parent.width - 200; height: 1 }
                }
                
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: Theme.cornerRadius
                    color: clearArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16) : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                    border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.5)
                    border.width: 1
                    visible: notificationHistory.count > 0
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingS
                        
                        Text {
                            text: "delete_sweep"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSizeSmall + 2
                            color: Theme.error
                            font.weight: Theme.iconFontWeight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: "Clear All Notifications"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.error
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            notificationHistory.clear()
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                    
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }
            
            // Notification List
            ScrollView {
                width: parent.width
                height: parent.height - 120
                clip: true
                
                ListView {
                    id: notificationListView
                    model: notificationHistory
                    spacing: Theme.spacingS
                    
                    delegate: Rectangle {
                        width: notificationListView.width
                        height: 80
                        radius: Theme.cornerRadius
                        color: notifArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                        
                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM
                            
                            // Notification icon based on EXAMPLE NotificationAppIcon pattern
                            Rectangle {
                                width: 48
                                height: 48
                                radius: width / 2  // Fully rounded like EXAMPLE
                                color: Theme.primaryContainer
                                anchors.verticalCenter: parent.verticalCenter
                                
                                // Material icon fallback (when no app icon)
                                Loader {
                                    active: !model.appIcon || model.appIcon === ""
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
                                    active: model.appIcon && model.appIcon !== "" && (!model.image || model.image === "")
                                    anchors.centerIn: parent
                                    sourceComponent: IconImage {
                                        width: 32
                                        height: 32
                                        asynchronous: true
                                        source: {
                                            if (!model.appIcon) return ""
                                            // Handle file:// URLs directly
                                            if (model.appIcon.startsWith("file://") || model.appIcon.startsWith("/")) {
                                                return model.appIcon
                                            }
                                            // Otherwise treat as icon name
                                            return Quickshell.iconPath(model.appIcon, "image-missing")
                                        }
                                    }
                                }
                                
                                // Notification image (like Discord user avatar) - PRIORITY
                                Loader {
                                    active: model.image && model.image !== ""
                                    anchors.fill: parent
                                    sourceComponent: Item {
                                        anchors.fill: parent
                                        
                                        Image {
                                            id: historyNotifImage
                                            anchors.fill: parent
                                            readonly property int size: parent.width
                                            property bool imageValid: true
                                            
                                            source: model.image || ""
                                            fillMode: Image.PreserveAspectCrop
                                            cache: true  // Enable caching for history
                                            antialiasing: true
                                            asynchronous: true
                                            smooth: true
                                            visible: imageValid
                                            
                                            // Proper sizing like EXAMPLE
                                            width: size
                                            height: size
                                            sourceSize.width: size
                                            sourceSize.height: size
                                            
                                            layer.enabled: true
                                            layer.effect: OpacityMask {
                                                maskSource: Rectangle {
                                                    width: historyNotifImage.size
                                                    height: historyNotifImage.size
                                                    radius: historyNotifImage.size / 2  // Fully rounded
                                                }
                                            }
                                            
                                            onStatusChanged: {
                                                if (status === Image.Error) {
                                                    console.warn("Failed to load notification history image:", source)
                                                    imageValid = false
                                                } else if (status === Image.Ready) {
                                                    console.log("Notification history image loaded:", source, "size:", sourceSize.width + "x" + sourceSize.height)
                                                    imageValid = true
                                                }
                                            }
                                        }
                                        
                                        // Fallback to app icon when primary image fails
                                        Loader {
                                            active: !historyNotifImage.imageValid && model.appIcon && model.appIcon !== ""
                                            anchors.centerIn: parent
                                            sourceComponent: IconImage {
                                                width: 32
                                                height: 32
                                                asynchronous: true
                                                source: {
                                                    if (!model.appIcon) return ""
                                                    if (model.appIcon.startsWith("file://") || model.appIcon.startsWith("/")) {
                                                        return model.appIcon
                                                    }
                                                    return Quickshell.iconPath(model.appIcon, "image-missing")
                                                }
                                            }
                                        }
                                        
                                        // Small app icon overlay when showing notification image
                                        Loader {
                                            active: historyNotifImage.imageValid && model.appIcon && model.appIcon !== ""
                                            anchors.bottom: parent.bottom
                                            anchors.right: parent.right
                                            sourceComponent: IconImage {
                                                width: 16
                                                height: 16
                                                asynchronous: true
                                                source: {
                                                    if (!model.appIcon) return ""
                                                    if (model.appIcon.startsWith("file://") || model.appIcon.startsWith("/")) {
                                                        return model.appIcon
                                                    }
                                                    return Quickshell.iconPath(model.appIcon, "image-missing")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Content
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 80
                                spacing: Theme.spacingXS
                                
                                Text {
                                    text: model.appName || "App"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
                                    font.weight: Font.Medium
                                }
                                
                                Text {
                                    text: model.summary || ""
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }
                                
                                Text {
                                    text: model.body || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }
                            }
                        }
                        
                        MouseArea {
                            id: notifArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                // Try to handle notification click if it has actions
                                if (model && root.handleNotificationClick) {
                                    root.handleNotificationClick(model)
                                }
                                // Remove from history after handling
                                notificationHistory.remove(index)
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
                
                // Empty state - properly centered
                Item {
                    anchors.fill: parent
                    visible: notificationHistory.count === 0
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM
                        width: parent.width * 0.8
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "notifications_none"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSizeLarge + 16
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
                            font.weight: Theme.iconFontWeight
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No notifications"
                            font.pixelSize: Theme.fontSizeLarge
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Notifications will appear here"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            width: parent.width
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
            root.notificationHistoryVisible = false
        }
    }
}