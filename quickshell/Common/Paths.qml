pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtCore
import qs.Services

Singleton {
    id: root

    readonly property url home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
    readonly property url pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
    readonly property url xdgCache: StandardPaths.standardLocations(StandardPaths.GenericCacheLocation)[0]

    readonly property url data: `${StandardPaths.standardLocations(StandardPaths.GenericDataLocation)[0]}/DankMaterialShell`
    readonly property url state: `${StandardPaths.standardLocations(StandardPaths.GenericStateLocation)[0]}/DankMaterialShell`
    readonly property url cache: `${StandardPaths.standardLocations(StandardPaths.GenericCacheLocation)[0]}/DankMaterialShell`
    readonly property url config: `${StandardPaths.standardLocations(StandardPaths.GenericConfigLocation)[0]}/DankMaterialShell`

    readonly property url imagecache: `${cache}/imagecache`

    function stringify(path: url): string {
        return path.toString().replace(/%20/g, " ");
    }

    function expandTilde(path: string): string {
        if (!path.startsWith("~"))
            return path;
        return strip(root.home) + path.substring(1);
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

    function themedIconPath(name: string): string {
        if (!name)
            return "";
        const themed = (typeof IconThemeService !== "undefined") ? IconThemeService.resolve(name) : "";
        if (themed)
            return themed;
        return Quickshell.iconPath(name, true);
    }

    function resolveIconPath(iconName: string): string {
        if (!iconName)
            return "";
        const moddedId = moddedAppId(iconName);
        if (moddedId !== iconName) {
            if (moddedId.startsWith("~") || moddedId.startsWith("/"))
                return toFileUrl(expandTilde(moddedId));
            if (moddedId.startsWith("file://"))
                return moddedId;
            return themedIconPath(moddedId);
        }
        return themedIconPath(iconName) || DesktopService.resolveIconPath(iconName);
    }

    function resolveIconUrl(iconName: string): string {
        if (!iconName)
            return "";
        const moddedId = moddedAppId(iconName);
        const target = (moddedId !== iconName) ? moddedId : iconName;
        if (target.startsWith("~") || target.startsWith("/"))
            return toFileUrl(expandTilde(target));
        if (target.startsWith("file://"))
            return target;
        const themed = (typeof IconThemeService !== "undefined") ? IconThemeService.resolve(target) : "";
        if (themed)
            return themed;
        return "image://icon/" + target;
    }

    function getAppIcon(appId: string, desktopEntry: var): string {
        if (appId === "org.quickshell") {
            return Qt.resolvedUrl("../assets/danklogo.svg");
        }

        const moddedId = moddedAppId(appId);
        if (moddedId !== appId)
            return resolveIconPath(appId);

        if (desktopEntry && desktopEntry.icon) {
            return themedIconPath(desktopEntry.icon);
        }

        const icon = themedIconPath(appId);
        if (icon && icon !== "")
            return icon;

        return DesktopService.resolveIconPath(appId);
    }

    function getAppName(appId: string, desktopEntry: var): string {
        if (appId === "org.quickshell" || appId === "com.danklinux.dms") {
            return "dms";
        }

        return desktopEntry && desktopEntry.name ? desktopEntry.name : appId;
    }
}
