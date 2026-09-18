pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Item {
    id: root

    property var hyprlandOverviewLoader: null

    readonly property var hostSlots: ShellLayout.islandKeys

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

    function hostForExactScreen(screen, barId) {
        return screen ? hostForScreenName(screen.name, barId) : null;
    }

    function hostForScreenName(screenName, barId) {
        const instances = ShellLayout.forScreen(screenName)?.instances ?? [];
        const ordered = instances.filter(instance => instance.kind === "island" && (!barId || instance.barId === barId)).sort((a, b) => Number(["left", "right"].includes(a.edge)) - Number(["left", "right"].includes(b.edge)) || a.configOrder - b.configOrder);
        for (const instance of ordered) {
            const host = hosts().find(host => host?.screen?.name === screenName && host.barId === instance.barId && host.islandController);
            if (host)
                return host;
        }
        return null;
    }

    function focusedHost() {
        const focused = hostForScreenName(CompositorService.getFocusedScreenName());
        if (focused)
            return focused;
        for (const screen of Quickshell.screens) {
            const host = hostForScreenName(screen.name);
            if (host)
                return host;
        }
        return null;
    }

    function focusedIslandScreen() {
        return focusedHost()?.screen ?? null;
    }

    function hasHostForScreen(screen, barId) {
        return screen ? hostForExactScreen(screen, barId) !== null : focusedHost() !== null;
    }

    function hostForScreenOrFocused(screen, barId) {
        if (barId && !screen)
            return null;
        return screen ? hostForExactScreen(screen, barId) : focusedHost();
    }

    function hostForScreen(screenName, barId) {
        const requested = (screenName || "").trim();
        return requested ? hostForScreenName(requested, barId) : barId ? null : focusedHost();
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
        case "media":
            if (!host.islandController.mediaAvailable)
                return host.islandController.requestActivity("home", true, true);
            return host.islandController.requestActivity("media", true, true);
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

    function openActivity(activityId, screen, section, barId): bool {
        const host = root.hostForScreenOrFocused(screen, barId);
        return host ? root.openActivityOn(host, activityId, section) === true : false;
    }

    function toggleActivity(activityId, screen, section, barId): bool {
        const host = root.hostForScreenOrFocused(screen, barId);
        if (!host)
            return false;
        const resolved = activityId === "media" && !host.islandController.mediaAvailable ? "home" : activityId;
        const openHost = barId ? (host.islandController.activeActivity === resolved && host.islandController.expanded ? host : null) : root.hostWithActivity(resolved);
        if (openHost) {
            openHost.islandController.requestCollapse();
            return true;
        }
        return root.openActivity(activityId, screen, section, barId);
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

    function ipcOpen(activity, screen, barId) {
        const host = root.hostForScreen(screen, barId);
        if (!host)
            return "DANK_ISLAND_UNAVAILABLE";
        const requested = root.activityName(activity);
        if (!root.openActivityOn(host, requested, ""))
            return `DANK_ISLAND_ACTIVITY_UNAVAILABLE: ${requested}`;
        return `DANK_ISLAND_OPEN: ${requested}\t${host.screen?.name ?? ""}`;
    }

    function ipcToggle(activity, screen, barId) {
        const host = root.hostForScreen(screen, barId);
        if (!host)
            return "DANK_ISLAND_UNAVAILABLE";
        if (host.islandController.expanded && !host.islandController.notificationActive) {
            host.islandController.requestCollapse();
            return `DANK_ISLAND_CLOSED: ${host.screen?.name ?? ""}`;
        }
        return ipcOpen(activity, screen, barId);
    }

    function ipcShow(activity, screen, barId) {
        const host = root.hostForScreen(screen, barId);
        if (!host)
            return "DANK_ISLAND_UNAVAILABLE";
        const requested = root.activityName(activity);
        if (!host.islandController.requestActivity(requested, false, false))
            return `DANK_ISLAND_ACTIVITY_UNAVAILABLE: ${requested}`;
        return `DANK_ISLAND_SHOW: ${requested}\t${host.screen?.name ?? ""}`;
    }

    function ipcClose(screen, barId) {
        const host = root.hostForScreen(screen, barId);
        if (!host)
            return "DANK_ISLAND_UNAVAILABLE";
        host.islandController.requestCollapse();
        return `DANK_ISLAND_CLOSED: ${host.screen?.name ?? ""}`;
    }

    function ipcCycle(screen, barId) {
        const host = root.hostForScreen(screen, barId);
        if (!host)
            return "DANK_ISLAND_UNAVAILABLE";
        host.islandController.cycleActivity(1, host.islandController.expanded);
        return `DANK_ISLAND_ACTIVITY: ${host.islandController.activeActivity}\t${host.screen?.name ?? ""}`;
    }

    function ipcStatus(screen, barId) {
        const host = root.hostForScreen(screen, barId);
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

            readonly property var identity: JSON.parse(modelData)
            screen: ShellLayout.screenForName(identity[0])
            barId: identity[1]
            hyprlandOverviewLoader: root.hyprlandOverviewLoader
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

        function openInstance(activity: string, screen: string, barId: string): string {
            return root.ipcOpen(activity, screen, barId);
        }

        function toggleInstance(activity: string, screen: string, barId: string): string {
            return root.ipcToggle(activity, screen, barId);
        }

        function notifications(): string {
            return root.ipcToggle("notificationcenter", "");
        }

        function notificationsOn(screen: string): string {
            return root.ipcToggle("notificationcenter", screen);
        }
    }
}
