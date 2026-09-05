pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Item {
    id: root

    // One host per (island instance, screen), skipping a screen edge another island already holds.
    readonly property var hostSlots: {
        SettingsData.barConfigs;
        Quickshell.screens;
        const slots = [];
        for (const screen of Quickshell.screens) {
            const claimed = {};
            for (const config of SettingsData.activeIslandConfigsForScreen(screen)) {
                const edge = SettingsData.islandEdge(config);
                if (claimed[edge])
                    continue;
                claimed[edge] = true;
                slots.push({
                    "barId": config.id,
                    "screen": screen
                });
            }
        }
        return slots;
    }

    readonly property bool launcherOpen: root.activityOpen("launcher")
    readonly property bool controlCenterOpen: root.activityOpen("controlcenter")

    function hosts() {
        return islandVariants.instances || [];
    }

    function hostWithActivity(activityId) {
        for (const host of hosts()) {
            if (host?.islandController?.activeActivity === activityId && host.islandController.expanded)
                return host;
        }
        return null;
    }

    function activityOpen(activityId) {
        return root.hostWithActivity(activityId) !== null;
    }

    function hostForExactScreen(screen) {
        if (!screen)
            return null;
        for (const host of hosts()) {
            if (host?.screen === screen || host?.screen?.name === screen.name)
                return host;
        }
        return null;
    }


    function hostForScreenName(screenName) {
        for (const host of hosts()) {
            if (host?.screen?.name === screenName)
                return host;
        }
        return null;
    }

    function focusedHost() {
        const focusedName = CompositorService.getFocusedScreen()?.name ?? "";
        return focusedName ? root.hostForScreenName(focusedName) : null;
    }

    function focusedIslandScreen() {
        return root.focusedHost()?.screen ?? null;
    }

    function hasHostForScreen(screen) {
        if (!screen)
            return hosts().length > 0;
        return root.hostForExactScreen(screen) !== null;
    }

    function hostForScreenOrFocused(screen) {
        return root.hostForExactScreen(screen) ?? root.focusedHost();
    }

    function hostForScreen(screenName) {
        const requestedName = (screenName || "").trim();
        if (requestedName)
            return root.hostForScreenName(requestedName);
        return root.focusedHost() ?? (hosts()[0] ?? null);
    }

    function activityName(activity) {
        const requested = (activity || "home").trim().toLowerCase();
        switch (requested) {
        case "media":
        case "launcher":
        case "controlcenter":
        case "wallpaper":
        case "weather":
        case "notificationcenter":
            return requested;
        case "control-center":
        case "cc":
            return "controlcenter";
        case "notifications":
        case "notification-center":
        case "notification":
        case "nc":
            return "notificationcenter";
        }
        return "home";
    }

    function openActivityOn(host, activityId, section) {
        switch (activityId) {
        case "launcher":
            return host.islandController.requestLauncher("", "", false);
        case "controlcenter":
            return host.islandController.requestControlCenter(section || "", false);
        case "wallpaper":
            return host.islandController.requestWallpaper(false);
        case "weather":
            return host.islandController.requestWeather(false);
        case "notificationcenter":
            return host.islandController.requestNotificationCenter(false);
        }
        return host.islandController.requestActivity(activityId, true, true);
    }

    function openActivity(activityId, screen, section): bool {
        const host = root.hostForScreenOrFocused(screen);
        return host ? root.openActivityOn(host, activityId, section) === true : false;
    }

    function toggleActivity(activityId, screen, section): bool {
        const openHost = root.hostWithActivity(activityId);
        if (openHost) {
            openHost.islandController.requestCollapse();
            return true;
        }
        return root.openActivity(activityId, screen, section);
    }

    function closeActivity(activityId): bool {
        const host = root.hostWithActivity(activityId);
        if (!host)
            return false;
        host.islandController.requestCollapse();
        return true;
    }

    function openLauncher(query, mode): bool {
        const host = root.focusedHost();
        return host ? host.islandController.requestLauncher(query || "", mode || "", false) : false;
    }

    function toggleLauncher(query, mode): bool {
        if (root.closeActivity("launcher"))
            return true;
        return root.openLauncher(query, mode);
    }

    function closeLauncher(): bool {
        return root.closeActivity("launcher");
    }

    function ipcOpen(activity, screen) {
        const host = root.hostForScreen(screen);
        if (!host)
            return "DANK_ISLAND_UNAVAILABLE";
        const requested = root.activityName(activity);
        if (!root.openActivityOn(host, requested, ""))
            return `DANK_ISLAND_ACTIVITY_UNAVAILABLE: ${requested}`;
        return `DANK_ISLAND_OPEN: ${requested}\t${host.screen?.name ?? ""}`;
    }

    function ipcToggle(activity, screen) {
        const host = root.hostForScreen(screen);
        if (!host)
            return "DANK_ISLAND_UNAVAILABLE";
        if (host.islandController.expanded && !host.islandController.notificationActive) {
            host.islandController.requestCollapse();
            return `DANK_ISLAND_CLOSED: ${host.screen?.name ?? ""}`;
        }
        return ipcOpen(activity, screen);
    }

    function ipcShow(activity, screen) {
        const host = root.hostForScreen(screen);
        if (!host)
            return "DANK_ISLAND_UNAVAILABLE";
        const requested = root.activityName(activity);
        if (!host.islandController.requestActivity(requested, false, false))
            return `DANK_ISLAND_ACTIVITY_UNAVAILABLE: ${requested}`;
        return `DANK_ISLAND_SHOW: ${requested}\t${host.screen?.name ?? ""}`;
    }

    function ipcClose(screen) {
        const host = root.hostForScreen(screen);
        if (!host)
            return "DANK_ISLAND_UNAVAILABLE";
        host.islandController.requestCollapse();
        return `DANK_ISLAND_CLOSED: ${host.screen?.name ?? ""}`;
    }

    function ipcCycle(screen) {
        const host = root.hostForScreen(screen);
        if (!host)
            return "DANK_ISLAND_UNAVAILABLE";
        host.islandController.cycleActivity(1, host.islandController.expanded);
        return `DANK_ISLAND_ACTIVITY: ${host.islandController.activeActivity}\t${host.screen?.name ?? ""}`;
    }

    function ipcStatus(screen) {
        const host = root.hostForScreen(screen);
        if (!host)
            return JSON.stringify({
                "available": false,
                "enabled": true,
                "launcherAvailable": false
            });
        return JSON.stringify({
            "available": true,
            "enabled": true,
            "screen": host.screen?.name ?? "",
            "activity": host.islandController.activeActivity,
            "expanded": host.islandController.expanded,
            "mediaAvailable": host.islandController.mediaAvailable,
            "launcherAvailable": true,
            "controlCenterAvailable": true,
            "wallpaperAvailable": true,
            "weatherAvailable": true,
            "notificationCenterAvailable": true,
            "launcherInputFocused": host.islandController.launcherInputFocused,
            "launcherResultCount": host.launcherResultCount,
            "compactHeight": host.islandController.compactThickness
        });
    }

    Component.onCompleted: PopoutService.dankIslandRouter = root
    Component.onDestruction: {
        if (PopoutService.dankIslandRouter === root)
            PopoutService.dankIslandRouter = null;
    }

    Variants {
        id: islandVariants

        model: root.hostSlots

        delegate: DankIslandHostWindow {
            required property var modelData

            screen: modelData.screen
            barId: modelData.barId
        }
    }

    IpcHandler {
        target: "island"

        function open(activity: string): string {
            return root.ipcOpen(activity, "");
        }

        function toggle(activity: string): string {
            return root.ipcToggle(activity, "");
        }

        function show(activity: string): string {
            return root.ipcShow(activity, "");
        }

        function close(): string {
            return root.ipcClose("");
        }

        function cycle(): string {
            return root.ipcCycle("");
        }

        function status(): string {
            return root.ipcStatus("");
        }

        function openOn(activity: string, screen: string): string {
            return root.ipcOpen(activity, screen);
        }

        function toggleOn(activity: string, screen: string): string {
            return root.ipcToggle(activity, screen);
        }

        function showOn(activity: string, screen: string): string {
            return root.ipcShow(activity, screen);
        }

        function closeOn(screen: string): string {
            return root.ipcClose(screen);
        }

        function cycleOn(screen: string): string {
            return root.ipcCycle(screen);
        }

        function statusOn(screen: string): string {
            return root.ipcStatus(screen);
        }

        function notifications(): string {
            return root.ipcToggle("notificationcenter", "");
        }

        function notificationsOn(screen: string): string {
            return root.ipcToggle("notificationcenter", screen);
        }
    }
}
