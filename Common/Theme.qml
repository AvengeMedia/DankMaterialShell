pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import "StockThemes.js" as StockThemes

Singleton {
    id: root

    readonly property bool envDisableMatugen: Quickshell.env("DMS_DISABLE_MATUGEN") === "1" || Quickshell.env("DMS_DISABLE_MATUGEN") === "true"

    // ! TODO - Synchronize with niri/hyprland gaps?
    readonly property real popupDistance: 2

    property string currentTheme: "blue"
    property string currentThemeCategory: "generic"
    property bool isLightMode: typeof SessionData !== "undefined" ? SessionData.isLightMode : false

    readonly property string dynamic: "dynamic"
    readonly property string custom : "custom"

    readonly property string homeDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation))
    readonly property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
    readonly property string shellDir: Paths.strip(Qt.resolvedUrl(".").toString()).replace("/Common/", "")
    readonly property string wallpaperPath: {
        if (typeof SessionData === "undefined") return ""

        if (SessionData.perMonitorWallpaper) {
            var screens = Quickshell.screens
            if (screens.length > 0) {
                var firstMonitorWallpaper = SessionData.getMonitorWallpaper(screens[0].name)
                var wallpaperPath = firstMonitorWallpaper || SessionData.wallpaperPath

                if (wallpaperPath && wallpaperPath.startsWith("we:")) {
                    return stateDir + "/we_screenshots/" + wallpaperPath.substring(3) + ".jpg"
                }

                return wallpaperPath
            }
        }

        var wallpaperPath = SessionData.wallpaperPath
        var screens = Quickshell.screens
        if (screens.length > 0 && wallpaperPath && wallpaperPath.startsWith("we:")) {
            return stateDir + "/we_screenshots/" + wallpaperPath.substring(3) + ".jpg"
        }

        return wallpaperPath
    }
    readonly property string rawWallpaperPath: {
        if (typeof SessionData === "undefined") return ""
        
        if (SessionData.perMonitorWallpaper) {
            // Use first monitor's wallpaper for dynamic theming
            var screens = Quickshell.screens
            if (screens.length > 0) {
                var firstMonitorWallpaper = SessionData.getMonitorWallpaper(screens[0].name)
                return firstMonitorWallpaper || SessionData.wallpaperPath
            }
        }

        return SessionData.wallpaperPath
    }

    property bool matugenAvailable: false
    property bool gtkThemingEnabled: typeof SettingsData !== "undefined" ? SettingsData.gtkAvailable : false
    property bool qtThemingEnabled: typeof SettingsData !== "undefined" ? (SettingsData.qt5ctAvailable || SettingsData.qt6ctAvailable) : false
    property var workerRunning: false
    property var matugenColors: ({})
    property int colorUpdateTrigger: 0
    property var customThemeData: null

    readonly property string stateDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.CacheLocation).toString()) + "/dankshell"

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir])
        matugenCheck.running = true
        if (typeof SessionData !== "undefined") {
            SessionData.isLightModeChanged.connect(root.onLightModeChanged)
            isLightMode = SessionData.isLightMode
        }

        if (typeof SettingsData !== "undefined" && SettingsData.currentThemeName) {
            switchTheme(SettingsData.currentThemeName, false, false)
        }
    }

    function applyGreeterTheme(themeName) {
        switchTheme(themeName, false, false)
        if (themeName === dynamic && dynamicColorsFileView.path) {
            dynamicColorsFileView.reload()
        }
    }

    function getMatugenColor(path, fallback) {
        colorUpdateTrigger
        const colorMode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
        let cur = matugenColors && matugenColors.colors && matugenColors.colors[colorMode]
        for (const part of path.split(".")) {
            if (!cur || typeof cur !== "object" || !(part in cur))
                return fallback
            cur = cur[part]
        }
        return cur || fallback
    }

    readonly property var currentThemeData: {
        if (currentTheme === "custom") {
            return customThemeData || StockThemes.getThemeByName("blue", isLightMode)
        } else if (currentTheme === dynamic) {
            return {
                "primary": getMatugenColor("primary", "#42a5f5"),
                "primaryText": getMatugenColor("on_primary", "#ffffff"),
                "primaryContainer": getMatugenColor("primary_container", "#1976d2"),
                "secondary": getMatugenColor("secondary", "#8ab4f8"),
                "surface": getMatugenColor("surface", "#1a1c1e"),
                "surfaceText": getMatugenColor("on_background", "#e3e8ef"),
                "surfaceVariant": getMatugenColor("surface_variant", "#44464f"),
                "surfaceVariantText": getMatugenColor("on_surface_variant", "#c4c7c5"),
                "surfaceTint": getMatugenColor("surface_tint", "#8ab4f8"),
                "background": getMatugenColor("background", "#1a1c1e"),
                "backgroundText": getMatugenColor("on_background", "#e3e8ef"),
                "outline": getMatugenColor("outline", "#8e918f"),
                "surfaceContainer": getMatugenColor("surface_container", "#1e2023"),
                "surfaceContainerHigh": getMatugenColor("surface_container_high", "#292b2f"),
                "surfaceContainerHighest": getMatugenColor("surface_container_highest", "#343740"),
                "error": "#F2B8B5",
                "warning": "#FF9800",
                "info": "#2196F3",
                "success": "#4CAF50"
            }
        } else {
            return StockThemes.getThemeByName(currentTheme, isLightMode)
        }
    }

    readonly property var availableMatugenSchemes: [
        ({ "value": "scheme-tonal-spot", "label": "Tonal Spot", "description": "Balanced palette with focused accents (default)." }),
        ({ "value": "scheme-content", "label": "Content", "description": "Derives colors that closely match the underlying image." }),
        ({ "value": "scheme-expressive", "label": "Expressive", "description": "Vibrant palette with playful saturation." }),
        ({ "value": "scheme-fidelity", "label": "Fidelity", "description": "High-fidelity palette that preserves source hues." }),
        ({ "value": "scheme-fruit-salad", "label": "Fruit Salad", "description": "Colorful mix of bright contrasting accents." }),
        ({ "value": "scheme-monochrome", "label": "Monochrome", "description": "Minimal palette built around a single hue." }),
        ({ "value": "scheme-neutral", "label": "Neutral", "description": "Muted palette with subdued, calming tones." }),
        ({ "value": "scheme-rainbow", "label": "Rainbow", "description": "Diverse palette spanning the full spectrum." })
    ]

    function getMatugenScheme(value) {
        const schemes = availableMatugenSchemes
        for (let i = 0; i < schemes.length; i++) {
            if (schemes[i].value === value)
                return schemes[i]
        }
        return schemes[0]
    }

    property color primary: currentThemeData.primary
    property color primaryText: currentThemeData.primaryText
    property color primaryContainer: currentThemeData.primaryContainer
    property color secondary: currentThemeData.secondary
    property color surface: {
        if (typeof SettingsData !== "undefined" && SettingsData.surfaceBase === "s") {
            return currentThemeData.background
        }
        return currentThemeData.surface
    }
    property color surfaceText: currentThemeData.surfaceText
    property color surfaceVariant: currentThemeData.surfaceVariant
    property color surfaceVariantText: currentThemeData.surfaceVariantText
    property color surfaceTint: currentThemeData.surfaceTint
    property color background: currentThemeData.background
    property color backgroundText: currentThemeData.backgroundText
    property color outline: currentThemeData.outline
    property color outlineVariant: currentThemeData.outlineVariant || Qt.rgba(outline.r, outline.g, outline.b, 0.6)
    property color surfaceContainer: {
        if (typeof SettingsData !== "undefined" && SettingsData.surfaceBase === "s") {
            return currentThemeData.surface
        }
        return currentThemeData.surfaceContainer
    }
    property color surfaceContainerHigh: {
        if (typeof SettingsData !== "undefined" && SettingsData.surfaceBase === "s") {
            return currentThemeData.surfaceContainer
        }
        return currentThemeData.surfaceContainerHigh
    }
    property color surfaceContainerHighest: {
        if (typeof SettingsData !== "undefined" && SettingsData.surfaceBase === "s") {
            return currentThemeData.surfaceContainerHigh
        }
        return currentThemeData.surfaceContainerHighest
    }

    property color onSurface: surfaceText
    property color onSurfaceVariant: surfaceVariantText
    property color onPrimary: primaryText
    property color onSurface_12: Qt.rgba(onSurface.r, onSurface.g, onSurface.b, 0.12)
    property color onSurface_38: Qt.rgba(onSurface.r, onSurface.g, onSurface.b, 0.38)
    property color onSurfaceVariant_30: Qt.rgba(onSurfaceVariant.r, onSurfaceVariant.g, onSurfaceVariant.b, 0.30)

    property color error: currentThemeData.error || "#F2B8B5"
    property color warning: currentThemeData.warning || "#FF9800"
    property color info: currentThemeData.info || "#2196F3"
    property color tempWarning: "#ff9933"
    property color tempDanger: "#ff5555"
    property color success: currentThemeData.success || "#4CAF50"

    property color primaryHover: Qt.rgba(primary.r, primary.g, primary.b, 0.12)
    property color primaryHoverLight: Qt.rgba(primary.r, primary.g, primary.b, 0.08)
    property color primaryPressed: Qt.rgba(primary.r, primary.g, primary.b, 0.16)
    property color primarySelected: Qt.rgba(primary.r, primary.g, primary.b, 0.3)
    property color primaryBackground: Qt.rgba(primary.r, primary.g, primary.b, 0.04)

    property color secondaryHover: Qt.rgba(secondary.r, secondary.g, secondary.b, 0.08)

    property color surfaceHover: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.08)
    property color surfacePressed: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.12)
    property color surfaceSelected: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.15)
    property color surfaceLight: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.1)
    property color surfaceVariantAlpha: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.2)
    property color surfaceTextHover: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.08)
    property color surfaceTextAlpha: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.3)
    property color surfaceTextLight: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.06)
    property color surfaceTextMedium: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.7)

    property color outlineButton: Qt.rgba(outline.r, outline.g, outline.b, 0.5)
    property color outlineLight: Qt.rgba(outline.r, outline.g, outline.b, 0.05)
    property color outlineMedium: Qt.rgba(outline.r, outline.g, outline.b, 0.08)
    property color outlineStrong: Qt.rgba(outline.r, outline.g, outline.b, 0.12)

    property color errorHover: Qt.rgba(error.r, error.g, error.b, 0.12)
    property color errorPressed: Qt.rgba(error.r, error.g, error.b, 0.16)

    property color shadowMedium: Qt.rgba(0, 0, 0, 0.08)
    property color shadowStrong: Qt.rgba(0, 0, 0, 0.3)

    readonly property var animationDurations: [
        { shorter: 0, short: 0, medium: 0, long: 0, extraLong: 0 },
        { shorter: 50, short: 75, medium: 150, long: 250, extraLong: 500 },
        { shorter: 100, short: 150, medium: 300, long: 500, extraLong: 1000 },
        { shorter: 150, short: 225, medium: 450, long: 750, extraLong: 1500 },
        { shorter: 200, short: 300, medium: 600, long: 1000, extraLong: 2000 }
    ]

    readonly property int currentAnimationSpeed: typeof SettingsData !== "undefined" ? SettingsData.animationSpeed : SettingsData.AnimationSpeed.Short
    readonly property var currentDurations: animationDurations[currentAnimationSpeed] || animationDurations[SettingsData.AnimationSpeed.Short]

    property int shorterDuration: currentDurations.shorter
    property int shortDuration: currentDurations.short
    property int mediumDuration: currentDurations.medium
    property int longDuration: currentDurations.long
    property int extraLongDuration: currentDurations.extraLong
    property int standardEasing: Easing.OutCubic
    property int emphasizedEasing: Easing.OutQuart

    property real cornerRadius: typeof SettingsData !== "undefined" ? SettingsData.cornerRadius : 12
    property real spacingXS: 4
    property real spacingS: 8
    property real spacingM: 12
    property real spacingL: 16
    property real spacingXL: 24
    property real fontSizeSmall: (typeof SettingsData !== "undefined" ? SettingsData.fontScale : 1.0) * 12
    property real fontSizeMedium: (typeof SettingsData !== "undefined" ? SettingsData.fontScale : 1.0) * 14
    property real fontSizeLarge: (typeof SettingsData !== "undefined" ? SettingsData.fontScale : 1.0) * 16
    property real fontSizeXLarge: (typeof SettingsData !== "undefined" ? SettingsData.fontScale : 1.0) * 20
    property real barHeight: 48
    property real iconSize: 24
    property real iconSizeSmall: 16
    property real iconSizeLarge: 32

    property real panelTransparency: 0.85
    property real widgetTransparency: typeof SettingsData !== "undefined" && SettingsData.dankBarWidgetTransparency !== undefined ? SettingsData.dankBarWidgetTransparency : 1.0
    property real popupTransparency: typeof SettingsData !== "undefined" && SettingsData.popupTransparency !== undefined ? SettingsData.popupTransparency : 1.0

    function screenTransition() {
        CompositorService.isNiri && NiriService.doScreenTransition()
    }

    function switchTheme(themeName, savePrefs = true, enableTransition = true) {
        if (enableTransition) {
            screenTransition()
            themeTransitionTimer.themeName = themeName
            themeTransitionTimer.savePrefs = savePrefs
            themeTransitionTimer.restart()
            return
        }

        if (themeName === dynamic) {
            currentTheme = dynamic
            currentThemeCategory = dynamic
        } else if (themeName === custom) {
            currentTheme = custom
            currentThemeCategory = custom
            if (typeof SettingsData !== "undefined" && SettingsData.customThemeFile) {
                loadCustomThemeFromFile(SettingsData.customThemeFile)
            }
        } else {
            currentTheme = themeName
            if (StockThemes.isCatppuccinVariant(themeName)) {
                currentThemeCategory = "catppuccin"
            } else {
                currentThemeCategory = "generic"
            }
        }
        const isGreeterMode = (typeof SessionData !== "undefined" && SessionData.isGreeterMode)
        if (savePrefs && typeof SettingsData !== "undefined" && !isGreeterMode)
            SettingsData.setTheme(currentTheme)

        if (!isGreeterMode) {
            generateSystemThemesFromCurrentTheme()
        }
    }

    function setLightMode(light, savePrefs = true, enableTransition = false) {
        if (enableTransition) {
            screenTransition()
            lightModeTransitionTimer.lightMode = light
            lightModeTransitionTimer.savePrefs = savePrefs
            lightModeTransitionTimer.restart()
            return
        }

        const isGreeterMode = (typeof SessionData !== "undefined" && SessionData.isGreeterMode)
        isLightMode = light
        if (savePrefs && typeof SessionData !== "undefined" && !isGreeterMode)
            SessionData.setLightMode(isLightMode)
        if (!isGreeterMode) {
            PortalService.setLightMode(isLightMode)
            generateSystemThemesFromCurrentTheme()
        }
    }

    function toggleLightMode(savePrefs = true) {
        setLightMode(!isLightMode, savePrefs, true)
    }

    function forceGenerateSystemThemes() {
        if (!matugenAvailable) {
            return
        }
        generateSystemThemesFromCurrentTheme()
    }

    function getAvailableThemes() {
        return StockThemes.getAllThemeNames()
    }

    function getThemeDisplayName(themeName) {
        const themeData = StockThemes.getThemeByName(themeName, isLightMode)
        return themeData.name
    }

    function getThemeColors(themeName) {
        if (themeName === "custom" && customThemeData) {
            return customThemeData
        }
        return StockThemes.getThemeByName(themeName, isLightMode)
    }

    function switchThemeCategory(category, defaultTheme) {
        screenTransition()
        themeCategoryTransitionTimer.category = category
        themeCategoryTransitionTimer.defaultTheme = defaultTheme
        themeCategoryTransitionTimer.restart()
    }

    function getCatppuccinColor(variantName) {
        const catColors = {
            "cat-rosewater": "#f5e0dc", "cat-flamingo": "#f2cdcd", "cat-pink": "#f5c2e7", "cat-mauve": "#cba6f7",
            "cat-red": "#f38ba8", "cat-maroon": "#eba0ac", "cat-peach": "#fab387", "cat-yellow": "#f9e2af",
            "cat-green": "#a6e3a1", "cat-teal": "#94e2d5", "cat-sky": "#89dceb", "cat-sapphire": "#74c7ec",
            "cat-blue": "#89b4fa", "cat-lavender": "#b4befe"
        }
        return catColors[variantName] || "#cba6f7"
    }

    function getCatppuccinVariantName(variantName) {
        const catNames = {
            "cat-rosewater": "Rosewater", "cat-flamingo": "Flamingo", "cat-pink": "Pink", "cat-mauve": "Mauve",
            "cat-red": "Red", "cat-maroon": "Maroon", "cat-peach": "Peach", "cat-yellow": "Yellow",
            "cat-green": "Green", "cat-teal": "Teal", "cat-sky": "Sky", "cat-sapphire": "Sapphire",
            "cat-blue": "Blue", "cat-lavender": "Lavender"
        }
        return catNames[variantName] || "Unknown"
    }

    function loadCustomTheme(themeData) {
        if (themeData.dark || themeData.light) {
            const colorMode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
            const selectedTheme = themeData[colorMode] || themeData.dark || themeData.light
            customThemeData = selectedTheme
        } else {
            customThemeData = themeData
        }

        generateSystemThemesFromCurrentTheme()
    }

    function loadCustomThemeFromFile(filePath) {
        customThemeFileView.path = filePath
    }

    property alias availableThemeNames: root._availableThemeNames
    readonly property var _availableThemeNames: StockThemes.getAllThemeNames()
    property string currentThemeName: currentTheme

    function popupBackground() {
        return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, popupTransparency)
    }

    function contentBackground() {
        return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, popupTransparency)
    }

    function panelBackground() {
        return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, panelTransparency)
    }

    property real notepadTransparency: SettingsData.notepadTransparencyOverride >= 0 ? SettingsData.notepadTransparencyOverride : popupTransparency

    property var widgetBaseBackgroundColor: {
        const colorMode = typeof SettingsData !== "undefined" ? SettingsData.widgetBackgroundColor : "sch"
        switch (colorMode) {
            case "s":
                return surface
            case "sc":
                return surfaceContainer
            case "sch":
                return surfaceContainerHigh
            case "sth":
            default:
                return surfaceTextHover
        }
    }

    property var widgetBaseHoverColor: {
        const baseColor = widgetBaseBackgroundColor
        const factor = 1.2
        return isLightMode ? Qt.darker(baseColor, factor) : Qt.lighter(baseColor, factor)
    }

    property var widgetBackground: {
        const colorMode = typeof SettingsData !== "undefined" ? SettingsData.widgetBackgroundColor : "sch"
        switch (colorMode) {
            case "s":
                return Qt.rgba(surface.r, surface.g, surface.b, widgetTransparency)
            case "sc":
                return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, widgetTransparency)
            case "sch":
                return Qt.rgba(surfaceContainerHigh.r, surfaceContainerHigh.g, surfaceContainerHigh.b, widgetTransparency)
            case "sth":
            default:
                return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, widgetTransparency)
        }
    }

    function getPopupBackgroundAlpha() {
        return popupTransparency
    }

    function getContentBackgroundAlpha() {
        return popupTransparency
    }

    function isColorDark(c) {
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) < 0.5
    }

    function barIconSize(barThickness, offset) {
        const defaultOffset = offset !== undefined ? offset : -6
        return Math.round((barThickness / 48) * (iconSize + defaultOffset))
    }

    function barTextSize(barThickness) {
        const scale = barThickness / 48
        const dankBarScale = (typeof SettingsData !== "undefined" ? SettingsData.dankBarFontScale : 1.0)
        if (scale <= 0.75) return fontSizeSmall * 0.9 * dankBarScale
        if (scale >= 1.25) return fontSizeMedium * dankBarScale
        return fontSizeSmall * dankBarScale
    }

    function getBatteryIcon(level, isCharging, batteryAvailable) {
        if (!batteryAvailable)
            return _getBatteryPowerProfileIcon()

        if (isCharging) {
            if (level >= 90)
                return "battery_charging_full"
            if (level >= 80)
                return "battery_charging_90"
            if (level >= 60)
                return "battery_charging_80"
            if (level >= 50)
                return "battery_charging_60"
            if (level >= 30)
                return "battery_charging_50"
            if (level >= 20)
                return "battery_charging_30"
            return "battery_charging_20"
        } else {
            if (level >= 95)
                return "battery_full"
            if (level >= 85)
                return "battery_6_bar"
            if (level >= 70)
                return "battery_5_bar"
            if (level >= 55)
                return "battery_4_bar"
            if (level >= 40)
                return "battery_3_bar"
            if (level >= 25)
                return "battery_2_bar"
            if (level >= 10)
                return "battery_1_bar"
            return "battery_alert"
        }
    }

    function _getBatteryPowerProfileIcon() {
        if (typeof PowerProfiles === "undefined")
            return "balance"

        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return "energy_savings_leaf"
        case PowerProfile.Performance:
            return "rocket_launch"
        default:
            return "balance"
        }
    }

    function getPowerProfileIcon(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver:
            return "battery_saver"
        case PowerProfile.Balanced:
            return "battery_std"
        case PowerProfile.Performance:
            return "flash_on"
        default:
            return "settings"
        }
    }

    function getPowerProfileLabel(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver:
            return "Power Saver"
        case PowerProfile.Balanced:
            return "Balanced"
        case PowerProfile.Performance:
            return "Performance"
        default:
            return profile.charAt(0).toUpperCase() + profile.slice(1)
        }
    }

    function getPowerProfileDescription(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver:
            return "Extend battery life"
        case PowerProfile.Balanced:
            return "Balance power and performance"
        case PowerProfile.Performance:
            return "Prioritize performance"
        default:
            return "Custom power profile"
        }
    }


    function onLightModeChanged() {
        if (matugenColors && Object.keys(matugenColors).length > 0) {
            colorUpdateTrigger++
        }

        if (currentTheme === "custom" && customThemeFileView.path) {
            customThemeFileView.reload()
        }
    }

    function setDesiredTheme(kind, value, isLight, iconTheme, matugenType) {
        if (!matugenAvailable) {
            console.warn("matugen not available or disabled - cannot set system theme")
            return
        }

        if (typeof NiriService !== "undefined" && CompositorService.isNiri) {
            NiriService.suppressNextToast()
        }

        const desired = {
            "kind": kind,
            "value": value,
            "mode": isLight ? "light" : "dark",
            "iconTheme": iconTheme || "System Default",
            "matugenType": matugenType || "scheme-tonal-spot",
            "surfaceBase": (typeof SettingsData !== "undefined" && SettingsData.surfaceBase) ? SettingsData.surfaceBase : "sc"
        }

        const json = JSON.stringify(desired)
        const desiredPath = stateDir + "/matugen.desired.json"

        Quickshell.execDetached(["sh", "-c", `mkdir -p '${stateDir}' && cat > '${desiredPath}' << 'EOF'\n${json}\nEOF`])
        workerRunning = true
        if (rawWallpaperPath.startsWith("we:")) {
            console.log("calling matugen worker")
            systemThemeGenerator.command = [
                "sh", "-c",
                `sleep 1 && ${shellDir}/scripts/matugen-worker.sh '${stateDir}' '${shellDir}' '${configDir}' --run`
            ]
        } else {
            systemThemeGenerator.command = [shellDir + "/scripts/matugen-worker.sh", stateDir, shellDir, configDir, "--run"]
        }
        systemThemeGenerator.running = true
    }

    function generateSystemThemesFromCurrentTheme() {
        const isGreeterMode = (typeof SessionData !== "undefined" && SessionData.isGreeterMode)
        if (!matugenAvailable || isGreeterMode)
            return

        const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode)
        const iconTheme = (typeof SettingsData !== "undefined" && SettingsData.iconTheme) ? SettingsData.iconTheme : "System Default"

        if (currentTheme === dynamic) {
            if (!wallpaperPath) {
                return
            }
            const selectedMatugenType = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme) ? SettingsData.matugenScheme : "scheme-tonal-spot"
            if (wallpaperPath.startsWith("#")) {
                setDesiredTheme("hex", wallpaperPath, isLight, iconTheme, selectedMatugenType)
            } else {
                setDesiredTheme("image", wallpaperPath, isLight, iconTheme, selectedMatugenType)
            }
        } else {
            let primaryColor
            let matugenType
            if (currentTheme === "custom") {
                if (!customThemeData || !customThemeData.primary) {
                    console.warn("Custom theme data not available for system theme generation")
                    return
                }
                primaryColor = customThemeData.primary
                matugenType = customThemeData.matugen_type
            } else {
                primaryColor = currentThemeData.primary
                matugenType = currentThemeData.matugen_type
            }

            if (!primaryColor) {
                console.warn("No primary color available for theme:", currentTheme)
                return
            }
            setDesiredTheme("hex", primaryColor, isLight, iconTheme, matugenType)
        }
    }

    function applyGtkColors() {
        if (!matugenAvailable) {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("matugen not available or disabled - cannot apply GTK colors")
            }
            return
        }

        const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "true" : "false"
        gtkApplier.command = [shellDir + "/scripts/gtk.sh", configDir, isLight, shellDir]
        gtkApplier.running = true
    }

    function applyQtColors() {
        if (!matugenAvailable) {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("matugen not available or disabled - cannot apply Qt colors")
            }
            return
        }

        qtApplier.command = [shellDir + "/scripts/qt.sh", configDir]
        qtApplier.running = true
    }

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    function snap(value, dpr) {
        return Math.round(value * dpr) / dpr
    }

    function invertHex(hex) {
        hex = hex.replace('#', '');

        if (!/^[0-9A-Fa-f]{6}$/.test(hex)) {
            return hex;
        }

        const r = parseInt(hex.substr(0, 2), 16);
        const g = parseInt(hex.substr(2, 2), 16);
        const b = parseInt(hex.substr(4, 2), 16);

        const invR = (255 - r).toString(16).padStart(2, '0');
        const invG = (255 - g).toString(16).padStart(2, '0');
        const invB = (255 - b).toString(16).padStart(2, '0');

        return `#${invR}${invG}${invB}`;
    }

    property string baseLogoColor: {
        if (typeof SettingsData === "undefined") return ""
        const colorOverride = SettingsData.launcherLogoColorOverride
        if (!colorOverride || colorOverride === "") return ""
        if (colorOverride === "primary") return primary
        if (colorOverride === "surface") return surfaceText
        return colorOverride
    }

    property string effectiveLogoColor: {
        if (typeof SettingsData === "undefined") return ""

        const colorOverride = SettingsData.launcherLogoColorOverride
        if (!colorOverride || colorOverride === "") return ""

        if (colorOverride === "primary") return primary
        if (colorOverride === "surface") return surfaceText

        if (!SettingsData.launcherLogoColorInvertOnMode) {
            return colorOverride
        }

        if (isLightMode) {
            return invertHex(colorOverride)
        }

        return colorOverride
    }



    Process {
        id: matugenCheck
        command: ["which", "matugen"]
        onExited: code => {
            matugenAvailable = (code === 0) && !envDisableMatugen
            const isGreeterMode = (typeof SessionData !== "undefined" && SessionData.isGreeterMode)

            if (!matugenAvailable || isGreeterMode) {
                return
            }

            const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode)
            const iconTheme = (typeof SettingsData !== "undefined" && SettingsData.iconTheme) ? SettingsData.iconTheme : "System Default"

            if (currentTheme === dynamic) {
                if (wallpaperPath) {
                    Quickshell.execDetached(["rm", "-f", stateDir + "/matugen.key"])
                    const selectedMatugenType = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme) ? SettingsData.matugenScheme : "scheme-tonal-spot"
                    if (wallpaperPath.startsWith("#")) {
                        setDesiredTheme("hex", wallpaperPath, isLight, iconTheme, selectedMatugenType)
                    } else {
                        setDesiredTheme("image", wallpaperPath, isLight, iconTheme, selectedMatugenType)
                    }
                }
            } else {
                let primaryColor
                let matugenType
                if (currentTheme === "custom") {
                    if (customThemeData && customThemeData.primary) {
                        primaryColor = customThemeData.primary
                        matugenType = customThemeData.matugen_type
                    }
                } else {
                    primaryColor = currentThemeData.primary
                    matugenType = currentThemeData.matugen_type
                }

                if (primaryColor) {
                    Quickshell.execDetached(["rm", "-f", stateDir + "/matugen.key"])
                    setDesiredTheme("hex", primaryColor, isLight, iconTheme, matugenType)
                }
            }
        }
    }



    Process {
        id: ensureStateDir
    }

    Process {
        id: systemThemeGenerator
        running: false

        onExited: exitCode => {
            workerRunning = false

            if (exitCode !== 0 && exitCode !== 2) {
                if (typeof ToastService !== "undefined") {
                    ToastService.showError("Theme worker failed (" + exitCode + ")")
                }
                console.warn("Theme worker failed with exit code:", exitCode)
            }
        }
    }

    Process {
        id: gtkApplier
        running: false

        stdout: StdioCollector {
            id: gtkStdout
        }

        stderr: StdioCollector {
            id: gtkStderr
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                if (typeof ToastService !== "undefined" && typeof NiriService !== "undefined" && !NiriService.matugenSuppression) {
                    ToastService.showInfo("GTK colors applied successfully")
                }
            } else {
                if (typeof ToastService !== "undefined") {
                    ToastService.showError("Failed to apply GTK colors: " + gtkStderr.text)
                }
            }
        }
    }

    Process {
        id: qtApplier
        running: false

        stdout: StdioCollector {
            id: qtStdout
        }

        stderr: StdioCollector {
            id: qtStderr
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                if (typeof ToastService !== "undefined") {
                    ToastService.showInfo("Qt colors applied successfully")
                }
            } else {
                if (typeof ToastService !== "undefined") {
                    ToastService.showError("Failed to apply Qt colors: " + qtStderr.text)
                }
            }
        }
    }

    FileView {
        id: customThemeFileView
        watchChanges: currentTheme === "custom"

        function parseAndLoadTheme() {
            try {
                var themeData = JSON.parse(customThemeFileView.text())
                loadCustomTheme(themeData)
            } catch (e) {
                ToastService.showError("Invalid JSON format: " + e.message)
            }
        }

        onLoaded: {
            parseAndLoadTheme()
        }

        onFileChanged: {
            customThemeFileView.reload()
        }

        onLoadFailed: function (error) {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("Failed to read theme file: " + error)
            }
        }
    }

    FileView {
        id: dynamicColorsFileView
        path: {
            const greetCfgDir = Quickshell.env("DMS_GREET_CFG_DIR") || "/etc/greetd/.dms"
            const colorsPath = SessionData.isGreeterMode
                ? greetCfgDir + "/colors.json"
                : stateDir + "/dms-colors.json"
            return colorsPath
        }
        watchChanges: currentTheme === dynamic && !SessionData.isGreeterMode

        function parseAndLoadColors() {
            try {
                const colorsText = dynamicColorsFileView.text()
                if (colorsText) {
                    root.matugenColors = JSON.parse(colorsText)
                    root.colorUpdateTrigger++
                    if (typeof ToastService !== "undefined") {
                        ToastService.clearWallpaperError()
                    }
                }
            } catch (e) {
                console.error("Theme: Failed to parse dynamic colors:", e)
                if (typeof ToastService !== "undefined") {
                    ToastService.wallpaperErrorStatus = "error"
                    ToastService.showError("Dynamic colors parse error: " + e.message)
                }
            }
        }

        onLoaded: {
            if (currentTheme === dynamic) {
                parseAndLoadColors()
            }
        }

        onFileChanged: {
            if (currentTheme === dynamic) {
                dynamicColorsFileView.reload()
            }
        }

        onLoadFailed: function (error) {
            if (currentTheme === dynamic && typeof ToastService !== "undefined") {
                ToastService.showError("Failed to read dynamic colors: " + error)
            }
        }
    }

    IpcHandler {
        target: "theme"

        function toggle(): string {
            root.toggleLightMode()
            return root.isLightMode ? "dark" : "light"
        }

        function light(): string {
            root.setLightMode(true, true, true)
            return "light"
        }

        function dark(): string {
            root.setLightMode(false, true, true)
            return "dark"
        }

        function getMode(): string {
            return root.isLightMode ? "light" : "dark"
        }
    }

    // These timers are for screen transitions, since sometimes QML still beats the niri call
    Timer {
        id: themeTransitionTimer
        interval: 50
        repeat: false
        property string themeName: ""
        property bool savePrefs: true
        onTriggered: root.switchTheme(themeName, savePrefs, false)
    }

    Timer {
        id: lightModeTransitionTimer
        interval: 100
        repeat: false
        property bool lightMode: false
        property bool savePrefs: true
        onTriggered: root.setLightMode(lightMode, savePrefs, false)
    }

    Timer {
        id: themeCategoryTransitionTimer
        interval: 50
        repeat: false
        property string category: ""
        property string defaultTheme: ""
        onTriggered: {
            root.currentThemeCategory = category
            root.switchTheme(defaultTheme, true, false)
        }
    }
}
