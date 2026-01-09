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

    function moddedAppId(appId: string): string {
        if (appId === "Spotify")
            return "spotify";
        if (appId === "beepertexts")
            return "beeper";
        if (appId === "home assistant desktop")
            return "homeassistant-desktop";
        if (appId.includes("com.transmissionbt.transmission")) {
            if (DesktopEntries.heuristicLookup("transmission-gtk"))
                return "transmission-gtk";
            if (DesktopEntries.heuristicLookup("transmission"))
                return "transmission";
            return "transmission-gtk";
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
        if (moddedId.startsWith("steam_icon_")) {
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
