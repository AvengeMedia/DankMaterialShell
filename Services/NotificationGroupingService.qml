import QtQuick
import Quickshell
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    // Grouped notifications model
    property var groupedNotifications: ListModel {}
    
    // Total count of all notifications across all groups
    property int totalCount: 0
    
    // Map to track group indices by app name for efficient lookups
    property var appGroupMap: ({})
    
    // Configuration
    property int maxNotificationsPerGroup: 10
    property int maxGroups: 20
    
    Component.onCompleted: {
        groupedNotifications = Qt.createQmlObject(`
            import QtQuick
            ListModel {}
        `, root)
    }
    
    // Add a new notification to the appropriate group
    function addNotification(notificationObj) {
        if (!notificationObj || !notificationObj.appName) {
            console.warn("Invalid notification object:", notificationObj)
            return
        }
        
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
        
        groupedNotifications.append({
            "appName": appName,
            "appIcon": notificationObj.appIcon || "",
            "notifications": notificationsList,
            "totalCount": 1,
            "latestNotification": notificationObj,
            "expanded": false,
            "timestamp": notificationObj.timestamp
        })
        
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
        
        // Update group metadata
        groupedNotifications.setProperty(groupIndex, "totalCount", group.totalCount + 1)
        groupedNotifications.setProperty(groupIndex, "latestNotification", notificationObj)
        groupedNotifications.setProperty(groupIndex, "timestamp", notificationObj.timestamp)
        
        // Keep only max notifications per group
        while (group.notifications.count > maxNotificationsPerGroup) {
            group.notifications.remove(group.notifications.count - 1)
        }
        
        // Move group to front (most recent activity)
        moveGroupToFront(groupIndex)
    }
    
    // Move a group to the front of the list
    function moveGroupToFront(groupIndex) {
        if (groupIndex === 0) return // Already at front
        
        const group = groupedNotifications.get(groupIndex)
        if (!group) return
        
        // Remove from current position
        groupedNotifications.remove(groupIndex)
        
        // Insert at front
        groupedNotifications.insert(0, group)
        
        // Update group map
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
                groupedNotifications.setProperty(groupIndex, "latestNotification", newLatest)
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
            updateGroupMap()
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