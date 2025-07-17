# Desktop Notifications API Documentation

This document describes the Desktop Notifications API available in Quickshell QML for implementing a complete notification daemon that complies with the [Desktop Notifications Specification](https://specifications.freedesktop.org/notification-spec/notification-spec-latest.html).

## Import Statement

```qml
import Quickshell.Services.Notifications
```

## Prerequisites

- D-Bus service must be available
- Notifications feature must be enabled during build (`-DSERVICE_NOTIFICATIONS=ON`, default)
- Your shell must register as a notification daemon to receive notifications

## Core Concepts

### Desktop Notifications Protocol
The notifications service implements the complete `org.freedesktop.Notifications` D-Bus interface, allowing your shell to receive notifications from any application that follows the Desktop Notifications Specification. This includes web browsers, email clients, media players, system services, and more.

### Capability-Based Architecture
The notification server operates on an opt-in basis. Most capabilities are disabled by default and must be explicitly enabled based on what your notification UI can support. This ensures applications receive accurate information about what features are available.

### Notification Lifecycle
1. **Reception** - Applications send notifications via D-Bus
2. **Tracking** - You must explicitly track notifications you want to keep
3. **Display** - Show notification UI based on properties and capabilities
4. **Interaction** - Handle user actions like clicking or dismissing
5. **Closure** - Notifications are closed via expiration, dismissal, or application request

## Main Components

### 1. NotificationServer

The main server that receives and manages notifications from external applications.

```qml
NotificationServer {
    id: notificationServer
    
    // Enable capabilities your UI supports
    actionsSupported: true
    imageSupported: true
    bodyMarkupSupported: true
    
    onNotification: function(notification) {
        // Must set tracked to true to keep the notification
        notification.tracked = true
        
        // Handle the notification in your UI
        showNotification(notification)
    }
}
```

**Server Capabilities (Properties):**
- `keepOnReload: bool` - Whether notifications persist across quickshell reloads (default: true)
- `persistenceSupported: bool` - Whether server advertises persistence capability (default: false)
- `bodySupported: bool` - Whether body text is supported (default: true)
- `bodyMarkupSupported: bool` - Whether body markup is supported (default: false)
- `bodyHyperlinksSupported: bool` - Whether body hyperlinks are supported (default: false)
- `bodyImagesSupported: bool` - Whether body images are supported (default: false)
- `actionsSupported: bool` - Whether notification actions are supported (default: false)
- `actionIconsSupported: bool` - Whether action icons are supported (default: false)
- `imageSupported: bool` - Whether notification images are supported (default: false)
- `inlineReplySupported: bool` - Whether inline reply is supported (default: false)
- `trackedNotifications: ObjectModel<Notification>` - All currently tracked notifications
- `extraHints: QVector<QString>` - Additional hints to expose to clients

**Signals:**
- `notification(Notification* notification)` - Emitted when a new notification is received

**Example:**
```qml
NotificationServer {
    // Enable features your notification UI supports
    actionsSupported: true
    imageSupported: true
    bodyMarkupSupported: true
    
    onNotification: function(notification) {
        // Track the notification to prevent automatic cleanup
        notification.tracked = true
        
        // Connect to closure signal for cleanup
        notification.closed.connect(function(reason) {
            console.log("Notification closed:", NotificationCloseReason.toString(reason))
        })
        
        // Show notification popup
        showNotificationPopup(notification)
    }
}
```

### 2. Notification

Represents a single notification with all its properties and available actions.

**Properties:**
- `id: quint32` - Unique notification ID (read-only)
- `tracked: bool` - Whether notification is tracked by the server
- `lastGeneration: bool` - Whether notification was carried over from previous quickshell generation (read-only)
- `expireTimeout: qreal` - Timeout in seconds for the notification
- `appName: QString` - Name of the sending application
- `appIcon: QString` - Application icon (fallback to desktop entry icon if not provided)
- `summary: QString` - Main notification text (title)
- `body: QString` - Detailed notification body
- `urgency: NotificationUrgency.Enum` - Urgency level (Low, Normal, Critical)
- `actions: QList<NotificationAction*>` - Available actions
- `hasActionIcons: bool` - Whether actions have icons
- `resident: bool` - Whether notification persists after action invocation
- `transient: bool` - Whether notification should skip persistence
- `desktopEntry: QString` - Associated desktop entry name
- `image: QString` - Associated image
- `hints: QVariantMap` - All raw hints from the client
- `hasInlineReply: bool` - Whether notification supports inline reply (read-only)
- `inlineReplyPlaceholder: QString` - Placeholder text for inline reply input (read-only)

**Methods:**
- `expire()` - Close notification as expired
- `dismiss()` - Close notification as dismissed by user
- `sendInlineReply(QString replyText)` - Send an inline reply (only if hasInlineReply is true)

**Signals:**
- `closed(NotificationCloseReason.Enum reason)` - Emitted when notification is closed

**Example:**
```qml
// In your notification UI component
Rectangle {
    property Notification notification
    
    Column {
        Text {
            text: notification.appName
            font.bold: true
        }
        
        Text {
            text: notification.summary
            font.pixelSize: 16
        }
        
        Text {
            text: notification.body
            wrapMode: Text.WordWrap
            visible: notification.body.length > 0
        }
        
        // Show notification image if available
        Image {
            source: notification.image
            visible: notification.image.length > 0
        }
        
        // Show actions if available
        Row {
            Repeater {
                model: notification.actions
                delegate: Button {
                    text: modelData.text
                    onClicked: {
                        modelData.invoke()
                    }
                }
            }
        }
    }
    
    // Auto-expire after timeout
    Timer {
        running: notification.expireTimeout > 0
        interval: notification.expireTimeout * 1000
        onTriggered: notification.expire()
    }
    
    // Handle user dismissal
    MouseArea {
        anchors.fill: parent
        onClicked: notification.dismiss()
    }
}
```

### 3. NotificationAction

Represents an action that can be taken on a notification.

**Properties:**
- `identifier: QString` - Action identifier (icon name when hasActionIcons is true)
- `text: QString` - Localized display text for the action

**Methods:**
- `invoke()` - Invoke the action (automatically dismisses non-resident notifications)

**Example:**
```qml
// Action button in notification
Button {
    property NotificationAction action
    
    text: action.text
    
    // Show icon if actions support icons
    icon.name: notificationServer.actionIconsSupported ? action.identifier : ""
    
    onClicked: {
        action.invoke()
        // Action automatically handles notification dismissal for non-resident notifications
    }
}
```

## Enum Types

### NotificationUrgency

Urgency levels for notifications.

**Values:**
- `NotificationUrgency.Low` - Low priority (value: 0)
- `NotificationUrgency.Normal` - Normal priority (value: 1)
- `NotificationUrgency.Critical` - High priority (value: 2)

**Methods:**
- `NotificationUrgency.toString(urgency)` - Convert urgency to string

### NotificationCloseReason

Reasons why a notification was closed.

**Values:**
- `NotificationCloseReason.Expired` - Notification timed out (value: 1)
- `NotificationCloseReason.Dismissed` - User explicitly dismissed (value: 2)
- `NotificationCloseReason.CloseRequested` - Application requested closure (value: 3)

**Methods:**
- `NotificationCloseReason.toString(reason)` - Convert reason to string

## Usage Examples

### Basic Notification Daemon

```qml
import QtQuick
import QtQuick.Controls
import Quickshell.Services.Notifications

ApplicationWindow {
    visible: true
    
    NotificationServer {
        id: notificationServer
        
        // Enable capabilities based on your UI
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: false
        
        onNotification: function(notification) {
            // Track notification to prevent cleanup
            notification.tracked = true
            
            // Add to notification list
            notificationList.append(notification)
            
            // Show popup for urgent notifications
            if (notification.urgency === NotificationUrgency.Critical) {
                showUrgentPopup(notification)
            }
        }
    }
    
    ListView {
        id: notificationListView
        anchors.fill: parent
        
        model: notificationServer.trackedNotifications
        
        delegate: Rectangle {
            width: parent.width
            height: 100
            border.color: getUrgencyColor(modelData.urgency)
            
            function getUrgencyColor(urgency) {
                switch (urgency) {
                    case NotificationUrgency.Low: return "gray"
                    case NotificationUrgency.Normal: return "blue"
                    case NotificationUrgency.Critical: return "red"
                    default: return "black"
                }
            }
            
            Column {
                anchors.margins: 10
                anchors.fill: parent
                
                Text {
                    text: modelData.appName
                    font.bold: true
                }
                
                Text {
                    text: modelData.summary
                    font.pixelSize: 14
                }
                
                Text {
                    text: modelData.body
                    wrapMode: Text.WordWrap
                    visible: modelData.body.length > 0
                }
                
                Row {
                    spacing: 10
                    
                    Button {
                        text: "Dismiss"
                        onClicked: modelData.dismiss()
                    }
                    
                    Repeater {
                        model: modelData.actions
                        delegate: Button {
                            text: modelData.text
                            onClicked: modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
```

### Notification Popup with Auto-Dismiss

```qml
import QtQuick
import QtQuick.Controls
import Quickshell.Services.Notifications

Popup {
    id: notificationPopup
    
    property Notification notification
    
    width: 300
    height: contentColumn.height + 20
    
    // Position in top-right corner
    x: parent.width - width - 20
    y: 20
    
    Column {
        id: contentColumn
        anchors.margins: 10
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10
        
        Row {
            spacing: 10
            
            Image {
                width: 48
                height: 48
                source: notification.image || notification.appIcon
                fillMode: Image.PreserveAspectFit
            }
            
            Column {
                Text {
                    text: notification.appName
                    font.bold: true
                }
                
                Text {
                    text: notification.summary
                    font.pixelSize: 16
                }
            }
        }
        
        Text {
            text: notification.body
            wrapMode: Text.WordWrap
            visible: notification.body.length > 0
            width: parent.width
        }
        
        Row {
            spacing: 10
            
            Repeater {
                model: notification.actions
                delegate: Button {
                    text: modelData.text
                    onClicked: {
                        modelData.invoke()
                        notificationPopup.close()
                    }
                }
            }
        }
    }
    
    // Auto-close timer
    Timer {
        running: notificationPopup.visible
        interval: notification.expireTimeout > 0 ? notification.expireTimeout * 1000 : 5000
        onTriggered: {
            notification.expire()
            notificationPopup.close()
        }
    }
    
    // Dismiss on click
    MouseArea {
        anchors.fill: parent
        onClicked: {
            notification.dismiss()
            notificationPopup.close()
        }
    }
}
```

### Notification History Manager

```qml
import QtQuick
import QtQuick.Controls
import Quickshell.Services.Notifications

QtObject {
    id: notificationHistory
    
    property var notifications: []
    property int maxNotifications: 100
    
    Component.onCompleted: {
        // Connect to notification server
        notificationServer.notification.connect(handleNotification)
    }
    
    function handleNotification(notification) {
        // Track notification
        notification.tracked = true
        
        // Add to history
        notifications.unshift(notification)
        
        // Limit history size
        if (notifications.length > maxNotifications) {
            notifications.pop()
        }
        
        // Connect to closure signal
        notification.closed.connect(function(reason) {
            console.log("Notification closed:", 
                       NotificationCloseReason.toString(reason))
        })
        
        // Show notification popup
        showNotificationPopup(notification)
    }
    
    function clearHistory() {
        notifications.forEach(function(notification) {
            if (notification.tracked) {
                notification.dismiss()
            }
        })
        notifications = []
    }
    
    function getNotificationsByApp(appName) {
        return notifications.filter(function(notification) {
            return notification.appName === appName
        })
    }
    
    function getUrgentNotifications() {
        return notifications.filter(function(notification) {
            return notification.urgency === NotificationUrgency.Critical
        })
    }
}
```

### Android 16-Style Grouped Notifications with Inline Reply

This example demonstrates how to implement modern Android 16-style notification grouping with expandable groups, inline reply support, and smart conversation handling.

```qml
import QtQuick
import QtQuick.Controls
import Quickshell.Services.Notifications

ApplicationWindow {
    visible: true
    width: 420
    height: 700
    
    NotificationServer {
        id: notificationServer
        
        // Enable all modern capabilities for Android 16-style notifications
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true
        inlineReplySupported: true
        bodyHyperlinksSupported: true
        
        onNotification: function(notification) {
            notification.tracked = true
            notificationManager.addNotification(notification)
        }
    }
    
    QtObject {
        id: notificationManager
        
        property var groupedNotifications: ({})
        property var expandedGroups: ({})
        
        function addNotification(notification) {
            let groupKey = getGroupKey(notification)
            
            if (!groupedNotifications[groupKey]) {
                groupedNotifications[groupKey] = {
                    key: groupKey,
                    appName: notification.appName,
                    notifications: [],
                    latestNotification: null,
                    count: 0,
                    hasInlineReply: false,
                    isConversation: isConversationApp(notification),
                    isMedia: isMediaApp(notification)
                }
            }
            
            let group = groupedNotifications[groupKey]
            group.notifications.unshift(notification)
            group.latestNotification = notification
            group.count = group.notifications.length
            
            // Check if any notification in group supports inline reply
            if (notification.hasInlineReply) {
                group.hasInlineReply = true
            }
            
            // Auto-expand conversation groups with new messages
            if (group.isConversation && group.count > 1) {
                expandedGroups[groupKey] = true
            }
            
            // Limit notifications per group
            if (group.notifications.length > 20) {
                let oldNotification = group.notifications.pop()
                oldNotification.dismiss()
            }
            
            // Trigger UI update
            updateGroupModel()
        }
        
        function getGroupKey(notification) {
            let appName = notification.appName.toLowerCase()
            
            // For messaging apps, group by conversation/channel
            if (isConversationApp(notification)) {
                let summary = notification.summary.toLowerCase()
                // Discord channels: "#channel-name"
                if (summary.startsWith("#")) {
                    return appName + ":" + summary
                }
                // Direct messages: group by sender name
                if (summary && !summary.includes("new message")) {
                    return appName + ":" + summary
                }
                return appName + ":conversation"
            }
            
            // Media apps: group all together
            if (isMediaApp(notification)) {
                return appName + ":media"
            }
            
            // System notifications: group by type
            if (appName.includes("system") || appName.includes("update")) {
                return "system"
            }
            
            // Default: group by app
            return appName
        }
        
        function isConversationApp(notification) {
            let appName = notification.appName.toLowerCase()
            return appName.includes("discord") || 
                   appName.includes("telegram") || 
                   appName.includes("signal") ||
                   appName.includes("whatsapp") ||
                   appName.includes("slack") ||
                   appName.includes("message")
        }
        
        function isMediaApp(notification) {
            let appName = notification.appName.toLowerCase()
            return appName.includes("spotify") ||
                   appName.includes("music") ||
                   appName.includes("player") ||
                   appName.includes("vlc")
        }
        
        function toggleGroupExpansion(groupKey) {
            expandedGroups[groupKey] = !expandedGroups[groupKey]
            updateGroupModel()
        }
        
        function updateGroupModel() {
            let sortedGroups = Object.values(groupedNotifications)
                .sort((a, b) => b.latestNotification.timestamp - a.latestNotification.timestamp)
            notificationRepeater.model = sortedGroups
        }
        
        function dismissGroup(groupKey) {
            let group = groupedNotifications[groupKey]
            if (group) {
                group.notifications.forEach(notif => notif.dismiss())
                delete groupedNotifications[groupKey]
                delete expandedGroups[groupKey]
                updateGroupModel()
            }
        }
        
        function getGroupSummary(group) {
            if (group.count === 1) {
                return group.latestNotification.summary
            }
            
            if (group.isConversation) {
                return `${group.count} new messages`
            } else if (group.isMedia) {
                return "Now playing"
            } else {
                return `${group.count} notifications`
            }
        }
        
        function getGroupBody(group) {
            if (group.count === 1) {
                return group.latestNotification.body
            }
            
            // For conversations, show latest message preview
            if (group.isConversation) {
                return group.latestNotification.body || "Tap to view messages"
            }
            
            return `Latest: ${group.latestNotification.summary}`
        }
    }
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 8
        
        Column {
            width: parent.width - 16
            spacing: 8
            
            Repeater {
                id: notificationRepeater
                
                delegate: GroupedNotificationCard {
                    width: parent.width
                    group: modelData
                    expanded: notificationManager.expandedGroups[modelData.key] || false
                    
                    onToggleExpansion: notificationManager.toggleGroupExpansion(group.key)
                    onDismissGroup: notificationManager.dismissGroup(group.key)
                    onReplyToLatest: function(replyText) {
                        if (group.latestNotification.hasInlineReply) {
                            group.latestNotification.sendInlineReply(replyText)
                        }
                    }
                }
            }
        }
    }
}

// Android 16-style grouped notification card component
component GroupedNotificationCard: Rectangle {
    id: root
    
    property var group
    property bool expanded: false
    
    signal toggleExpansion()
    signal dismissGroup()
    signal replyToLatest(string replyText)
    
    height: expanded ? expandedContent.height + 32 : collapsedContent.height + 32
    radius: 16
    color: "#1a1a1a"
    border.color: group && group.latestNotification.urgency === NotificationUrgency.Critical ? 
                  "#ff4444" : "#333333"
    border.width: 1
    
    Behavior on height {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
    
    // Collapsed view - shows summary of the group
    Column {
        id: collapsedContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 8
        visible: !expanded
        
        Row {
            width: parent.width
            spacing: 12
            
            // App icon or conversation avatar
            Rectangle {
                width: 48
                height: 48
                radius: group && group.isConversation ? 24 : 8
                color: "#333333"
                
                Image {
                    anchors.fill: parent
                    anchors.margins: group && group.isConversation ? 0 : 8
                    source: group ? (group.latestNotification.image || group.latestNotification.appIcon) : ""
                    fillMode: Image.PreserveAspectCrop
                    radius: parent.radius
                }
            }
            
            Column {
                width: parent.width - 48 - 12 - 60
                spacing: 4
                
                Row {
                    width: parent.width
                    
                    Text {
                        text: group ? group.appName : ""
                        color: "#888888"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    
                    Item { width: 8; height: 1 }
                    
                    // Count badge for grouped notifications
                    Rectangle {
                        width: countText.width + 12
                        height: 20
                        radius: 10
                        color: "#444444"
                        visible: group && group.count > 1
                        
                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: group ? group.count : "0"
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                }
                
                Text {
                    text: group ? notificationManager.getGroupSummary(group) : ""
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    width: parent.width
                    elide: Text.ElideRight
                }
                
                Text {
                    text: group ? notificationManager.getGroupBody(group) : ""
                    color: "#cccccc"
                    font.pixelSize: 13
                    width: parent.width
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
            
            // Expand/dismiss controls
            Column {
                width: 60
                spacing: 4
                
                Button {
                    width: 32
                    height: 32
                    text: expanded ? "↑" : "↓"
                    visible: group && group.count > 1
                    onClicked: toggleExpansion()
                }
                
                Button {
                    width: 32
                    height: 32
                    text: "✕"
                    onClicked: dismissGroup()
                }
            }
        }
        
        // Quick reply for conversations
        Row {
            width: parent.width
            spacing: 8
            visible: group && group.hasInlineReply && !expanded
            
            TextField {
                id: quickReplyField
                width: parent.width - 60
                height: 36
                placeholderText: "Reply..."
                background: Rectangle {
                    color: "#2a2a2a"
                    radius: 18
                    border.color: parent.activeFocus ? "#4a9eff" : "#444444"
                }
                color: "#ffffff"
                
                onAccepted: {
                    if (text.length > 0) {
                        replyToLatest(text)
                        text = ""
                    }
                }
            }
            
            Button {
                width: 52
                height: 36
                text: "Send"
                enabled: quickReplyField.text.length > 0
                onClicked: {
                    replyToLatest(quickReplyField.text)
                    quickReplyField.text = ""
                }
            }
        }
    }
    
    // Expanded view - shows all notifications in group
    Column {
        id: expandedContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 8
        visible: expanded
        
        // Group header
        Row {
            width: parent.width
            spacing: 12
            
            Rectangle {
                width: 32
                height: 32
                radius: group && group.isConversation ? 16 : 4
                color: "#333333"
                
                Image {
                    anchors.fill: parent
                    anchors.margins: group && group.isConversation ? 0 : 4
                    source: group ? group.latestNotification.appIcon : ""
                    fillMode: Image.PreserveAspectCrop
                    radius: parent.radius
                }
            }
            
            Text {
                text: group ? `${group.appName} (${group.count})` : ""
                color: "#ffffff"
                font.pixelSize: 16
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Item { Layout.fillWidth: true }
            
            Button {
                text: "↑"
                width: 32
                height: 32
                onClicked: toggleExpansion()
            }
            
            Button {
                text: "✕"
                width: 32
                height: 32
                onClicked: dismissGroup()
            }
        }
        
        // Individual notifications
        Repeater {
            model: group ? group.notifications.slice(0, 10) : [] // Show max 10 expanded
            
            delegate: Rectangle {
                width: parent.width
                height: notifContent.height + 16
                radius: 8
                color: "#2a2a2a"
                border.color: modelData.urgency === NotificationUrgency.Critical ? 
                             "#ff4444" : "transparent"
                
                Column {
                    id: notifContent
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 12
                    spacing: 6
                    
                    Row {
                        width: parent.width
                        spacing: 8
                        
                        Image {
                            width: 24
                            height: 24
                            source: modelData.image || modelData.appIcon
                            fillMode: Image.PreserveAspectCrop
                            radius: group && group.isConversation ? 12 : 4
                        }
                        
                        Column {
                            width: parent.width - 32
                            spacing: 2
                            
                            Text {
                                text: modelData.summary
                                color: "#ffffff"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: modelData.body
                                color: "#cccccc"
                                font.pixelSize: 13
                                width: parent.width
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }
                    }
                    
                    // Individual notification inline reply
                    Row {
                        width: parent.width
                        spacing: 8
                        visible: modelData.hasInlineReply
                        
                        TextField {
                            id: replyField
                            width: parent.width - 60
                            height: 32
                            placeholderText: modelData.inlineReplyPlaceholder || "Reply..."
                            background: Rectangle {
                                color: "#1a1a1a"
                                radius: 16
                                border.color: parent.activeFocus ? "#4a9eff" : "#444444"
                            }
                            color: "#ffffff"
                            font.pixelSize: 12
                            
                            onAccepted: {
                                if (text.length > 0) {
                                    modelData.sendInlineReply(text)
                                    text = ""
                                }
                            }
                        }
                        
                        Button {
                            width: 52
                            height: 32
                            text: "Send"
                            enabled: replyField.text.length > 0
                            onClicked: {
                                modelData.sendInlineReply(replyField.text)
                                replyField.text = ""
                            }
                        }
                    }
                    
                    // Actions
                    Row {
                        spacing: 8
                        visible: modelData.actions && modelData.actions.length > 0
                        
                        Repeater {
                            model: modelData.actions
                            delegate: Button {
                                text: modelData.text
                                height: 28
                                onClicked: modelData.invoke()
                            }
                        }
                    }
                }
            }
        }
        
        // "Show more" if there are many notifications
        Button {
            text: `Show ${group.count - 10} more notifications...`
            visible: group && group.count > 10
            onClicked: {
                // Implement pagination or full expansion
            }
        }
    }
    
    // Tap to expand (only for collapsed state)
    MouseArea {
        anchors.fill: parent
        visible: !expanded && group && group.count > 1
        onClicked: toggleExpansion()
    }
}
```

### Media Notification Handler

```qml
import QtQuick
import QtQuick.Controls
import Quickshell.Services.Notifications

QtObject {
    id: mediaNotificationHandler
    
    property var currentMediaNotification: null
    
    Component.onCompleted: {
        notificationServer.notification.connect(handleNotification)
    }
    
    function handleNotification(notification) {
        notification.tracked = true
        
        // Check if this is a media notification
        if (isMediaNotification(notification)) {
            // Replace current media notification
            if (currentMediaNotification) {
                currentMediaNotification.dismiss()
            }
            
            currentMediaNotification = notification
            showMediaControls(notification)
        } else {
            // Handle as regular notification
            showRegularNotification(notification)
        }
    }
    
    function isMediaNotification(notification) {
        // Check for media-related hints or app names
        return notification.appName.toLowerCase().includes("music") ||
               notification.appName.toLowerCase().includes("player") ||
               notification.hints.hasOwnProperty("x-kde-media-notification") ||
               notification.actions.some(function(action) {
                   return action.identifier.includes("media-")
               })
    }
    
    function showMediaControls(notification) {
        // Create persistent media control UI
        mediaControlsPopup.notification = notification
        mediaControlsPopup.open()
    }
    
    function showRegularNotification(notification) {
        // Show regular notification popup
        regularNotificationPopup.notification = notification
        regularNotificationPopup.open()
    }
}
```

### Inline Reply Support

The notification system now supports inline replies, allowing users to quickly respond to messages directly from the notification without opening the source application.

```qml
import QtQuick
import QtQuick.Controls
import Quickshell.Services.Notifications

Popup {
    id: replyableNotificationPopup
    
    property Notification notification
    
    width: 400
    height: contentColumn.height + 20
    
    Column {
        id: contentColumn
        anchors.margins: 10
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10
        
        // Notification header
        Row {
            spacing: 10
            
            Image {
                width: 48
                height: 48
                source: notification.appIcon
                fillMode: Image.PreserveAspectFit
            }
            
            Column {
                Text {
                    text: notification.appName
                    font.bold: true
                }
                
                Text {
                    text: notification.summary
                    font.pixelSize: 16
                }
            }
        }
        
        // Notification body
        Text {
            text: notification.body
            wrapMode: Text.WordWrap
            width: parent.width
            visible: notification.body.length > 0
        }
        
        // Inline reply input (only shown if supported)
        Row {
            width: parent.width
            spacing: 10
            visible: notification.hasInlineReply
            
            TextField {
                id: replyField
                width: parent.width - sendButton.width - 10
                placeholderText: notification.inlineReplyPlaceholder || "Type a reply..."
                
                onAccepted: sendReply()
            }
            
            Button {
                id: sendButton
                text: "Send"
                enabled: replyField.text.length > 0
                
                onClicked: sendReply()
            }
        }
        
        // Regular actions
        Row {
            spacing: 10
            visible: notification.actions.length > 0 && !notification.hasInlineReply
            
            Repeater {
                model: notification.actions
                delegate: Button {
                    text: modelData.text
                    onClicked: {
                        modelData.invoke()
                        replyableNotificationPopup.close()
                    }
                }
            }
        }
    }
    
    function sendReply() {
        if (replyField.text.length > 0) {
            notification.sendInlineReply(replyField.text)
            replyableNotificationPopup.close()
        }
    }
}
```

### Advanced Inline Reply Implementation

```qml
import QtQuick
import QtQuick.Controls
import Quickshell.Services.Notifications

ApplicationWindow {
    visible: true
    
    NotificationServer {
        id: notificationServer
        
        // Enable inline reply support
        inlineReplySupported: true
        actionsSupported: true
        imageSupported: true
        
        onNotification: function(notification) {
            notification.tracked = true
            
            // Create appropriate UI based on notification capabilities
            if (notification.hasInlineReply) {
                createReplyableNotification(notification)
            } else {
                createStandardNotification(notification)
            }
        }
    }
    
    Component {
        id: replyableNotificationComponent
        
        Rectangle {
            property Notification notification
            
            width: 350
            height: contentColumn.implicitHeight + 20
            radius: 10
            color: "#2a2a2a"
            border.color: notification.urgency === NotificationUrgency.Critical ? 
                         "#ff4444" : "#444444"
            
            Column {
                id: contentColumn
                anchors.margins: 15
                anchors.fill: parent
                spacing: 12
                
                // Header with app info
                Row {
                    width: parent.width
                    spacing: 10
                    
                    Image {
                        width: 40
                        height: 40
                        source: notification.appIcon
                        fillMode: Image.PreserveAspectFit
                    }
                    
                    Column {
                        width: parent.width - 50
                        
                        Text {
                            text: notification.appName
                            color: "#888888"
                            font.pixelSize: 12
                        }
                        
                        Text {
                            text: notification.summary
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.bold: true
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }
                }
                
                // Message body
                Text {
                    text: notification.body
                    color: "#cccccc"
                    wrapMode: Text.WordWrap
                    width: parent.width
                    visible: notification.body.length > 0
                }
                
                // Inline reply section
                Rectangle {
                    width: parent.width
                    height: 40
                    radius: 5
                    color: "#1a1a1a"
                    border.color: replyField.activeFocus ? "#4488ff" : "#333333"
                    
                    Row {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 5
                        
                        TextField {
                            id: replyField
                            width: parent.width - 60
                            height: parent.height
                            placeholderText: notification.inlineReplyPlaceholder
                            color: "#ffffff"
                            background: Rectangle { color: "transparent" }
                            
                            onAccepted: {
                                if (text.length > 0) {
                                    notification.sendInlineReply(text)
                                    notificationItem.destroy()
                                }
                            }
                        }
                        
                        Button {
                            width: 50
                            height: parent.height
                            text: "↵"
                            enabled: replyField.text.length > 0
                            
                            onClicked: {
                                notification.sendInlineReply(replyField.text)
                                notificationItem.destroy()
                            }
                        }
                    }
                }
                
                // Dismiss button
                Text {
                    text: "✕"
                    color: "#666666"
                    font.pixelSize: 16
                    anchors.right: parent.right
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            notification.dismiss()
                            notificationItem.destroy()
                        }
                    }
                }
            }
            
            // Auto-dismiss timer
            Timer {
                running: notification.expireTimeout > 0 && !replyField.activeFocus
                interval: notification.expireTimeout * 1000
                onTriggered: {
                    notification.expire()
                    notificationItem.destroy()
                }
            }
        }
    }
    
    function createReplyableNotification(notification) {
        let notificationItem = replyableNotificationComponent.createObject(
            notificationContainer, 
            { notification: notification }
        )
    }
}
```

## Common Patterns

### Android 16-Style Notification Grouping

```qml
// Smart grouping by conversation and app
function getSmartGroupKey(notification) {
    const appName = notification.appName.toLowerCase()
    
    // Messaging apps: group by conversation/channel
    if (isMessagingApp(appName)) {
        const summary = notification.summary.toLowerCase()
        
        // Discord channels: "#general", "#announcements"
        if (summary.startsWith("#")) {
            return `${appName}:${summary}`
        }
        
        // Direct messages: group by sender name
        if (summary && !summary.includes("new message")) {
            return `${appName}:dm:${summary}`
        }
        
        // Fallback to app-level grouping
        return `${appName}:messages`
    }
    
    // Media: replace previous media notification
    if (isMediaApp(appName)) {
        return `${appName}:nowplaying`
    }
    
    // System notifications: group by category
    if (appName.includes("system")) {
        if (notification.summary.toLowerCase().includes("update")) {
            return "system:updates"
        }
        if (notification.summary.toLowerCase().includes("battery")) {
            return "system:battery"
        }
        return "system:general"
    }
    
    // Default: group by app
    return appName
}

function isMessagingApp(appName) {
    return ["discord", "telegram", "signal", "whatsapp", "slack", "vesktop"].some(
        app => appName.includes(app)
    )
}

function isMediaApp(appName) {
    return ["spotify", "vlc", "mpv", "music", "player"].some(
        app => appName.includes(app)
    )
}
```

### Collapsible Notification Groups with Inline Reply

```qml
component AndroidStyleNotificationGroup: Rectangle {
    id: root
    
    property var notificationGroup
    property bool expanded: false
    property bool hasUnread: notificationGroup.notifications.some(n => !n.read)
    
    height: expanded ? expandedHeight : collapsedHeight
    radius: 16
    color: "#1e1e1e"
    border.color: hasUnread ? "#4a9eff" : "#333333"
    border.width: hasUnread ? 2 : 1
    
    readonly property int collapsedHeight: 80
    readonly property int expandedHeight: Math.min(400, 80 + (notificationGroup.notifications.length * 60))
    
    Behavior on height {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }
    
    // Collapsed view - shows latest notification + count
    Item {
        anchors.fill: parent
        anchors.margins: 16
        visible: !expanded
        
        Row {
            anchors.fill: parent
            spacing: 12
            
            // Avatar/Icon
            Rectangle {
                width: 48
                height: 48
                radius: notificationGroup.isConversation ? 24 : 8
                color: "#333333"
                
                Image {
                    anchors.fill: parent
                    anchors.margins: notificationGroup.isConversation ? 0 : 8
                    source: notificationGroup.latestNotification.image || 
                           notificationGroup.latestNotification.appIcon
                    fillMode: Image.PreserveAspectCrop
                    radius: parent.radius
                }
                
                // Unread indicator
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: "#4a9eff"
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: -2
                    visible: hasUnread
                }
            }
            
            // Content
            Column {
                width: parent.width - 48 - 12 - 80
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                
                Row {
                    width: parent.width
                    spacing: 8
                    
                    Text {
                        text: notificationGroup.appName
                        color: "#888888"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    
                    // Count badge
                    Rectangle {
                        width: Math.max(20, countText.width + 8)
                        height: 16
                        radius: 8
                        color: "#555555"
                        visible: notificationGroup.count > 1
                        
                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: notificationGroup.count
                            color: "#ffffff"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                }
                
                Text {
                    text: getGroupTitle(notificationGroup)
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    width: parent.width
                    elide: Text.ElideRight
                }
                
                Text {
                    text: notificationGroup.latestNotification.body
                    color: "#cccccc"
                    font.pixelSize: 13
                    width: parent.width
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
            
            // Controls
            Column {
                width: 80
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                
                Button {
                    width: 36
                    height: 36
                    text: "↓"
                    visible: notificationGroup.count > 1
                    onClicked: expanded = true
                }
                
                Button {
                    width: 36
                    height: 36
                    text: "✕"
                    onClicked: dismissGroup()
                }
            }
        }
        
        // Quick reply for conversations
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            height: 40
            radius: 20
            color: "#2a2a2a"
            border.color: "#444444"
            visible: notificationGroup.hasInlineReply
            
            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8
                
                TextField {
                    id: quickReply
                    width: parent.width - 50
                    height: parent.height
                    placeholderText: "Quick reply..."
                    background: Item {}
                    color: "#ffffff"
                    font.pixelSize: 14
                    
                    onAccepted: sendQuickReply()
                }
                
                Button {
                    width: 42
                    height: parent.height
                    text: "→"
                    enabled: quickReply.text.length > 0
                    onClicked: sendQuickReply()
                }
            }
        }
    }
    
    // Expanded view - shows all notifications
    ScrollView {
        anchors.fill: parent
        anchors.margins: 16
        visible: expanded
        
        Column {
            width: parent.width
            spacing: 8
            
            // Group header
            Row {
                width: parent.width
                spacing: 12
                
                Rectangle {
                    width: 32
                    height: 32
                    radius: notificationGroup.isConversation ? 16 : 4
                    color: "#333333"
                    
                    Image {
                        anchors.fill: parent
                        anchors.margins: notificationGroup.isConversation ? 0 : 4
                        source: notificationGroup.latestNotification.appIcon
                        fillMode: Image.PreserveAspectCrop
                        radius: parent.radius
                    }
                }
                
                Text {
                    text: `${notificationGroup.appName} (${notificationGroup.count})`
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "↑"
                    width: 32
                    height: 32
                    onClicked: expanded = false
                }
                
                Button {
                    text: "✕"
                    width: 32
                    height: 32
                    onClicked: dismissGroup()
                }
            }
            
            // Individual notifications in conversation style
            Repeater {
                model: notificationGroup.notifications.slice(0, 15) // Show recent 15
                
                delegate: Rectangle {
                    width: parent.width
                    height: messageContent.height + 16
                    radius: 8
                    color: "#2a2a2a"
                    
                    Column {
                        id: messageContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 6
                        
                        Row {
                            width: parent.width
                            spacing: 8
                            
                            Rectangle {
                                width: 24
                                height: 24
                                radius: notificationGroup.isConversation ? 12 : 4
                                color: "#444444"
                                
                                Image {
                                    anchors.fill: parent
                                    source: modelData.image || modelData.appIcon
                                    fillMode: Image.PreserveAspectCrop
                                    radius: parent.radius
                                }
                            }
                            
                            Column {
                                width: parent.width - 32
                                spacing: 2
                                
                                Row {
                                    width: parent.width
                                    
                                    Text {
                                        text: modelData.summary
                                        color: "#ffffff"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    
                                    Text {
                                        text: formatTime(modelData.timestamp)
                                        color: "#888888"
                                        font.pixelSize: 11
                                    }
                                }
                                
                                Text {
                                    text: modelData.body
                                    color: "#cccccc"
                                    font.pixelSize: 13
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        
                        // Individual inline reply
                        Rectangle {
                            width: parent.width
                            height: 36
                            radius: 18
                            color: "#1a1a1a"
                            border.color: "#444444"
                            visible: modelData.hasInlineReply
                            
                            Row {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6
                                
                                TextField {
                                    id: replyField
                                    width: parent.width - 40
                                    height: parent.height
                                    placeholderText: modelData.inlineReplyPlaceholder || "Reply..."
                                    background: Item {}
                                    color: "#ffffff"
                                    font.pixelSize: 12
                                    
                                    onAccepted: {
                                        if (text.length > 0) {
                                            modelData.sendInlineReply(text)
                                            text = ""
                                        }
                                    }
                                }
                                
                                Button {
                                    width: 34
                                    height: parent.height
                                    text: "→"
                                    enabled: replyField.text.length > 0
                                    onClicked: {
                                        modelData.sendInlineReply(replyField.text)
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
    
    // Functions
    function getGroupTitle(group) {
        if (group.count === 1) {
            return group.latestNotification.summary
        }
        
        if (group.isConversation) {
            return `${group.count} new messages`
        }
        
        return `${group.count} notifications`
    }
    
    function sendQuickReply() {
        if (quickReply.text.length > 0 && notificationGroup.hasInlineReply) {
            notificationGroup.latestNotification.sendInlineReply(quickReply.text)
            quickReply.text = ""
        }
    }
    
    function dismissGroup() {
        notificationGroup.notifications.forEach(notification => {
            notification.dismiss()
        })
    }
    
    function formatTime(timestamp) {
        const now = new Date()
        const diff = now.getTime() - timestamp.getTime()
        const minutes = Math.floor(diff / 60000)
        const hours = Math.floor(minutes / 60)
        
        if (hours > 0) return `${hours}h`
        if (minutes > 0) return `${minutes}m`
        return "now"
    }
    
    // Tap to expand
    MouseArea {
        anchors.fill: parent
        visible: !expanded && notificationGroup.count > 1
        onClicked: expanded = true
    }
}
```

### Filtering Notifications by Urgency

```qml
// High priority notifications only
model: notificationServer.trackedNotifications.filter(function(notification) {
    return notification.urgency === NotificationUrgency.Critical
})
```

### Auto-dismiss Timer

```qml
Timer {
    property Notification notification
    
    running: notification && notification.expireTimeout > 0
    interval: notification.expireTimeout * 1000
    
    onTriggered: {
        if (notification) {
            notification.expire()
        }
    }
}
```

### Persistent Notification Storage

```qml
QtObject {
    property var persistentNotifications: []
    
    function addPersistentNotification(notification) {
        if (!notification.transient) {
            persistentNotifications.push({
                appName: notification.appName,
                summary: notification.summary,
                body: notification.body,
                timestamp: new Date()
            })
        }
    }
}
```

## Best Practices

### Capability Management
- Only enable capabilities your UI can properly handle
- Test with different notification sources to ensure compatibility
- Consider performance implications of advanced features

### Memory Management
- Always set `tracked: true` for notifications you want to keep
- Clean up notification references when no longer needed
- Use object pools for frequent notification creation/destruction

### User Experience for Android 16-Style Notifications
- **Progressive Disclosure**: Show summary first, expand for details
- **Smart Grouping**: Group conversations by channel/sender, media by app
- **Quick Actions**: Provide inline reply for conversations, media controls for audio
- **Visual Hierarchy**: Use conversation avatars vs app icons appropriately
- **Count Badges**: Show notification count for groups clearly
- **Auto-Expansion**: Expand conversation groups when new messages arrive
- **Smooth Animations**: Use easing transitions for expand/collapse
- **Contextual UI**: Adapt interface based on notification type (conversation, media, system)

### Performance
- Use efficient data structures for notification storage
- Implement proper cleanup for dismissed notifications
- Consider virtualization for large notification lists

## Notes

- **D-Bus Integration** - The service automatically handles D-Bus registration and interface implementation
- **Hot Reloading** - Notifications can optionally persist across quickshell reloads
- **Thread Safety** - All operations are thread-safe and properly synchronized
- **Specification Compliance** - Fully implements the Desktop Notifications Specification
- **Image Support** - Handles both file paths and embedded D-Bus image data
- **Action Icons** - Supports action icons when `actionIconsSupported` is enabled
- **Markup Support** - Can handle HTML-like markup in notification body when enabled
- **Inline Reply** - Supports quick replies for messaging applications when enabled
- You must explicitly track notifications by setting `tracked: true`
- The server doesn't advertise capabilities by default - you must enable them
- Actions automatically dismiss non-resident notifications when invoked
- Notification IDs are unique within the current session
- Image paths can be local files or embedded D-Bus image data

## Migration Strategy

### Overview
This migration strategy helps you transition from other notification systems to Quickshell's native notification implementation, including support for the new inline reply feature.

### Phase 1: Assessment
1. **Inventory Current Features**
   - List all notification features your current setup uses
   - Document custom behaviors and UI elements
   - Note any application-specific handling

2. **Capability Mapping**
   - Map your features to Quickshell capabilities:
     - Basic text → `bodySupported` (enabled by default)
     - HTML/Markup → `bodyMarkupSupported`
     - Clickable links → `bodyHyperlinksSupported`
     - Images → `imageSupported`
     - Action buttons → `actionsSupported`
     - Icon buttons → `actionIconsSupported`
     - **Quick replies → `inlineReplySupported`** (NEW)
     - Persistence → `persistenceSupported`

### Phase 2: Basic Implementation
1. **Create Notification Server**
   ```qml
   NotificationServer {
       id: notificationServer
       
       // Start with minimal capabilities
       actionsSupported: false
       imageSupported: false
       inlineReplySupported: false
       
       onNotification: function(notification) {
           notification.tracked = true
           // Basic notification display
       }
   }
   ```

2. **Test Core Functionality**
   - Send test notifications: `notify-send "Test" "Basic notification"`
   - Verify reception and display
   - Check notification lifecycle

### Phase 3: Progressive Enhancement
1. **Enable Features Incrementally**
   ```qml
   NotificationServer {
       // Phase 3.1: Add images
       imageSupported: true
       
       // Phase 3.2: Add actions
       actionsSupported: true
       
       // Phase 3.3: Add inline replies
       inlineReplySupported: true
       
       // Phase 3.4: Add markup
       bodyMarkupSupported: true
   }
   ```

2. **Implement UI for Each Feature**
   - Images: Add Image component with fallback
   - Actions: Create button row with action handling
   - **Inline Reply: Add TextField with send button** (NEW)
   - Markup: Use Text component with textFormat

### Phase 4: Inline Reply Implementation (NEW)

1. **Detection and UI Creation**
   ```qml
   onNotification: function(notification) {
       notification.tracked = true
       
       if (notification.hasInlineReply) {
           // Create UI with reply field
           createReplyableNotification(notification)
       } else {
           // Standard notification UI
           createStandardNotification(notification)
       }
   }
   ```

2. **Reply UI Component**
   ```qml
   // Minimal inline reply UI
   Row {
       visible: notification.hasInlineReply
       
       TextField {
           id: replyInput
           placeholderText: notification.inlineReplyPlaceholder
           onAccepted: {
               if (text) notification.sendInlineReply(text)
           }
       }
       
       Button {
           text: "Send"
           enabled: replyInput.text.length > 0
           onClicked: {
               notification.sendInlineReply(replyInput.text)
           }
       }
   }
   ```

3. **Testing Inline Reply**
   - Test with messaging apps (Telegram, Discord, etc.)
   - Verify reply delivery
   - Check notification dismissal behavior

### Phase 5: Advanced Android 16-Style Features

1. **Smart Notification Grouping**
   - Group by application and conversation
   - Implement automatic conversation detection
   - Handle channel-based grouping (Discord, Slack)
   - Smart media notification replacement

2. **Interactive Inline Reply**
   - Implement conversation threading for inline replies
   - Auto-expand conversation groups with new messages
   - Quick reply from collapsed notifications
   - Reply persistence and history

3. **Android 16-Style UI Elements**
   - Collapsible notification cards with smooth animations
   - Count badges for grouped notifications
   - Conversation avatars vs app icons
   - Progressive disclosure (show latest, expand for more)

4. **Advanced Behaviors**
   - Auto-expand conversations with new messages
   - Smart notification replacement for media
   - Context-aware grouping algorithms
   - Adaptive UI based on notification type

### Phase 6: Migration Completion

1. **Feature Parity Checklist**
   - [ ] All notifications display correctly
   - [ ] Actions work as expected
   - [ ] Images render properly
   - [ ] **Inline replies function correctly** (NEW)
   - [ ] Performance is acceptable
   - [ ] No missing notifications

2. **Cleanup**
   - Remove old notification daemon
   - Update system configuration
   - Document any custom behaviors

### Common Migration Issues

1. **Missing Notifications**
   - Ensure D-Bus service is registered
   - Check that old daemon is stopped
   - Verify no other notification handlers

2. **Inline Reply Not Working**
   - Confirm `inlineReplySupported: true`
   - Check application supports inline reply
   - Verify D-Bus communication

3. **Performance Issues**
   - Limit tracked notifications
   - Implement notification cleanup
   - Use efficient data structures

### Testing Applications

Test with various applications to ensure compatibility:
- **Basic**: `notify-send`, system notifications
- **Media**: Spotify, VLC, music players
- **Messaging**: Telegram, Discord, Signal (inline reply)
- **Email**: Thunderbird, Evolution
- **Development**: IDE notifications, build status

### Rollback Plan

Keep your old configuration available:
1. Document old notification daemon setup
2. Keep configuration files backed up
3. Test rollback procedure
4. Have quick switch mechanism ready

## Android 16-Style Implementation Demos

### Demo 1: Basic Grouped Popup Notifications

```qml
// Replace your existing NotificationInit.qml content
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications

PanelWindow {
    id: notificationPopup
    
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
        right: 16
    }
    
    implicitWidth: 420
    implicitHeight: groupedNotificationsList.height + 32
    
    Column {
        id: groupedNotificationsList
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 16
        anchors.rightMargin: 16
        spacing: 12
        width: 400
        
        Repeater {
            model: NotificationService.groupedPopups
            
            delegate: AndroidStyleGroupedNotificationCard {
                required property var modelData
                group: modelData
                width: parent.width
                
                // Auto-dismiss single notifications
                Timer {
                    running: group.count === 1 && group.latestNotification.popup
                    interval: group.latestNotification.notification.expireTimeout > 0 ? 
                             group.latestNotification.notification.expireTimeout : 5000
                    onTriggered: {
                        group.latestNotification.popup = false
                    }
                }
                
                // Don't auto-dismiss conversation groups - let user interact
                property bool isConversationGroup: group.isConversation && group.count > 1
            }
        }
    }
}

component AndroidStyleGroupedNotificationCard: Rectangle {
    id: root
    
    property var group
    property bool autoExpanded: group.isConversation && group.count > 1
    
    height: contentColumn.height + 24
    radius: 16
    color: "#1a1a1a"
    border.color: group.latestNotification.urgency === 2 ? "#ff4444" : "#333333"
    border.width: 1
    
    Column {
        id: contentColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 12
        
        // Header row
        Row {
            width: parent.width
            spacing: 12
            
            Rectangle {
                width: 48
                height: 48
                radius: group.isConversation ? 24 : 8
                color: "#333333"
                
                Image {
                    anchors.fill: parent
                    anchors.margins: group.isConversation ? 0 : 8
                    source: group.latestNotification.image || group.latestNotification.appIcon
                    fillMode: Image.PreserveAspectCrop
                    radius: parent.radius
                }
            }
            
            Column {
                width: parent.width - 60 - 60
                spacing: 4
                
                Row {
                    width: parent.width
                    spacing: 8
                    
                    Text {
                        text: group.appName
                        color: "#888888"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    
                    Rectangle {
                        width: Math.max(20, countText.width + 8)
                        height: 16
                        radius: 8
                        color: "#4a9eff"
                        visible: group.count > 1
                        
                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: group.count
                            color: "#ffffff"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                }
                
                Text {
                    text: getGroupTitle()
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    width: parent.width
                    elide: Text.ElideRight
                }
                
                Text {
                    text: group.latestNotification.body
                    color: "#cccccc"
                    font.pixelSize: 13
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: autoExpanded ? -1 : 2
                    elide: Text.ElideRight
                }
            }
            
            Button {
                width: 32
                height: 32
                text: "✕"
                onClicked: NotificationService.dismissGroup(group.key)
            }
        }
        
        // Inline reply for conversations
        Row {
            width: parent.width
            spacing: 8
            visible: group.hasInlineReply
            
            TextField {
                id: replyField
                width: parent.width - 60
                height: 36
                placeholderText: "Reply..."
                background: Rectangle {
                    color: "#2a2a2a"
                    radius: 18
                    border.color: parent.activeFocus ? "#4a9eff" : "#444444"
                }
                color: "#ffffff"
                
                onAccepted: {
                    if (text.length > 0) {
                        group.latestNotification.notification.sendInlineReply(text)
                        text = ""
                    }
                }
            }
            
            Button {
                width: 52
                height: 36
                text: "Send"
                enabled: replyField.text.length > 0
                onClicked: {
                    group.latestNotification.notification.sendInlineReply(replyField.text)
                    replyField.text = ""
                }
            }
        }
        
        // Actions row
        Row {
            spacing: 8
            visible: group.latestNotification.actions && group.latestNotification.actions.length > 0
            
            Repeater {
                model: group.latestNotification.actions || []
                delegate: Button {
                    text: modelData.text
                    height: 32
                    onClicked: modelData.invoke()
                }
            }
        }
    }
    
    function getGroupTitle() {
        if (group.count === 1) {
            return group.latestNotification.summary
        }
        
        if (group.isConversation) {
            return `${group.count} new messages`
        }
        
        if (group.isMedia) {
            return "Now playing"
        }
        
        return `${group.count} notifications`
    }
}
```

### Demo 2: Notification History with Grouping

```qml
// Update your NotificationCenter.qml to use grouped notifications
ListView {
    model: NotificationService.groupedNotifications
    spacing: 12
    
    delegate: AndroidStyleGroupedNotificationCard {
        width: ListView.view.width
        group: modelData
        
        // History mode - always show expanded view for better browsing
        autoExpanded: true
        showAllNotifications: true
        
        property bool showAllNotifications: false
        
        // Override content to show more notifications
        // ... (extend the component to show paginated history)
    }
}
```

### Demo 3: Service Integration

```qml
// Update your NotificationService.qml to add grouping capabilities
pragma Singleton
import QtQuick
import Quickshell.Services.Notifications

Singleton {
    id: root
    
    readonly property list<NotifWrapper> notifications: []
    readonly property list<NotifWrapper> popups: notifications.filter(n => n.popup)
    
    // New grouped properties
    readonly property var groupedNotifications: getGroupedNotifications()
    readonly property var groupedPopups: getGroupedPopups()
    
    NotificationServer {
        id: server
        
        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        inlineReplySupported: true  // Enable inline reply
        
        onNotification: notif => {
            notif.tracked = true;
            const wrapper = notifComponent.createObject(root, {
                popup: true,
                notification: notif
            });
            root.notifications.push(wrapper);
        }
    }
    
    // ... (rest of your existing NotifWrapper and helper functions)
    
    // New grouping functions
    function getGroupKey(wrapper) {
        const appName = wrapper.appName || "Unknown";
        
        if (wrapper.isConversation) {
            const summary = wrapper.summary.toLowerCase();
            if (summary.match(/^[#@]?[\w\s]+$/)) {
                return appName + ":" + wrapper.summary;
            }
            return appName + ":conversation";
        }
        
        if (wrapper.isMedia) {
            return appName + ":media";
        }
        
        if (wrapper.isSystem) {
            return appName + ":system";
        }
        
        return appName;
    }
    
    function getGroupedNotifications() {
        const groups = {};
        
        for (const notif of notifications) {
            const groupKey = getGroupKey(notif);
            if (!groups[groupKey]) {
                groups[groupKey] = {
                    key: groupKey,
                    appName: notif.appName,
                    notifications: [],
                    latestNotification: null,
                    count: 0,
                    hasInlineReply: false,
                    isConversation: notif.isConversation,
                    isMedia: notif.isMedia,
                    isSystem: notif.isSystem
                };
            }
            
            groups[groupKey].notifications.unshift(notif);
            groups[groupKey].latestNotification = groups[groupKey].notifications[0];
            groups[groupKey].count = groups[groupKey].notifications.length;
            
            if (notif.notification.hasInlineReply) {
                groups[groupKey].hasInlineReply = true;
            }
        }
        
        return Object.values(groups).sort((a, b) => {
            return b.latestNotification.time.getTime() - a.latestNotification.time.getTime();
        });
    }
    
    function getGroupedPopups() {
        const groups = {};
        
        for (const notif of popups) {
            const groupKey = getGroupKey(notif);
            if (!groups[groupKey]) {
                groups[groupKey] = {
                    key: groupKey,
                    appName: notif.appName,
                    notifications: [],
                    latestNotification: null,
                    count: 0,
                    hasInlineReply: false,
                    isConversation: notif.isConversation,
                    isMedia: notif.isMedia,
                    isSystem: notif.isSystem
                };
            }
            
            groups[groupKey].notifications.unshift(notif);
            groups[groupKey].latestNotification = groups[groupKey].notifications[0];
            groups[groupKey].count = groups[groupKey].notifications.length;
            
            if (notif.notification.hasInlineReply) {
                groups[groupKey].hasInlineReply = true;
            }
        }
        
        return Object.values(groups).sort((a, b) => {
            return b.latestNotification.time.getTime() - a.latestNotification.time.getTime();
        });
    }
    
    function dismissGroup(groupKey) {
        const notificationsCopy = [...notifications];
        for (const notif of notificationsCopy) {
            if (getGroupKey(notif) === groupKey) {
                notif.notification.dismiss();
            }
        }
    }
}
```

### Demo 4: Testing Your Implementation

```bash
# Test basic notifications
notify-send "Test App" "Single notification"

# Test conversation grouping (Discord simulation)
notify-send "Discord" "#general" -i discord
notify-send "Discord" "#general" -i discord
notify-send "Discord" "john_doe" -i discord

# Test media notifications
notify-send "Spotify" "Now Playing" "Song Title - Artist" -i spotify

# Test inline reply (requires supporting app)
# This would come from messaging apps that support inline reply
```