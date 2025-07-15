import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../Common"
import "../Services"

// Compact notification group component for Android 16-style collapsed groups
Rectangle {
    id: root
    
    property var groupData
    property bool isHovered: false
    property bool showExpandButton: groupData ? groupData.totalCount > 1 : false
    property int groupPriority: groupData ? (groupData.priority || NotificationGroupingService.priorityNormal) : NotificationGroupingService.priorityNormal
    property int notificationType: groupData ? (groupData.notificationType || NotificationGroupingService.typeNormal) : NotificationGroupingService.typeNormal
    
    signal expandRequested()
    signal groupClicked()
    signal groupDismissed()
    
    width: parent.width
    height: getCompactHeight()
    radius: Theme.cornerRadius
    color: getBackgroundColor()
    
    // Enhanced elevation effect for high priority
    layer.enabled: groupPriority === NotificationGroupingService.priorityHigh
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 1
        shadowBlur: 0.2
        shadowColor: Qt.rgba(0, 0, 0, 0.08)
    }
    
    function getCompactHeight() {
        if (notificationType === NotificationGroupingService.typeMedia) {
            return 72  // Slightly taller for media controls
        }
        return groupPriority === NotificationGroupingService.priorityHigh ? 64 : 56
    }
    
    function getBackgroundColor() {
        if (isHovered) {
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
        }
        
        if (groupPriority === NotificationGroupingService.priorityHigh) {
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.04)
        }
        
        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.06)
    }
    
    // Priority indicator strip
    Rectangle {
        width: 3
        height: parent.height - 8
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        radius: 1.5
        color: getPriorityColor()
        visible: groupPriority === NotificationGroupingService.priorityHigh
    }
    
    function getPriorityColor() {
        if (notificationType === NotificationGroupingService.typeConversation) {
            return Theme.primary
        } else if (notificationType === NotificationGroupingService.typeMedia) {
            return "#FF6B35"  // Orange for media
        }
        return Theme.primary
    }
    
    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        anchors.leftMargin: groupPriority === NotificationGroupingService.priorityHigh ? Theme.spacingM + 6 : Theme.spacingM
        spacing: Theme.spacingM
        
        // App Icon
        Rectangle {
            width: getIconSize()
            height: width
            radius: width / 2
            color: getIconBackgroundColor()
            anchors.verticalCenter: parent.verticalCenter
            
            // Subtle glow for high priority
            layer.enabled: groupPriority === NotificationGroupingService.priorityHigh
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 0.4
                shadowColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
            }
            
            function getIconSize() {
                if (groupPriority === NotificationGroupingService.priorityHigh) {
                    return 40
                }
                return 32
            }
            
            function getIconBackgroundColor() {
                if (notificationType === NotificationGroupingService.typeConversation) {
                    return Theme.primaryContainer
                } else if (notificationType === NotificationGroupingService.typeMedia) {
                    return Qt.rgba(1, 0.42, 0.21, 0.2)  // Orange tint for media
                }
                return Theme.primaryContainer
            }
            
            // App icon or fallback
            Loader {
                anchors.fill: parent
                sourceComponent: groupData && groupData.appIcon ? iconComponent : fallbackComponent
            }
            
            Component {
                id: iconComponent
                IconImage {
                    width: parent.width * 0.7
                    height: width
                    anchors.centerIn: parent
                    asynchronous: true
                    source: {
                        if (!groupData || !groupData.appIcon) return ""
                        if (groupData.appIcon.startsWith("file://") || groupData.appIcon.startsWith("/")) {
                            return groupData.appIcon
                        }
                        return Quickshell.iconPath(groupData.appIcon, "image-missing")
                    }
                }
            }
            
            Component {
                id: fallbackComponent
                Text {
                    anchors.centerIn: parent
                    text: getDefaultIcon()
                    font.family: Theme.iconFont
                    font.pixelSize: parent.width * 0.5
                    color: Theme.primaryText
                    
                    function getDefaultIcon() {
                        if (notificationType === NotificationGroupingService.typeConversation) {
                            return "chat"
                        } else if (notificationType === NotificationGroupingService.typeMedia) {
                            return "music_note"
                        } else if (notificationType === NotificationGroupingService.typeSystem) {
                            return "settings"
                        }
                        return "apps"
                    }
                }
            }
        }
        
        // Content area
        Column {
            width: parent.width - parent.spacing - 40 - (showExpandButton ? 40 : 0) - (notificationType === NotificationGroupingService.typeMedia ? 100 : 0)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            
            // App name and count
            Row {
                width: parent.width
                spacing: Theme.spacingS
                
                Text {
                    text: groupData ? groupData.appName : "App"
                    font.pixelSize: groupPriority === NotificationGroupingService.priorityHigh ? Theme.fontSizeLarge : Theme.fontSizeMedium
                    color: Theme.surfaceText
                    font.weight: groupPriority === NotificationGroupingService.priorityHigh ? Font.DemiBold : Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                // Count badge
                Rectangle {
                    width: Math.max(countText.width + 6, 18)
                    height: 18
                    radius: 9
                    color: Theme.primary
                    visible: groupData && groupData.totalCount > 1
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: groupData ? groupData.totalCount.toString() : "0"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primaryText
                        font.weight: Font.Medium
                    }
                }
                
                // Time indicator
                Text {
                    text: getTimeText()
                    font.pixelSize: Theme.fontSizeSmall
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    function getTimeText() {
                        if (!groupData || !groupData.latestNotification) return ""
                        return NotificationGroupingService.formatTimestamp(groupData.latestNotification.timestamp)
                    }
                }
            }
            
            // Summary text
            Text {
                text: getSummaryText()
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.8)
                width: parent.width
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: text.length > 0
                
                function getSummaryText() {
                    if (!groupData) return ""
                    
                    if (groupData.totalCount === 1) {
                        const notif = groupData.latestNotification
                        return notif ? (notif.summary || notif.body || "") : ""
                    }
                    
                    // Use smart summary for multiple notifications
                    return NotificationGroupingService.generateGroupSummary(groupData)
                }
            }
        }
        
        // Media controls (if applicable)
        Loader {
            active: notificationType === NotificationGroupingService.typeMedia
            width: active ? 100 : 0
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            
            sourceComponent: Row {
                spacing: Theme.spacingS
                anchors.centerIn: parent
                
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: Theme.primaryContainer
                    
                    Text {
                        anchors.centerIn: parent
                        text: "skip_previous"
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                        color: Theme.primaryText
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // Handle previous track
                            console.log("Previous track clicked")
                        }
                    }
                }
                
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: Theme.primary
                    
                    Text {
                        anchors.centerIn: parent
                        text: "pause"  // Could be "play_arrow" based on state
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                        color: Theme.primaryText
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // Handle play/pause
                            console.log("Play/pause clicked")
                        }
                    }
                }
                
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: Theme.primaryContainer
                    
                    Text {
                        anchors.centerIn: parent
                        text: "skip_next"
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                        color: Theme.primaryText
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // Handle next track
                            console.log("Next track clicked")
                        }
                    }
                }
            }
        }
        
        // Expand button
        Rectangle {
            width: showExpandButton ? 32 : 0
            height: 32
            radius: 16
            color: expandArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
            anchors.verticalCenter: parent.verticalCenter
            visible: showExpandButton
            
            Text {
                anchors.centerIn: parent
                text: "expand_more"
                font.family: Theme.iconFont
                font.pixelSize: 18
                color: expandArea.containsMouse ? Theme.primary : Theme.surfaceText
            }
            
            MouseArea {
                id: expandArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    expandRequested()
                }
            }
            
            Behavior on width {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        }
    }
    
    // Main interaction area
    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: showExpandButton ? 40 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onEntered: {
            isHovered = true
        }
        
        onExited: {
            isHovered = false
        }
        
        onClicked: {
            if (showExpandButton) {
                expandRequested()
            } else {
                groupClicked()
            }
        }
    }
    
    // Swipe gesture for dismissal
    DragHandler {
        target: null
        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Mouse
        
        property real startX: 0
        property real threshold: 100
        
        onActiveChanged: {
            if (active) {
                startX = centroid.position.x
            } else {
                const deltaX = centroid.position.x - startX
                if (deltaX < -threshold) {
                    groupDismissed()
                }
            }
        }
    }
    
    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}