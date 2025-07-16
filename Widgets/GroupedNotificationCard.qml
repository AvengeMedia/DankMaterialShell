import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.Common
import qs.Services

Rectangle {
    id: root
    
    required property var group
    
    // Context detection - set by parent if in popup
    property bool isPopupContext: false
    
    // Bind directly to the service property for automatic updates
    readonly property bool expanded: NotificationService.expandedGroups[group.key] || false
    
    // Height calculation with popup context adjustment
    height: {
        let baseHeight = expanded ? expandedContent.height + Theme.spacingL * 2 : collapsedContent.height + Theme.spacingL * 2;
        // Add extra height for single notifications in popup context
        if (isPopupContext && group.count === 1) {
            return baseHeight + 12;
        }
        return baseHeight;
    }
    radius: Theme.cornerRadiusLarge
    color: Theme.popupBackground()
    border.color: group.latestNotification.urgency === 2 ? 
                 Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : 
                 Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: group.latestNotification.urgency === 2 ? 2 : 1
    
    // Stabilize layout during content changes
    clip: true
    
    // Priority indicator for urgent notifications
    Rectangle {
        width: 4
        height: parent.height - 16
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        radius: 2
        color: Theme.primary
        visible: group.latestNotification.urgency === 2
    }
    
    Behavior on height {
        enabled: !isPopupContext  // Disable automatic height animation in popup to prevent glitches
        SequentialAnimation {
            // Small pause to let content settle
            PauseAnimation {
                duration: 25
            }
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
    }
    
    // Collapsed view - shows app header and latest notification
    Column {
        id: collapsedContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingS
        visible: !expanded
        
        // App header with group info
        Item {
            width: parent.width
            height: 48 // Fixed height to prevent layout shifts
            
            // Round app icon with proper API usage
            Item {
                id: iconContainer
                width: 48
                height: 48
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                
                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                    border.width: 1
                    clip: true
                    
                    IconImage {
                        anchors.fill: parent
                        anchors.margins: 6
                        source: {
                            console.log("Icon source for", group.appName, ":", group.latestNotification.appIcon)
                            if (group.latestNotification.appIcon && group.latestNotification.appIcon !== "") {
                                return Quickshell.iconPath(group.latestNotification.appIcon, "")
                            }
                            return ""
                        }
                        visible: status === Image.Ready
                        
                        onStatusChanged: {
                            console.log("Icon status changed for", group.appName, ":", status)
                            if (status === Image.Error || status === Image.Null || source === "") {
                                fallbackIcon.visible = true
                            } else if (status === Image.Ready) {
                                fallbackIcon.visible = false
                            }
                        }
                    }
                    
                    // Fallback icon - show by default, hide when real icon loads
                    Text {
                        id: fallbackIcon
                        anchors.centerIn: parent
                        visible: true // Start visible, hide when real icon loads
                        text: {
                            // Use first letter of app name as fallback
                            const appName = group.appName || "?"
                            return appName.charAt(0).toUpperCase()
                        }
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: Theme.primaryText
                    }
                }
                
                // Count badge for multiple notifications - small circle
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: Theme.primary
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: -2
                    anchors.rightMargin: -2
                    visible: group.count > 1
                    
                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: group.count > 99 ? "99+" : group.count.toString()
                        color: Theme.primaryText
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
            }
            
            // App info and latest notification content
            Column {
                id: contentColumn
                anchors.left: iconContainer.right
                anchors.leftMargin: Theme.spacingM
                anchors.right: controlsContainer.left
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS
                
                // App name and timestamp on same line
                Text {
                    width: parent.width
                    text: {
                        if (group.latestNotification.timeStr.length > 0) {
                            return group.appName + " • " + group.latestNotification.timeStr
                        } else {
                            return group.appName
                        }
                    }
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                
                // Latest notification title (emphasized)
                Text {
                    text: group.latestNotification.summary
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium + 1  // Slightly larger for emphasis
                    font.weight: Font.Medium
                    width: parent.width
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }
                
                // Latest notification body (smaller, secondary)
                Text {
                    text: group.latestNotification.body
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    width: parent.width
                    elide: Text.ElideRight
                    maximumLineCount: group.count > 1 ? 1 : 2  // More space for single notifications
                    wrapMode: Text.WordWrap
                    visible: text.length > 0
                }
            }
            
            // Expand/dismiss controls - use anchored layout for stability
            Item {
                id: controlsContainer
                width: 72
                height: 32
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                
                Rectangle {
                    id: expandButton
                    width: 32
                    height: 32
                    radius: 16
                    anchors.left: parent.left
                    color: expandArea.containsMouse ? 
                           Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : 
                           "transparent"
                    visible: group.count > 1
                    
                    Text {
                        anchors.centerIn: parent
                        text: "expand_more"
                        font.family: Theme.iconFont
                        font.pixelSize: 18
                        color: Theme.surfaceText
                        rotation: expanded ? 180 : 0
                        
                        Behavior on rotation {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }
                    
                    MouseArea {
                        id: expandArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            console.log("Expand clicked for group:", group.key, "current state:", expanded)
                            NotificationService.toggleGroupExpansion(group.key)
                        }
                    }
                }
                
                Rectangle {
                    id: dismissButton
                    width: 32
                    height: 32
                    radius: 16
                    anchors.right: parent.right
                    color: dismissArea.containsMouse ? 
                           Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : 
                           "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                        color: Theme.surfaceText
                    }
                    
                    MouseArea {
                        id: dismissArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationService.dismissGroup(group.key)
                    }
                }
            }
        }
        
        // Quick reply for conversations (only if latest notification supports it)
        Row {
            width: parent.width
            spacing: Theme.spacingS
            visible: group.latestNotification.notification.hasInlineReply && !expanded
            
            Rectangle {
                width: parent.width - 60
                height: 36
                radius: 18
                color: Theme.surfaceContainer
                border.color: quickReplyField.activeFocus ? Theme.primary : Theme.outline
                border.width: 1
                
                TextField {
                    id: quickReplyField
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    placeholderText: group.latestNotification.notification.inlineReplyPlaceholder || "Quick reply..."
                    background: Item {}
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    
                    onAccepted: {
                        if (text.length > 0) {
                            group.latestNotification.notification.sendInlineReply(text)
                            text = ""
                        }
                    }
                }
            }
            
            Rectangle {
                width: 52
                height: 36
                radius: 18
                color: quickReplyField.text.length > 0 ? Theme.primary : Theme.surfaceContainer
                border.color: quickReplyField.text.length > 0 ? "transparent" : Theme.outline
                border.width: quickReplyField.text.length > 0 ? 0 : 1
                
                Text {
                    anchors.centerIn: parent
                    text: "send"
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                    color: quickReplyField.text.length > 0 ? Theme.primaryText : Theme.surfaceVariantText
                }
                
                MouseArea {
                    anchors.fill: parent
                    enabled: quickReplyField.text.length > 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        group.latestNotification.notification.sendInlineReply(quickReplyField.text)
                        quickReplyField.text = ""
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
    
    // Expanded view - shows all notifications stacked
    Column {
        id: expandedContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM
        visible: expanded
        
        // Group header with fixed anchored positioning
        Item {
            width: parent.width
            height: 48
            
            // Round app icon - fixed position on left
            Rectangle {
                id: expandedIconContainer
                width: 40
                height: 40
                radius: 20
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                border.width: 1
                clip: true
                
                IconImage {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: group.latestNotification.appIcon ? Quickshell.iconPath(group.latestNotification.appIcon, "") : ""
                    visible: status === Image.Ready
                }
                
                // Fallback for expanded view
                Text {
                    anchors.centerIn: parent
                    visible: !group.latestNotification.appIcon || group.latestNotification.appIcon === ""
                    text: {
                        const appName = group.appName || "?"
                        return appName.charAt(0).toUpperCase()
                    }
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: Theme.primaryText
                }
            }
            
            // App name and count badge - centered area
            Item {
                anchors.left: expandedIconContainer.right
                anchors.leftMargin: Theme.spacingM
                anchors.right: expandedControlsContainer.left
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                height: 32
                
                Text {
                    id: expandedAppNameText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: group.appName
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                }
                
                // Count badge in expanded view - positioned next to app name
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: Theme.primary
                    anchors.left: expandedAppNameText.right
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        anchors.centerIn: parent
                        text: group.count > 99 ? "99+" : group.count.toString()
                        color: Theme.primaryText
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }
            }
            
            // Controls container - fixed position on right
            Item {
                id: expandedControlsContainer
                width: 72
                height: 32
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                
                Rectangle {
                    id: collapseButton
                    width: 32
                    height: 32
                    radius: 16
                    anchors.left: parent.left
                    color: collapseArea.containsMouse ? 
                           Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : 
                           "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "expand_less"
                        font.family: Theme.iconFont
                        font.pixelSize: 18
                        color: Theme.surfaceText
                    }
                    
                    MouseArea {
                        id: collapseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationService.toggleGroupExpansion(group.key)
                    }
                }
                
                Rectangle {
                    id: dismissAllButton
                    width: 32
                    height: 32
                    radius: 16
                    anchors.right: parent.right
                    color: dismissAllArea.containsMouse ? 
                           Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : 
                           "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                        color: Theme.surfaceText
                    }
                    
                    MouseArea {
                        id: dismissAllArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationService.dismissGroup(group.key)
                    }
                }
            }
        }
        
        // Stacked individual notifications with smooth transitions
        Column {
            width: parent.width
            spacing: Theme.spacingS
            
            Repeater {
                model: group.notifications.slice(0, 10) // Show max 10 expanded
                
                delegate: Rectangle {
                    required property var modelData
                    
                    width: parent.width
                    height: notifContent.height + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                    border.color: modelData.urgency === 2 ? 
                                 Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : 
                                 "transparent"
                    border.width: modelData.urgency === 2 ? 1 : 0
                    
                    // Stabilize layout during dismiss operations
                    clip: true
                    
                    // Smooth height transitions
                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                    
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                    
                    Item {
                        id: notifContent
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: Theme.spacingM
                        height: Math.max(individualIcon.height, contentColumn.height)
                        
                        // Small round notification icon/avatar - fixed position on left
                        Rectangle {
                            id: individualIcon
                            width: 32
                            height: 32
                            radius: 16
                            anchors.left: parent.left
                            anchors.top: parent.top
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                            border.width: 1
                            clip: true
                            
                            IconImage {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: modelData.appIcon ? Quickshell.iconPath(modelData.appIcon, "") : ""
                                visible: status === Image.Ready
                            }
                            
                            // Fallback for individual notifications
                            Text {
                                anchors.centerIn: parent
                                visible: !modelData.appIcon || modelData.appIcon === ""
                                text: {
                                    const appName = modelData.appName || "?"
                                    return appName.charAt(0).toUpperCase()
                                }
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: Theme.primaryText
                            }
                        }
                        
                        // Individual dismiss button - fixed position on right
                        Rectangle {
                            id: individualDismissButton
                            width: 24
                            height: 24
                            radius: 12
                            anchors.right: parent.right
                            anchors.top: parent.top
                            color: individualDismissArea.containsMouse ? 
                                   Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : 
                                   "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "close"
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                                color: Theme.surfaceVariantText
                            }
                            
                            MouseArea {
                                id: individualDismissArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotificationService.dismissNotification(modelData)
                            }
                        }
                        
                        // Notification content - fills space between icon and dismiss button
                        Column {
                            id: contentColumn
                            anchors.left: individualIcon.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: individualDismissButton.left
                            anchors.rightMargin: Theme.spacingM
                            anchors.top: parent.top
                            spacing: Theme.spacingXS
                            
                            // Title and timestamp
                            Item {
                                width: parent.width
                                height: Math.max(titleText.height, timeText.height)
                                
                                Text {
                                    id: titleText
                                    anchors.left: parent.left
                                    anchors.right: timeText.left
                                    anchors.rightMargin: Theme.spacingS
                                    text: modelData.summary
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    id: timeText
                                    anchors.right: parent.right
                                    text: modelData.timeStr
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: 10
                                }
                            }
                            
                            // Body text
                            Text {
                                text: modelData.body
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                width: parent.width
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                visible: text.length > 0
                            }
                            
                            // Individual notification inline reply
                            Row {
                                width: parent.width
                                spacing: Theme.spacingS
                                visible: modelData.notification.hasInlineReply
                                
                                Rectangle {
                                    width: parent.width - 50
                                    height: 28
                                    radius: 14
                                    color: Theme.surface
                                    border.color: replyField.activeFocus ? Theme.primary : Theme.outline
                                    border.width: 1
                                    
                                    TextField {
                                        id: replyField
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingXS
                                        placeholderText: modelData.notification.inlineReplyPlaceholder || "Reply..."
                                        background: Item {}
                                        color: Theme.surfaceText
                                        font.pixelSize: 11
                                        
                                        onAccepted: {
                                            if (text.length > 0) {
                                                modelData.notification.sendInlineReply(text)
                                                text = ""
                                            }
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    width: 42
                                    height: 28
                                    radius: 14
                                    color: replyField.text.length > 0 ? Theme.primary : Theme.surfaceContainer
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "send"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 12
                                        color: replyField.text.length > 0 ? Theme.primaryText : Theme.surfaceVariantText
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: replyField.text.length > 0
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            modelData.notification.sendInlineReply(replyField.text)
                                            replyField.text = ""
                                        }
                                    }
                                }
                            }
                            
                            // Actions
                            Row {
                                spacing: Theme.spacingS
                                visible: modelData.actions && modelData.actions.length > 0
                                
                                Repeater {
                                    model: modelData.actions || []
                                    delegate: Rectangle {
                                        width: actionText.width + Theme.spacingS * 2
                                        height: 24
                                        radius: Theme.cornerRadius
                                        color: actionArea.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer
                                        border.color: Theme.outline
                                        border.width: 1
                                        
                                        Text {
                                            id: actionText
                                            anchors.centerIn: parent
                                            text: modelData.text
                                            font.pixelSize: 11
                                            color: Theme.surfaceText
                                            font.weight: Font.Medium
                                        }
                                        
                                        MouseArea {
                                            id: actionArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: modelData.invoke()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // "Show more" if there are many notifications
            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.cornerRadius
                color: Theme.surfaceContainer
                visible: group.count > 10
                
                Text {
                    anchors.centerIn: parent
                    text: `Show ${group.count - 10} more notifications...`
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Implement pagination or full expansion
                        console.log("Show more notifications")
                    }
                }
            }
        }
    }
    
    // Tap to expand (only for collapsed state with multiple notifications)
    MouseArea {
        anchors.fill: parent
        visible: !expanded && group.count > 1
        onClicked: NotificationService.toggleGroupExpansion(group.key)
        z: -1
    }
}