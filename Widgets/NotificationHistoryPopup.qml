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
        color: Theme.surfaceContainer
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        border.width: 1
        
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
                        
                        // Group Header
                        Rectangle {
                            width: parent.width
                            height: 56
                            radius: Theme.cornerRadius
                            color: groupHeaderArea.containsMouse ? 
                                   Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
                                   Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                            
                            // App Icon
                            Rectangle {
                                width: 32
                                height: 32
                                radius: width / 2
                                color: Theme.primaryContainer
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                
                                // Material icon fallback
                                Loader {
                                    active: !model.appIcon || model.appIcon === ""
                                    anchors.fill: parent
                                    sourceComponent: Text {
                                        anchors.centerIn: parent
                                        text: "apps"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 16
                                        color: Theme.primaryText
                                    }
                                }
                                
                                // App icon
                                Loader {
                                    active: model.appIcon && model.appIcon !== ""
                                    anchors.centerIn: parent
                                    sourceComponent: IconImage {
                                        width: 24
                                        height: 24
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
                            
                            // App Name and Summary
                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM + 32 + Theme.spacingM  // Icon + spacing
                                anchors.right: parent.right
                                anchors.rightMargin: 80  // Space for buttons
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                
                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS
                                    
                                    Text {
                                        text: model.appName || "App"
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                    }
                                    
                                    // Notification count badge
                                    Rectangle {
                                        width: Math.max(countText.width + 8, 20)
                                        height: 20
                                        radius: 10
                                        color: Theme.primary
                                        visible: model.totalCount > 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        
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
                                
                                Text {
                                    text: model.latestNotification ? 
                                          (model.latestNotification.summary || model.latestNotification.body || "") : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }
                            }
                            
                            // Expand/Collapse Icon
                            Rectangle {
                                id: expandCollapseButton
                                width: 32
                                height: 32
                                radius: 16
                                anchors.right: parent.right
                                anchors.rightMargin: 40  // More space from close button
                                anchors.verticalCenter: parent.verticalCenter
                                color: expandButtonArea.containsMouse ? 
                                       Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                                       "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: isExpanded ? "expand_less" : "expand_more"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 20
                                    color: expandButtonArea.containsMouse ? Theme.primary : Theme.surfaceText
                                    
                                    Behavior on rotation {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.standardEasing
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    id: expandButtonArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
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
                                anchors.rightMargin: 76  // Exclude both expand and close button areas
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: false
                                propagateComposedEvents: true
                                
                                onClicked: {
                                    NotificationGroupingService.toggleGroupExpansion(index)
                                }
                            }
                            
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                        
                        // Expanded Notifications List
                        Item {
                            width: parent.width
                            height: isExpanded ? expandedContent.height : 0
                            clip: true
                            
                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.mediumDuration
                                    easing.type: Theme.emphasizedEasing
                                }
                            }
                            
                            Column {
                                id: expandedContent
                                width: parent.width
                                spacing: Theme.spacingXS
                                opacity: isExpanded ? 1.0 : 0.0
                                
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                                
                                Repeater {
                                    model: groupData.notifications
                                    
                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 80
                                        radius: Theme.cornerRadius
                                        color: notifArea.containsMouse ? 
                                               Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
                                               Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                                        
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