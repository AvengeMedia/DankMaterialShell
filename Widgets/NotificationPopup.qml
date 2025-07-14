import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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
    }
    
    margins {
        top: Theme.barHeight
        right: 0
    }
    
    implicitWidth: 396
    implicitHeight: 116  // Just the notification area
    
    Rectangle {
        id: popupContainer
        anchors.fill: parent
        anchors.topMargin: 16   // 16px from the top of this window
        anchors.rightMargin: 16  // 16px from the right edge
        
        color: Theme.surfaceContainer
        radius: Theme.cornerRadiusLarge
        border.width: 0  // Remove border completely
        
        opacity: root.showNotificationPopup ? 1.0 : 0.0
        
        // Transform for swipe animations
        transform: Translate {
            id: swipeTransform
            x: 0
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }
        
        // Drag area for swipe gestures
        DragHandler {
            id: dragHandler
            target: null  // We'll handle the transform manually
            acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Mouse
            
            property real startX: 0
            property real currentDelta: 0
            property bool isDismissing: false
            
            onActiveChanged: {
                if (active) {
                    startX = centroid.position.x
                    currentDelta = 0
                    isDismissing = false
                } else {
                    // Handle end of drag
                    let deltaX = centroid.position.x - startX
                    
                    if (Math.abs(deltaX) > 80) { // Threshold for swipe action
                        if (deltaX > 0) {
                            // Swipe right - open notification history
                            swipeOpenHistory()
                        } else {
                            // Swipe left - dismiss notification
                            swipeDismiss()
                        }
                    } else {
                        // Snap back to original position
                        snapBack()
                    }
                }
            }
            
            onCentroidChanged: {
                if (active) {
                    let deltaX = centroid.position.x - startX
                    currentDelta = deltaX
                    
                    // Limit swipe distance and add resistance
                    let maxDistance = 120
                    let resistance = 0.6
                    
                    if (Math.abs(deltaX) > maxDistance) {
                        deltaX = deltaX > 0 ? maxDistance : -maxDistance
                    }
                    
                    swipeTransform.x = deltaX * resistance
                    
                    // Visual feedback - reduce opacity when swiping left (dismiss)
                    if (deltaX < 0) {
                        popupContainer.opacity = Math.max(0.3, 1.0 - Math.abs(deltaX) / 150)
                    } else {
                        popupContainer.opacity = Math.max(0.7, 1.0 - Math.abs(deltaX) / 200)
                    }
                }
            }
            
            function swipeOpenHistory() {
                // Animate to the right and open history
                swipeAnimation.to = 400
                swipeAnimation.onFinished = function() {
                    root.notificationHistoryVisible = true
                    Utils.hideNotificationPopup()
                    snapBack()
                }
                swipeAnimation.start()
            }
            
            function swipeDismiss() {
                // Animate to the left and dismiss
                swipeAnimation.to = -400
                swipeAnimation.onFinished = function() {
                    Utils.hideNotificationPopup()
                    snapBack()
                }
                swipeAnimation.start()
            }
            
            function snapBack() {
                swipeAnimation.to = 0
                swipeAnimation.onFinished = function() {
                    popupContainer.opacity = Qt.binding(() => root.showNotificationPopup ? 1.0 : 0.0)
                }
                swipeAnimation.start()
            }
        }
        
        // Swipe animation
        NumberAnimation {
            id: swipeAnimation
            target: swipeTransform
            property: "x"
            duration: 200
            easing.type: Easing.OutCubic
        }
        
        // Tap area for notification interaction
        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: 36  // Don't overlap with close button
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            
            onClicked: (mouse) => {
                console.log("Popup clicked!")
                if (root.activeNotification) {
                    root.handleNotificationClick(root.activeNotification)
                    // Don't remove from history - just hide popup
                }
                // Hide popup but keep in history
                Utils.hideNotificationPopup()
                mouse.accepted = true  // Prevent event propagation
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
            color: closeButtonArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
            
            Text {
                anchors.centerIn: parent
                text: "close"
                font.family: Theme.iconFont
                font.pixelSize: 16
                color: closeButtonArea.containsMouse ? Theme.primary : Theme.surfaceText
            }
            
            MouseArea {
                id: closeButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: (mouse) => {
                    Utils.hideNotificationPopup()
                    mouse.accepted = true  // Prevent event propagation
                }
            }
            
            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        }
        
        // Small dismiss button - bottom right corner
        Rectangle {
            width: 60
            height: 18
            radius: 9
            color: dismissButtonArea.containsMouse ? 
                   Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                   Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.1)
            border.color: dismissButtonArea.containsMouse ? 
                         Theme.primary : 
                         Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.5)
            border.width: 1
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 12
            anchors.bottomMargin: 10
            
            Row {
                anchors.centerIn: parent
                spacing: 4
                
                Text {
                    text: "archive"
                    font.family: Theme.iconFont
                    font.pixelSize: 10
                    color: dismissButtonArea.containsMouse ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    text: "Dismiss"
                    font.pixelSize: 10
                    color: dismissButtonArea.containsMouse ? Theme.primary : Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            MouseArea {
                id: dismissButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    // Just hide the popup, keep in history
                    Utils.hideNotificationPopup()
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
        
        // Content layout
        Row {
            anchors.fill: parent
            anchors.margins: 12
            anchors.rightMargin: 32
            anchors.bottomMargin: 6  // Reduced bottom margin to account for dismiss button
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
                            
                            source: root.activeNotification ? root.activeNotification.image : ""
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                            antialiasing: true
                            asynchronous: true
                            smooth: true
                            
                            // Use the parent size for optimization
                            sourceSize.width: parent.width
                            sourceSize.height: parent.height
                            
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: Rectangle {
                                    width: 48
                                    height: 48
                                    radius: 24  // Fully rounded
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