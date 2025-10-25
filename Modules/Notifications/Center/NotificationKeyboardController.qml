import QtQuick
import qs.Common
import qs.Services

QtObject {
    id: controller

    property var listView: null
    property bool isOpen: false
    property var onClose: null

    property int selectionVersion: 0

    property bool keyboardNavigationActive: false
    property int selectedFlatIndex: 0
    property var flatNavigation: []
    property bool showKeyboardHints: false

    property string selectedNotificationId: ""
    property string selectedGroupKey: ""
    property string selectedItemType: ""
    property bool isTogglingGroup: false
    property bool isRebuilding: false

    function rebuildFlatNavigation() {
        isRebuilding = true

        const nav = []
        const groups = NotificationService.groupedNotifications

        for (let i = 0; i < groups.length; i++) {
            const group = groups[i]
            const isExpanded = NotificationService.expandedGroups[group.key] || false

            nav.push({
                         "type": "group",
                         "groupIndex": i,
                         "notificationIndex": -1,
                         "groupKey": group.key,
                         "notificationId": ""
                     })

            if (isExpanded) {
                const notifications = group.notifications || []
                for (let j = 0; j < notifications.length; j++) {
                    const notifId = String(notifications[j] && notifications[j].notification && notifications[j].notification.id ? notifications[j].notification.id : "")
                    nav.push({
                                 "type": "notification",
                                 "groupIndex": i,
                                 "notificationIndex": j,
                                 "groupKey": group.key,
                                 "notificationId": notifId
                             })
                }
            }
        }

        flatNavigation = nav
        updateSelectedIndexFromId()
        isRebuilding = false
    }

    function updateSelectedIndexFromId() {
        if (!keyboardNavigationActive) {
            return
        }

        for (let i = 0; i < flatNavigation.length; i++) {
            const item = flatNavigation[i]

            if (selectedItemType === "group" && item.type === "group" && item.groupKey === selectedGroupKey) {
                selectedFlatIndex = i
                selectionVersion++ // Trigger UI update
                return
            } else if (selectedItemType === "notification" && item.type === "notification" && String(item.notificationId) === String(selectedNotificationId)) {
                selectedFlatIndex = i
                selectionVersion++ // Trigger UI update
                return
            }
        }

        // If not found, try to find the same group but select the group header instead
        if (selectedItemType === "notification") {
            for (let j = 0; j < flatNavigation.length; j++) {
                const groupItem = flatNavigation[j]
                if (groupItem.type === "group" && groupItem.groupKey === selectedGroupKey) {
                    selectedFlatIndex = j
                    selectedItemType = "group"
                    selectedNotificationId = ""
                    selectionVersion++ // Trigger UI update
                    return
                }
            }
        }

        // If still not found, clamp to valid range and update
        if (flatNavigation.length > 0) {
            selectedFlatIndex = Math.min(selectedFlatIndex, flatNavigation.length - 1)
            selectedFlatIndex = Math.max(selectedFlatIndex, 0)
            updateSelectedIdFromIndex()
            selectionVersion++ // Trigger UI update
        }
    }

    function updateSelectedIdFromIndex() {
        if (selectedFlatIndex >= 0 && selectedFlatIndex < flatNavigation.length) {
            const item = flatNavigation[selectedFlatIndex]
            selectedItemType = item.type
            selectedGroupKey = item.groupKey
            selectedNotificationId = item.notificationId
        }
    }

    function reset() {
        selectedFlatIndex = 0
        keyboardNavigationActive = false
        showKeyboardHints = false
        // Reset keyboardActive when modal is reset
        if (listView) {
            listView.keyboardActive = false
        }
        rebuildFlatNavigation()
    }

    function selectNext() {
        keyboardNavigationActive = true
        if (flatNavigation.length === 0)
            return

        // Re-enable auto-scrolling when arrow keys are used
        if (listView && listView.enableAutoScroll) {
            listView.enableAutoScroll()
        }

        selectedFlatIndex = Math.min(selectedFlatIndex + 1, flatNavigation.length - 1)
        updateSelectedIdFromIndex()
        selectionVersion++
        ensureVisible()
    }

    function selectNextWrapping() {
        keyboardNavigationActive = true
        if (flatNavigation.length === 0)
            return

        // Re-enable auto-scrolling when arrow keys are used
        if (listView && listView.enableAutoScroll) {
            listView.enableAutoScroll()
        }

        selectedFlatIndex = (selectedFlatIndex + 1) % flatNavigation.length
        updateSelectedIdFromIndex()
        selectionVersion++
        ensureVisible()
    }

    function selectPrevious() {
        keyboardNavigationActive = true
        if (flatNavigation.length === 0)
            return

        // Re-enable auto-scrolling when arrow keys are used
        if (listView && listView.enableAutoScroll) {
            listView.enableAutoScroll()
        }

        selectedFlatIndex = Math.max(selectedFlatIndex - 1, 0)
        updateSelectedIdFromIndex()
        selectionVersion++
        ensureVisible()
    }

    function toggleGroupExpanded() {
        if (flatNavigation.length === 0 || selectedFlatIndex >= flatNavigation.length)
            return

        const currentItem = flatNavigation[selectedFlatIndex]
        const groups = NotificationService.groupedNotifications
        const group = groups[currentItem.groupIndex]
        if (!group)
            return

        // Prevent expanding groups with < 2 notifications
        const notificationCount = group.notifications ? group.notifications.length : 0
        if (notificationCount < 2)
            return

        const wasExpanded = NotificationService.expandedGroups[group.key] || false
        const groupIndex = currentItem.groupIndex

        isTogglingGroup = true
        NotificationService.toggleGroupExpansion(group.key)
        rebuildFlatNavigation()

        // Smart selection after toggle
        if (!wasExpanded) {
            // Just expanded - move to first notification in the group
            for (let i = 0; i < flatNavigation.length; i++) {
                if (flatNavigation[i].type === "notification" && flatNavigation[i].groupIndex === groupIndex) {
                    selectedFlatIndex = i
                    break
                }
            }
        } else {
            // Just collapsed - stay on the group header
            for (let i = 0; i < flatNavigation.length; i++) {
                if (flatNavigation[i].type === "group" && flatNavigation[i].groupIndex === groupIndex) {
                    selectedFlatIndex = i
                    break
                }
            }
        }

        isTogglingGroup = false
        ensureVisible()
    }

    function handleEnterKey() {
        if (flatNavigation.length === 0 || selectedFlatIndex >= flatNavigation.length)
            return

        const currentItem = flatNavigation[selectedFlatIndex]
        const groups = NotificationService.groupedNotifications
        const group = groups[currentItem.groupIndex]
        if (!group)
            return

        if (currentItem.type === "group") {
            const notificationCount = group.notifications ? group.notifications.length : 0
            if (notificationCount >= 2) {
                toggleGroupExpanded()
            } else {
                executeAction(0)
            }
        } else if (currentItem.type === "notification") {
            executeAction(0)
        }
    }

    function toggleTextExpanded() {
        if (flatNavigation.length === 0 || selectedFlatIndex >= flatNavigation.length)
            return

        const currentItem = flatNavigation[selectedFlatIndex]
        const groups = NotificationService.groupedNotifications
        const group = groups[currentItem.groupIndex]
        if (!group)
            return

        let messageId = ""

        if (currentItem.type === "group") {
            messageId = group.latestNotification?.notification?.id + "_desc"
        } else if (currentItem.type === "notification" && currentItem.notificationIndex >= 0 && currentItem.notificationIndex < group.notifications.length) {
            messageId = group.notifications[currentItem.notificationIndex]?.notification?.id + "_desc"
        }

        if (messageId) {
            NotificationService.toggleMessageExpansion(messageId)
        }
    }

    function executeAction(actionIndex) {
        if (flatNavigation.length === 0 || selectedFlatIndex >= flatNavigation.length)
            return

        const currentItem = flatNavigation[selectedFlatIndex]
        const groups = NotificationService.groupedNotifications
        const group = groups[currentItem.groupIndex]
        if (!group)
            return

        let actions = []

        if (currentItem.type === "group") {
            actions = group.latestNotification?.actions || []
        } else if (currentItem.type === "notification" && currentItem.notificationIndex >= 0 && currentItem.notificationIndex < group.notifications.length) {
            actions = group.notifications[currentItem.notificationIndex]?.actions || []
        }

        if (actionIndex >= 0 && actionIndex < actions.length) {
            const action = actions[actionIndex]
            if (action.invoke) {
                action.invoke()
                if (onClose)
                    onClose()
            }
        }
    }

    function clearSelected() {
        if (flatNavigation.length === 0 || selectedFlatIndex >= flatNavigation.length)
            return

        const currentItem = flatNavigation[selectedFlatIndex]
        const groups = NotificationService.groupedNotifications
        const group = groups[currentItem.groupIndex]
        if (!group)
            return

        if (currentItem.type === "group") {
            NotificationService.dismissGroup(group.key)
        } else if (currentItem.type === "notification") {
            const notification = group.notifications[currentItem.notificationIndex]
            NotificationService.dismissNotification(notification)
        }

        rebuildFlatNavigation()

        if (flatNavigation.length === 0) {
            keyboardNavigationActive = false
            if (listView) {
                listView.keyboardActive = false
            }
        } else {
            selectedFlatIndex = Math.min(selectedFlatIndex, flatNavigation.length - 1)
            updateSelectedIdFromIndex()
            ensureVisible()
        }
    }

    function ensureVisible() {
        if (flatNavigation.length === 0 || selectedFlatIndex >= flatNavigation.length || !listView)
            return

        const currentItem = flatNavigation[selectedFlatIndex]

        if (keyboardNavigationActive && currentItem && currentItem.groupIndex >= 0) {
            // Always center the selected item for better visibility
            // This ensures the selected item stays in view even when new notifications arrive
            if (currentItem.type === "notification") {
                // For individual notifications, center on the group but bias towards the notification
                listView.positionViewAtIndex(currentItem.groupIndex, ListView.Center)
            } else {
                // For group headers, center on the group
                listView.positionViewAtIndex(currentItem.groupIndex, ListView.Center)
            }

            // Force immediate update
            listView.forceLayout()
        }
    }

    function handleKey(event) {
        if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && (event.modifiers & Qt.ShiftModifier)) {
            NotificationService.clearAllNotifications()
            rebuildFlatNavigation()
            if (flatNavigation.length === 0) {
                keyboardNavigationActive = false
                if (listView) {
                    listView.keyboardActive = false
                }
            } else {
                selectedFlatIndex = 0
                updateSelectedIdFromIndex()
            }
            selectionVersion++
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Escape) {
            if (keyboardNavigationActive) {
                keyboardNavigationActive = false
                event.accepted = true
            } else {
                if (onClose)
                    onClose()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J || event.key === 16777237) {
            if (!keyboardNavigationActive) {
                keyboardNavigationActive = true
                rebuildFlatNavigation() // Ensure we have fresh navigation data
                selectedFlatIndex = 0
                updateSelectedIdFromIndex()
                // Set keyboardActive on listView to show highlight
                if (listView) {
                    listView.keyboardActive = true
                }
                selectionVersion++
                ensureVisible()
                event.accepted = true
            } else {
                selectNext()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K || event.key === 16777235) {
            if (!keyboardNavigationActive) {
                keyboardNavigationActive = true
                rebuildFlatNavigation() // Ensure we have fresh navigation data
                selectedFlatIndex = 0
                updateSelectedIdFromIndex()
                // Set keyboardActive on listView to show highlight
                if (listView) {
                    listView.keyboardActive = true
                }
                selectionVersion++
                ensureVisible()
                event.accepted = true
            } else if (selectedFlatIndex === 0) {
                keyboardNavigationActive = false
                // Reset keyboardActive when navigation is disabled
                if (listView) {
                    listView.keyboardActive = false
                }
                selectionVersion++
                event.accepted = true
                return
            } else {
                selectPrevious()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier) {
            if (!keyboardNavigationActive) {
                keyboardNavigationActive = true
                rebuildFlatNavigation()
                selectedFlatIndex = 0
                updateSelectedIdFromIndex()
                if (listView) {
                    listView.keyboardActive = true
                }
                selectionVersion++
                ensureVisible()
            } else {
                selectNext()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier) {
            if (!keyboardNavigationActive) {
                keyboardNavigationActive = true
                rebuildFlatNavigation()
                selectedFlatIndex = 0
                updateSelectedIdFromIndex()
                if (listView) {
                    listView.keyboardActive = true
                }
                selectionVersion++
                ensureVisible()
            } else if (selectedFlatIndex === 0) {
                keyboardNavigationActive = false
                if (listView) {
                    listView.keyboardActive = false
                }
                selectionVersion++
            } else {
                selectPrevious()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier) {
            if (!keyboardNavigationActive) {
                keyboardNavigationActive = true
                rebuildFlatNavigation()
                selectedFlatIndex = 0
                updateSelectedIdFromIndex()
                if (listView) {
                    listView.keyboardActive = true
                }
                selectionVersion++
                ensureVisible()
            } else {
                selectNext()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier) {
            if (!keyboardNavigationActive) {
                keyboardNavigationActive = true
                rebuildFlatNavigation()
                selectedFlatIndex = 0
                updateSelectedIdFromIndex()
                if (listView) {
                    listView.keyboardActive = true
                }
                selectionVersion++
                ensureVisible()
            } else if (selectedFlatIndex === 0) {
                keyboardNavigationActive = false
                if (listView) {
                    listView.keyboardActive = false
                }
                selectionVersion++
            } else {
                selectPrevious()
            }
            event.accepted = true
        } else if (keyboardNavigationActive) {
            if (event.key === Qt.Key_Space) {
                toggleGroupExpanded()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                handleEnterKey()
                event.accepted = true
            } else if (event.key === Qt.Key_E) {
                toggleTextExpanded()
                event.accepted = true
            } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                clearSelected()
                event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
                selectNext()
                event.accepted = true
            } else if (event.key === Qt.Key_Backtab) {
                selectPrevious()
                event.accepted = true
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                const actionIndex = event.key - Qt.Key_1
                executeAction(actionIndex)
                event.accepted = true
            }
        }

        if (event.key === Qt.Key_F10) {
            showKeyboardHints = !showKeyboardHints
            event.accepted = true
        }
    }

    // Get current selection info for UI
    function getCurrentSelection() {
        if (!keyboardNavigationActive || selectedFlatIndex < 0 || selectedFlatIndex >= flatNavigation.length) {
            return {
                "type": "",
                "groupIndex": -1,
                "notificationIndex": -1
            }
        }
        const result = flatNavigation[selectedFlatIndex] || {
            "type": "",
            "groupIndex": -1,
            "notificationIndex": -1
        }
        return result
    }
}
