pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import "../Modules/DankDash/Wellbeing/Wellbeing.js" as Wellbeing

Singleton {
    id: root

    readonly property int idleTimeoutSeconds: 300
    readonly property int summaryDays: Wellbeing.monthLength
    readonly property var ownAppIds: ["com.danklinux.dms", "org.quickshell", "quickshell"]
    readonly property bool available: DMSService.isConnected && DMSService.capabilities.includes("wellbeing")
    readonly property bool enabled: SettingsData.wellbeingEnabled
    readonly property bool tracking: available && enabled
    readonly property bool sessionActive: !idleMonitor.isIdle && !IdleService.isShellLocked && !SessionService.locked
    readonly property string pushedState: tracking ? focusedAppId + "\n" + sessionActive : ""
    readonly property var limitParams: {
        const apps = {};
        const stored = SettingsData.wellbeingAppLimits ?? {};
        for (const appId in stored) {
            const minutes = Number(stored[appId]);
            if (minutes > 0)
                apps[appId] = minutes * 60;
        }
        return {
            "daily": Math.max(0, Number(SettingsData.wellbeingDailyLimit) || 0) * 60,
            "apps": apps
        };
    }
    readonly property Toplevel managerActiveToplevel: ToplevelManager.activeToplevel

    property string focusedAppId: ""
    property var today: Wellbeing.emptyDay("")
    property int revision: 0
    property real seq: 0

    IdleMonitor {
        id: idleMonitor
        timeout: root.idleTimeoutSeconds
        respectInhibitors: true
        enabled: root.tracking
    }

    onManagerActiveToplevelChanged: updateFocusedApp()
    onPushedStateChanged: pushState()
    onTrackingChanged: ensureSubscription()
    onLimitParamsChanged: pushLimits()

    Component.onCompleted: {
        updateFocusedApp();
        ensureSubscription();
    }

    Connections {
        target: CompositorService

        function onToplevelsChanged() {
            root.updateFocusedApp();
        }

        function onWorkspaceStateChanged() {
            root.updateFocusedApp();
        }
    }

    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            if (!DMSService.isConnected)
                return;
            root.ensureSubscription();
            root.pushLimits();
            root.pushState();
        }

        function onWellbeingStateUpdate(data) {
            root.handleStateUpdate(data);
        }
    }

    function updateFocusedApp() {
        const window = CompositorService.activeWindowForScreen(null, null, false);
        const appId = window?.appId ?? "";
        focusedAppId = ownAppIds.includes(appId) ? "" : appId;
    }

    function ensureSubscription() {
        const subscribed = DMSService.activeSubscriptions.includes("wellbeing");
        if (!enabled) {
            if (subscribed)
                DMSService.removeSubscription("wellbeing");
            return;
        }
        if (!available || subscribed || DMSService.activeSubscriptions.includes("all"))
            return;
        DMSService.addSubscription("wellbeing");
    }

    function pushState() {
        if (!available)
            return;
        seq = Math.max(Date.now(), seq + 1);
        DMSService.sendRequest("wellbeing.setState", {
            "appId": tracking ? focusedAppId : "",
            "active": tracking && sessionActive,
            "seq": seq
        }, null);
    }

    function pushLimits() {
        if (!available)
            return;
        DMSService.sendRequest("wellbeing.setLimits", limitParams, null);
    }

    function handleStateUpdate(data) {
        if (!data)
            return;
        if (data.today) {
            today = data.today;
            revision++;
        }
        if (data.resync) {
            pushLimits();
            pushState();
        }
        if (data.limit)
            notifyLimit(data.limit);
    }

    function notifyLimit(limit) {
        const summary = limit.kind === "daily" ? I18n.tr("Daily screen time limit reached") : I18n.tr("%1 limit reached", "screen time notification title, %1 is an app name").arg(appName(limit.appId));
        DMSService.notifySend({
            "summary": summary,
            "body": formatDuration(limit.used) + " · " + I18n.tr("Today"),
            "icon": "preferences-system-time"
        }, null);
    }

    function summary(callback) {
        if (!available) {
            callback([]);
            return;
        }
        DMSService.sendRequest("wellbeing.summary", {
            "days": summaryDays
        }, response => callback(response?.result?.days ?? []));
    }

    function clearHistory() {
        if (!available)
            return;
        DMSService.sendRequest("wellbeing.clear", null, null);
    }

    function appLimitMinutes(appId) {
        return Math.max(0, Number((SettingsData.wellbeingAppLimits ?? {})[appId]) || 0);
    }

    function setAppLimit(appId, minutes) {
        if (!appId)
            return;
        const limits = Object.assign({}, SettingsData.wellbeingAppLimits ?? {});
        if (minutes > 0)
            limits[appId] = minutes;
        else
            delete limits[appId];
        SettingsData.set("wellbeingAppLimits", limits);
    }

    function desktopEntry(appId) {
        return appId ? DesktopEntries.heuristicLookup(Paths.moddedAppId(appId)) : null;
    }

    function appName(appId) {
        return Paths.getAppName(appId, desktopEntry(appId));
    }

    function formatDuration(seconds) {
        const split = Wellbeing.splitDuration(seconds);
        if (split.hours === 0)
            return I18n.tr("%1m").arg(split.minutes);
        return I18n.tr("%1h %2m").arg(split.hours).arg(split.minutes);
    }
}
