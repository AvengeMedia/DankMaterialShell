import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    readonly property var brightnessNames: ["brightnessAvailable", "brightnessIconName", "brightnessLevel", "brightnessMaximum", "brightnessMinimum", "brightnessUnit", "brightnessVersion", "currentDevice", "devices", "getCurrentDeviceInfo", "getCurrentDeviceInfoByName", "getDefaultDevice", "getDeviceBrightness", "lastIpcDevice", "setBrightness", "setCurrentDevice"]
    readonly property var nightModeNames: ["automationAvailable", "gammaAdjustAvailable", "gammaControlAvailable", "gammaCurrentTemp", "gammaIsDay", "gammaNextTransition", "gammaSunriseTime", "gammaSunsetTime", "nightModeEnabled", "setDisplayContrast", "setDisplayGamma", "toggleNightMode"]

    function check(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function same(a, b) {
        if (typeof a === "function")
            return typeof b === "function";
        if (a !== null && typeof a === "object")
            return JSON.stringify(a) === JSON.stringify(b);
        return a === b;
    }

    function checkOwner(owner, ownerName, names) {
        for (const name of names) {
            root.check(owner[name] !== undefined, ownerName + " lacks " + name);
            root.check(DisplayService[name] !== undefined, "DisplayService lacks " + name);
            root.check(root.same(DisplayService[name], owner[name]), "DisplayService." + name + " differs from " + ownerName);
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        BrightnessService.brightnessAvailable;
        NightModeService.gammaControlAvailable;
        RefreshRateService.batteryRefreshRateTarget;
    }

    Timer {
        interval: 2500
        running: true
        onTriggered: {
            try {
                root.check(!DMSService.isConnected, "fixture runner is offline");
                root.check(RefreshRateService.batteryRefreshRateTarget > 0, "refresh rate service resolves");
                root.check(!BrightnessService.brightnessAvailable, "no brightness devices offline");
                root.check(!NightModeService.gammaControlAvailable, "no gamma control offline");
                root.check(!NightModeService.automationAvailable, "no automation offline");
                root.check(BrightnessService.brightnessLevel > 0, "brightnessLevel falls back to a usable level");
                root.check(!BrightnessService.suppressOsd, "osd suppression lifted after startup");
                root.checkOwner(BrightnessService, "BrightnessService", root.brightnessNames);
                root.checkOwner(NightModeService, "NightModeService", root.nightModeNames);
                console.log("FIXTURE_PASS");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
