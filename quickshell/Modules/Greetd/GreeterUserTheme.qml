pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property var log: Log.scoped("GreeterUserTheme")
    readonly property string greetCfgDir: Quickshell.env("DMS_GREET_CFG_DIR") || "/var/cache/dms-greeter"

    property string activeUsername: ""

    function userCacheDir(username) {
        if (!username)
            return "";
        return greetCfgDir + "/users/" + username;
    }

    function applyForUser(username) {
        const name = (username || "").trim();
        activeUsername = name;
        if (!name) {
            applyDefault();
            return;
        }
        const dir = userCacheDir(name);
        if (typeof GreeterUsersService !== "undefined" && GreeterUsersService.hasSyncedTheme(name)) {
            Theme.setGreeterColorsBaseDir(dir);
            SessionData.setGreeterSessionBaseDir(dir);
            GreetdSettings.setConfigBaseDir(dir);
            return;
        }
        applyDefault();
    }

    function applyDefault() {
        activeUsername = "";
        Theme.resetGreeterColorsBaseDir();
        SessionData.resetGreeterSessionBaseDir();
        GreetdSettings.resetConfigBaseDir();
    }

    readonly property string activeWallpaperOverridePath: {
        const base = activeUsername && typeof GreeterUsersService !== "undefined" && GreeterUsersService.hasSyncedTheme(activeUsername) ? userCacheDir(activeUsername) : greetCfgDir;
        return base ? base + "/greeter_wallpaper_override.jpg" : "";
    }
}
