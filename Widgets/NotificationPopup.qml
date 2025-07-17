import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.Common
import qs.Services

PanelWindow {
    id: notificationPopup
    objectName: "notificationPopup"
    
    visible: NotificationService.groupedPopups.length > 0
    
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
        right: 12
    }
    
    implicitWidth: 400
    implicitHeight: notificationsList.height + 32
    
    // Expose key child objects for testing
    // Expose the currently visible quickReplyField for testing
    property TextField quickReplyField: null
    // Expose the currently visible iconContainer for testing
    property Item iconContainer: null
    // Expose the currently visible expandedContent for testing
    property Column expandedContent: null
    // Expose the currently visible hoverArea for testing
    property MouseArea hoverArea: null

    Column {
        id: notificationsList
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 16
        anchors.rightMargin: 16
        spacing: Theme.spacingM
        width: 380
        
        Repeater {
            model: NotificationService.groupedPopups
            
            delegate: Rectangle {
                required property var modelData
                
                // Context detection for popup
                readonly property bool isPopupContext: true
                readonly property bool expanded: NotificationService.expandedGroups[modelData.key] || false
                
                width: parent.width
                height: {
                    let calculatedHeight;
                    if (expanded) {
                        // Calculate expanded height properly: header (48) + spacing + notifications
                        let headerHeight = 48 + Theme.spacingM
                        let maxNotificationsInPopup = Math.min(modelData.notifications.length, 5)
                        let notificationHeight = maxNotificationsInPopup * (60 + Theme.spacingS)
                        calculatedHeight = headerHeight + notificationHeight + Theme.spacingL * 2
                    } else {
                        // Collapsed height: header (72) + quick reply if present
                        calculatedHeight = 72 + Theme.spacingS * 2
                        if (modelData.latestNotification.notification.hasInlineReply) {
                            calculatedHeight += 36 + Theme.spacingS
                        }
                        calculatedHeight += Theme.spacingL * 2
                    }
                    
                    // Add extra height for single notifications in popup context
                    if (isPopupContext && modelData.count === 1) {
                        calculatedHeight += 12;
                    }
                    return calculatedHeight;
                }
                radius: Theme.cornerRadiusLarge
                color: Theme.popupBackground()
                border.color: modelData.latestNotification.urgency === 2 ? 
                             Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : 
                             Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                border.width: modelData.latestNotification.urgency === 2 ? 2 : 1
                
                // Stabilize layout during content changes
                clip: true
                
                // Smooth popup animations
                transform: Translate {
                    x: notificationPopup.visible ? 0 : 400
                    Behavior on x {
                        NumberAnimation {
                            duration: 350
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                
                opacity: notificationPopup.visible ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
                
                scale: notificationPopup.visible ? 1.0 : 0.98
                Behavior on scale {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutCubic
                    }
                }
                
                // Priority indicator for urgent notifications
                Rectangle {
                    width: 4
                    height: parent.height - 16
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 2
                    color: Theme.primary
                    visible: modelData.latestNotification.urgency === 2
                }
                
                Behavior on height {
                    enabled: !isPopupContext  // Disable automatic height animation in popup to prevent glitches
                    SequentialAnimation {
                        PauseAnimation { duration: 25 }
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
                        height: 72 // Increased height for better text spacing
                        
                        // Round app icon with proper API usage
                        Item {
                            id: iconContainer
                            Component.onCompleted: {
                                // Expose this iconContainer to the root for testing if visible
                                notificationPopup.iconContainer = iconContainer
                            }
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
                                        if (modelData.latestNotification.appIcon && modelData.latestNotification.appIcon !== "") {
                                            return Quickshell.iconPath(modelData.latestNotification.appIcon, "")
                                        }
                                        return ""
                                    }
                                    visible: status === Image.Ready
                                    
                                    onStatusChanged: {
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
                                        const appName = modelData.appName || "?"
                                        return appName.charAt(0).toUpperCase()
                                    }
                                    font.pixelSize: 20
                                    font.weight: Font.Bold
                                    color: Theme.primaryText
                                }
                            }
                            
                            // Count badge for multiple notifications - smaller circle
                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                color: Theme.primary
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: -2
                                anchors.rightMargin: -2
                                visible: modelData.count > 1
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.count > 99 ? "99+" : modelData.count.toString()
                                    color: Theme.primaryText
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }
                        }
                        
                        // App info and latest notification content
                        Column {
                            anchors.left: iconContainer.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: controlsContainer.left
                            anchors.rightMargin: Theme.spacingM
                            anchors.top: parent.top
                            anchors.topMargin: Theme.spacingS
                            spacing: Theme.spacingS
                            
                            // App name and timestamp on same line
                            Text {
                                width: parent.width
                                text: {
                                    if (modelData.latestNotification.timeStr.length > 0) {
                                        return modelData.appName + " • " + modelData.latestNotification.timeStr
                                    } else {
                                        return modelData.appName
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
                                text: modelData.latestNotification.summary
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
                                text: modelData.latestNotification.body
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                width: parent.width
                                elide: Text.ElideRight
                                maximumLineCount: modelData.count > 1 ? 1 : 2  // More space for single notifications
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
                                width: 32
                                height: 32
                                radius: 16
                                anchors.left: parent.left
                                color: expandArea.containsMouse ? 
                                       Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : 
                                       "transparent"
                                visible: modelData.count > 1
                                
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
    // ...existing code...
                                    id: expandArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        console.log("Expand clicked - pausing timer")
                                        dismissTimer.stop()
                                        NotificationService.toggleGroupExpansion(modelData.key)
                                    }
                                }
                            }
                            
                            Rectangle {
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
                                    onClicked: NotificationService.dismissGroup(modelData.key)
                                }
                            }
                        }
                    }
                    
                    // Quick reply for conversations (only if latest notification supports it)
                    Row {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: modelData.latestNotification.notification.hasInlineReply && !expanded
                        
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
                                placeholderText: modelData.latestNotification.notification.inlineReplyPlaceholder || "Quick reply..."
                                background: Item {}
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                
                                onAccepted: {
                                    if (text.length > 0) {
                                        modelData.latestNotification.notification.sendInlineReply(text)
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
                                    modelData.latestNotification.notification.sendInlineReply(quickReplyField.text)
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
                    Component.onCompleted: {
                        // Expose this expandedContent to the root for testing if visible
                        notificationPopup.expandedContent = expandedContent
                    }
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
                                source: modelData.latestNotification.appIcon ? Quickshell.iconPath(modelData.latestNotification.appIcon, "") : ""
                                visible: status === Image.Ready
                            }
                            
                            // Fallback for expanded view
                            Text {
                                anchors.centerIn: parent
                                visible: !modelData.latestNotification.appIcon || modelData.latestNotification.appIcon === ""
                                text: {
                                    const appName = modelData.appName || "?"
                                    return appName.charAt(0).toUpperCase()
                                }
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: Theme.primaryText
                            }
                        }
                        
                        // App name and count badge - centered area
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 52
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.appName
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                        }
                        
                        // Controls container - fixed position on right
                        Item {
                            width: 72
                            height: 32
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Rectangle {
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
                                    onClicked: {
                                        console.log("Expand clicked - pausing timer")
                                        dismissTimer.stop()
                                        NotificationService.toggleGroupExpansion(modelData.key)
                                    }
                                }
                            }
                            
                            Rectangle {
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
                                    onClicked: NotificationService.dismissGroup(modelData.key)
                                }
                            }
                        }
                    }
                    
                    // Stacked individual notifications with smooth transitions
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        
                        Repeater {
                            model: modelData.notifications.slice(0, 5) // Show max 5 in popup
                            
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
                                
                                Item {
                                    id: notifContent
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: Theme.spacingM
                                    height: Math.max(32, contentColumn.height)
                                    
                                    // Small round notification icon/avatar - fixed position on left
                                    Rectangle {
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
                                        anchors.left: parent.left
                                        anchors.leftMargin: 44
                                        anchors.right: parent.right
                                        anchors.rightMargin: 36
                                        anchors.top: parent.top
                                        spacing: Theme.spacingXS
                                        
                                        // Title and timestamp
                                        Text {
                                            text: modelData.summary
                                            color: Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            width: parent.width
                                            elide: Text.ElideRight
                                        }
                                        
                                        // Body text
                                        Text {
                                            text: modelData.body
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
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
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Hover to pause auto-dismiss - MUST be properly configured
                MouseArea {
                    id: hoverArea
                    Component.onCompleted: {
                        // Expose this hoverArea to the root for testing if visible
                        notificationPopup.hoverArea = hoverArea
                    }
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    z: 10  // Higher z-order to ensure hover detection
                    propagateComposedEvents: true
                    
                    onEntered: {
                        console.log("Notification hover entered - pausing timer")
                        dismissTimer.stop()
                    }
                    
                    onExited: {
                        console.log("Notification hover exited - resuming timer")
                        if (modelData.latestNotification.popup && !expanded) {
                            dismissTimer.restart()
                        }
                    }
                }
                
                // Auto-dismiss timer - properly pauses on hover
                Timer {
                    id: dismissTimer
                    running: modelData.latestNotification.popup && !expanded
                    interval: modelData.latestNotification.notification.expireTimeout > 0 ? 
                             modelData.latestNotification.notification.expireTimeout * 1000 : 5000
                    onTriggered: {
                        console.log("Timer triggered - hover state:", hoverArea.containsMouse, "expanded:", expanded)
                        if (!hoverArea.containsMouse && !expanded) {
                            console.log("Dismissing notification")
                            modelData.latestNotification.popup = false
                        } else {
                            console.log("Conditions not met - not dismissing")
                        }
                    }
                }
            }
        }
    }
    // Smooth height animation
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.emphasizedEasing
        }
    }
}