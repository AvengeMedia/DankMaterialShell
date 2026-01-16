pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtCore

Singleton {
    id: root

    readonly property url home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
    readonly property url pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]

    readonly property url data: `${StandardPaths.standardLocations(StandardPaths.GenericDataLocation)[0]}/DankMaterialShell`
    readonly property url state: `${StandardPaths.standardLocations(StandardPaths.GenericStateLocation)[0]}/DankMaterialShell`
    readonly property url cache: `${StandardPaths.standardLocations(StandardPaths.GenericCacheLocation)[0]}/DankMaterialShell`
    readonly property url config: `${StandardPaths.standardLocations(StandardPaths.GenericConfigLocation)[0]}/DankMaterialShell`

    readonly property url imagecache: `${cache}/imagecache`

    function stringify(path: url): string {
        return path.toString().replace(/%20/g, " ");
    }

    function expandTilde(path: string): string {
        return strip(path.replace("~", stringify(root.home)));
    }

    function shortenHome(path: string): string {
        return path.replace(strip(root.home), "~");
    }

    function strip(path: url): string {
        return stringify(path).replace("file://", "");
    }

    function toFileUrl(path: string): string {
        return path.startsWith("file://") ? path : "file://" + path;
    }

    function mkdir(path: url): void {
        Quickshell.execDetached(["mkdir", "-p", strip(path)]);
    }

    function copy(from: url, to: url): void {
        Quickshell.execDetached(["cp", strip(from), strip(to)]);
    }

    function isSteamApp(appId: string): bool {
        return appId && /^steam_app_\d+$/.test(appId);
    }

    function moddedAppId(appId: string): string {
        const subs = SettingsData.appIdSubstitutions || [];
        for (let i = 0; i < subs.length; i++) {
            const sub = subs[i];
            if (sub.type === "exact" && appId === sub.pattern) {
                return sub.replacement;
            } else if (sub.type === "contains" && appId.includes(sub.pattern)) {
                return sub.replacement;
            } else if (sub.type === "regex") {
                const match = appId.match(new RegExp(sub.pattern));
                if (match) {
                    return sub.replacement.replace(/\$(\d+)/g, (_, n) => match[n] || "");
                }
            }
        }
        const steamMatch = appId.match(/^steam_app_(\d+)$/);
        if (steamMatch)
            return `steam_icon_${steamMatch[1]}`;
        return appId;
    }

    function getAppIcon(appId: string, desktopEntry: var): string {
        if (appId === "org.quickshell") {
            return Qt.resolvedUrl("../assets/danklogo.svg");
        }

        const moddedId = moddedAppId(appId);
        if (moddedId !== appId) {
            return Quickshell.iconPath(moddedId, true);
        }

        return desktopEntry && desktopEntry.icon ? Quickshell.iconPath(desktopEntry.icon, true) : "";
    }

    function getAppName(appId: string, desktopEntry: var): string {
        if (appId === "org.quickshell") {
            return "dms";
        }

        return desktopEntry && desktopEntry.name ? desktopEntry.name : appId;
    }
}
