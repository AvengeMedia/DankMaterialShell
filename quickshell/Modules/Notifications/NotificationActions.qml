import QtQuick
import qs.Common
import qs.Services

QtObject {
    id: root
    property string appName: ""
    property string desktopEntry: ""
    property string dismissText: I18n.tr("Dismiss")
    readonly property bool isMuted: SettingsData.isAppMuted(appName, desktopEntry)
    readonly property bool isDndBypassed: SettingsData.isAppDndBypassed(appName, desktopEntry)
    signal dismissRequested
    signal appMuted

    readonly property var items: [
        {
            icon: "tune",
            label: I18n.tr("Set notification rules"),
            action: "rules"
        },
        {
            icon: isMuted ? "notifications" : "notifications_off",
            label: isMuted ? I18n.tr("Unmute popups for %1", "notification menu action, %1 is the app name").arg(appName || I18n.tr("this app")) : I18n.tr("Mute popups for %1", "notification menu action, %1 is the app name").arg(appName || I18n.tr("this app")),
            action: "mute"
        },
        {
            icon: isDndBypassed ? "do_not_disturb_on" : "do_not_disturb_off",
            label: isDndBypassed ? I18n.tr("Block %1 in Do Not Disturb", "notification menu action, %1 is the app name").arg(appName || I18n.tr("this app")) : I18n.tr("Allow %1 in Do Not Disturb", "notification menu action, %1 is the app name").arg(appName || I18n.tr("this app")),
            action: "dnd"
        },
        {
            icon: "close",
            label: root.dismissText,
            action: "dismiss"
        }
    ]

    function defaultAction(notification) {
        const actions = notification?.actions || [];
        return actions.find(action => action.identifier === "default") || actions[0] || null;
    }

    function trigger(action) {
        switch (action) {
        case "rules":
            SettingsData.addNotificationRuleForNotification(appName, desktopEntry);
            PopoutService.openSettingsWithTab("notifications");
            return;
        case "mute":
            if (isMuted) {
                SettingsData.removeMuteRuleForApp(appName, desktopEntry);
                return;
            }
            SettingsData.addMuteRuleForApp(appName, desktopEntry);
            appMuted();
            return;
        case "dnd":
            SettingsData.setAppDndBypass(appName, desktopEntry, !isDndBypassed);
            return;
        case "dismiss":
            dismissRequested();
        }
    }
}
