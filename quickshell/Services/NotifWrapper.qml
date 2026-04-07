import QtQuick
import Quickshell.Services.Notifications
import qs.Common

QtObject {
    id: wrapper

    property bool popup: false
    property bool removedByLimit: false
    property bool isPersistent: true
    property int seq: 0
    property string persistedImagePath: ""

    onPopupChanged: {
        if (!popup) {
            NotificationService.removeFromVisibleNotifications(wrapper);
        }
    }

    readonly property Timer timer: Timer {
        interval: {
            if (!wrapper.notification)
                return 5000;
            switch (wrapper.urgency) {
            case NotificationUrgency.Low:
                return SettingsData.notificationTimeoutLow;
            case NotificationUrgency.Critical:
                return SettingsData.notificationTimeoutCritical;
            default:
                return SettingsData.notificationTimeoutNormal;
            }
        }
        repeat: false
        running: false
        onTriggered: {
            if (interval > 0) {
                wrapper.popup = false;
            }
        }
    }

    readonly property date time: new Date()
    readonly property string timeStr: {
        NotificationService.timeUpdateTick;
        NotificationService.clockFormatChanged;

        const now = new Date();
        const diff = now.getTime() - time.getTime();
        const minutes = Math.floor(diff / 60000);
        const hours = Math.floor(minutes / 60);

        if (hours < 1) {
            if (minutes < 1) {
                return "now";
            }
            return `${minutes}m ago`;
        }

        const nowDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const timeDate = new Date(time.getFullYear(), time.getMonth(), time.getDate());
        const daysDiff = Math.floor((nowDate - timeDate) / (1000 * 60 * 60 * 24));

        if (daysDiff === 0) {
            return formatTime(time);
        }

        try {
            const localeName = (typeof I18n !== "undefined" && I18n.locale) ? I18n.locale().name : "en-US";
            const weekday = time.toLocaleDateString(localeName, {
                weekday: "long"
            });
            return `${weekday}, ${formatTime(time)}`;
        } catch (e) {
            return formatTime(time);
        }
    }

    function formatTime(date) {
        let use24Hour = true;
        try {
            if (typeof SettingsData !== "undefined" && SettingsData.use24HourClock !== undefined) {
                use24Hour = SettingsData.use24HourClock;
            }
        } catch (e) {
            use24Hour = true;
        }

        if (use24Hour) {
            return date.toLocaleTimeString(Qt.locale(), "HH:mm");
        } else {
            return date.toLocaleTimeString(Qt.locale(), "h:mm AP");
        }
    }

    required property Notification notification
    readonly property string summary: (notification?.summary ?? "").replace(/<img\b[^>]*>/gi, "")
    readonly property string body: (notification?.body ?? "").replace(/<img\b[^>]*>/gi, "")
    readonly property string htmlBody: NotificationService._resolveHtmlBody(body)
    readonly property string appIcon: notification?.appIcon ?? ""
    readonly property string appName: {
        if (!notification)
            return "app";
        if (notification.appName == "") {
            const entry = DesktopEntries.heuristicLookup(notification.desktopEntry);
            if (entry && entry.name)
                return entry.name.toLowerCase();
        }
        return notification.appName || "app";
    }
    readonly property string desktopEntry: notification?.desktopEntry ?? ""
    readonly property string image: notification?.image ?? ""
    readonly property string cleanImage: {
        if (!image)
            return "";
        return Paths.strip(image);
    }
    property int urgencyOverride: notification?.urgency ?? NotificationUrgency.Normal
    readonly property int urgency: urgencyOverride
    readonly property list<NotificationAction> actions: notification?.actions ?? []

    readonly property Connections conn: Connections {
        target: wrapper.notification?.Retainable ?? null

        function onDropped(): void {
            NotificationService.allWrappers = NotificationService.allWrappers.filter(w => w !== wrapper);
            NotificationService.notifications = NotificationService.notifications.filter(w => w !== wrapper);

            if (NotificationService.bulkDismissing) {
                return;
            }

            const groupKey = NotificationService.getGroupKey(wrapper);
            const remainingInGroup = NotificationService.notifications.filter(n => NotificationService.getGroupKey(n) === groupKey);

            if (remainingInGroup.length <= 1) {
                NotificationService.clearGroupExpansionState(groupKey);
            }

            NotificationService.cleanupExpansionStates();
            NotificationService._recomputeGroupsLater();
        }

        function onAboutToDestroy(): void {
            wrapper.destroy();
        }
    }
}
