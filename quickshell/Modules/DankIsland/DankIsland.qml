pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Item {
    id: root

    property var screenModel: Quickshell.screens
    property var colorPickerModal: null
    property var powerMenuModalLoader: null

    signal lockRequested

    readonly property bool launcherOpen: root.activityOpen("launcher")
    readonly property bool controlCenterOpen: root.activityOpen("controlcenter")
    readonly property bool wallpaperOpen: root.activityOpen("wallpaper")
    readonly property bool weatherOpen: root.activityOpen("weather")
    readonly property bool mediaOpen: root.activityOpen("media")
    readonly property bool homeOpen: root.activityOpen("home")
    readonly property bool notificationCenterOpen: root.activityOpen("notificationcenter")

    function activityOpen(activityId) {
        const hosts = islandVariants.instances || [];
        for (let i = 0; i < hosts.length; i++) {
            if (hosts[i]?.islandController?.activeActivity === activityId && hosts[i].islandController.expanded)
                return true;
        }
        return false;
    }

    function hostWithActivity(activityId) {
        const hosts = islandVariants.instances || [];
        for (let i = 0; i < hosts.length; i++) {
            if (hosts[i]?.islandController?.activeActivity === activityId && hosts[i].islandController.expanded)
                return hosts[i];
        }
        return null;
    }

    function hasHostForScreen(screen) {
        if (!screen)
            return (islandVariants.instances || []).length > 0;
        const hosts = islandVariants.instances || [];
        for (let i = 0; i < hosts.length; i++) {
            if (hosts[i]?.screen === screen || hosts[i]?.screen?.name === screen.name)
                return true;
        }
        return false;
    }

    function hostForScreen(screenName) {
        const requestedName = (screenName || "").trim();
        const hosts = islandVariants.instances || [];
        // An explicitly named screen with no island is an error, not a redirect to another display.
        if (requestedName) {
            for (let i = 0; i < hosts.length; i++) {
                if (hosts[i]?.screen?.name === requestedName)
                    return hosts[i];
            }
            return null;
        }
        const focusedName = CompositorService.getFocusedScreen()?.name ?? "";
        if (focusedName) {
            for (let i = 0; i < hosts.length; i++) {
                if (hosts[i]?.screen?.name === focusedName)
                    return hosts[i];
            }
        }
        return hosts.length > 0 ? hosts[0] : null;
    }

    function activityName(activity) {
        const requested = (activity || "home").trim().toLowerCase();
        if (requested === "media" || requested === "launcher" || requested === "controlcenter" || requested === "wallpaper" || requested === "weather" || requested === "notificationcenter")
            return requested;
        if (requested === "control-center" || requested === "cc")
            return "controlcenter";
        if (requested === "notifications" || requested === "notification-center" || requested === "notification" || requested === "nc")
            return "notificationcenter";
        return "home";
    }

    function openActivityOn(host, activityId) {
        switch (activityId) {
        case "launcher":
            return host.islandController.requestLauncher("", "", false);
        case "controlcenter":
            return host.islandController.requestControlCenter("", false);
        case "wallpaper":
            return host.islandController.requestWallpaper(false);
        case "weather":
            return host.islandController.requestWeather(false);
        case "notificationcenter":
            return host.islandController.requestNotificationCenter(false);
        }
        return host.islandController.requestActivity(activityId, true, true);
    }

    function focusedHost() {
        const focusedName = CompositorService.getFocusedScreen()?.name ?? "";
        if (!focusedName)
            return null;
        const hosts = islandVariants.instances || [];
        for (let i = 0; i < hosts.length; i++) {
            if (hosts[i]?.screen?.name === focusedName)
                return hosts[i];
        }
        return null;
    }

    function focusedIslandScreen() {
        return root.focusedHost()?.screen ?? null;
    }

    function activeLauncherHost() {
        return root.hostWithActivity("launcher");
    }

    function openLauncher(query, mode): bool {
        const host = root.focusedHost();
        return host ? host.islandController.requestLauncher(query || "", mode || "", false) : false;
    }

    function toggleLauncher(query, mode): bool {
        const openHost = root.activeLauncherHost();
        if (openHost) {
            openHost.islandController.requestCollapse();
            return true;
        }
        const host = root.focusedHost();
        return host ? host.islandController.requestLauncher(query || "", mode || "", false) : false;
    }

    function closeLauncher(): bool {
        const host = root.activeLauncherHost();
        if (!host)
            return false;
        host.islandController.requestCollapse();
        return true;
    }

    function controlCenterHostForScreen(screen) {
        if (screen) {
            const hosts = islandVariants.instances || [];
            for (let i = 0; i < hosts.length; i++) {
                if (hosts[i]?.screen === screen || hosts[i]?.screen?.name === screen.name)
                    return hosts[i];
            }
        }
        return root.focusedHost();
    }

    function openControlCenter(section, screen): bool {
        const host = root.controlCenterHostForScreen(screen);
        return host ? host.islandController.requestControlCenter(section || "", false) : false;
    }

    function toggleControlCenter(section, screen): bool {
        const openHost = root.hostWithActivity("controlcenter");
        if (openHost) {
            openHost.islandController.requestCollapse();
            return true;
        }
        return root.openControlCenter(section, screen);
    }

    function closeControlCenter(): bool {
        const host = root.hostWithActivity("controlcenter");
        if (!host)
            return false;
        host.islandController.requestCollapse();
        return true;
    }

    function wallpaperHostForScreen(screen) {
        if (screen) {
            const hosts = islandVariants.instances || [];
            for (let i = 0; i < hosts.length; i++) {
                if (hosts[i]?.screen === screen || hosts[i]?.screen?.name === screen.name)
                    return hosts[i];
            }
        }
        return root.focusedHost();
    }

    function openWallpaper(screen): bool {
        const host = root.wallpaperHostForScreen(screen);
        return host ? host.islandController.requestWallpaper(false) : false;
    }

    function toggleWallpaper(screen): bool {
        const openHost = root.hostWithActivity("wallpaper");
        if (openHost) {
            openHost.islandController.requestCollapse();
            return true;
        }
        return root.openWallpaper(screen);
    }

    function closeWallpaper(): bool {
        const host = root.hostWithActivity("wallpaper");
        if (!host)
            return false;
        host.islandController.requestCollapse();
        return true;
    }

    function weatherHostForScreen(screen) {
        if (screen) {
            const hosts = islandVariants.instances || [];
            for (let i = 0; i < hosts.length; i++) {
                if (hosts[i]?.screen === screen || hosts[i]?.screen?.name === screen.name)
                    return hosts[i];
            }
        }
        return root.focusedHost();
    }

    function openWeather(screen): bool {
        const host = root.weatherHostForScreen(screen);
        return host ? host.islandController.requestWeather(false) : false;
    }

    function toggleWeather(screen): bool {
        const openHost = root.hostWithActivity("weather");
        if (openHost) {
            openHost.islandController.requestCollapse();
            return true;
        }
        return root.openWeather(screen);
    }

    function closeWeather(): bool {
        const host = root.hostWithActivity("weather");
        if (!host)
            return false;
        host.islandController.requestCollapse();
        return true;
    }

    function notificationHostForScreen(screen) {
        if (screen) {
            const hosts = islandVariants.instances || [];
            for (let i = 0; i < hosts.length; i++) {
                if (hosts[i]?.screen === screen || hosts[i]?.screen?.name === screen.name)
                    return hosts[i];
            }
        }
        return root.focusedHost();
    }

    function openNotifications(screen): bool {
        const host = root.notificationHostForScreen(screen);
        return host ? host.islandController.requestNotificationCenter(false) : false;
    }

    function toggleNotifications(screen): bool {
        const openHost = root.hostWithActivity("notificationcenter");
        if (openHost) {
            openHost.islandController.requestCollapse();
            return true;
        }
        return root.openNotifications(screen);
    }

    function closeNotifications(): bool {
        const host = root.hostWithActivity("notificationcenter");
        if (!host)
            return false;
        host.islandController.requestCollapse();
        return true;
    }

    function mediaHostForScreen(screen) {
        if (screen) {
            const hosts = islandVariants.instances || [];
            for (let i = 0; i < hosts.length; i++) {
                if (hosts[i]?.screen === screen || hosts[i]?.screen?.name === screen.name)
                    return hosts[i];
            }
        }
        return root.focusedHost();
    }

    function openMedia(screen): bool {
        const host = root.mediaHostForScreen(screen);
        return host ? host.islandController.requestActivity("media", true, true) : false;
    }

    function toggleMedia(screen): bool {
        const openHost = root.hostWithActivity("media");
        if (openHost) {
            openHost.islandController.requestCollapse();
            return true;
        }
        return root.openMedia(screen);
    }

    function closeMedia(): bool {
        const host = root.hostWithActivity("media");
        if (!host)
            return false;
        host.islandController.requestCollapse();
        return true;
    }

    function homeHostForScreen(screen) {
        if (screen) {
            const hosts = islandVariants.instances || [];
            for (let i = 0; i < hosts.length; i++) {
                if (hosts[i]?.screen === screen || hosts[i]?.screen?.name === screen.name)
                    return hosts[i];
            }
        }
        return root.focusedHost();
    }

    function openHome(screen): bool {
        const host = root.homeHostForScreen(screen);
        return host ? host.islandController.requestActivity("home", true, true) : false;
    }

    function toggleHome(screen): bool {
        const openHost = root.hostWithActivity("home");
        if (openHost) {
            openHost.islandController.requestCollapse();
            return true;
        }
        return root.openHome(screen);
    }

    function closeHome(): bool {
        const host = root.hostWithActivity("home");
        if (!host)
            return false;
        host.islandController.requestCollapse();
        return true;
    }

    Component.onCompleted: PopoutService.dankIslandRouter = root
    Component.onDestruction: {
        if (PopoutService.dankIslandRouter === root)
            PopoutService.dankIslandRouter = null;
    }

    Variants {
        id: islandVariants

        model: root.screenModel

        delegate: DankIslandHostWindow {
            required property var modelData

            screen: modelData
            colorPickerModal: root.colorPickerModal
            powerMenuModalLoader: root.powerMenuModalLoader
            onLockRequested: root.lockRequested()
        }
    }

    IpcHandler {
        target: "island"

        function _runOpen(activity, screen) {
            const host = root.hostForScreen(screen);
            if (!host)
                return "DANK_ISLAND_UNAVAILABLE";
            const requested = root.activityName(activity);
            const accepted = root.openActivityOn(host, requested);
            if (!accepted)
                return `DANK_ISLAND_ACTIVITY_UNAVAILABLE: ${requested}`;
            return `DANK_ISLAND_OPEN: ${requested}\t${host.screen?.name ?? ""}`;
        }

        function _runToggle(activity, screen) {
            const host = root.hostForScreen(screen);
            if (!host)
                return "DANK_ISLAND_UNAVAILABLE";
            if (host.islandController.expanded && !host.islandController.notificationActive) {
                host.islandController.requestCollapse();
                return `DANK_ISLAND_CLOSED: ${host.screen?.name ?? ""}`;
            }
            return _runOpen(activity, screen);
        }

        function _runShow(activity, screen) {
            const host = root.hostForScreen(screen);
            if (!host)
                return "DANK_ISLAND_UNAVAILABLE";
            const requested = root.activityName(activity);
            if (!host.islandController.requestActivity(requested, false, false))
                return `DANK_ISLAND_ACTIVITY_UNAVAILABLE: ${requested}`;
            return `DANK_ISLAND_SHOW: ${requested}\t${host.screen?.name ?? ""}`;
        }

        function _runClose(screen) {
            const host = root.hostForScreen(screen);
            if (!host)
                return "DANK_ISLAND_UNAVAILABLE";
            host.islandController.requestCollapse();
            return `DANK_ISLAND_CLOSED: ${host.screen?.name ?? ""}`;
        }

        function _runCycle(screen) {
            const host = root.hostForScreen(screen);
            if (!host)
                return "DANK_ISLAND_UNAVAILABLE";
            host.islandController.cycleActivity(1, host.islandController.expanded);
            return `DANK_ISLAND_ACTIVITY: ${host.islandController.activeActivity}\t${host.screen?.name ?? ""}`;
        }

        function _runStatus(screen) {
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
                "compactHeight": host.islandController.compactHeight
            });
        }

        function open(activity: string): string {
            return _runOpen(activity, "");
        }

        function toggle(activity: string): string {
            return _runToggle(activity, "");
        }

        function show(activity: string): string {
            return _runShow(activity, "");
        }

        function close(): string {
            return _runClose("");
        }

        function cycle(): string {
            return _runCycle("");
        }

        function status(): string {
            return _runStatus("");
        }

        function openOn(activity: string, screen: string): string {
            return _runOpen(activity, screen);
        }

        function toggleOn(activity: string, screen: string): string {
            return _runToggle(activity, screen);
        }

        function showOn(activity: string, screen: string): string {
            return _runShow(activity, screen);
        }

        function closeOn(screen: string): string {
            return _runClose(screen);
        }

        function cycleOn(screen: string): string {
            return _runCycle(screen);
        }

        function statusOn(screen: string): string {
            return _runStatus(screen);
        }

        function notifications(): string {
            return _runToggle("notificationcenter", "");
        }

        function notificationsOn(screen: string): string {
            return _runToggle("notificationcenter", screen);
        }
    }
}
