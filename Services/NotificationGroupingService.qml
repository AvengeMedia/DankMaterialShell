import QtQuick
import Quickshell
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    // Grouped notifications model - initialize as ListModel directly
    property ListModel groupedNotifications: ListModel {}
    
    // Total count of all notifications across all groups
    property int totalCount: 0
    
    // Map to track group indices by app name for efficient lookups
    property var appGroupMap: ({})
    
    // Debounce timer for sorting
    property bool _sortDirty: false
    Timer {
        id: sortTimer
        interval: 50  // 50ms debounce interval
        onTriggered: {
            if (_sortDirty) {
                sortGroupsByPriority()
                _sortDirty = false
            }
        }
    }
    
    // Configuration
    property int maxNotificationsPerGroup: 10
    property int maxGroups: 20
    
    // Priority constants for Android 16-style stacking
    readonly property int priorityHigh: 2      // Conversations, calls, media
    readonly property int priorityNormal: 1    // Regular notifications
    readonly property int priorityLow: 0       // System, background updates
    
    // Notification type constants
    readonly property int typeConversation: 1
    readonly property int typeMedia: 2
    readonly property int typeSystem: 3
    readonly property int typeNormal: 4
    
    
    
    // Format timestamp for display
    function formatTimestamp(timestamp) {
        if (!timestamp) return ""
        
        const now = new Date()
        const notifTime = new Date(timestamp)
        const diffMs = now.getTime() - notifTime.getTime()
        const diffMinutes = Math.floor(diffMs / 60000)
        const diffHours = Math.floor(diffMs / 3600000)
        const diffDays = Math.floor(diffMs / 86400000)
        
        if (diffMinutes < 1) {
            return "now"
        } else if (diffMinutes < 60) {
            return `${diffMinutes}m ago`
        } else if (diffHours < 24) {
            return `${diffHours}h ago`
        } else if (diffDays < 7) {
            return `${diffDays}d ago`
        } else {
            return notifTime.toLocaleDateString()
        }
    }
    
    // Add a new notification to the appropriate group
    function addNotification(notificationObj) {
        if (!notificationObj || !notificationObj.appName) {
            console.warn("Invalid notification object:", notificationObj)
            return
        }
        
        // Enhance notification with priority and type detection
        notificationObj = enhanceNotification(notificationObj)
        
        const appName = notificationObj.appName
        let groupIndex = appGroupMap[appName]
        
        if (groupIndex === undefined) {
            // Create new group
            groupIndex = createNewGroup(appName, notificationObj)
        } else {
            // Add to existing group
            addToExistingGroup(groupIndex, notificationObj)
        }
        
        updateTotalCount()
    }
    
    // Create a new notification group
    function createNewGroup(appName, notificationObj) {
        // Check if we need to remove oldest group
        if (groupedNotifications.count >= maxGroups) {
            removeOldestGroup()
        }
        
        const groupIndex = groupedNotifications.count
        const notificationsList = Qt.createQmlObject(`
            import QtQuick
            ListModel {}
        `, root)
        
        notificationsList.append(notificationObj)
        
        // Create properly structured latestNotification object
        const latestNotificationData = {
            "id": notificationObj.id || "",
            "appName": notificationObj.appName || "",
            "appIcon": notificationObj.appIcon || "",
            "summary": notificationObj.summary || "",
            "body": notificationObj.body || "",
            "timestamp": notificationObj.timestamp || new Date(),
            "priority": notificationObj.priority || priorityNormal,
            "notificationType": notificationObj.notificationType || typeNormal,
            "urgency": notificationObj.urgency || 1,
            "image": notificationObj.image || ""
        }
        
        const groupData = {
            "appName": appName,
            "appIcon": notificationObj.appIcon || "",
            "notifications": notificationsList,
            "totalCount": 1,
            "latestNotification": latestNotificationData,
            "expanded": false,
            "timestamp": notificationObj.timestamp || new Date(),
            "priority": notificationObj.priority || priorityNormal,
            "notificationType": notificationObj.notificationType || typeNormal
        }
        
        groupedNotifications.append(groupData)
        
        // Sort groups by priority after adding
        requestSort()
        
        appGroupMap[appName] = groupIndex
        updateGroupMap()
        
        return groupIndex
    }
    
    // Add notification to existing group
    function addToExistingGroup(groupIndex, notificationObj) {
        if (groupIndex >= groupedNotifications.count) {
            console.warn("Invalid group index:", groupIndex)
            return
        }
        
        const group = groupedNotifications.get(groupIndex)
        if (!group) return
        
        // Add to front of group (newest first)
        group.notifications.insert(0, notificationObj)
        
        // Create a new object with proper property structure for latestNotification
        const latestNotificationData = {
            "id": notificationObj.id || "",
            "appName": notificationObj.appName || "",
            "appIcon": notificationObj.appIcon || "",
            "summary": notificationObj.summary || "",
            "body": notificationObj.body || "",
            "timestamp": notificationObj.timestamp || new Date(),
            "priority": notificationObj.priority || priorityNormal,
            "notificationType": notificationObj.notificationType || typeNormal,
            "urgency": notificationObj.urgency || 1,
            "image": notificationObj.image || ""
        }
        
        // Update group metadata
        groupedNotifications.setProperty(groupIndex, "totalCount", group.totalCount + 1)
        groupedNotifications.setProperty(groupIndex, "latestNotification", latestNotificationData)
        groupedNotifications.setProperty(groupIndex, "timestamp", notificationObj.timestamp || new Date())
        
        // Update group priority if this notification has higher priority
        const currentPriority = group.priority || priorityNormal
        const newPriority = Math.max(currentPriority, notificationObj.priority || priorityNormal)
        groupedNotifications.setProperty(groupIndex, "priority", newPriority)
        
        // Update notification type if needed
        if (notificationObj.notificationType === typeConversation || 
            notificationObj.notificationType === typeMedia) {
            groupedNotifications.setProperty(groupIndex, "notificationType", notificationObj.notificationType)
        }
        
        // Keep only max notifications per group
        while (group.notifications.count > maxNotificationsPerGroup) {
            group.notifications.remove(group.notifications.count - 1)
        }
        
        // Re-sort groups by priority after updating
        requestSort()
    }
    
    // Request a debounced sort
    function requestSort() {
        _sortDirty = true
        sortTimer.restart()
    }

    // Sort groups by priority and recency
    function sortGroupsByPriority() {
        if (groupedNotifications.count <= 1) return

        for (let i = 0; i < groupedNotifications.count - 1; i++) {
            for (let j = 0; j < groupedNotifications.count - i - 1; j++) {
                const groupA = groupedNotifications.get(j)
                const groupB = groupedNotifications.get(j + 1)

                const priorityA = groupA.priority || priorityNormal
                const priorityB = groupB.priority || priorityNormal
                
                let shouldSwap = false
                if (priorityA !== priorityB) {
                    if (priorityB > priorityA) {
                        shouldSwap = true
                    }
                } else {
                    const timeA = new Date(groupA.timestamp || 0).getTime()
                    const timeB = new Date(groupB.timestamp || 0).getTime()
                    if (timeB > timeA) {
                        shouldSwap = true
                    }
                }

                if (shouldSwap) {
                    // Swap the elements at j and j + 1
                    groupedNotifications.move(j, j + 1, 1)
                }
            }
        }

        updateGroupMap()
    }
    
    // Remove the oldest group (least recent activity)
    function removeOldestGroup() {
        if (groupedNotifications.count === 0) return
        
        const lastIndex = groupedNotifications.count - 1
        const group = groupedNotifications.get(lastIndex)
        if (group) {
            delete appGroupMap[group.appName]
            groupedNotifications.remove(lastIndex)
            updateGroupMap()
        }
    }
    
    // Update the app group map after structural changes
    function updateGroupMap() {
        appGroupMap = {}
        for (let i = 0; i < groupedNotifications.count; i++) {
            const group = groupedNotifications.get(i)
            if (group) {
                appGroupMap[group.appName] = i
            }
        }
    }
    
    // Toggle group expansion state
    function toggleGroupExpansion(groupIndex) {
        if (groupIndex >= groupedNotifications.count) return
        
        const group = groupedNotifications.get(groupIndex)
        if (group) {
            groupedNotifications.setProperty(groupIndex, "expanded", !group.expanded)
        }
    }
    
    // Remove a specific notification from a group
    function removeNotification(groupIndex, notificationIndex) {
        if (groupIndex >= groupedNotifications.count) return
        
        const group = groupedNotifications.get(groupIndex)
        if (!group || notificationIndex >= group.notifications.count) return
        
        group.notifications.remove(notificationIndex)
        
        // Update group count
        const newCount = group.totalCount - 1
        groupedNotifications.setProperty(groupIndex, "totalCount", newCount)
        
        // If group is empty, remove it
        if (newCount === 0) {
            removeGroup(groupIndex)
        } else {
            // Update latest notification if we removed the latest one
            if (notificationIndex === 0 && group.notifications.count > 0) {
                const newLatest = group.notifications.get(0)
                
                // Create a new object with the correct structure
                const latestNotificationData = {
                    "id": newLatest.id || "",
                    "appName": newLatest.appName || "",
                    "appIcon": newLatest.appIcon || "",
                    "summary": newLatest.summary || "",
                    "body": newLatest.body || "",
                    "timestamp": newLatest.timestamp || new Date(),
                    "priority": newLatest.priority || priorityNormal,
                    "notificationType": newLatest.notificationType || typeNormal,
                    "urgency": newLatest.urgency || 1,
                    "image": newLatest.image || ""
                }
                
                groupedNotifications.setProperty(groupIndex, "latestNotification", latestNotificationData)
                
                // Update group priority after removal
                const newPriority = getGroupPriority(groupIndex)
                groupedNotifications.setProperty(groupIndex, "priority", newPriority)
            }
        }
        
        updateTotalCount()
    }
    
    // Remove an entire group
    function removeGroup(groupIndex) {
        if (groupIndex >= groupedNotifications.count) return

        const group = groupedNotifications.get(groupIndex)
        if (group) {
            delete appGroupMap[group.appName]
            groupedNotifications.remove(groupIndex)
            updateGroupMap() // Re-map all group indices
            updateTotalCount()
        }
    }
    
    // Clear all notifications
    function clearAllNotifications() {
        groupedNotifications.clear()
        appGroupMap = {}
        totalCount = 0
    }
    
    // Update total count across all groups
    function updateTotalCount() {
        let count = 0
        for (let i = 0; i < groupedNotifications.count; i++) {
            const group = groupedNotifications.get(i)
            if (group) {
                count += group.totalCount
            }
        }
        totalCount = count
    }
    
    // Enhance notification with priority and type detection
    function enhanceNotification(notificationObj) {
        const enhanced = Object.assign({}, notificationObj)
        
        // Detect notification type and priority
        enhanced.notificationType = detectNotificationType(enhanced)
        enhanced.priority = detectPriority(enhanced)
        
        return enhanced
    }
    
    // Detect notification type based on content and app
    function detectNotificationType(notification) {
        const appName = notification.appName?.toLowerCase() || ""
        const summary = notification.summary?.toLowerCase() || ""
        const body = notification.body?.toLowerCase() || ""
        
        // Media notifications
        if (appName.includes("music") || appName.includes("player") || 
            appName.includes("spotify") || appName.includes("youtube") ||
            summary.includes("now playing") || summary.includes("playing")) {
            return typeMedia
        }
        
        // Conversation notifications
        if (appName.includes("message") || appName.includes("chat") ||
            appName.includes("telegram") || appName.includes("whatsapp") ||
            appName.includes("discord") || appName.includes("slack") ||
            summary.includes("message") || body.includes("message")) {
            return typeConversation
        }
        
        // System notifications
        if (appName.includes("system") || appName.includes("update") ||
            summary.includes("update") || summary.includes("system")) {
            return typeSystem
        }
        
        return typeNormal
    }
    
    // Detect priority based on type and urgency
    function detectPriority(notification) {
        const notificationType = notification.notificationType
        const urgency = notification.urgency || 1  // Default to normal
        
        // High priority for conversations and media
        if (notificationType === typeConversation || notificationType === typeMedia) {
            return priorityHigh
        }
        
        // Low priority for system notifications
        if (notificationType === typeSystem) {
            return priorityLow
        }
        
        // Use urgency for regular notifications
        if (urgency >= 2) {
            return priorityHigh
        } else if (urgency >= 1) {
            return priorityNormal
        }
        
        return priorityLow
    }
    
    // Get group priority (highest priority notification in group)
    function getGroupPriority(groupIndex) {
        if (groupIndex >= groupedNotifications.count) return priorityLow
        
        const group = groupedNotifications.get(groupIndex)
        if (!group) return priorityLow
        
        let maxPriority = priorityLow
        for (let i = 0; i < group.notifications.count; i++) {
            const notification = group.notifications.get(i)
            if (notification && notification.priority > maxPriority) {
                maxPriority = notification.priority
            }
        }
        
        return maxPriority
    }
    
    // Generate smart group summary for collapsed state
    function generateGroupSummary(group) {
        if (!group || !group.notifications || group.notifications.count === 0) {
            return ""
        }
        
        const notificationCount = group.notifications.count
        const latestNotification = group.notifications.get(0)
        
        if (notificationCount === 1) {
            return latestNotification.summary || latestNotification.body || ""
        }
        
        // For conversations, show sender names
        if (latestNotification.notificationType === typeConversation) {
            const senders = []
            for (let i = 0; i < Math.min(3, notificationCount); i++) {
                const notif = group.notifications.get(i)
                if (notif && notif.summary && !senders.includes(notif.summary)) {
                    senders.push(notif.summary)
                }
            }
            
            if (senders.length > 0) {
                const remaining = notificationCount - senders.length
                if (remaining > 0) {
                    return `${senders.join(", ")} and ${remaining} other${remaining > 1 ? "s" : ""}`
                }
                return senders.join(", ")
            }
        }
        
        // For media, show current track info
        if (latestNotification.notificationType === typeMedia) {
            return latestNotification.summary || "Media playing"
        }
        
        // Generic summary for other types
        return `${notificationCount} notification${notificationCount > 1 ? "s" : ""}`
    }
    
    // Get notification by ID across all groups
    function getNotificationById(notificationId) {
        for (let i = 0; i < groupedNotifications.count; i++) {
            const group = groupedNotifications.get(i)
            if (!group) continue
            
            for (let j = 0; j < group.notifications.count; j++) {
                const notification = group.notifications.get(j)
                if (notification && notification.id === notificationId) {
                    return {
                        groupIndex: i,
                        notificationIndex: j,
                        notification: notification
                    }
                }
            }
        }
        return null
    }
    
    // Get group by app name
    function getGroupByAppName(appName) {
        const groupIndex = appGroupMap[appName]
        if (groupIndex !== undefined) {
            return {
                groupIndex: groupIndex,
                group: groupedNotifications.get(groupIndex)
            }
        }
        return null
    }
    
    // Get visible notifications for a group (considering expansion state)
    function getVisibleNotifications(groupIndex, maxVisible = 3) {
        if (groupIndex >= groupedNotifications.count) return []
        
        const group = groupedNotifications.get(groupIndex)
        if (!group) return []
        
        if (group.expanded) {
            // Show all notifications when expanded
            return group.notifications
        } else {
            // Show only the latest notification(s) when collapsed
            const visibleCount = Math.min(maxVisible, group.notifications.count)
            const visible = []
            for (let i = 0; i < visibleCount; i++) {
                visible.push(group.notifications.get(i))
            }
            return visible
        }
    }
}