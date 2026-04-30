pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "GreetdEnv.js" as GreetdEnv

Singleton {
    id: root
    readonly property var log: Log.scoped("GreetdSettings")

    readonly property string configPath: {
        const greetCfgDir = Quickshell.env("DMS_GREET_CFG_DIR") || "/var/cache/dms-greeter";
        return greetCfgDir + "/settings.json";
    }

    readonly property string _greeterCacheDir: {
        const i = root.configPath.lastIndexOf("/");
        return i >= 0 ? root.configPath.substring(0, i) : "";
    }
    readonly property string greeterWallpaperOverridePath: root._greeterCacheDir ? (root._greeterCacheDir + "/greeter_wallpaper_override.jpg") : ""

    property string currentThemeName: "purple"
    property bool settingsLoaded: false
    property string customThemeFile: ""
    property var registryThemeVariants: ({})
    property string matugenScheme: "scheme-tonal-spot"
    property bool use24HourClock: true
    property bool showSeconds: false
    property bool padHours12Hour: false
    property bool greeterUse24HourClock: true
    property bool greeterShowSeconds: false
    property bool greeterPadHours12Hour: false
    property string greeterLockDateFormat: ""
    property string greeterFontFamily: ""
    property string greeterWallpaperFillMode: ""
    property bool useFahrenheit: false
    property bool nightModeEnabled: false
    property string weatherLocation: "New York, NY"
    property string weatherCoordinates: "40.7128,-74.0060"
    property bool useAutoLocation: false
    property bool weatherEnabled: true
    property string iconTheme: "System Default"
    property bool useOSLogo: false
    property string osLogoColorOverride: ""
    property real osLogoBrightness: 0.5
    property real osLogoContrast: 1
    property string fontFamily: "Inter Variable"
    property string monoFontFamily: "Fira Code"
    property int fontWeight: Font.Normal
    property real fontScale: 1.0
    property real cornerRadius: 12
    property string widgetBackgroundColor: "sch"
    property string lockDateFormat: ""
    property bool lockScreenShowPowerActions: true
    property bool lockScreenShowProfileImage: true
    property bool rememberLastSession: true
    property bool rememberLastUser: true
    property bool greeterEnableFprint: false
    property bool greeterEnableU2f: false
    property string greeterWallpaperPath: ""
    property bool powerActionConfirm: true
    property real powerActionHoldDuration: 0.5
    property var powerMenuActions: ["reboot", "logout", "poweroff", "lock", "suspend", "restart"]
    property string powerMenuDefaultAction: "logout"
    property bool powerMenuGridLayout: false
    property var screenPreferences: ({})
    property int animationSpeed: 2
    property string wallpaperFillMode: "Fill"

    function parseSettings(content) {
        try {
            let settings = {};
            if (content && content.trim()) {
                settings = JSON.parse(content);
            }

            const envRememberLastSession = GreetdEnv.readBoolOverride(Quickshell.env, ["DMS_GREET_REMEMBER_LAST_SESSION", "DMS_SAVE_SESSION"], undefined);
            const envRememberLastUser = GreetdEnv.readBoolOverride(Quickshell.env, ["DMS_GREET_REMEMBER_LAST_USER", "DMS_SAVE_USERNAME"], undefined);

            currentThemeName = settings.currentThemeName !== undefined ? settings.currentThemeName : "purple";
            customThemeFile = settings.customThemeFile !== undefined ? settings.customThemeFile : "";
            registryThemeVariants = settings.registryThemeVariants !== undefined ? settings.registryThemeVariants : ({});
            matugenScheme = settings.matugenScheme !== undefined ? settings.matugenScheme : "scheme-tonal-spot";
            use24HourClock = settings.use24HourClock !== undefined ? settings.use24HourClock : true;
            showSeconds = settings.showSeconds !== undefined ? settings.showSeconds : false;
            padHours12Hour = settings.padHours12Hour !== undefined ? settings.padHours12Hour : false;
            greeterUse24HourClock = settings.greeterUse24HourClock !== undefined ? settings.greeterUse24HourClock : use24HourClock;
            greeterShowSeconds = settings.greeterShowSeconds !== undefined ? settings.greeterShowSeconds : showSeconds;
            greeterPadHours12Hour = settings.greeterPadHours12Hour !== undefined ? settings.greeterPadHours12Hour : padHours12Hour;
            greeterLockDateFormat = settings.greeterLockDateFormat !== undefined ? settings.greeterLockDateFormat : "";
            greeterFontFamily = settings.greeterFontFamily !== undefined ? settings.greeterFontFamily : "";
            greeterWallpaperFillMode = settings.greeterWallpaperFillMode !== undefined ? settings.greeterWallpaperFillMode : "";
            useFahrenheit = settings.useFahrenheit !== undefined ? settings.useFahrenheit : false;
            nightModeEnabled = settings.nightModeEnabled !== undefined ? settings.nightModeEnabled : false;
            weatherLocation = settings.weatherLocation !== undefined ? settings.weatherLocation : "New York, NY";
            weatherCoordinates = settings.weatherCoordinates !== undefined ? settings.weatherCoordinates : "40.7128,-74.0060";
            useAutoLocation = settings.useAutoLocation !== undefined ? settings.useAutoLocation : false;
            weatherEnabled = settings.weatherEnabled !== undefined ? settings.weatherEnabled : true;
            iconTheme = settings.iconTheme !== undefined ? settings.iconTheme : "System Default";
            useOSLogo = settings.useOSLogo !== undefined ? settings.useOSLogo : false;
            osLogoColorOverride = settings.osLogoColorOverride !== undefined ? settings.osLogoColorOverride : "";
            osLogoBrightness = settings.osLogoBrightness !== undefined ? settings.osLogoBrightness : 0.5;
            osLogoContrast = settings.osLogoContrast !== undefined ? settings.osLogoContrast : 1;
            fontFamily = settings.fontFamily !== undefined ? settings.fontFamily : Theme.defaultFontFamily;
            monoFontFamily = settings.monoFontFamily !== undefined ? settings.monoFontFamily : Theme.defaultMonoFontFamily;
            fontWeight = settings.fontWeight !== undefined ? settings.fontWeight : Font.Normal;
            fontScale = settings.fontScale !== undefined ? settings.fontScale : 1.0;
            cornerRadius = settings.cornerRadius !== undefined ? settings.cornerRadius : 12;
            widgetBackgroundColor = settings.widgetBackgroundColor !== undefined ? settings.widgetBackgroundColor : "sch";
            lockDateFormat = settings.lockDateFormat !== undefined ? settings.lockDateFormat : "";
            lockScreenShowPowerActions = settings.lockScreenShowPowerActions !== undefined ? settings.lockScreenShowPowerActions : true;
            lockScreenShowProfileImage = settings.lockScreenShowProfileImage !== undefined ? settings.lockScreenShowProfileImage : true;
            if (envRememberLastSession !== undefined) {
                rememberLastSession = envRememberLastSession;
            } else {
                rememberLastSession = settings.greeterRememberLastSession !== undefined ? settings.greeterRememberLastSession : settings.rememberLastSession !== undefined ? settings.rememberLastSession : true;
            }
            if (envRememberLastUser !== undefined) {
                rememberLastUser = envRememberLastUser;
            } else {
                rememberLastUser = settings.greeterRememberLastUser !== undefined ? settings.greeterRememberLastUser : settings.rememberLastUser !== undefined ? settings.rememberLastUser : true;
            }
            greeterEnableFprint = settings.greeterEnableFprint !== undefined ? settings.greeterEnableFprint : false;
            greeterEnableU2f = settings.greeterEnableU2f !== undefined ? settings.greeterEnableU2f : false;
            greeterWallpaperPath = settings.greeterWallpaperPath !== undefined ? settings.greeterWallpaperPath : "";
            powerActionConfirm = settings.powerActionConfirm !== undefined ? settings.powerActionConfirm : true;
            powerActionHoldDuration = settings.powerActionHoldDuration !== undefined ? settings.powerActionHoldDuration : 0.5;
            powerMenuActions = settings.powerMenuActions !== undefined ? settings.powerMenuActions : ["reboot", "logout", "poweroff", "lock", "suspend", "restart"];
            powerMenuDefaultAction = settings.powerMenuDefaultAction !== undefined ? settings.powerMenuDefaultAction : "logout";
            powerMenuGridLayout = settings.powerMenuGridLayout !== undefined ? settings.powerMenuGridLayout : false;
            screenPreferences = settings.screenPreferences !== undefined ? settings.screenPreferences : ({});
            animationSpeed = settings.animationSpeed !== undefined ? settings.animationSpeed : 2;
            wallpaperFillMode = settings.wallpaperFillMode !== undefined ? settings.wallpaperFillMode : "Fill";

            if (typeof Theme !== "undefined") {
                if (currentThemeName === "custom" && customThemeFile) {
                    Theme.loadCustomThemeFromFile(customThemeFile);
                }
                Theme.applyGreeterTheme(currentThemeName);
            }
        } catch (e) {
            log.warn("Failed to parse greetd settings:", e);
        } finally {
            settingsLoaded = true;
        }
    }

    function getEffectiveTimeFormat() {
        const use24 = greeterUse24HourClock;
        const secs = greeterShowSeconds;
        const pad = greeterPadHours12Hour;
        if (use24)
            return secs ? "hh:mm:ss" : "hh:mm";
        if (pad)
            return secs ? "hh:mm:ss AP" : "hh:mm AP";
        return secs ? "h:mm:ss AP" : "h:mm AP";
    }

    function getEffectiveLockDateFormat() {
        const fmt = (greeterLockDateFormat !== undefined && greeterLockDateFormat !== "") ? greeterLockDateFormat : lockDateFormat;
        return fmt && fmt.length > 0 ? fmt : Locale.LongFormat;
    }

    function getEffectiveWallpaperFillMode() {
        return (greeterWallpaperFillMode && greeterWallpaperFillMode !== "") ? greeterWallpaperFillMode : wallpaperFillMode;
    }

    function getEffectiveFontFamily() {
        return (greeterFontFamily && greeterFontFamily !== "") ? greeterFontFamily : fontFamily;
    }

    function getFilteredScreens(componentId) {
        const prefs = screenPreferences && screenPreferences[componentId] || ["all"];
        if (prefs.includes("all")) {
            return Quickshell.screens;
        }
        return Quickshell.screens.filter(screen => prefs.includes(screen.name));
    }

    FileView {
        id: settingsFile
        path: root.configPath
        blockLoading: false
        blockWrites: true
        atomicWrites: false
        watchChanges: false
        printErrors: true
        onLoaded: {
            parseSettings(settingsFile.text());
        }
        onLoadFailed: error => {
            log.warn("Failed to load greetd settings:", error);
            root.parseSettings("");
        }
    }
}
