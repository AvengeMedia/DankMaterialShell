pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string configPath: {
        const greetCfgDir = Quickshell.env("DMS_GREET_CFG_DIR") || "/etc/greetd/.dms"
        return greetCfgDir + "/settings.json"
    }

    property string currentThemeName: "blue"
    property bool settingsLoaded: false
    property string customThemeFile: ""
    property string matugenScheme: "scheme-tonal-spot"
    property bool use24HourClock: true
    property bool showSeconds: false
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
    property string surfaceBase: "s"
    property string lockDateFormat: ""
    property bool lockScreenShowPowerActions: true
    property var screenPreferences: ({})
    property int animationSpeed: 2
    property string wallpaperFillMode: "Fill"

    readonly property string defaultFontFamily: "Inter Variable"
    readonly property string defaultMonoFontFamily: "Fira Code"

    function parseSettings(content) {
        try {
            if (content && content.trim()) {
                const settings = JSON.parse(content)
                currentThemeName = settings.currentThemeName !== undefined ? settings.currentThemeName : "blue"
                customThemeFile = settings.customThemeFile !== undefined ? settings.customThemeFile : ""
                matugenScheme = settings.matugenScheme !== undefined ? settings.matugenScheme : "scheme-tonal-spot"
                use24HourClock = settings.use24HourClock !== undefined ? settings.use24HourClock : true
                showSeconds = settings.showSeconds !== undefined ? settings.showSeconds : false
                useFahrenheit = settings.useFahrenheit !== undefined ? settings.useFahrenheit : false
                nightModeEnabled = settings.nightModeEnabled !== undefined ? settings.nightModeEnabled : false
                weatherLocation = settings.weatherLocation !== undefined ? settings.weatherLocation : "New York, NY"
                weatherCoordinates = settings.weatherCoordinates !== undefined ? settings.weatherCoordinates : "40.7128,-74.0060"
                useAutoLocation = settings.useAutoLocation !== undefined ? settings.useAutoLocation : false
                weatherEnabled = settings.weatherEnabled !== undefined ? settings.weatherEnabled : true
                iconTheme = settings.iconTheme !== undefined ? settings.iconTheme : "System Default"
                useOSLogo = settings.useOSLogo !== undefined ? settings.useOSLogo : false
                osLogoColorOverride = settings.osLogoColorOverride !== undefined ? settings.osLogoColorOverride : ""
                osLogoBrightness = settings.osLogoBrightness !== undefined ? settings.osLogoBrightness : 0.5
                osLogoContrast = settings.osLogoContrast !== undefined ? settings.osLogoContrast : 1
                fontFamily = settings.fontFamily !== undefined ? settings.fontFamily : defaultFontFamily
                monoFontFamily = settings.monoFontFamily !== undefined ? settings.monoFontFamily : defaultMonoFontFamily
                fontWeight = settings.fontWeight !== undefined ? settings.fontWeight : Font.Normal
                fontScale = settings.fontScale !== undefined ? settings.fontScale : 1.0
                cornerRadius = settings.cornerRadius !== undefined ? settings.cornerRadius : 12
                widgetBackgroundColor = settings.widgetBackgroundColor !== undefined ? settings.widgetBackgroundColor : "sch"
                surfaceBase = settings.surfaceBase !== undefined ? settings.surfaceBase : "s"
                lockDateFormat = settings.lockDateFormat !== undefined ? settings.lockDateFormat : ""
                lockScreenShowPowerActions = settings.lockScreenShowPowerActions !== undefined ? settings.lockScreenShowPowerActions : true
                screenPreferences = settings.screenPreferences !== undefined ? settings.screenPreferences : ({})
                animationSpeed = settings.animationSpeed !== undefined ? settings.animationSpeed : 2
                wallpaperFillMode = settings.wallpaperFillMode !== undefined ? settings.wallpaperFillMode : "Fill"
                settingsLoaded = true

                if (typeof Theme !== "undefined") {
                    Theme.applyGreeterTheme(currentThemeName)
                }
            }
        } catch (e) {
            console.warn("Failed to parse greetd settings:", e)
        }
    }

    function getEffectiveLockDateFormat() {
        return lockDateFormat && lockDateFormat.length > 0 ? lockDateFormat : Locale.LongFormat
    }

    function getFilteredScreens(componentId) {
        const prefs = screenPreferences && screenPreferences[componentId] || ["all"]
        if (prefs.includes("all")) {
            return Quickshell.screens
        }
        return Quickshell.screens.filter(screen => prefs.includes(screen.name))
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
            parseSettings(settingsFile.text())
        }
    }
}
