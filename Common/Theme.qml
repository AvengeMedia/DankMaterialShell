pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Services
import "StockThemes.js" as StockThemes

Singleton {
    id: root

    property string currentTheme: "blue"
    property bool isLightMode: false

    readonly property string dynamic: "dynamic"

    readonly property string homeDir: {
        const url = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString()
        return url.startsWith("file://") ? url.substring(7) : url
    }
    readonly property string configDir: {
        const url = StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString()
        return url.startsWith("file://") ? url.substring(7) : url
    }
    readonly property string shellDir: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Common/", "")
    readonly property string wallpaperPath: {
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
    property bool extractionRequested: false
    property int colorUpdateTrigger: 0
    property var customThemeData: null

    readonly property string stateDir: {
        const cacheHome = StandardPaths.writableLocation(StandardPaths.CacheLocation).toString()
        const path = cacheHome.startsWith("file://") ? cacheHome.substring(7) : cacheHome
        return path + "/dankshell"
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
                "error": "#F2B8B5",
                "warning": "#FF9800",
                "info": "#2196F3",
                "success": "#4CAF50"
            }
        } else {
            return StockThemes.getThemeByName(currentTheme, isLightMode)
        }
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
    property color surfaceContainer: currentThemeData.surfaceContainer
    property color surfaceContainerHigh: currentThemeData.surfaceContainerHigh

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

    property color shadowMedium: Qt.rgba(0, 0, 0, 0.08)
    property color shadowStrong: Qt.rgba(0, 0, 0, 0.3)

    property int shorterDuration: 100
    property int shortDuration: 150
    property int mediumDuration: 300
    property int longDuration: 500
    property int extraLongDuration: 1000
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
    property real widgetTransparency: typeof SettingsData !== "undefined" && SettingsData.topBarWidgetTransparency !== undefined ? SettingsData.topBarWidgetTransparency : 0.85
    property real popupTransparency: typeof SettingsData !== "undefined" && SettingsData.popupTransparency !== undefined ? SettingsData.popupTransparency : 0.92

    function switchTheme(themeName, savePrefs = true) {
        if (themeName === dynamic) {
            currentTheme = dynamic
            extractColors()
        } else if (themeName === "custom") {
            currentTheme = "custom"
            if (typeof SettingsData !== "undefined" && SettingsData.customThemeFile) {
                loadCustomThemeFromFile(SettingsData.customThemeFile)
            }
        } else {
            currentTheme = themeName
        }
        if (savePrefs && typeof SettingsData !== "undefined")
            SettingsData.setTheme(currentTheme)

        generateSystemThemesFromCurrentTheme()
    }

    function setLightMode(light, savePrefs = true) {
        isLightMode = light
        if (savePrefs && typeof SessionData !== "undefined")
            SessionData.setLightMode(isLightMode)
        PortalService.setLightMode(isLightMode)
        generateSystemThemesFromCurrentTheme()
    }

    function toggleLightMode(savePrefs = true) {
        setLightMode(!isLightMode, savePrefs)
    }

    function forceGenerateSystemThemes() {
        if (!matugenAvailable) {
            if (typeof ToastService !== "undefined") {
                ToastService.showWarning("matugen not available - cannot generate system themes")
            }
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

    function widgetBackground() {
        return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, widgetTransparency)
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

    function extractColors() {
        extractionRequested = true
        if (matugenAvailable)
            fileChecker.running = true
        else
            matugenCheck.running = true
    }

    function onLightModeChanged() {
        if (matugenColors && Object.keys(matugenColors).length > 0) {
            colorUpdateTrigger++
        }

        if (currentTheme === "custom" && customThemeFileView.path) {
            customThemeFileView.reload()
        }

        generateSystemThemesFromCurrentTheme()
    }

    function setDesiredTheme(kind, value, isLight, iconTheme) {
        if (!matugenAvailable) {
            console.warn("matugen not available - cannot set system theme")
            return
        }

        const desired = {
            "kind": kind,
            "value": value,
            "mode": isLight ? "light" : "dark",
            "iconTheme": iconTheme || "System Default"
        }

        const json = JSON.stringify(desired)
        const desiredPath = stateDir + "/matugen.desired.json"

        Quickshell.execDetached(["sh", "-c", `mkdir -p '${stateDir}' && cat > '${desiredPath}' << 'EOF'\n${json}\nEOF`])
        workerRunning = true
        systemThemeGenerator.command = [shellDir + "/scripts/matugen-worker.sh", stateDir, shellDir, "--run"]
        systemThemeGenerator.running = true
    }

    function generateSystemThemesFromCurrentTheme() {
        if (!matugenAvailable)
            return

        const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode)
        const iconTheme = (typeof SettingsData !== "undefined" && SettingsData.iconTheme) ? SettingsData.iconTheme : "System Default"

        if (currentTheme === dynamic) {
            if (!wallpaperPath) {
                return
            }
            if (wallpaperPath.startsWith("#")) {
                setDesiredTheme("hex", wallpaperPath, isLight, iconTheme)
            } else {
                setDesiredTheme("image", wallpaperPath, isLight, iconTheme)
            }
        } else {
            let primaryColor
            if (currentTheme === "custom") {
                if (!customThemeData || !customThemeData.primary) {
                    console.warn("Custom theme data not available for system theme generation")
                    return
                }
                primaryColor = customThemeData.primary
            } else {
                primaryColor = currentThemeData.primary
            }

            if (!primaryColor) {
                console.warn("No primary color available for theme:", currentTheme)
                return
            }
            setDesiredTheme("hex", primaryColor, isLight, iconTheme)
        }
    }

    function applyGtkColors() {
        if (!matugenAvailable) {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("matugen not available - cannot apply GTK colors")
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
                ToastService.showError("matugen not available - cannot apply Qt colors")
            }
            return
        }

        qtApplier.command = [shellDir + "/scripts/qt.sh", configDir]
        qtApplier.running = true
    }

    function extractJsonFromText(text) {
        if (!text)
            return null

        const start = text.search(/[{\[]/)
        if (start === -1)
            return null

        const open = text[start]
        const pairs = {
            "{": '}',
            "[": ']'
        }
        const close = pairs[open]
        if (!close)
            return null

        let inString = false
        let escape = false
        const stack = [open]

        for (var i = start + 1; i < text.length; i++) {
            const ch = text[i]

            if (inString) {
                if (escape) {
                    escape = false
                } else if (ch === '\\') {
                    escape = true
                } else if (ch === '"') {
                    inString = false
                }
                continue
            }

            if (ch === '"') {
                inString = true
                continue
            }
            if (ch === '{' || ch === '[') {
                stack.push(ch)
                continue
            }
            if (ch === '}' || ch === ']') {
                const last = stack.pop()
                if (!last || pairs[last] !== ch) {
                    return null
                }
                if (stack.length === 0) {
                    return text.slice(start, i + 1)
                }
            }
        }
        return null
    }

    Process {
        id: matugenCheck
        command: ["which", "matugen"]
        onExited: code => {
            matugenAvailable = (code === 0)
            if (!matugenAvailable) {
                if (typeof ToastService !== "undefined") {
                    ToastService.wallpaperErrorStatus = "matugen_missing"
                    ToastService.showWarning("matugen not found - dynamic theming disabled")
                }
                return
            }
            if (extractionRequested) {
                fileChecker.running = true
            }

            const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode)
            const iconTheme = (typeof SettingsData !== "undefined" && SettingsData.iconTheme) ? SettingsData.iconTheme : "System Default"

            if (currentTheme === dynamic) {
                if (wallpaperPath) {
                    Quickshell.execDetached(["rm", "-f", stateDir + "/matugen.key"])
                    if (wallpaperPath.startsWith("#")) {
                        setDesiredTheme("hex", wallpaperPath, isLight, iconTheme)
                    } else {
                        setDesiredTheme("image", wallpaperPath, isLight, iconTheme)
                    }
                }
            } else {
                let primaryColor
                if (currentTheme === "custom") {
                    if (customThemeData && customThemeData.primary) {
                        primaryColor = customThemeData.primary
                    }
                } else {
                    primaryColor = currentThemeData.primary
                }

                if (primaryColor) {
                    Quickshell.execDetached(["rm", "-f", stateDir + "/matugen.key"])
                    setDesiredTheme("hex", primaryColor, isLight, iconTheme)
                }
            }
        }
    }

    Process {
        id: fileChecker
        command: ["test", "-r", wallpaperPath]
        onExited: code => {
            if (code === 0) {
                matugenProcess.running = true
            } else if (wallpaperPath.startsWith("#")) {
                colorMatugenProcess.running = true
            }
        }
    }

    Process {
        id: matugenProcess
        command: ["matugen", "image", wallpaperPath, "--json", "hex"]

        stdout: StdioCollector {
            id: matugenCollector
            onStreamFinished: {
                if (!matugenCollector.text) {
                    if (typeof ToastService !== "undefined") {
                        ToastService.wallpaperErrorStatus = "error"
                        ToastService.showError("Wallpaper Processing Failed: Empty JSON extracted from matugen output.")
                    }
                    return
                }
                const extractedJson = extractJsonFromText(matugenCollector.text)
                if (!extractedJson) {
                    if (typeof ToastService !== "undefined") {
                        ToastService.wallpaperErrorStatus = "error"
                        ToastService.showError("Wallpaper Processing Failed: Invalid JSON extracted from matugen output.")
                    }
                    console.log("Raw matugen output:", matugenCollector.text)
                    return
                }
                try {
                    root.matugenColors = JSON.parse(extractedJson)
                    root.colorUpdateTrigger++
                    if (typeof ToastService !== "undefined") {
                        ToastService.clearWallpaperError()
                    }
                } catch (e) {
                    if (typeof ToastService !== "undefined") {
                        ToastService.wallpaperErrorStatus = "error"
                        ToastService.showError("Wallpaper processing failed (JSON parse error after extraction)")
                    }
                }
            }
        }

        onExited: code => {
            if (code !== 0) {
                if (typeof ToastService !== "undefined") {
                    ToastService.wallpaperErrorStatus = "error"
                    ToastService.showError("Matugen command failed with exit code " + code)
                }
            }
        }
    }

    Process {
        id: colorMatugenProcess
        command: ["matugen", "color", "hex", wallpaperPath, "--json", "hex"]

        stdout: StdioCollector {
            id: colorMatugenCollector
            onStreamFinished: {
                if (!colorMatugenCollector.text) {
                    if (typeof ToastService !== "undefined") {
                        ToastService.wallpaperErrorStatus = "error"
                        ToastService.showError("Color Processing Failed: Empty JSON extracted from matugen output.")
                    }
                    return
                }
                const extractedJson = extractJsonFromText(colorMatugenCollector.text)
                if (!extractedJson) {
                    if (typeof ToastService !== "undefined") {
                        ToastService.wallpaperErrorStatus = "error"
                        ToastService.showError("Color Processing Failed: Invalid JSON extracted from matugen output.")
                    }
                    console.log("Raw matugen output:", colorMatugenCollector.text)
                    return
                }
                try {
                    root.matugenColors = JSON.parse(extractedJson)
                    root.colorUpdateTrigger++
                    if (typeof ToastService !== "undefined") {
                        ToastService.clearWallpaperError()
                    }
                } catch (e) {
                    if (typeof ToastService !== "undefined") {
                        ToastService.wallpaperErrorStatus = "error"
                        ToastService.showError("Color processing failed (JSON parse error after extraction)")
                    }
                }
            }
        }

        onExited: code => {
            if (code !== 0) {
                if (typeof ToastService !== "undefined") {
                    ToastService.wallpaperErrorStatus = "error"
                    ToastService.showError("Matugen color command failed with exit code " + code)
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

            if (exitCode === 2) {
                // Exit code 2 means wallpaper/color not found - this is expected on first run
                console.log("Theme worker: wallpaper/color not found, skipping theme generation")
            } else if (exitCode !== 0) {
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
                if (typeof ToastService !== "undefined") {
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

    Component.onCompleted: {
        matugenCheck.running = true
        if (typeof SessionData !== "undefined")
        SessionData.isLightModeChanged.connect(root.onLightModeChanged)
        
        if (typeof SettingsData !== "undefined" && SettingsData.currentThemeName) {
            switchTheme(SettingsData.currentThemeName, false)
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

    IpcHandler {
        target: "theme"

        function toggle(): string {
            root.toggleLightMode()
            return root.isLightMode ? "light" : "dark"
        }

        function light(): string {
            root.setLightMode(true)
            return "light"
        }

        function dark(): string {
            root.setLightMode(false)
            return "dark"
        }

        function getMode(): string {
            return root.isLightMode ? "light" : "dark"
        }
    }
}
