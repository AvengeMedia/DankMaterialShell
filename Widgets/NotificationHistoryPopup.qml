import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../Common"
import "../Services"

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
    
    // Timer to update timestamps periodically
    Timer {
        id: timestampUpdateTimer
        interval: 60000  // Update every minute
        running: visible
        repeat: true
        onTriggered: {
            // Force model refresh to update timestamps
            groupedNotificationListView.model = NotificationGroupingService.groupedNotifications
        }
    }
    
    Rectangle {
        width: 400
        height: 500
        x: parent.width - width - Theme.spacingL
        y: Theme.barHeight + Theme.spacingXS
        color: Theme.popupBackground()
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 0.5
        
        // TopBar dropdown animation - slide down from bar (consistent with other TopBar widgets)
        transform: [
            Scale {
                id: scaleTransform
                origin.x: parent.width  // Scale from top-right corner
                origin.y: 0
                xScale: root.notificationHistoryVisible ? 1.0 : 0.95
                yScale: root.notificationHistoryVisible ? 1.0 : 0.8
            },
            Translate {
                id: translateTransform
                x: root.notificationHistoryVisible ? 0 : 15  // Slide slightly left when hidden
                y: root.notificationHistoryVisible ? 0 : -30
            }
        ]
        
        opacity: root.notificationHistoryVisible ? 1.0 : 0.0
        
        // Single coordinated animation for better performance
        states: [
            State {
                name: "visible"
                when: root.notificationHistoryVisible
                PropertyChanges { target: scaleTransform; xScale: 1.0; yScale: 1.0 }
                PropertyChanges { target: translateTransform; x: 0; y: 0 }
            },
            State {
                name: "hidden"
                when: !root.notificationHistoryVisible
                PropertyChanges { target: scaleTransform; xScale: 0.95; yScale: 0.8 }
                PropertyChanges { target: translateTransform; x: 15; y: -30 }
            }
        ]
        
        transitions: [
            Transition {
                from: "*"; to: "*"
                ParallelAnimation {
                    NumberAnimation {
                        targets: [scaleTransform, translateTransform]
                        properties: "xScale,yScale,x,y"
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }
        ]
        
        Behavior on opacity {
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
                        id: notificationsTitle
                        text: "Notifications"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Item { 
                        width: parent.width - notificationsTitle.width - clearButton.width - Theme.spacingM
                        height: 1 
                    }
                    
                    // Compact Clear All Button
                    Rectangle {
                        id: clearButton
                        width: 120
                        height: 28
                        radius: Theme.cornerRadius
                        anchors.verticalCenter: parent.verticalCenter
                        visible: NotificationGroupingService.totalCount > 0
                        
                        color: clearArea.containsMouse ? 
                               Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                               Theme.surfaceContainer
                        
                        border.color: clearArea.containsMouse ? 
                                     Theme.primary : 
                                     Theme.outline
                        border.width: 1
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS
                            
                            Text {
                                text: "delete_sweep"
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSizeSmall
                                color: clearArea.containsMouse ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Text {
                                text: "Clear All"
                                font.pixelSize: Theme.fontSizeSmall
                                color: clearArea.containsMouse ? Theme.primary : Theme.surfaceText
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
                                NotificationGroupingService.clearAllNotifications()
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
            }
            
            // Grouped Notification List
            ScrollView {
                width: parent.width
                height: parent.height - 120
                clip: true
                contentWidth: -1  // Fit to width
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                
                ListView {
                    id: groupedNotificationListView
                    model: NotificationGroupingService.groupedNotifications
                    spacing: Theme.spacingM
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 1500
                    maximumFlickVelocity: 2000
                    
                    delegate: Column {
                        width: groupedNotificationListView.width
                        spacing: Theme.spacingXS
                        
                        property var groupData: model
                        property bool isExpanded: model.expanded || false
                        property int groupPriority: model.priority || NotificationGroupingService.priorityNormal
                        property int notificationType: model.notificationType || NotificationGroupingService.typeNormal
                        
                        // Group Header with enhanced visual hierarchy
                        Rectangle {
                            width: parent.width
                            height: getGroupHeaderHeight()
                            radius: Theme.cornerRadius
                            color: getGroupHeaderColor()
                            
                            // Enhanced elevation effect based on priority
                            layer.enabled: groupPriority === NotificationGroupingService.priorityHigh
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowHorizontalOffset: 0
                                shadowVerticalOffset: 2
                                shadowBlur: 0.4
                                shadowColor: Qt.rgba(0, 0, 0, 0.1)
                            }
                            
                            // Priority indicator strip
                            Rectangle {
                                width: 4
                                height: parent.height
                                anchors.left: parent.left
                                radius: 2
                                color: getPriorityColor()
                                visible: groupPriority === NotificationGroupingService.priorityHigh
                            }
                            
                            function getGroupHeaderHeight() {
                                // Dynamic height based on content length and priority
                                // Calculate height based on message content length
                                const bodyText = (model.latestNotification && model.latestNotification.body) ? model.latestNotification.body : ""
                                const bodyLines = Math.min(Math.ceil((bodyText.length / 50)), 4) // Estimate lines needed
                                const bodyHeight = bodyLines * 16 // 16px per line
                                const indicatorHeight = model.totalCount > 1 ? 16 : 0
                                const paddingTop = Theme.spacingM
                                const paddingBottom = Theme.spacingS
                                
                                let calculatedHeight = paddingTop + 20 + bodyHeight + indicatorHeight + paddingBottom
                                
                                // Minimum height based on priority
                                const minHeight = groupPriority === NotificationGroupingService.priorityHigh ? 90 : 80
                                
                                return Math.max(calculatedHeight, minHeight)
                            }
                            
                            function getGroupHeaderColor() {
                                if (groupHeaderArea.containsMouse) {
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                }
                                
                                // Different background colors based on priority
                                if (groupPriority === NotificationGroupingService.priorityHigh) {
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.05)
                                }
                                
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                            }
                            
                            function getPriorityColor() {
                                if (notificationType === NotificationGroupingService.typeConversation) {
                                    return Theme.primary
                                } else if (notificationType === NotificationGroupingService.typeMedia) {
                                    return "#FF6B35"  // Orange for media
                                }
                                return Theme.primary
                            }
                            
                            // App Icon with enhanced styling
                            Rectangle {
                                width: groupPriority === NotificationGroupingService.priorityHigh ? 40 : 32
                                height: width
                                radius: width / 2
                                color: getIconBackgroundColor()
                                anchors.left: parent.left
                                anchors.leftMargin: groupPriority === NotificationGroupingService.priorityHigh ? Theme.spacingM + 4 : Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                
                                // Removed glow effect as requested
                                
                                function getIconBackgroundColor() {
                                    if (notificationType === NotificationGroupingService.typeConversation) {
                                        return Theme.primaryContainer
                                    } else if (notificationType === NotificationGroupingService.typeMedia) {
                                        return Qt.rgba(1, 0.42, 0.21, 0.2)  // Orange tint for media
                                    }
                                    return Theme.primaryContainer
                                }
                                
                                // Material icon fallback with type-specific icons
                                Loader {
                                    active: !model.appIcon || model.appIcon === ""
                                    anchors.fill: parent
                                    sourceComponent: Text {
                                        anchors.centerIn: parent
                                        text: getDefaultIcon()
                                        font.family: Theme.iconFont
                                        font.pixelSize: groupPriority === NotificationGroupingService.priorityHigh ? 20 : 16
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
                                
                                // App icon with priority-based sizing
                                Loader {
                                    active: model.appIcon && model.appIcon !== ""
                                    anchors.centerIn: parent
                                    sourceComponent: IconImage {
                                        width: groupPriority === NotificationGroupingService.priorityHigh ? 28 : 24
                                        height: width
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
                            
                            // App Name and Summary with enhanced layout
                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM + (groupPriority === NotificationGroupingService.priorityHigh ? 48 : 40) + Theme.spacingM
                                anchors.right: parent.right
                                anchors.rightMargin: 32  // Maximum available width for message content
                                anchors.verticalCenter: parent.verticalCenter  // Center the entire content vertically
                                spacing: groupPriority === NotificationGroupingService.priorityHigh ? 4 : 2
                                
                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS
                                    
                                    Text {
                                        text: model.appName || "App"
                                        font.pixelSize: groupPriority === NotificationGroupingService.priorityHigh ? Theme.fontSizeLarge : Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        font.weight: groupPriority === NotificationGroupingService.priorityHigh ? Font.DemiBold : Font.Medium
                                    }
                                    
                                    // Enhanced notification count badge
                                    Rectangle {
                                        width: Math.max(countText.width + 8, 20)
                                        height: 20
                                        radius: 10
                                        color: getBadgeColor()
                                        visible: model.totalCount > 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        // Removed glow effect as requested
                                        
                                        function getBadgeColor() {
                                            if (groupPriority === NotificationGroupingService.priorityHigh) {
                                                return Theme.primary
                                            }
                                            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.8)
                                        }
                                        
                                        Text {
                                            id: countText
                                            anchors.centerIn: parent
                                            text: model.totalCount.toString()
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.primaryText
                                            font.weight: Font.Medium
                                        }
                                    }
                                }
                                
                                // Latest message summary (title)
                                Text {
                                    text: getLatestMessageTitle()
                                    font.pixelSize: groupPriority === NotificationGroupingService.priorityHigh ? Theme.fontSizeMedium : Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                    font.weight: Font.Medium
                                    
                                    function getLatestMessageTitle() {
                                        if (model.latestNotification) {
                                            return model.latestNotification.summary || ""
                                        }
                                        return ""
                                    }
                                }
                                
                                // Latest message body (content)
                                Text {
                                    text: getLatestMessageBody()
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.8)
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                    maximumLineCount: groupPriority === NotificationGroupingService.priorityHigh ? 3 : 2
                                    
                                    function getLatestMessageBody() {
                                        if (model.latestNotification) {
                                            return model.latestNotification.body || ""
                                        }
                                        return ""
                                    }
                                }
                                
                                // Additional messages indicator removed - moved below as floating text
                            }
                            
                            // Enhanced Expand/Collapse Icon - moved up more for better spacing
                            Rectangle {
                                id: expandCollapseButton
                                width: model.totalCount > 1 ? 32 : 0
                                height: 32
                                radius: 16
                                anchors.right: parent.right
                                anchors.rightMargin: 6  // Reduced right margin to add left padding
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 16  // Moved up even more for better spacing
                                color: expandButtonArea.containsMouse ? 
                                       Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                                       "transparent"
                                visible: model.totalCount > 1
                                
                                Behavior on width {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: isExpanded ? "expand_less" : "expand_more"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 20
                                    color: expandButtonArea.containsMouse ? Theme.primary : Theme.surfaceText
                                    
                                    Behavior on text {
                                        enabled: false  // Disable animation on text change to prevent flicker
                                    }
                                }
                                
                                MouseArea {
                                    id: expandButtonArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: model.totalCount > 1
                                    
                                    onClicked: {
                                        NotificationGroupingService.toggleGroupExpansion(index)
                                    }
                                }
                            }
                            
                            // Close group button
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                color: closeGroupArea.containsMouse ? 
                                       Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                                       "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "close"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
                                    color: closeGroupArea.containsMouse ? Theme.primary : Theme.surfaceText
                                }
                                
                                MouseArea {
                                    id: closeGroupArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        NotificationGroupingService.removeGroup(index)
                                    }
                                }
                            }
                            
                            // Timestamp positioned under close button
                            Text {
                                id: timestampText
                                text: model.latestNotification ? 
                                      NotificationGroupingService.formatTimestamp(model.latestNotification.timestamp) : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: 6
                                anchors.bottomMargin: 6
                                visible: text.length > 0
                            }
                            
                            MouseArea {
                                id: groupHeaderArea
                                anchors.fill: parent
                                anchors.rightMargin: 32  // Adjusted for maximum content width
                                hoverEnabled: true
                                cursorShape: model.totalCount > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                preventStealing: false
                                propagateComposedEvents: true
                                
                                onClicked: {
                                    if (model.totalCount > 1) {
                                        NotificationGroupingService.toggleGroupExpansion(index)
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
                        
                        // Floating "More messages" indicator - positioned below the main group
                        Rectangle {
                            width: Math.min(parent.width * 0.8, 200)
                            height: 24
                            radius: 12
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.topMargin: 1 
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                            border.width: 1
                            visible: model.totalCount > 1 && !isExpanded
                            
                            // Smooth fade animation
                            opacity: (model.totalCount > 1 && !isExpanded) ? 1.0 : 0.0
                            
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: getFloatingIndicatorText()
                                font.pixelSize: Theme.fontSizeSmall
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.9)
                                font.weight: Font.Medium
                                
                                function getFloatingIndicatorText() {
                                    if (model.totalCount > 1) {
                                        const additionalCount = model.totalCount - 1
                                        return `${additionalCount} more message${additionalCount > 1 ? "s" : ""} • Tap to expand`
                                    }
                                    return ""
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    NotificationGroupingService.toggleGroupExpansion(index)
                                }
                            }
                            
                            // Subtle hover effect
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                        
                        // Expanded Notifications List with enhanced animation
                        Item {
                            width: parent.width
                            height: isExpanded ? expandedContent.height + Theme.spacingS : 0
                            clip: true
                            
                            // Enhanced staggered animation
                            Behavior on height {
                                SequentialAnimation {
                                    NumberAnimation {
                                        duration: Theme.mediumDuration
                                        easing.type: Theme.emphasizedEasing
                                    }
                                }
                            }
                            
                            Column {
                                id: expandedContent
                                width: parent.width
                                spacing: Theme.spacingXS
                                opacity: isExpanded ? 1.0 : 0.0
                                topPadding: Theme.spacingS
                                bottomPadding: Theme.spacingM
                                
                                // Enhanced opacity animation
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.mediumDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                                
                                Repeater {
                                    model: groupData.notifications
                                    
                                    delegate: Rectangle {
                                        // Skip the first (latest) notification since it's shown in the header
                                        visible: index > 0
                                        width: parent.width
                                        height: 80
                                        radius: Theme.cornerRadius
                                        color: notifArea.containsMouse ? 
                                               Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
                                               Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                                        
                                        // Subtle left border for nested notifications
                                        Rectangle {
                                            width: 2
                                            height: parent.height - 16
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                                            radius: 1
                                        }
                                        
                                        // Smooth appearance animation
                                        opacity: isExpanded ? 1.0 : 0.0
                                        transform: Translate {
                                            y: isExpanded ? 0 : -10
                                        }
                                        
                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.shortDuration
                                                easing.type: Theme.standardEasing
                                            }
                                        }
                                        
                                        Behavior on transform {
                                            NumberAnimation {
                                                duration: Theme.shortDuration
                                                easing.type: Theme.standardEasing
                                            }
                                        }
                                        
                                        // Individual notification close button
                                        Rectangle {
                                            width: 24
                                            height: 24
                                            radius: 12
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 8
                                            color: closeNotifArea.containsMouse ? 
                                                   Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                                                   "transparent"
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "close"
                                                font.family: Theme.iconFont
                                                font.pixelSize: 14
                                                color: closeNotifArea.containsMouse ? Theme.primary : Theme.surfaceText
                                            }
                                            
                                            MouseArea {
                                                id: closeNotifArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    // Use the parent ListView's index to get the group index
                                                    let groupIndex = parent.parent.parent.parent.parent.index
                                                    NotificationGroupingService.removeNotification(groupIndex, model.index)
                                                }
                                            }
                                        }
                                        
                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingM
                                            anchors.leftMargin: Theme.spacingM + 8  // Extra space for border
                                            anchors.rightMargin: 36
                                            spacing: Theme.spacingM
                                            
                                            // Notification icon
                                            Rectangle {
                                                width: 48
                                                height: 48
                                                radius: width / 2
                                                color: Theme.primaryContainer
                                                anchors.verticalCenter: parent.verticalCenter
                                                
                                                // Material icon fallback
                                                Loader {
                                                    active: !model.appIcon || model.appIcon === ""
                                                    anchors.fill: parent
                                                    sourceComponent: Text {
                                                        anchors.centerIn: parent
                                                        text: "notifications"
                                                        font.family: Theme.iconFont
                                                        font.pixelSize: 20
                                                        color: Theme.primaryText
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
                                                            if (model.appIcon.startsWith("file://") || model.appIcon.startsWith("/")) {
                                                                return model.appIcon
                                                            }
                                                            return Quickshell.iconPath(model.appIcon, "image-missing")
                                                        }
                                                    }
                                                }
                                                
                                                // Notification image (priority)
                                                Loader {
                                                    active: model.image && model.image !== ""
                                                    anchors.fill: parent
                                                    sourceComponent: Item {
                                                        anchors.fill: parent
                                                        
                                                        Image {
                                                            id: notifImage
                                                            anchors.fill: parent
                                                            source: model.image || ""
                                                            fillMode: Image.PreserveAspectCrop
                                                            cache: true
                                                            antialiasing: true
                                                            asynchronous: true
                                                            smooth: true
                                                            sourceSize.width: parent.width
                                                            sourceSize.height: parent.height
                                                            
                                                            layer.enabled: true
                                                            layer.effect: MultiEffect {
                                                                maskEnabled: true
                                                                maskSource: Rectangle {
                                                                    width: 48
                                                                    height: 48
                                                                    radius: 24
                                                                }
                                                            }
                                                        }
                                                        
                                                        // Small app icon overlay
                                                        Loader {
                                                            active: model.appIcon && model.appIcon !== "" && notifImage.status === Image.Ready
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
                                            
                                            // Notification content
                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 80
                                                spacing: Theme.spacingXS
                                                
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
                                                
                                                Text {
                                                    text: NotificationGroupingService.formatTimestamp(model.timestamp)
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                                                    visible: text.length > 0
                                                }
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: notifArea
                                            anchors.fill: parent
                                            anchors.rightMargin: 32
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            preventStealing: false
                                            propagateComposedEvents: true
                                            
                                            onClicked: {
                                                if (model && root.handleNotificationClick) {
                                                    root.handleNotificationClick(model)
                                                }
                                                // Use the parent ListView's index to get the group index
                                                let groupIndex = parent.parent.parent.parent.parent.index
                                                NotificationGroupingService.removeNotification(groupIndex, model.index)
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
                    }
                }
                
                // Empty state
                Item {
                    anchors.fill: parent
                    visible: NotificationGroupingService.totalCount === 0
                    
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
                            text: "Notifications will appear here grouped by app"
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