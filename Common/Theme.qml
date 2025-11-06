pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import qs.Modules.Greetd
import "StockThemes.js" as StockThemes

Singleton {
    id: root

    readonly property string stateDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericCacheLocation).toString()) + "/DankMaterialShell"

    readonly property bool envDisableMatugen: Quickshell.env("DMS_DISABLE_MATUGEN") === "1" || Quickshell.env("DMS_DISABLE_MATUGEN") === "true"

    readonly property real popupDistance: {
        if (typeof SettingsData === "undefined")
        return 4
        return SettingsData.popupGapsAuto ? Math.max(4, SettingsData.dankBarSpacing) : SettingsData.popupGapsManual
    }

    property string currentTheme: "blue"
    property string currentThemeCategory: "generic"
    property bool isLightMode: typeof SessionData !== "undefined" ? SessionData.isLightMode : false
    property bool colorsFileLoadFailed: false

    readonly property string dynamic: "dynamic"
    readonly property string custom: "custom"

    readonly property string homeDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation))
    readonly property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
    readonly property string shellDir: Paths.strip(Qt.resolvedUrl(".").toString()).replace("/Common/", "")
    readonly property string wallpaperPath: {
        if (typeof SessionData === "undefined")
        return ""

        if (SessionData.perMonitorWallpaper) {
            var screens = Quickshell.screens
            if (screens.length > 0) {
                var firstMonitorWallpaper = SessionData.getMonitorWallpaper(screens[0].name)
                return firstMonitorWallpaper || SessionData.wallpaperPath
            }
        }

        return SessionData.wallpaperPath
    }
    readonly property string rawWallpaperPath: {
        if (typeof SessionData === "undefined")
        return ""

        if (SessionData.perMonitorWallpaper) {
            var screens = Quickshell.screens
            if (screens.length > 0) {
                var targetMonitor = (typeof SettingsData !== "undefined" && SettingsData.matugenTargetMonitor && SettingsData.matugenTargetMonitor !== "") ? SettingsData.matugenTargetMonitor : screens[0].name

                var targetMonitorExists = false
                for (var i = 0; i < screens.length; i++) {
                    if (screens[i].name === targetMonitor) {
                        targetMonitorExists = true
                        break
                    }
                }

                if (!targetMonitorExists) {
                    targetMonitor = screens[0].name
                }

                var targetMonitorWallpaper = SessionData.getMonitorWallpaper(targetMonitor)
                return targetMonitorWallpaper || SessionData.wallpaperPath
            }
        }

        return SessionData.wallpaperPath
    }

    property bool matugenAvailable: false
    property bool gtkThemingEnabled: typeof SettingsData !== "undefined" ? SettingsData.gtkAvailable : false
    property bool qtThemingEnabled: typeof SettingsData !== "undefined" ? (SettingsData.qt5ctAvailable || SettingsData.qt6ctAvailable) : false
    property var workerRunning: false
    property var matugenColors: ({})
    property var customThemeData: null

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir])
        Proc.runCommand("matugenCheck", ["which", "matugen"], (output, code) => {
                            matugenAvailable = (code === 0) && !envDisableMatugen
                            const isGreeterMode = (typeof SessionData !== "undefined" && SessionData.isGreeterMode)

                            if (!matugenAvailable || isGreeterMode) {
                                return
                            }

                            if (colorsFileLoadFailed && currentTheme === dynamic && rawWallpaperPath) {
                                console.info("Theme: Matugen now available, regenerating colors for dynamic theme")
                                const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode)
                                const iconTheme = (typeof SettingsData !== "undefined" && SettingsData.iconTheme) ? SettingsData.iconTheme : "System Default"
                                const selectedMatugenType = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme) ? SettingsData.matugenScheme : "scheme-tonal-spot"
                                if (rawWallpaperPath.startsWith("#")) {
                                    setDesiredTheme("hex", rawWallpaperPath, isLight, iconTheme, selectedMatugenType)
                                } else {
                                    setDesiredTheme("image", rawWallpaperPath, isLight, iconTheme, selectedMatugenType)
                                }
                                return
                            }

                            const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode)
                            const iconTheme = (typeof SettingsData !== "undefined" && SettingsData.iconTheme) ? SettingsData.iconTheme : "System Default"

                            if (currentTheme === dynamic) {
                                if (rawWallpaperPath) {
                                    const selectedMatugenType = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme) ? SettingsData.matugenScheme : "scheme-tonal-spot"
                                    if (rawWallpaperPath.startsWith("#")) {
                                        setDesiredTheme("hex", rawWallpaperPath, isLight, iconTheme, selectedMatugenType)
                                    } else {
                                        setDesiredTheme("image", rawWallpaperPath, isLight, iconTheme, selectedMatugenType)
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
                                    setDesiredTheme("hex", primaryColor, isLight, iconTheme, matugenType)
                                }
                            }
                        }, 0)
        if (typeof SessionData !== "undefined") {
            SessionData.isLightModeChanged.connect(root.onLightModeChanged)
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

    readonly property var availableMatugenSchemes: [({
                                                         "value": "scheme-tonal-spot",
                                                         "label": "Tonal Spot",
                                                         "description": I18n.tr("Balanced palette with focused accents (default).")
                                                     }), ({
                                                              "value": "scheme-vibrant-spot",
                                                              "label": "Vibrant Spot",
                                                              "description": I18n.tr("Lively palette with saturated accents.")
                                                          }), ({
                                                                   "value": "scheme-dynamic-contrast",
                                                                   "label": "Dynamic Contrast",
                                                                   "description": I18n.tr("High-contrast palette for strong visual distinction.")
                                                               }), ({
                                                                        "value": "scheme-content",
                                                                        "label": "Content",
                                                                        "description": I18n.tr("Derives colors that closely match the underlying image.")
                                                                    }), ({
                                                                             "value": "scheme-expressive",
                                                                             "label": "Expressive",
                                                                             "description": I18n.tr("Vibrant palette with playful saturation.")
                                                                         }), ({
                                                                                  "value": "scheme-fidelity",
                                                                                  "label": "Fidelity",
                                                                                  "description": I18n.tr("High-fidelity palette that preserves source hues.")
                                                                              }), ({
                                                                                       "value": "scheme-fruit-salad",
                                                                                       "label": "Fruit Salad",
                                                                                       "description": I18n.tr("Colorful mix of bright contrasting accents.")
                                                                                   }), ({
                                                                                            "value": "scheme-monochrome",
                                                                                            "label": "Monochrome",
                                                                                            "description": I18n.tr("Minimal palette built around a single hue.")
                                                                                        }), ({
                                                                                                 "value": "scheme-neutral",
                                                                                                 "label": "Neutral",
                                                                                                 "description": I18n.tr("Muted palette with subdued, calming tones.")
                                                                                             }), ({
                                                                                                      "value": "scheme-rainbow",
                                                                                                      "label": "Rainbow",
                                                                                                      "description": I18n.tr("Diverse palette spanning the full spectrum.")
                                                                                                  })]

    function getMatugenScheme(value) {
        const schemes = availableMatugenSchemes
        for (var i = 0; i < schemes.length; i++) {
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

    readonly property var animationDurations: [{
            "shorter": 0,
            "short": 0,
            "medium": 0,
            "long": 0,
            "extraLong": 0
        }, {
            "shorter": 50,
            "short": 75,
            "medium": 150,
            "long": 250,
            "extraLong": 500
        }, {
            "shorter": 100,
            "short": 150,
            "medium": 300,
            "long": 500,
            "extraLong": 1000
        }, {
            "shorter": 150,
            "short": 225,
            "medium": 450,
            "long": 750,
            "extraLong": 1500
        }, {
            "shorter": 200,
            "short": 300,
            "medium": 600,
            "long": 1000,
            "extraLong": 2000
        }]

    readonly property int currentAnimationSpeed: typeof SettingsData !== "undefined" ? SettingsData.animationSpeed : SettingsData.AnimationSpeed.Short
    readonly property var currentDurations: animationDurations[currentAnimationSpeed] || animationDurations[SettingsData.AnimationSpeed.Short]

    property int shorterDuration: currentDurations.shorter
    property int shortDuration: currentDurations.short
    property int mediumDuration: currentDurations.medium
    property int longDuration: currentDurations.long
    property int extraLongDuration: currentDurations.extraLong
    property int standardEasing: Easing.OutCubic
    property int emphasizedEasing: Easing.OutQuart

    readonly property var expressiveCurves: {
        "emphasized": [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1],
        "emphasizedAccel": [0.3, 0, 0.8, 0.15, 1, 1],
        "emphasizedDecel": [0.05, 0.7, 0.1, 1, 1, 1],
        "standard": [0.2, 0, 0, 1, 1, 1],
        "standardAccel": [0.3, 0, 1, 1, 1, 1],
        "standardDecel": [0, 0, 0, 1, 1, 1],
        "expressiveFastSpatial": [0.42, 1.67, 0.21, 0.9, 1, 1],
        "expressiveDefaultSpatial": [0.38, 1.21, 0.22, 1, 1, 1],
        "expressiveEffects": [0.34, 0.8, 0.34, 1, 1, 1]
    }

    readonly property var animationPresetDurations: {
        "none": 0,
        "short": 250,
        "medium": 500,
        "long": 750
    }

    readonly property int currentAnimationBaseDuration: {
        if (typeof SettingsData === "undefined")
        return 500

        if (SettingsData.animationSpeed === SettingsData.AnimationSpeed.Custom) {
            return SettingsData.customAnimationDuration
        }

        const presetMap = [0, 250, 500, 750]
        return presetMap[SettingsData.animationSpeed] !== undefined ? presetMap[SettingsData.animationSpeed] : 500
    }

    readonly property var expressiveDurations: {
        if (typeof SettingsData === "undefined") {
            return {
                "fast": 200,
                "normal": 400,
                "large": 600,
                "extraLarge": 1000,
                "expressiveFastSpatial": 350,
                "expressiveDefaultSpatial": 500,
                "expressiveEffects": 200
            }
        }

        const baseDuration = currentAnimationBaseDuration
        return {
            "fast": baseDuration * 0.4,
            "normal": baseDuration * 0.8,
            "large": baseDuration * 1.2,
            "extraLarge": baseDuration * 2.0,
            "expressiveFastSpatial": baseDuration * 0.7,
            "expressiveDefaultSpatial": baseDuration,
            "expressiveEffects": baseDuration * 0.4
        }
    }

    property real cornerRadius: {
        if (typeof SessionData !== "undefined" && SessionData.isGreeterMode && typeof GreetdSettings !== "undefined") {
            return GreetdSettings.cornerRadius
        }
        return typeof SettingsData !== "undefined" ? SettingsData.cornerRadius : 12
    }
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
            SettingsData.set("currentThemeName", currentTheme)

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
        if (savePrefs && typeof SessionData !== "undefined" && !isGreeterMode)
            SessionData.setLightMode(light)
        if (!isGreeterMode) {
            // Skip with matugen becuase, our script runner will do it.
            if (!matugenAvailable) {
                PortalService.setLightMode(light)
            }
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
            "cat-rosewater": "#f5e0dc",
            "cat-flamingo": "#f2cdcd",
            "cat-pink": "#f5c2e7",
            "cat-mauve": "#cba6f7",
            "cat-red": "#f38ba8",
            "cat-maroon": "#eba0ac",
            "cat-peach": "#fab387",
            "cat-yellow": "#f9e2af",
            "cat-green": "#a6e3a1",
            "cat-teal": "#94e2d5",
            "cat-sky": "#89dceb",
            "cat-sapphire": "#74c7ec",
            "cat-blue": "#89b4fa",
            "cat-lavender": "#b4befe"
        }
        return catColors[variantName] || "#cba6f7"
    }

    function getCatppuccinVariantName(variantName) {
        const catNames = {
            "cat-rosewater": "Rosewater",
            "cat-flamingo": "Flamingo",
            "cat-pink": "Pink",
            "cat-mauve": "Mauve",
            "cat-red": "Red",
            "cat-maroon": "Maroon",
            "cat-peach": "Peach",
            "cat-yellow": "Yellow",
            "cat-green": "Green",
            "cat-teal": "Teal",
            "cat-sky": "Sky",
            "cat-sapphire": "Sapphire",
            "cat-blue": "Blue",
            "cat-lavender": "Lavender"
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
        if (scale <= 0.75)
            return fontSizeSmall * 0.9 * dankBarScale
        if (scale >= 1.25)
            return fontSizeMedium * dankBarScale
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
        if (currentTheme === "custom" && customThemeFileView.path) {
            customThemeFileView.reload()
        }
    }

    function setDesiredTheme(kind, value, isLight, iconTheme, matugenType) {
        if (!matugenAvailable) {
            console.warn("Theme: matugen not available or disabled - cannot set system theme")
            return
        }

        console.info("Theme: Setting desired theme -", kind, "mode:", isLight ? "light" : "dark", "type:", matugenType)

        if (typeof NiriService !== "undefined" && CompositorService.isNiri) {
            NiriService.suppressNextToast()
        }

        const desired = {
            "kind": kind,
            "value": value,
            "mode": isLight ? "light" : "dark",
            "iconTheme": iconTheme || "System Default",
            "matugenType": matugenType || "scheme-tonal-spot",
            "surfaceBase": (typeof SettingsData !== "undefined" && SettingsData.surfaceBase) ? SettingsData.surfaceBase : "sc",
            "runUserTemplates": (typeof SettingsData !== "undefined") ? SettingsData.runUserMatugenTemplates : true
        }

        const json = JSON.stringify(desired)
        const desiredPath = stateDir + "/matugen.desired.json"

        Quickshell.execDetached(["sh", "-c", `mkdir -p '${stateDir}' && cat > '${desiredPath}' << 'EOF'\n${json}\nEOF`])
        workerRunning = true
        const syncModeWithPortal = (typeof SettingsData !== "undefined" && SettingsData.syncModeWithPortal) ? "true" : "false"
        console.log("Theme: Starting matugen worker")
        systemThemeGenerator.command = [shellDir + "/scripts/matugen-worker.sh", stateDir, shellDir, configDir, syncModeWithPortal, "--run"]
        systemThemeGenerator.running = true
    }

    function generateSystemThemesFromCurrentTheme() {
        const isGreeterMode = (typeof SessionData !== "undefined" && SessionData.isGreeterMode)
        if (!matugenAvailable || isGreeterMode)
            return

        const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode)
        const iconTheme = (typeof SettingsData !== "undefined" && SettingsData.iconTheme) ? SettingsData.iconTheme : "System Default"

        if (currentTheme === dynamic) {
            if (!rawWallpaperPath) {
                return
            }
            const selectedMatugenType = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme) ? SettingsData.matugenScheme : "scheme-tonal-spot"
            if (rawWallpaperPath.startsWith("#")) {
                setDesiredTheme("hex", rawWallpaperPath, isLight, iconTheme, selectedMatugenType)
            } else {
                setDesiredTheme("image", rawWallpaperPath, isLight, iconTheme, selectedMatugenType)
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
        Proc.runCommand("gtkApplier", [shellDir + "/scripts/gtk.sh", configDir, isLight, shellDir], (output, exitCode) => {
                            if (exitCode === 0) {
                                if (typeof ToastService !== "undefined" && typeof NiriService !== "undefined" && !NiriService.matugenSuppression) {
                                    ToastService.showInfo("GTK colors applied successfully")
                                }
                            } else {
                                if (typeof ToastService !== "undefined") {
                                    ToastService.showError("Failed to apply GTK colors")
                                }
                            }
                        })
    }

    function applyQtColors() {
        if (!matugenAvailable) {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("matugen not available or disabled - cannot apply Qt colors")
            }
            return
        }

        Proc.runCommand("qtApplier", [shellDir + "/scripts/qt.sh", configDir], (output, exitCode) => {
                            if (exitCode === 0) {
                                if (typeof ToastService !== "undefined") {
                                    ToastService.showInfo("Qt colors applied successfully")
                                }
                            } else {
                                if (typeof ToastService !== "undefined") {
                                    ToastService.showError("Failed to apply Qt colors")
                                }
                            }
                        })
    }

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function getFillMode(modeName) {
        switch (modeName) {
        case "Stretch":
            return Image.Stretch
        case "Fit":
        case "PreserveAspectFit":
            return Image.PreserveAspectFit
        case "Fill":
        case "PreserveAspectCrop":
            return Image.PreserveAspectCrop
        case "Tile":
            return Image.Tile
        case "TileVertically":
            return Image.TileVertically
        case "TileHorizontally":
            return Image.TileHorizontally
        case "Pad":
            return Image.Pad
        default:
            return Image.PreserveAspectCrop
        }
    }

    function snap(value, dpr) {
        const s = dpr || 1
        return Math.round(value * s) / s
    }

    function px(value, dpr) {
        const s = dpr || 1
        return Math.round(value * s) / s
    }

    function hairline(dpr) {
        return 1 / (dpr || 1)
    }

    function invertHex(hex) {
        hex = hex.replace('#', '')

        if (!/^[0-9A-Fa-f]{6}$/.test(hex)) {
            return hex
        }

        const r = parseInt(hex.substr(0, 2), 16)
        const g = parseInt(hex.substr(2, 2), 16)
        const b = parseInt(hex.substr(4, 2), 16)

        const invR = (255 - r).toString(16).padStart(2, '0')
        const invG = (255 - g).toString(16).padStart(2, '0')
        const invB = (255 - b).toString(16).padStart(2, '0')

        return `#${invR}${invG}${invB}`
    }

    property string baseLogoColor: {
        if (typeof SettingsData === "undefined")
        return ""
        const colorOverride = SettingsData.launcherLogoColorOverride
        if (!colorOverride || colorOverride === "")
        return ""
        if (colorOverride === "primary")
        return primary
        if (colorOverride === "surface")
        return surfaceText
        return colorOverride
    }

    property string effectiveLogoColor: {
        if (typeof SettingsData === "undefined")
        return ""

        const colorOverride = SettingsData.launcherLogoColorOverride
        if (!colorOverride || colorOverride === "")
        return ""

        if (colorOverride === "primary")
        return primary
        if (colorOverride === "surface")
        return surfaceText

        if (!SettingsData.launcherLogoColorInvertOnMode) {
            return colorOverride
        }

        if (isLightMode) {
            return invertHex(colorOverride)
        }

        return colorOverride
    }

    Process {
        id: systemThemeGenerator
        running: false

        onExited: exitCode => {
            workerRunning = false

            if (exitCode === 0) {
                console.info("Theme: Matugen worker completed successfully")
                if (currentTheme === dynamic) {
                    console.log("Theme: Reloading dynamic colors file")
                    dynamicColorsFileView.reload()
                }
            } else if (exitCode === 2) {
                console.log("Theme: Matugen worker completed with code 2 (no changes needed)")
            } else {
                if (typeof ToastService !== "undefined") {
                    ToastService.showError("Theme worker failed (" + exitCode + ")")
                }
                console.warn("Theme: Matugen worker failed with exit code:", exitCode)
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
            const colorsPath = SessionData.isGreeterMode ? greetCfgDir + "/colors.json" : stateDir + "/dms-colors.json"
            return colorsPath
        }
        watchChanges: currentTheme === dynamic && !SessionData.isGreeterMode

        function parseAndLoadColors() {
            try {
                const colorsText = dynamicColorsFileView.text()
                if (colorsText) {
                    root.matugenColors = JSON.parse(colorsText)
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
                console.info("Theme: Dynamic colors file loaded successfully")
                colorsFileLoadFailed = false
                parseAndLoadColors()
            }
        }

        onFileChanged: {
            if (currentTheme === dynamic) {
                dynamicColorsFileView.reload()
            }
        }

        onLoadFailed: function (error) {
            if (currentTheme === dynamic) {
                console.warn("Theme: Dynamic colors file load failed, marking for regeneration")
                colorsFileLoadFailed = true
                const isGreeterMode = (typeof SessionData !== "undefined" && SessionData.isGreeterMode)
                if (!isGreeterMode && matugenAvailable && rawWallpaperPath) {
                    console.log("Theme: Matugen available, triggering immediate regeneration")
                    generateSystemThemesFromCurrentTheme()
                }
            }
        }

        onPathChanged: {
            colorsFileLoadFailed = false
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
