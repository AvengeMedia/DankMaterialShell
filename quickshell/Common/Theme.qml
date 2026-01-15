pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Greetd
import "StockThemes.js" as StockThemes

Singleton {
    id: root

    readonly property string stateDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericCacheLocation).toString()) + "/DankMaterialShell"
    readonly property bool envDisableMatugen: Quickshell.env("DMS_DISABLE_MATUGEN") === "1" || Quickshell.env("DMS_DISABLE_MATUGEN") === "true"
    readonly property string defaultFontFamily: "Inter Variable"
    readonly property string defaultMonoFontFamily: "Fira Code"

    readonly property real popupDistance: {
        if (typeof SettingsData === "undefined")
            return 4;
        const defaultBar = SettingsData.barConfigs[0] || SettingsData.getBarConfig("default");
        if (!defaultBar)
            return 4;
        const useAuto = defaultBar.popupGapsAuto ?? true;
        const manualValue = defaultBar.popupGapsManual ?? 4;
        const spacing = defaultBar.spacing ?? 4;
        return useAuto ? Math.max(4, spacing) : manualValue;
    }

    property string currentTheme: "purple"
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
            return "";

        if (SessionData.perMonitorWallpaper) {
            var screens = Quickshell.screens;
            if (screens.length > 0) {
                var firstMonitorWallpaper = SessionData.getMonitorWallpaper(screens[0].name);
                return firstMonitorWallpaper || SessionData.wallpaperPath;
            }
        }

        return SessionData.wallpaperPath;
    }
    readonly property string rawWallpaperPath: {
        if (typeof SessionData === "undefined")
            return "";

        if (SessionData.perMonitorWallpaper) {
            var screens = Quickshell.screens;
            if (screens.length > 0) {
                var targetMonitor = (typeof SettingsData !== "undefined" && SettingsData.matugenTargetMonitor && SettingsData.matugenTargetMonitor !== "") ? SettingsData.matugenTargetMonitor : screens[0].name;

                var targetMonitorExists = false;
                for (var i = 0; i < screens.length; i++) {
                    if (screens[i].name === targetMonitor) {
                        targetMonitorExists = true;
                        break;
                    }
                }

                if (!targetMonitorExists) {
                    targetMonitor = screens[0].name;
                }

                var targetMonitorWallpaper = SessionData.getMonitorWallpaper(targetMonitor);
                return targetMonitorWallpaper || SessionData.wallpaperPath;
            }
        }

        return SessionData.wallpaperPath;
    }

    property bool matugenAvailable: false
    property bool gtkThemingEnabled: typeof SettingsData !== "undefined" ? SettingsData.gtkAvailable : false
    property bool qtThemingEnabled: typeof SettingsData !== "undefined" ? (SettingsData.qt5ctAvailable || SettingsData.qt6ctAvailable) : false
    property var workerRunning: false
    property var pendingThemeRequest: null

    signal matugenCompleted(string mode, string result)
    property var matugenColors: ({})
    property var _pendingGenerateParams: null

    readonly property var dank16: {
        const raw = matugenColors?.dank16;
        if (!raw)
            return null;

        const dark = {};
        const light = {};
        const def = {};

        for (let i = 0; i < 16; i++) {
            const key = "color" + i;
            const c = raw[key];
            if (!c)
                continue;
            dark[key] = c.dark;
            light[key] = c.light;
            def[key] = c.default;
        }

        return {
            dark,
            light,
            "default": def
        };
    }
    property var customThemeData: null
    property var customThemeRawData: null
    readonly property var currentThemeVariants: customThemeRawData?.variants || null
    readonly property string currentThemeId: customThemeRawData?.id || ""

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir]);
        Proc.runCommand("matugenCheck", ["which", "matugen"], (output, code) => {
            matugenAvailable = (code === 0) && !envDisableMatugen;
            const isGreeterMode = (typeof SessionData !== "undefined" && SessionData.isGreeterMode);

            if (!matugenAvailable || isGreeterMode) {
                return;
            }

            if (colorsFileLoadFailed && currentTheme === dynamic && rawWallpaperPath) {
                console.info("Theme: Matugen now available, regenerating colors for dynamic theme");
                const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode);
                const iconTheme = (typeof SettingsData !== "undefined" && SettingsData.iconTheme) ? SettingsData.iconTheme : "System Default";
                const selectedMatugenType = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme) ? SettingsData.matugenScheme : "scheme-tonal-spot";
                if (rawWallpaperPath.startsWith("#")) {
                    setDesiredTheme("hex", rawWallpaperPath, isLight, iconTheme, selectedMatugenType);
                } else {
                    setDesiredTheme("image", rawWallpaperPath, isLight, iconTheme, selectedMatugenType);
                }
                return;
            }

            const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode);
            const iconTheme = (typeof SettingsData !== "undefined" && SettingsData.iconTheme) ? SettingsData.iconTheme : "System Default";

            if (currentTheme === dynamic) {
                if (rawWallpaperPath) {
                    const selectedMatugenType = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme) ? SettingsData.matugenScheme : "scheme-tonal-spot";
                    if (rawWallpaperPath.startsWith("#")) {
                        setDesiredTheme("hex", rawWallpaperPath, isLight, iconTheme, selectedMatugenType);
                    } else {
                        setDesiredTheme("image", rawWallpaperPath, isLight, iconTheme, selectedMatugenType);
                    }
                }
            } else if (currentTheme !== "custom") {
                const darkTheme = StockThemes.getThemeByName(currentTheme, false);
                const lightTheme = StockThemes.getThemeByName(currentTheme, true);
                if (darkTheme && darkTheme.primary) {
                    const stockColors = buildMatugenColorsFromTheme(darkTheme, lightTheme);
                    const themeData = isLight ? lightTheme : darkTheme;
                    setDesiredTheme("hex", themeData.primary, isLight, iconTheme, themeData.matugen_type, stockColors);
                }
            }
        }, 0);
        if (typeof SessionData !== "undefined") {
            SessionData.isLightModeChanged.connect(root.onLightModeChanged);
        }

        if (typeof SettingsData !== "undefined" && SettingsData.currentThemeName) {
            switchTheme(SettingsData.currentThemeName, false, false);
        }
    }

    function applyGreeterTheme(themeName) {
        switchTheme(themeName, false, false);
        if (themeName === dynamic && dynamicColorsFileView.path) {
            dynamicColorsFileView.reload();
        }
    }

    function getMatugenColor(path, fallback) {
        const colorMode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark";
        let cur = matugenColors && matugenColors.colors && matugenColors.colors[colorMode];
        for (const part of path.split(".")) {
            if (!cur || typeof cur !== "object" || !(part in cur))
                return fallback;
            cur = cur[part];
        }
        return cur || fallback;
    }

    readonly property var currentThemeData: {
        if (currentTheme === "custom") {
            return customThemeData || StockThemes.getThemeByName("purple", isLightMode);
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
            };
        } else {
            return StockThemes.getThemeByName(currentTheme, isLightMode);
        }
    }

    readonly property var availableMatugenSchemes: [({
                "value": "scheme-tonal-spot",
                "label": "Tonal Spot",
                "description": I18n.tr("Balanced palette with focused accents (default).")
            }), ({
                "value": "scheme-vibrant",
                "label": "Vibrant",
                "description": I18n.tr("Lively palette with saturated accents.")
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
        const schemes = availableMatugenSchemes;
        for (var i = 0; i < schemes.length; i++) {
            if (schemes[i].value === value)
                return schemes[i];
        }
        return schemes[0];
    }

    property color primary: currentThemeData.primary
    property color primaryText: currentThemeData.primaryText
    property color primaryContainer: currentThemeData.primaryContainer
    property color secondary: currentThemeData.secondary
    property color surface: currentThemeData.surface
    property color surfaceText: currentThemeData.surfaceText
    property color surfaceVariant: currentThemeData.surfaceVariant
    property color surfaceVariantText: currentThemeData.surfaceVariantText
    property color surfaceTint: currentThemeData.surfaceTint
    property color background: currentThemeData.background
    property color backgroundText: currentThemeData.backgroundText
    property color outline: currentThemeData.outline
    property color outlineVariant: currentThemeData.outlineVariant || Qt.rgba(outline.r, outline.g, outline.b, 0.6)
    property color surfaceContainer: currentThemeData.surfaceContainer
    property color surfaceContainerHigh: currentThemeData.surfaceContainerHigh
    property color surfaceContainerHighest: currentThemeData.surfaceContainerHighest || surfaceContainerHigh

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
        {
            "shorter": 0,
            "short": 0,
            "medium": 0,
            "long": 0,
            "extraLong": 0
        },
        {
            "shorter": 50,
            "short": 75,
            "medium": 150,
            "long": 250,
            "extraLong": 500
        },
        {
            "shorter": 100,
            "short": 150,
            "medium": 300,
            "long": 500,
            "extraLong": 1000
        },
        {
            "shorter": 150,
            "short": 225,
            "medium": 450,
            "long": 750,
            "extraLong": 1500
        },
        {
            "shorter": 200,
            "short": 300,
            "medium": 600,
            "long": 1000,
            "extraLong": 2000
        }
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
            return 500;

        if (SettingsData.animationSpeed === SettingsData.AnimationSpeed.Custom) {
            return SettingsData.customAnimationDuration;
        }

        const presetMap = [0, 250, 500, 750];
        return presetMap[SettingsData.animationSpeed] !== undefined ? presetMap[SettingsData.animationSpeed] : 500;
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
            };
        }

        const baseDuration = currentAnimationBaseDuration;
        return {
            "fast": baseDuration * 0.4,
            "normal": baseDuration * 0.8,
            "large": baseDuration * 1.2,
            "extraLarge": baseDuration * 2.0,
            "expressiveFastSpatial": baseDuration * 0.7,
            "expressiveDefaultSpatial": baseDuration,
            "expressiveEffects": baseDuration * 0.4
        };
    }

    property real cornerRadius: {
        if (typeof SessionData !== "undefined" && SessionData.isGreeterMode && typeof GreetdSettings !== "undefined") {
            return GreetdSettings.cornerRadius;
        }
        return typeof SettingsData !== "undefined" ? SettingsData.cornerRadius : 12;
    }

    property string fontFamily: {
        if (typeof SessionData !== "undefined" && SessionData.isGreeterMode && typeof GreetdSettings !== "undefined") {
            return GreetdSettings.fontFamily;
        }
        return typeof SettingsData !== "undefined" ? SettingsData.fontFamily : "Inter Variable";
    }

    property string monoFontFamily: {
        if (typeof SessionData !== "undefined" && SessionData.isGreeterMode && typeof GreetdSettings !== "undefined") {
            return GreetdSettings.monoFontFamily;
        }
        return typeof SettingsData !== "undefined" ? SettingsData.monoFontFamily : "Fira Code";
    }

    property int fontWeight: {
        if (typeof SessionData !== "undefined" && SessionData.isGreeterMode && typeof GreetdSettings !== "undefined") {
            return GreetdSettings.fontWeight;
        }
        return typeof SettingsData !== "undefined" ? SettingsData.fontWeight : Font.Normal;
    }

    property real fontScale: {
        if (typeof SessionData !== "undefined" && SessionData.isGreeterMode && typeof GreetdSettings !== "undefined") {
            return GreetdSettings.fontScale;
        }
        return typeof SettingsData !== "undefined" ? SettingsData.fontScale : 1.0;
    }

    property real spacingXS: 4
    property real spacingS: 8
    property real spacingM: 12
    property real spacingL: 16
    property real spacingXL: 24
    property real fontSizeSmall: Math.round(fontScale * 12)
    property real fontSizeMedium: Math.round(fontScale * 14)
    property real fontSizeLarge: Math.round(fontScale * 16)
    property real fontSizeXLarge: Math.round(fontScale * 20)
    property real barHeight: 48
    property real iconSize: 24
    property real iconSizeSmall: 16
    property real iconSizeLarge: 32

    property real panelTransparency: 0.85
    property real popupTransparency: typeof SettingsData !== "undefined" && SettingsData.popupTransparency !== undefined ? SettingsData.popupTransparency : 1.0

    function screenTransition() {
        CompositorService.isNiri && NiriService.doScreenTransition();
    }

    function switchTheme(themeName, savePrefs = true, enableTransition = true) {
        if (enableTransition) {
            screenTransition();
            themeTransitionTimer.themeName = themeName;
            themeTransitionTimer.savePrefs = savePrefs;
            themeTransitionTimer.restart();
            return;
        }

        if (themeName === dynamic) {
            currentTheme = dynamic;
            if (currentThemeCategory !== "registry")
                currentThemeCategory = dynamic;
        } else if (themeName === custom) {
            currentTheme = custom;
            if (currentThemeCategory !== "registry")
                currentThemeCategory = custom;
            if (typeof SettingsData !== "undefined" && SettingsData.customThemeFile) {
                loadCustomThemeFromFile(SettingsData.customThemeFile);
            }
        } else if (themeName === "" && currentThemeCategory === "registry") {
            // Registry category selected but no theme chosen yet
        } else {
            currentTheme = themeName;
            if (currentThemeCategory !== "registry") {
                currentThemeCategory = "generic";
            }
        }
        const isGreeterMode = (typeof SessionData !== "undefined" && SessionData.isGreeterMode);
        if (savePrefs && typeof SettingsData !== "undefined" && !isGreeterMode) {
            SettingsData.set("currentThemeCategory", currentThemeCategory);
            SettingsData.set("currentThemeName", currentTheme);
        }

        if (!isGreeterMode) {
            generateSystemThemesFromCurrentTheme();
        }
    }

    function setLightMode(light, savePrefs = true, enableTransition = false) {
        if (enableTransition) {
            screenTransition();
            lightModeTransitionTimer.lightMode = light;
            lightModeTransitionTimer.savePrefs = savePrefs;
            lightModeTransitionTimer.restart();
            return;
        }

        const isGreeterMode = (typeof SessionData !== "undefined" && SessionData.isGreeterMode);
        if (savePrefs && typeof SessionData !== "undefined" && !isGreeterMode)
            SessionData.setLightMode(light);
        if (!isGreeterMode) {
            // Skip with matugen because, our script runner will do it.
            if (!matugenAvailable) {
                PortalService.setLightMode(light);
            }
            generateSystemThemesFromCurrentTheme();
        }
    }

    function toggleLightMode(savePrefs = true) {
        setLightMode(!isLightMode, savePrefs, true);
    }

    function forceGenerateSystemThemes() {
        if (!matugenAvailable) {
            return;
        }
        generateSystemThemesFromCurrentTheme();
    }

    function getAvailableThemes() {
        return StockThemes.getAllThemeNames();
    }

    function getThemeDisplayName(themeName) {
        const themeData = StockThemes.getThemeByName(themeName, isLightMode);
        return themeData.name;
    }

    function getThemeColors(themeName) {
        if (themeName === "custom" && customThemeData) {
            return customThemeData;
        }
        return StockThemes.getThemeByName(themeName, isLightMode);
    }

    function switchThemeCategory(category, defaultTheme) {
        screenTransition();
        themeCategoryTransitionTimer.category = category;
        themeCategoryTransitionTimer.defaultTheme = defaultTheme;
        themeCategoryTransitionTimer.restart();
    }

    function loadCustomTheme(themeData) {
        customThemeRawData = themeData;
        const colorMode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark";

        var baseColors = {};
        if (themeData.dark || themeData.light) {
            baseColors = themeData[colorMode] || themeData.dark || themeData.light || {};
        } else {
            baseColors = themeData;
        }

        if (themeData.variants) {
            const themeId = themeData.id || "";

            if (themeData.variants.type === "multi" && themeData.variants.flavors && themeData.variants.accents) {
                const defaults = themeData.variants.defaults || {};
                const modeDefaults = defaults[colorMode] || defaults.dark || {};
                const stored = typeof SettingsData !== "undefined" ? SettingsData.getRegistryThemeMultiVariant(themeId, modeDefaults) : modeDefaults;
                var flavorId = stored.flavor || modeDefaults.flavor || "";
                const accentId = stored.accent || modeDefaults.accent || "";
                var flavor = findVariant(themeData.variants.flavors, flavorId);
                if (flavor) {
                    const hasCurrentModeColors = flavor[colorMode] && (flavor[colorMode].primary || flavor[colorMode].surface);
                    if (!hasCurrentModeColors) {
                        flavorId = modeDefaults.flavor || "";
                        flavor = findVariant(themeData.variants.flavors, flavorId);
                    }
                }
                const accent = findAccent(themeData.variants.accents, accentId);
                if (flavor) {
                    const flavorColors = flavor[colorMode] || flavor.dark || flavor.light || {};
                    baseColors = mergeColors(baseColors, flavorColors);
                }
                if (accent && flavor) {
                    const accentColors = accent[flavor.id] || {};
                    baseColors = mergeColors(baseColors, accentColors);
                }
                customThemeData = baseColors;
                generateSystemThemesFromCurrentTheme();
                return;
            }

            if (themeData.variants.options && themeData.variants.options.length > 0) {
                const selectedVariantId = typeof SettingsData !== "undefined" ? SettingsData.getRegistryThemeVariant(themeId, themeData.variants.default) : themeData.variants.default;
                const variant = findVariant(themeData.variants.options, selectedVariantId);
                if (variant) {
                    const variantColors = variant[colorMode] || variant.dark || variant.light || {};
                    customThemeData = mergeColors(baseColors, variantColors);
                    generateSystemThemesFromCurrentTheme();
                    return;
                }
            }
        }

        customThemeData = baseColors;
        generateSystemThemesFromCurrentTheme();
    }

    function findVariant(options, variantId) {
        if (!variantId || !options)
            return null;
        for (var i = 0; i < options.length; i++) {
            if (options[i].id === variantId)
                return options[i];
        }
        return options[0] || null;
    }

    function findAccent(accents, accentId) {
        if (!accentId || !accents)
            return null;
        for (var i = 0; i < accents.length; i++) {
            if (accents[i].id === accentId)
                return accents[i];
        }
        return accents[0] || null;
    }

    function mergeColors(base, overlay) {
        var result = JSON.parse(JSON.stringify(base));
        for (var key in overlay) {
            if (overlay[key])
                result[key] = overlay[key];
        }
        return result;
    }

    function loadCustomThemeFromFile(filePath) {
        customThemeFileView.path = filePath;
    }

    function reloadCustomThemeVariant() {
        if (currentTheme !== "custom" || !customThemeRawData)
            return;
        loadCustomTheme(customThemeRawData);
    }

    property alias availableThemeNames: root._availableThemeNames
    readonly property var _availableThemeNames: StockThemes.getAllThemeNames()
    property string currentThemeName: currentTheme

    function panelBackground() {
        return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, panelTransparency);
    }

    property real notepadTransparency: SettingsData.notepadTransparencyOverride >= 0 ? SettingsData.notepadTransparencyOverride : popupTransparency

    property bool widgetBackgroundHasAlpha: {
        const colorMode = typeof SettingsData !== "undefined" ? SettingsData.widgetBackgroundColor : "sch";
        return colorMode === "sth";
    }

    property var widgetBaseBackgroundColor: {
        const colorMode = typeof SettingsData !== "undefined" ? SettingsData.widgetBackgroundColor : "sch";
        switch (colorMode) {
        case "s":
            return surface;
        case "sc":
            return surfaceContainer;
        case "sch":
            return surfaceContainerHigh;
        case "sth":
        default:
            return surfaceTextHover;
        }
    }

    property color widgetBaseHoverColor: {
        const blended = blend(widgetBaseBackgroundColor, primary, 0.1);
        return withAlpha(blended, Math.max(0.3, blended.a));
    }

    property color widgetIconColor: {
        if (typeof SettingsData === "undefined") {
            return surfaceText;
        }

        switch (SettingsData.widgetColorMode) {
        case "colorful":
            return surfaceText;
        case "default":
        default:
            return surfaceText;
        }
    }

    property color widgetTextColor: {
        if (typeof SettingsData === "undefined") {
            return surfaceText;
        }

        switch (SettingsData.widgetColorMode) {
        case "colorful":
            return primary;
        case "default":
        default:
            return surfaceText;
        }
    }

    function isColorDark(c) {
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) < 0.5;
    }

    function barIconSize(barThickness, offset) {
        const defaultOffset = offset !== undefined ? offset : -6;
        return Math.round((barThickness / 48) * (iconSize + defaultOffset));
    }

    function barTextSize(barThickness, fontScale) {
        const scale = barThickness / 48;
        const dankBarScale = fontScale !== undefined ? fontScale : 1.0;
        if (scale <= 0.75)
            return Math.round(fontSizeSmall * 0.9 * dankBarScale);
        if (scale >= 1.25)
            return Math.round(fontSizeMedium * dankBarScale);
        return Math.round(fontSizeSmall * dankBarScale);
    }

    function getBatteryIcon(level, isCharging, batteryAvailable) {
        if (!batteryAvailable)
            return "battery_std";

        if (isCharging) {
            if (level >= 90)
                return "battery_charging_full";
            if (level >= 80)
                return "battery_charging_90";
            if (level >= 60)
                return "battery_charging_80";
            if (level >= 50)
                return "battery_charging_60";
            if (level >= 30)
                return "battery_charging_50";
            if (level >= 20)
                return "battery_charging_30";
            return "battery_charging_20";
        } else {
            if (level >= 95)
                return "battery_full";
            if (level >= 85)
                return "battery_6_bar";
            if (level >= 70)
                return "battery_5_bar";
            if (level >= 55)
                return "battery_4_bar";
            if (level >= 40)
                return "battery_3_bar";
            if (level >= 25)
                return "battery_2_bar";
            if (level >= 10)
                return "battery_1_bar";
            return "battery_alert";
        }
    }

    function getPowerProfileIcon(profile) {
        switch (profile) {
        case 0:
            return "battery_saver";
        case 1:
            return "battery_std";
        case 2:
            return "flash_on";
        default:
            return "settings";
        }
    }

    function getPowerProfileLabel(profile) {
        switch (profile) {
        case 0:
            return "Power Saver";
        case 1:
            return "Balanced";
        case 2:
            return "Performance";
        default:
            return "Unknown";
        }
    }

    function getPowerProfileDescription(profile) {
        switch (profile) {
        case 0:
            return "Extend battery life";
        case 1:
            return "Balance power and performance";
        case 2:
            return "Prioritize performance";
        default:
            return "Custom power profile";
        }
    }

    function onLightModeChanged() {
        if (currentTheme === "custom" && customThemeFileView.path) {
            customThemeFileView.reload();
        }
    }

    function setDesiredTheme(kind, value, isLight, iconTheme, matugenType, stockColors) {
        if (!matugenAvailable) {
            console.warn("Theme: matugen not available or disabled - cannot set system theme");
            return;
        }

        if (workerRunning) {
            console.info("Theme: Worker already running, queueing request");
            pendingThemeRequest = {
                kind,
                value,
                isLight,
                iconTheme,
                matugenType,
                stockColors
            };
            return;
        }

        console.info("Theme: Setting desired theme -", kind, "mode:", isLight ? "light" : "dark", stockColors ? "(stock colors)" : "(dynamic)");

        if (typeof NiriService !== "undefined" && CompositorService.isNiri) {
            NiriService.suppressNextToast();
        }

        const desired = {
            "kind": kind,
            "value": value,
            "mode": isLight ? "light" : "dark",
            "iconTheme": iconTheme || "System Default",
            "matugenType": matugenType || "scheme-tonal-spot",
            "runUserTemplates": (typeof SettingsData !== "undefined") ? SettingsData.runUserMatugenTemplates : true
        };

        console.log("Theme: Starting matugen worker");
        workerRunning = true;

        const args = ["dms", "matugen", "queue", "--state-dir", stateDir, "--shell-dir", shellDir, "--config-dir", configDir, "--kind", desired.kind, "--value", desired.value, "--mode", desired.mode, "--icon-theme", desired.iconTheme, "--matugen-type", desired.matugenType,];

        if (!desired.runUserTemplates) {
            args.push("--run-user-templates=false");
        }
        if (stockColors) {
            args.push("--stock-colors", JSON.stringify(stockColors));
        }
        if (typeof SettingsData !== "undefined" && SettingsData.syncModeWithPortal) {
            args.push("--sync-mode-with-portal");
        }
        if (typeof SettingsData !== "undefined" && SettingsData.terminalsAlwaysDark) {
            args.push("--terminals-always-dark");
        }

        if (typeof SettingsData !== "undefined") {
            const skipTemplates = [];
            if (!SettingsData.runDmsMatugenTemplates) {
                skipTemplates.push("gtk", "nvim", "niri", "qt5ct", "qt6ct", "firefox", "pywalfox", "zenbrowser", "vesktop", "equibop", "ghostty", "kitty", "foot", "alacritty", "wezterm", "dgop", "kcolorscheme", "vscode");
            } else {
                if (!SettingsData.matugenTemplateGtk)
                    skipTemplates.push("gtk");
                if (!SettingsData.matugenTemplateNiri)
                    skipTemplates.push("niri");
                if (!SettingsData.matugenTemplateHyprland)
                    skipTemplates.push("hyprland");
                if (!SettingsData.matugenTemplateMangowc)
                    skipTemplates.push("mangowc");
                if (!SettingsData.matugenTemplateQt5ct)
                    skipTemplates.push("qt5ct");
                if (!SettingsData.matugenTemplateQt6ct)
                    skipTemplates.push("qt6ct");
                if (!SettingsData.matugenTemplateFirefox)
                    skipTemplates.push("firefox");
                if (!SettingsData.matugenTemplatePywalfox)
                    skipTemplates.push("pywalfox");
                if (!SettingsData.matugenTemplateZenBrowser)
                    skipTemplates.push("zenbrowser");
                if (!SettingsData.matugenTemplateVesktop)
                    skipTemplates.push("vesktop");
                if (!SettingsData.matugenTemplateEquibop)
                    skipTemplates.push("equibop");
                if (!SettingsData.matugenTemplateGhostty)
                    skipTemplates.push("ghostty");
                if (!SettingsData.matugenTemplateKitty)
                    skipTemplates.push("kitty");
                if (!SettingsData.matugenTemplateFoot)
                    skipTemplates.push("foot");
                if (!SettingsData.matugenTemplateNeovim)
                    skipTemplates.push("nvim");
                if (!SettingsData.matugenTemplateAlacritty)
                    skipTemplates.push("alacritty");
                if (!SettingsData.matugenTemplateWezterm)
                    skipTemplates.push("wezterm");
                if (!SettingsData.matugenTemplateDgop)
                    skipTemplates.push("dgop");
                if (!SettingsData.matugenTemplateKcolorscheme)
                    skipTemplates.push("kcolorscheme");
                if (!SettingsData.matugenTemplateVscode)
                    skipTemplates.push("vscode");
            }
            if (skipTemplates.length > 0) {
                args.push("--skip-templates", skipTemplates.join(","));
            }
        }

        systemThemeGenerator.command = args;
        systemThemeGenerator.running = true;
    }

    function generateSystemThemesFromCurrentTheme() {
        const isGreeterMode = (typeof SessionData !== "undefined" && SessionData.isGreeterMode);
        if (!matugenAvailable || isGreeterMode)
            return;

        _pendingGenerateParams = true;
        _themeGenerateDebounce.restart();
    }

    function _executeThemeGeneration() {
        if (!_pendingGenerateParams)
            return;
        _pendingGenerateParams = null;

        const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode);
        const iconTheme = (typeof SettingsData !== "undefined" && SettingsData.iconTheme) ? SettingsData.iconTheme : "System Default";

        if (currentTheme === dynamic) {
            if (!rawWallpaperPath)
                return;
            const selectedMatugenType = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme) ? SettingsData.matugenScheme : "scheme-tonal-spot";
            const kind = rawWallpaperPath.startsWith("#") ? "hex" : "image";
            setDesiredTheme(kind, rawWallpaperPath, isLight, iconTheme, selectedMatugenType, null);
            return;
        }

        let darkTheme, lightTheme;
        if (currentTheme === "custom") {
            if (customThemeRawData && (customThemeRawData.dark || customThemeRawData.light)) {
                darkTheme = customThemeRawData.dark || customThemeRawData.light;
                lightTheme = customThemeRawData.light || customThemeRawData.dark;

                if (customThemeRawData.variants) {
                    const themeId = customThemeRawData.id || "";

                    if (customThemeRawData.variants.type === "multi" && customThemeRawData.variants.flavors && customThemeRawData.variants.accents) {
                        const defaults = customThemeRawData.variants.defaults || {};
                        const darkDefaults = defaults.dark || {};
                        const lightDefaults = defaults.light || defaults.dark || {};
                        const storedDark = typeof SettingsData !== "undefined" ? SettingsData.getRegistryThemeMultiVariant(themeId, darkDefaults) : darkDefaults;
                        const storedLight = typeof SettingsData !== "undefined" ? SettingsData.getRegistryThemeMultiVariant(themeId, lightDefaults) : lightDefaults;
                        const darkFlavorId = storedDark.flavor || darkDefaults.flavor || "";
                        const lightFlavorId = storedLight.flavor || lightDefaults.flavor || "";
                        const accentId = storedDark.accent || darkDefaults.accent || "";
                        const darkFlavor = findVariant(customThemeRawData.variants.flavors, darkFlavorId);
                        const lightFlavor = findVariant(customThemeRawData.variants.flavors, lightFlavorId);
                        const accent = findAccent(customThemeRawData.variants.accents, accentId);
                        if (darkFlavor) {
                            darkTheme = mergeColors(darkTheme, darkFlavor.dark || {});
                            if (accent)
                                darkTheme = mergeColors(darkTheme, accent[darkFlavor.id] || {});
                        }
                        if (lightFlavor) {
                            lightTheme = mergeColors(lightTheme, lightFlavor.light || {});
                            if (accent)
                                lightTheme = mergeColors(lightTheme, accent[lightFlavor.id] || {});
                        }
                    } else if (customThemeRawData.variants.options) {
                        const selectedVariantId = typeof SettingsData !== "undefined" ? SettingsData.getRegistryThemeVariant(themeId, customThemeRawData.variants.default) : customThemeRawData.variants.default;
                        const variant = findVariant(customThemeRawData.variants.options, selectedVariantId);
                        if (variant) {
                            darkTheme = mergeColors(darkTheme, variant.dark || {});
                            lightTheme = mergeColors(lightTheme, variant.light || {});
                        }
                    }
                }
            } else {
                darkTheme = customThemeData;
                lightTheme = customThemeData;
            }
        } else {
            darkTheme = StockThemes.getThemeByName(currentTheme, false);
            lightTheme = StockThemes.getThemeByName(currentTheme, true);
        }

        if (!darkTheme || !darkTheme.primary) {
            console.warn("Theme data not available for:", currentTheme);
            return;
        }

        const stockColors = buildMatugenColorsFromTheme(darkTheme, lightTheme);
        const themeData = isLight ? lightTheme : darkTheme;
        setDesiredTheme("hex", themeData.primary, isLight, iconTheme, themeData.matugen_type, stockColors);
    }

    function buildMatugenColorsFromTheme(darkTheme, lightTheme) {
        const colors = {};
        const isLight = SessionData !== "undefined" && SessionData.isLightMode;

        function addColor(matugenKey, darkVal, lightVal) {
            if (!darkVal && !lightVal)
                return;
            colors[matugenKey] = {
                "dark": {
                    "color": String(darkVal || lightVal)
                },
                "light": {
                    "color": String(lightVal || darkVal)
                },
                "default": {
                    "color": String((isLight && lightVal) ? lightVal : darkVal)
                }
            };
        }

        function get(theme, key, fallback) {
            return theme[key] || fallback;
        }

        addColor("primary", darkTheme.primary, lightTheme.primary);
        addColor("on_primary", darkTheme.primaryText, lightTheme.primaryText);
        addColor("primary_container", darkTheme.primaryContainer, lightTheme.primaryContainer);
        addColor("on_primary_container", darkTheme.primaryContainerText || darkTheme.surfaceText, lightTheme.primaryContainerText || lightTheme.surfaceText);
        addColor("secondary", darkTheme.secondary, lightTheme.secondary);
        addColor("on_secondary", darkTheme.secondaryText || darkTheme.primaryText, lightTheme.secondaryText || lightTheme.primaryText);
        addColor("secondary_container", darkTheme.secondaryContainer || darkTheme.surfaceContainerHigh, lightTheme.secondaryContainer || lightTheme.surfaceContainerHigh);
        addColor("on_secondary_container", darkTheme.secondaryContainerText || darkTheme.surfaceText, lightTheme.secondaryContainerText || lightTheme.surfaceText);
        addColor("tertiary", darkTheme.tertiary || darkTheme.secondary, lightTheme.tertiary || lightTheme.secondary);
        addColor("on_tertiary", darkTheme.tertiaryText || darkTheme.secondaryText || darkTheme.primaryText, lightTheme.tertiaryText || lightTheme.secondaryText || lightTheme.primaryText);
        addColor("tertiary_container", darkTheme.tertiaryContainer || darkTheme.secondaryContainer || darkTheme.surfaceContainerHigh, lightTheme.tertiaryContainer || lightTheme.secondaryContainer || lightTheme.surfaceContainerHigh);
        addColor("on_tertiary_container", darkTheme.tertiaryContainerText || darkTheme.surfaceText, lightTheme.tertiaryContainerText || lightTheme.surfaceText);
        addColor("error", darkTheme.error || "#F2B8B5", lightTheme.error || "#B3261E");
        addColor("on_error", darkTheme.errorText || "#601410", lightTheme.errorText || "#FFFFFF");
        addColor("error_container", darkTheme.errorContainer || "#8C1D18", lightTheme.errorContainer || "#F9DEDC");
        addColor("on_error_container", darkTheme.errorContainerText || "#F9DEDC", lightTheme.errorContainerText || "#410E0B");
        addColor("surface", darkTheme.surface, lightTheme.surface);
        addColor("on_surface", darkTheme.surfaceText, lightTheme.surfaceText);
        addColor("surface_variant", darkTheme.surfaceVariant, lightTheme.surfaceVariant);
        addColor("on_surface_variant", darkTheme.surfaceVariantText, lightTheme.surfaceVariantText);
        addColor("surface_tint", darkTheme.surfaceTint, lightTheme.surfaceTint);
        addColor("background", darkTheme.background, lightTheme.background);
        addColor("on_background", darkTheme.backgroundText, lightTheme.backgroundText);
        addColor("outline", darkTheme.outline, lightTheme.outline);
        addColor("outline_variant", darkTheme.outlineVariant || darkTheme.surfaceVariant, lightTheme.outlineVariant || lightTheme.surfaceVariant);
        addColor("surface_container", darkTheme.surfaceContainer, lightTheme.surfaceContainer);
        addColor("surface_container_high", darkTheme.surfaceContainerHigh, lightTheme.surfaceContainerHigh);
        addColor("surface_container_highest", darkTheme.surfaceContainerHighest || darkTheme.surfaceContainerHigh, lightTheme.surfaceContainerHighest || lightTheme.surfaceContainerHigh);
        addColor("surface_container_low", darkTheme.surfaceContainerLow || darkTheme.surface, lightTheme.surfaceContainerLow || lightTheme.surface);
        addColor("surface_container_lowest", darkTheme.surfaceContainerLowest || darkTheme.background, lightTheme.surfaceContainerLowest || lightTheme.background);
        addColor("surface_bright", darkTheme.surfaceBright || darkTheme.surfaceContainerHighest || darkTheme.surfaceContainerHigh, lightTheme.surfaceBright || lightTheme.surface);
        addColor("surface_dim", darkTheme.surfaceDim || darkTheme.background, lightTheme.surfaceDim || lightTheme.surfaceContainer);
        addColor("inverse_surface", darkTheme.inverseSurface || lightTheme.surface, lightTheme.inverseSurface || darkTheme.surface);
        addColor("inverse_on_surface", darkTheme.inverseOnSurface || lightTheme.surfaceText, lightTheme.inverseOnSurface || darkTheme.surfaceText);
        addColor("inverse_primary", darkTheme.inversePrimary || lightTheme.primary, lightTheme.inversePrimary || darkTheme.primary);
        addColor("scrim", darkTheme.scrim || "#000000", lightTheme.scrim || "#000000");
        addColor("shadow", darkTheme.shadow || "#000000", lightTheme.shadow || "#000000");
        addColor("source_color", darkTheme.primary, lightTheme.primary);
        addColor("primary_fixed", darkTheme.primaryFixed || darkTheme.primaryContainer, lightTheme.primaryFixed || lightTheme.primaryContainer);
        addColor("primary_fixed_dim", darkTheme.primaryFixedDim || darkTheme.primary, lightTheme.primaryFixedDim || lightTheme.primary);
        addColor("on_primary_fixed", darkTheme.onPrimaryFixed || darkTheme.primaryText, lightTheme.onPrimaryFixed || lightTheme.primaryText);
        addColor("on_primary_fixed_variant", darkTheme.onPrimaryFixedVariant || darkTheme.primaryText, lightTheme.onPrimaryFixedVariant || lightTheme.primaryText);
        addColor("secondary_fixed", darkTheme.secondaryFixed || darkTheme.secondary, lightTheme.secondaryFixed || lightTheme.secondary);
        addColor("secondary_fixed_dim", darkTheme.secondaryFixedDim || darkTheme.secondary, lightTheme.secondaryFixedDim || lightTheme.secondary);
        addColor("on_secondary_fixed", darkTheme.onSecondaryFixed || darkTheme.primaryText, lightTheme.onSecondaryFixed || lightTheme.primaryText);
        addColor("on_secondary_fixed_variant", darkTheme.onSecondaryFixedVariant || darkTheme.primaryText, lightTheme.onSecondaryFixedVariant || lightTheme.primaryText);
        addColor("tertiary_fixed", darkTheme.tertiaryFixed || darkTheme.tertiary || darkTheme.secondary, lightTheme.tertiaryFixed || lightTheme.tertiary || lightTheme.secondary);
        addColor("tertiary_fixed_dim", darkTheme.tertiaryFixedDim || darkTheme.tertiary || darkTheme.secondary, lightTheme.tertiaryFixedDim || lightTheme.tertiary || lightTheme.secondary);
        addColor("on_tertiary_fixed", darkTheme.onTertiaryFixed || darkTheme.primaryText, lightTheme.onTertiaryFixed || lightTheme.primaryText);
        addColor("on_tertiary_fixed_variant", darkTheme.onTertiaryFixedVariant || darkTheme.primaryText, lightTheme.onTertiaryFixedVariant || lightTheme.primaryText);

        return colors;
    }

    function applyGtkColors() {
        if (!matugenAvailable) {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("matugen not available or disabled - cannot apply GTK colors");
            }
            return;
        }

        const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "true" : "false";
        Proc.runCommand("gtkApplier", [shellDir + "/scripts/gtk.sh", configDir, isLight, shellDir], (output, exitCode) => {
            if (exitCode === 0) {
                if (typeof ToastService !== "undefined" && typeof NiriService !== "undefined" && !NiriService.matugenSuppression) {
                    ToastService.showInfo("GTK colors applied successfully");
                }
            } else {
                if (typeof ToastService !== "undefined") {
                    ToastService.showError("Failed to apply GTK colors");
                }
            }
        });
    }

    function applyQtColors() {
        if (!matugenAvailable) {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("matugen not available or disabled - cannot apply Qt colors");
            }
            return;
        }

        Proc.runCommand("qtApplier", [shellDir + "/scripts/qt.sh", configDir], (output, exitCode) => {
            if (exitCode === 0) {
                if (typeof ToastService !== "undefined") {
                    ToastService.showInfo("Qt colors applied successfully");
                }
            } else {
                if (typeof ToastService !== "undefined") {
                    ToastService.showError("Failed to apply Qt colors");
                }
            }
        });
    }

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function blendAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, c.a * a);
    }

    function blend(c1, c2, r) {
        return Qt.rgba(c1.r * (1 - r) + c2.r * r, c1.g * (1 - r) + c2.g * r, c1.b * (1 - r) + c2.b * r, c1.a * (1 - r) + c2.a * r);
    }

    function getFillMode(modeName) {
        switch (modeName) {
        case "Stretch":
            return Image.Stretch;
        case "Fit":
        case "PreserveAspectFit":
            return Image.PreserveAspectFit;
        case "Fill":
        case "PreserveAspectCrop":
            return Image.PreserveAspectCrop;
        case "Tile":
            return Image.Tile;
        case "TileVertically":
            return Image.TileVertically;
        case "TileHorizontally":
            return Image.TileHorizontally;
        case "Pad":
            return Image.Pad;
        default:
            return Image.PreserveAspectCrop;
        }
    }

    function snap(value, dpr) {
        const s = dpr || 1;
        return Math.round(value * s) / s;
    }

    function px(value, dpr) {
        const s = dpr || 1;
        return Math.round(value * s) / s;
    }

    function hairline(dpr) {
        return 1 / (dpr || 1);
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
        if (typeof SettingsData === "undefined")
            return "";
        const colorOverride = SettingsData.launcherLogoColorOverride;
        if (!colorOverride || colorOverride === "")
            return "";
        if (colorOverride === "primary")
            return primary;
        if (colorOverride === "surface")
            return surfaceText;
        return colorOverride;
    }

    property string effectiveLogoColor: {
        if (typeof SettingsData === "undefined")
            return "";

        const colorOverride = SettingsData.launcherLogoColorOverride;
        if (!colorOverride || colorOverride === "")
            return "";

        if (colorOverride === "primary")
            return primary;
        if (colorOverride === "surface")
            return surfaceText;

        if (!SettingsData.launcherLogoColorInvertOnMode) {
            return colorOverride;
        }

        if (isLightMode) {
            return invertHex(colorOverride);
        }

        return colorOverride;
    }

    Process {
        id: systemThemeGenerator
        running: false
        stdout: SplitParser {
            onRead: data => console.info("Theme worker:", data)
        }
        stderr: SplitParser {
            onRead: data => console.warn("Theme worker:", data)
        }

        onExited: exitCode => {
            workerRunning = false;
            const currentMode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark";

            switch (exitCode) {
            case 0:
                console.info("Theme: Matugen worker completed successfully");
                root.matugenCompleted(currentMode, "success");
                break;
            case 2:
                console.log("Theme: Matugen worker completed with code 2 (no changes needed)");
                root.matugenCompleted(currentMode, "no-changes");
                break;
            default:
                if (typeof ToastService !== "undefined") {
                    ToastService.showError("Theme worker failed (" + exitCode + ")");
                }
                console.warn("Theme: Matugen worker failed with exit code:", exitCode);
                root.matugenCompleted(currentMode, "error");
            }

            if (!pendingThemeRequest)
                return;

            const req = pendingThemeRequest;
            pendingThemeRequest = null;
            console.info("Theme: Processing queued theme request");
            setDesiredTheme(req.kind, req.value, req.isLight, req.iconTheme, req.matugenType, req.stockColors);
        }
    }

    FileView {
        id: customThemeFileView
        watchChanges: currentTheme === "custom"

        function parseAndLoadTheme() {
            try {
                var themeData = JSON.parse(customThemeFileView.text());
                loadCustomTheme(themeData);
            } catch (e) {
                ToastService.showError("Invalid JSON format: " + e.message);
            }
        }

        onLoaded: {
            parseAndLoadTheme();
        }

        onFileChanged: {
            customThemeFileView.reload();
        }

        onLoadFailed: function (error) {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("Failed to read theme file: " + error);
            }
        }
    }

    FileView {
        id: dynamicColorsFileView
        path: {
            const greetCfgDir = Quickshell.env("DMS_GREET_CFG_DIR") || "/etc/greetd/.dms";
            const colorsPath = SessionData.isGreeterMode ? greetCfgDir + "/colors.json" : stateDir + "/dms-colors.json";
            return colorsPath;
        }
        watchChanges: !SessionData.isGreeterMode

        function parseAndLoadColors() {
            try {
                const colorsText = dynamicColorsFileView.text();
                if (colorsText) {
                    root.matugenColors = JSON.parse(colorsText);
                    if (typeof ToastService !== "undefined") {
                        ToastService.clearWallpaperError();
                    }
                }
            } catch (e) {
                console.error("Theme: Failed to parse dynamic colors:", e);
                if (typeof ToastService !== "undefined") {
                    ToastService.wallpaperErrorStatus = "error";
                    ToastService.showError("Dynamic colors parse error: " + e.message);
                }
            }
        }

        onLoaded: {
            if (currentTheme === dynamic)
                colorsFileLoadFailed = false;
            parseAndLoadColors();
        }

        onFileChanged: {
            dynamicColorsFileView.reload();
        }

        onLoadFailed: function (error) {
            if (currentTheme === dynamic) {
                console.warn("Theme: Dynamic colors file load failed, marking for regeneration");
                colorsFileLoadFailed = true;
                const isGreeterMode = (typeof SessionData !== "undefined" && SessionData.isGreeterMode);
                if (!isGreeterMode && matugenAvailable && rawWallpaperPath) {
                    console.log("Theme: Matugen available, triggering immediate regeneration");
                    generateSystemThemesFromCurrentTheme();
                }
            }
        }

        onPathChanged: {
            colorsFileLoadFailed = false;
        }
    }

    IpcHandler {
        target: "theme"

        function toggle(): string {
            root.toggleLightMode();
            return root.isLightMode ? "dark" : "light";
        }

        function light(): string {
            root.setLightMode(true, true, true);
            return "light";
        }

        function dark(): string {
            root.setLightMode(false, true, true);
            return "dark";
        }

        function getMode(): string {
            return root.isLightMode ? "light" : "dark";
        }
    }

    Timer {
        id: _themeGenerateDebounce
        interval: 100
        repeat: false
        onTriggered: root._executeThemeGeneration()
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
            root.currentThemeCategory = category;
            root.switchTheme(defaultTheme, true, false);
        }
    }
}
