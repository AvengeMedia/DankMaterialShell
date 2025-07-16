pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property list<NotifWrapper> notifications: []
    readonly property list<NotifWrapper> popups: notifications.filter(n => n.popup)
    
    // Android 16-style grouped notifications
    readonly property var groupedNotifications: getGroupedNotifications()
    readonly property var groupedPopups: getGroupedPopups()
    
    property var expandedGroups: ({}) // Track which groups are expanded

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        inlineReplySupported: true

        onNotification: notif => {
            console.log("New notification received:", notif.appName, "-", notif.summary);
            notif.tracked = true;

            const wrapper = notifComponent.createObject(root, {
                popup: true,
                notification: notif
            });

            if (wrapper) {
                root.notifications.push(wrapper);
                console.log("Notification added. Total notifications:", root.notifications.length);
                console.log("Grouped notifications:", root.groupedNotifications.length);
            } else {
                console.error("Failed to create notification wrapper");
            }
        }
    }

    component NotifWrapper: QtObject {
        id: wrapper

        property bool popup: true
        readonly property date time: new Date()
        readonly property string timeStr: {
            const now = new Date();
            const diff = now.getTime() - time.getTime();
            const m = Math.floor(diff / 60000);
            const h = Math.floor(m / 60);

            if (h < 1 && m < 1)
                return "now";
            if (h < 1)
                return `${m}m`;
            return `${h}h`;
        }

        required property Notification notification
        readonly property string summary: notification.summary
        readonly property string body: notification.body
        readonly property string appIcon: notification.appIcon
        readonly property string appName: notification.appName
        readonly property string image: notification.image
        readonly property int urgency: notification.urgency
        readonly property list<NotificationAction> actions: notification.actions

        // Enhanced properties for better handling
        readonly property bool hasImage: image && image.length > 0
        readonly property bool hasAppIcon: appIcon && appIcon.length > 0
        readonly property bool isConversation: detectIsConversation()
        readonly property bool isMedia: detectIsMedia()
        readonly property bool isSystem: detectIsSystem()

        function detectIsConversation() {
            const appNameLower = appName.toLowerCase();
            const summaryLower = summary.toLowerCase();
            const bodyLower = body.toLowerCase();
            
            return appNameLower.includes("discord") || 
                   appNameLower.includes("vesktop") ||
                   appNameLower.includes("vencord") ||
                   appNameLower.includes("telegram") ||
                   appNameLower.includes("whatsapp") ||
                   appNameLower.includes("signal") ||
                   appNameLower.includes("slack") ||
                   appNameLower.includes("message") ||
                   summaryLower.includes("message") ||
                   bodyLower.includes("message");
        }

        function detectIsMedia() {
            const appNameLower = appName.toLowerCase();
            const summaryLower = summary.toLowerCase();
            
            return appNameLower.includes("spotify") ||
                   appNameLower.includes("vlc") ||
                   appNameLower.includes("mpv") ||
                   appNameLower.includes("music") ||
                   appNameLower.includes("player") ||
                   summaryLower.includes("now playing") ||
                   summaryLower.includes("playing");
        }

        function detectIsSystem() {
            const appNameLower = appName.toLowerCase();
            const summaryLower = summary.toLowerCase();
            
            return appNameLower.includes("system") ||
                   appNameLower.includes("update") ||
                   summaryLower.includes("update") ||
                   summaryLower.includes("system");
        }

        readonly property Timer timer: Timer {
            running: wrapper.popup
            interval: wrapper.notification.expireTimeout > 0 ? wrapper.notification.expireTimeout : 5000 // 5 second default
            onTriggered: {
                wrapper.popup = false;
            }
        }

        readonly property Connections conn: Connections {
            target: wrapper.notification.Retainable

            function onDropped(): void {
                const index = root.notifications.indexOf(wrapper);
                if (index !== -1) {
                    root.notifications.splice(index, 1);
                }
            }

            function onAboutToDestroy(): void {
                wrapper.destroy();
            }
        }
    }

    Component {
        id: notifComponent
        NotifWrapper {}
    }

    // Helper functions
    function clearAllNotifications() {
        // Create a copy of the array to avoid modification during iteration
        const notificationsCopy = [...root.notifications];
        for (const notif of notificationsCopy) {
            notif.notification.dismiss();
        }
    }

    function dismissNotification(wrapper) {
        wrapper.notification.dismiss();
    }

    function getNotificationIcon(wrapper) {
        // Priority 1: Use notification image if available (Discord avatars, etc.)
        if (wrapper.hasImage) {
            return wrapper.image;
        }
        
        // Priority 2: Use app icon if available
        if (wrapper.hasAppIcon) {
            return Quickshell.iconPath(wrapper.appIcon, "image-missing");
        }
        
        // Priority 3: Generate fallback icon based on type
        return getFallbackIcon(wrapper);
    }

    function getFallbackIcon(wrapper) {
        if (wrapper.isConversation) {
            return Quickshell.iconPath("chat-symbolic");
        } else if (wrapper.isMedia) {
            return Quickshell.iconPath("audio-x-generic-symbolic");
        } else if (wrapper.isSystem) {
            return Quickshell.iconPath("preferences-system-symbolic");
        }
        return Quickshell.iconPath("application-x-executable-symbolic");
    }

    function getAppIconPath(wrapper) {
        if (wrapper.hasAppIcon) {
            return Quickshell.iconPath(wrapper.appIcon);
        }
        return getFallbackIcon(wrapper);
    }

    // Android 16-style notification grouping functions
    function getGroupKey(wrapper) {
        const appName = wrapper.appName.toLowerCase();
        
        // Group by app only - one group per unique application
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

    function toggleGroupExpansion(groupKey) {
        let newExpandedGroups = {};
        for (const key in expandedGroups) {
            newExpandedGroups[key] = expandedGroups[key];
        }
        newExpandedGroups[groupKey] = !newExpandedGroups[groupKey];
        expandedGroups = newExpandedGroups;
    }

    function dismissGroup(groupKey) {
        // Use array iteration to avoid spread operator issues
        for (let i = notifications.length - 1; i >= 0; i--) {
            const notif = notifications[i];
            if (getGroupKey(notif) === groupKey) {
                notif.notification.dismiss();
            }
        }
    }

    function getGroupTitle(group) {
        if (group.count === 1) {
            return group.latestNotification.summary;
        }
        
        if (group.isConversation) {
            return `${group.count} new messages`;
        }
        
        if (group.isMedia) {
            return "Now playing";
        }
        
        return `${group.count} notifications`;
    }

    function getGroupBody(group) {
        if (group.count === 1) {
            return group.latestNotification.body;
        }
        
        if (group.isConversation) {
            return group.latestNotification.body || "Tap to view messages";
        }
        
        return `Latest: ${group.latestNotification.summary}`;
    }
}