pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property list<NotifWrapper> notifications: []
    readonly property list<NotifWrapper> popups: notifications.filter(n => n.popup)

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: notif => {
            notif.tracked = true;

            const wrapper = notifComponent.createObject(root, {
                popup: true,
                notification: notif
            });

            root.notifications.push(wrapper);
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
            return Quickshell.iconPath("chat", "image-missing");
        } else if (wrapper.isMedia) {
            return Quickshell.iconPath("music_note", "image-missing");
        } else if (wrapper.isSystem) {
            return Quickshell.iconPath("settings", "image-missing");
        }
        return Quickshell.iconPath("apps", "image-missing");
    }

    function getAppIconPath(wrapper) {
        if (wrapper.hasAppIcon) {
            return Quickshell.iconPath(wrapper.appIcon, "image-missing");
        }
        return getFallbackIcon(wrapper);
    }
}