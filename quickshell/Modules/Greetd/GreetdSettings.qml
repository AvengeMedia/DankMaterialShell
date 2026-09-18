pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import "GreetdEnv.js" as GreetdEnv

Singleton {
    id: root

    readonly property var _envRememberLastSession: GreetdEnv.readBoolOverride(Quickshell.env, ["DMS_GREET_REMEMBER_LAST_SESSION", "DMS_SAVE_SESSION"], undefined)
    readonly property var _envRememberLastUser: GreetdEnv.readBoolOverride(Quickshell.env, ["DMS_GREET_REMEMBER_LAST_USER", "DMS_SAVE_USERNAME"], undefined)

    readonly property bool settingsLoaded: SettingsData._hasLoaded
    readonly property bool rememberLastSession: _envRememberLastSession !== undefined ? _envRememberLastSession : SettingsData.greeterRememberLastSession
    readonly property bool rememberLastUser: _envRememberLastUser !== undefined ? _envRememberLastUser : SettingsData.greeterRememberLastUser

    function setConfigBaseDir(dir) {
        SettingsData.setGreeterSettingsBaseDir(dir);
    }

    function resetConfigBaseDir() {
        SettingsData.resetGreeterSettingsBaseDir();
    }
}
