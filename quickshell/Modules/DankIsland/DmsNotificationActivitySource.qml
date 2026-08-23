pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Common
import qs.Services

QtObject {
    id: root

    required property IslandController controller
    required property var targetScreen

    property var currentWrapper: null
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string timeText: ""
    property string imageSource: ""
    property string fallbackIcon: "material:notifications"
    property string fallbackText: ""
    property string actionLabel: ""
    property bool critical: false
    property int demoIndex: 0

    readonly property bool demoEnabled: Quickshell.env("DMS_DANKISLAND_NOTIFICATION_DEMO") === "1"
    readonly property bool hasAction: actionLabel.length > 0
    // Keep the wrapper alive while the island is hovered or expanded, matching NotificationPopup.
    readonly property bool wrapperTimeoutHeld: (controller.notificationActive && controller.timeoutSuspended) || controller.notificationHeldForSystem

    function isFocusedScreen() {
        if (!SettingsData.notificationFocusedMonitor)
            return true;
        const focused = CompositorService.getFocusedScreen();
        return !!focused && !!root.targetScreen && focused.name === root.targetScreen.name;
    }

    // Hold display fields through the outgoing crossfade.
    function scheduleDisplayFieldClear() {
        displayFieldClearTimer.restart();
    }

    function clearDisplayFields() {
        if (currentWrapper)
            return;
        appName = "";
        summary = "";
        body = "";
        timeText = "";
        imageSource = "";
        fallbackIcon = "material:notifications";
        fallbackText = "";
        actionLabel = "";
        critical = false;
    }

    function wrapperTimeout(wrapper) {
        const interval = wrapper?.timer?.interval ?? -1;
        return interval >= 0 ? interval : 5000;
    }

    function plainText(value) {
        return String(value || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
    }

    function resolveImage(wrapper) {
        const image = wrapper?.cleanImage || "";
        if (image)
            return image;
        const icon = wrapper?.appIcon || "";
        if (icon.startsWith("file://") || icon.startsWith("http://") || icon.startsWith("https://") || icon.includes("/"))
            return icon;
        return "";
    }

    function resolveFallbackIcon(wrapper) {
        const rawImage = wrapper?.image || "";
        if (rawImage.startsWith("image://icon/"))
            return rawImage.substring(13);
        return wrapper?.appIcon || "material:notifications";
    }

    function applyWrapperTimeoutHold() {
        const timer = currentWrapper?.timer;
        if (!timer)
            return;
        if (wrapperTimeoutHeld) {
            timer.stop();
            return;
        }
        if (currentWrapper.popup && timer.interval > 0)
            timer.restart();
    }

    function releaseWrapperTimeoutHold() {
        const timer = currentWrapper?.timer;
        if (!timer || !currentWrapper.popup || timer.interval <= 0)
            return;
        timer.restart();
    }

    function adopt(wrapper) {
        if (!wrapper || !isFocusedScreen())
            return false;

        const isCritical = wrapper.urgency === NotificationUrgency.Critical;
        if (!controller.canRequestNotification(isCritical))
            return false;

        releaseWrapperTimeoutHold();
        displayFieldClearTimer.stop();
        currentWrapper = wrapper;
        appName = wrapper.appName || "Notification";
        summary = plainText(wrapper.summary) || appName;
        body = plainText(wrapper.body);
        timeText = wrapper.timeStr || "Now";
        imageSource = resolveImage(wrapper);
        fallbackIcon = resolveFallbackIcon(wrapper);
        fallbackText = appName.charAt(0).toUpperCase();
        critical = isCritical;
        const actions = wrapper.actions || [];
        actionLabel = actions.length > 0 ? (actions[0].text || "Open") : "";
        controller.notificationTimeout = wrapperTimeout(wrapper);
        const accepted = controller.requestNotification(isCritical);
        applyWrapperTimeoutHold();
        return accepted;
    }

    function refreshDeduplicated(wrapper) {
        if (!wrapper || wrapper !== currentWrapper)
            return;
        controller.refreshNotification();
        applyWrapperTimeoutHold();
    }

    onWrapperTimeoutHeldChanged: applyWrapperTimeoutHold()

    function syncVisibleNotifications() {
        if (demoEnabled)
            return;

        const visible = NotificationService.visibleNotifications || [];
        if (visible.length > 0) {
            const latest = visible[visible.length - 1];
            if (latest === currentWrapper || adopt(latest))
                return;
        }

        if (currentWrapper && visible.indexOf(currentWrapper) === -1) {
            currentWrapper = null;
            controller.completeNotification();
            scheduleDisplayFieldClear();
        }
    }

    function activate() {
        if (demoEnabled) {
            controller.completeNotification();
            return;
        }
        const actions = currentWrapper?.actions || [];
        if (actions.length > 0)
            actions[0].invoke();
        dismiss();
    }

    function dismiss() {
        const wrapper = currentWrapper;
        currentWrapper = null;
        controller.completeNotification();
        scheduleDisplayFieldClear();
        if (!demoEnabled && wrapper)
            NotificationService.dismissNotification(wrapper);
    }

    function showDemo() {
        const variants = [
            {
                "appName": "Messages",
                "summary": "New message from Alex",
                "body": "The new activity transition looks great. Are we still on for tomorrow?",
                "icon": "material:mark_chat_unread",
                "action": "Reply"
            },
            {
                "appName": "Calendar",
                "summary": "Design review in 10 minutes",
                "body": "DankIsland activity protocol · Studio call",
                "icon": "material:event_upcoming",
                "action": "Open"
            }
        ];
        const demo = variants[demoIndex % variants.length];
        demoIndex += 1;
        if (!controller.canRequestNotification(false))
            return;
        releaseWrapperTimeoutHold();
        displayFieldClearTimer.stop();
        currentWrapper = null;
        appName = demo.appName;
        summary = demo.summary;
        body = demo.body;
        timeText = "Now";
        imageSource = "";
        fallbackIcon = demo.icon;
        fallbackText = demo.appName.charAt(0);
        actionLabel = demo.action;
        critical = false;
        controller.notificationTimeout = 5000;
        controller.requestNotification(false);
    }

    property Connections notificationConnections: Connections {
        target: NotificationService

        function onVisibleNotificationsChanged() {
            root.syncVisibleNotifications();
        }

        function onNotificationDeduplicated(wrapper) {
            root.refreshDeduplicated(wrapper);
        }
    }

    property Timer displayFieldClearTimer: Timer {
        interval: 400
        onTriggered: root.clearDisplayFields()
    }

    property Timer demoTimer: Timer {
        interval: 7000
        repeat: true
        running: root.demoEnabled
        onTriggered: root.showDemo()
    }

    Component.onCompleted: {
        if (demoEnabled)
            Qt.callLater(showDemo);
        else
            syncVisibleNotifications();
    }
}
