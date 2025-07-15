import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Common"
import "../Services"
import "../Widgets"

// Demo component to test the enhanced Android 16-style notification system
ApplicationWindow {
    id: demoWindow
    width: 800
    height: 600
    visible: true
    title: "Android 16 Notification System Demo"
    
    color: Theme.background
    
    Component.onCompleted: {
        // Add some sample notifications to demonstrate the system
        addSampleNotifications()
    }
    
    function addSampleNotifications() {
        // High priority conversation notifications
        NotificationGroupingService.addNotification({
            id: "msg1",
            appName: "Messages",
            appIcon: "message",
            summary: "John Doe",
            body: "Hey, are you free for lunch today?",
            timestamp: new Date(),
            urgency: 2
        })
        
        NotificationGroupingService.addNotification({
            id: "msg2", 
            appName: "Messages",
            appIcon: "message",
            summary: "Jane Smith",
            body: "Meeting moved to 3 PM",
            timestamp: new Date(Date.now() - 300000), // 5 minutes ago
            urgency: 2
        })
        
        NotificationGroupingService.addNotification({
            id: "msg3",
            appName: "Messages", 
            appIcon: "message",
            summary: "John Doe",
            body: "Let me know!",
            timestamp: new Date(Date.now() - 60000), // 1 minute ago
            urgency: 2
        })
        
        // Media notification
        NotificationGroupingService.addNotification({
            id: "media1",
            appName: "Spotify",
            appIcon: "music_note",
            summary: "Now Playing: Gemini Dreams",
            body: "Artist: Synthwave Collective",
            timestamp: new Date(Date.now() - 120000), // 2 minutes ago
            urgency: 1
        })
        
        // Regular notifications
        NotificationGroupingService.addNotification({
            id: "gmail1",
            appName: "Gmail",
            appIcon: "mail",
            summary: "New email from Sarah",
            body: "Project update - please review",
            timestamp: new Date(Date.now() - 600000), // 10 minutes ago
            urgency: 1
        })
        
        NotificationGroupingService.addNotification({
            id: "gmail2",
            appName: "Gmail",
            appIcon: "mail", 
            summary: "Weekly newsletter",
            body: "Your weekly digest is ready",
            timestamp: new Date(Date.now() - 900000), // 15 minutes ago
            urgency: 0
        })
        
        // System notifications (low priority)
        NotificationGroupingService.addNotification({
            id: "sys1",
            appName: "System",
            appIcon: "settings",
            summary: "Software update available",
            body: "Update to version 1.2.3",
            timestamp: new Date(Date.now() - 1800000), // 30 minutes ago
            urgency: 0
        })
        
        // Discord conversation
        NotificationGroupingService.addNotification({
            id: "discord1",
            appName: "Discord",
            appIcon: "chat",
            summary: "Alice in #general",
            body: "Anyone up for a game tonight?",
            timestamp: new Date(Date.now() - 180000), // 3 minutes ago
            urgency: 1
        })
        
        NotificationGroupingService.addNotification({
            id: "discord2",
            appName: "Discord",
            appIcon: "chat",
            summary: "Bob in #general", 
            body: "I'm in! What time?",
            timestamp: new Date(Date.now() - 150000), // 2.5 minutes ago
            urgency: 1
        })
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingL
        
        // Header
        Text {
            text: "Android 16 Notification System Demo"
            font.pixelSize: Theme.fontSizeXLarge
            color: Theme.surfaceText
            font.weight: Font.Bold
            Layout.fillWidth: true
        }
        
        // Stats row
        Row {
            spacing: Theme.spacingL
            Layout.fillWidth: true
            
            Text {
                text: "Total Notifications: " + NotificationGroupingService.totalCount
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: "Groups: " + NotificationGroupingService.groupedNotifications.count
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Button {
                text: "Add Sample Notification"
                onClicked: addRandomNotification()
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Button {
                text: "Clear All"
                onClicked: NotificationGroupingService.clearAllNotifications()
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        
        // Main notification list
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            ListView {
                id: notificationList
                model: NotificationGroupingService.groupedNotifications
                spacing: Theme.spacingM
                
                delegate: Column {
                    width: notificationList.width
                    spacing: Theme.spacingXS
                    
                    property var groupData: model
                    property bool isExpanded: model.expanded || false
                    
                    // Group header (similar to NotificationHistoryPopup but for demo)
                    Rectangle {
                        width: parent.width
                        height: getPriorityHeight()
                        radius: Theme.cornerRadius
                        color: getGroupColor()
                        
                        // Priority indicator
                        Rectangle {
                            width: 4
                            height: parent.height - 8
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 2
                            color: Theme.primary
                            visible: (model.priority || 1) === NotificationGroupingService.priorityHigh
                        }
                        
                        function getPriorityHeight() {
                            return (model.priority || 1) === NotificationGroupingService.priorityHigh ? 70 : 60
                        }
                        
                        function getGroupColor() {
                            if ((model.priority || 1) === NotificationGroupingService.priorityHigh) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                            }
                            return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                        }
                        
                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM
                            
                            // App icon
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                color: Theme.primaryContainer
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: getTypeIcon()
                                    font.family: Theme.iconFont
                                    font.pixelSize: 20
                                    color: Theme.primaryText
                                    
                                    function getTypeIcon() {
                                        const type = model.notificationType || NotificationGroupingService.typeNormal
                                        if (type === NotificationGroupingService.typeConversation) {
                                            return "chat"
                                        } else if (type === NotificationGroupingService.typeMedia) {
                                            return "music_note"
                                        } else if (type === NotificationGroupingService.typeSystem) {
                                            return "settings"
                                        }
                                        return "apps"
                                    }
                                }
                            }
                            
                            // Content
                            Column {
                                width: parent.width - 40 - Theme.spacingM - 60
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                
                                Row {
                                    spacing: Theme.spacingS
                                    
                                    Text {
                                        text: model.appName || "App"
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                    }
                                    
                                    Rectangle {
                                        width: Math.max(countText.width + 6, 18)
                                        height: 18
                                        radius: 9
                                        color: Theme.primary
                                        visible: model.totalCount > 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Text {
                                            id: countText
                                            anchors.centerIn: parent
                                            text: model.totalCount.toString()
                                            font.pixelSize: 10
                                            color: Theme.primaryText
                                            font.weight: Font.Medium
                                        }
                                    }
                                    
                                    Text {
                                        text: getPriorityText()
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.primary
                                        font.weight: Font.Medium
                                        visible: text.length > 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        function getPriorityText() {
                                            const priority = model.priority || NotificationGroupingService.priorityNormal
                                            if (priority === NotificationGroupingService.priorityHigh) {
                                                return "HIGH"
                                            } else if (priority === NotificationGroupingService.priorityLow) {
                                                return "LOW"
                                            }
                                            return ""
                                        }
                                    }
                                }
                                
                                Text {
                                    text: NotificationGroupingService.generateGroupSummary(model)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                    width: parent.width
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }
                            
                            // Expand button
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: expandArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                visible: model.totalCount > 1
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: isExpanded ? "expand_less" : "expand_more"
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
                                        NotificationGroupingService.toggleGroupExpansion(index)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Expanded notifications
                    Item {
                        width: parent.width
                        height: isExpanded ? expandedContent.height : 0
                        clip: true
                        
                        Behavior on height {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        Column {
                            id: expandedContent
                            width: parent.width
                            spacing: Theme.spacingXS
                            
                            Repeater {
                                model: groupData.notifications
                                
                                delegate: Rectangle {
                                    width: parent.width
                                    height: 60
                                    radius: Theme.cornerRadius
                                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                                    
                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingM
                                        spacing: Theme.spacingM
                                        
                                        Rectangle {
                                            width: 32
                                            height: 32
                                            radius: 16
                                            color: Theme.primaryContainer
                                            anchors.verticalCenter: parent.verticalCenter
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "notifications"
                                                font.family: Theme.iconFont
                                                font.pixelSize: 16
                                                color: Theme.primaryText
                                            }
                                        }
                                        
                                        Column {
                                            width: parent.width - 32 - Theme.spacingM
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2
                                            
                                            Text {
                                                text: model.summary || ""
                                                font.pixelSize: Theme.fontSizeMedium
                                                color: Theme.surfaceText
                                                font.weight: Font.Medium
                                                width: parent.width
                                                elide: Text.ElideRight
                                            }
                                            
                                            Text {
                                                text: model.body || ""
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                                width: parent.width
                                                elide: Text.ElideRight
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
    }
    
    function addRandomNotification() {
        const apps = ["Messages", "Gmail", "Discord", "Spotify", "System"]
        const summaries = ["New message", "Update available", "Someone mentioned you", "Now playing", "Task completed"]
        const bodies = ["This is a sample notification body", "Please check this out", "Important update", "Don't miss this", "Action required"]
        
        const randomApp = apps[Math.floor(Math.random() * apps.length)]
        const randomSummary = summaries[Math.floor(Math.random() * summaries.length)]
        const randomBody = bodies[Math.floor(Math.random() * bodies.length)]
        
        NotificationGroupingService.addNotification({
            id: "random_" + Date.now(),
            appName: randomApp,
            appIcon: randomApp.toLowerCase(),
            summary: randomSummary,
            body: randomBody,
            timestamp: new Date(),
            urgency: Math.floor(Math.random() * 3)
        })
    }
}