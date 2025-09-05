pragma Singleton

import Quickshell
import QtCore

Singleton {
    id: root

    readonly property url home: StandardPaths.standardLocations(
                                    StandardPaths.HomeLocation)[0]
    readonly property url pictures: StandardPaths.standardLocations(
                                        StandardPaths.PicturesLocation)[0]

    readonly property url data: `${StandardPaths.standardLocations(
                                    StandardPaths.GenericDataLocation)[0]}/DankMaterialShell`
    readonly property url state: `${StandardPaths.standardLocations(
                                     StandardPaths.GenericStateLocation)[0]}/DankMaterialShell`
    readonly property url cache: `${StandardPaths.standardLocations(
                                     StandardPaths.GenericCacheLocation)[0]}/DankMaterialShell`
    readonly property url config: `${StandardPaths.standardLocations(
                                      StandardPaths.GenericConfigLocation)[0]}/DankMaterialShell`

    readonly property url imagecache: `${cache}/imagecache`

    function stringify(path: url): string {
        return path.toString().replace(/%20/g, " ")
    }

    function expandTilde(path: string): string {
        return strip(path.replace("~", stringify(root.home)))
    }

    function shortenHome(path: string): string {
        return path.replace(strip(root.home), "~")
    }

    function strip(path: url): string {
        return stringify(path).replace("file://", "")
    }

    function mkdir(path: url): void {
        Quickshell.execDetached(["mkdir", "-p", strip(path)])
    }

    function copy(from: url, to: url): void {
        Quickshell.execDetached(["cp", strip(from), strip(to)])
    }

    // ! Spotify and maybe some other apps report the wrong app id in toplevels, hardcode special case
    function moddedAppId(appId: string): string {
        if (appId === "Spotify")
            return "spotify-launcher"
        if (appId === "beepertexts")
            return "beeper"
        if (appId === "home assistant desktop")
            return "homeassistant-desktop"
        return appId
    }
}
