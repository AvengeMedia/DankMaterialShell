pragma Singleton
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    
    property int themeIndex: 0
    property bool themeIsDynamic: false
    property bool isLightMode: false
    property real topBarTransparency: 0.75
    property real popupTransparency: 0.92
    property var recentlyUsedApps: []
    
    // New global preferences
    property bool use24HourClock: true
    property bool useFahrenheit: false
    property bool nightModeEnabled: false
    property string profileImage: ""
    property string weatherLocationOverride: "New York, NY"
    
    // Widget visibility preferences for TopBar
    property bool showFocusedWindow: true
    property bool showWeather: true  
    property bool showMusic: true
    property bool showClipboard: true
    property bool showSystemResources: true
    property bool showSystemTray: true
    
    // View mode preferences for launchers
    property string appLauncherViewMode: "list"
    property string spotlightLauncherViewMode: "list"
    
    
    Component.onCompleted: loadSettings()
    
    // Monitor system resources preference changes to control service monitoring
    onShowSystemResourcesChanged: {
        console.log("Prefs: System resources monitoring", showSystemResources ? "enabled" : "disabled")
        // Control SystemMonitorService based on whether system monitor widgets are visible
        if (typeof SystemMonitorService !== 'undefined') {
            SystemMonitorService.enableTopBarMonitoring(showSystemResources)
        }
    }
    
    FileView {
        id: settingsFile
        path: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/DankMaterialShell/settings.json"
        blockLoading: true
        blockWrites: true
        watchChanges: true
        
        onLoaded: {
            console.log("Settings file loaded successfully")
            parseSettings(settingsFile.text())
        }
        
        onLoadFailed: (error) => {
            console.log("Settings file not found, using defaults. Error:", error)
            applyStoredTheme()
        }
    }
    
    function loadSettings() {
        parseSettings(settingsFile.text())
    }
    
    function parseSettings(content) {
        try {
            if (content && content.trim()) {
                var settings = JSON.parse(content)
                themeIndex = settings.themeIndex !== undefined ? settings.themeIndex : 0
                themeIsDynamic = settings.themeIsDynamic !== undefined ? settings.themeIsDynamic : false
                isLightMode = settings.isLightMode !== undefined ? settings.isLightMode : false
                topBarTransparency = settings.topBarTransparency !== undefined ? 
                    (settings.topBarTransparency > 1 ? settings.topBarTransparency / 100.0 : settings.topBarTransparency) : 0.75
                popupTransparency = settings.popupTransparency !== undefined ? 
                    (settings.popupTransparency > 1 ? settings.popupTransparency / 100.0 : settings.popupTransparency) : 0.92
                recentlyUsedApps = settings.recentlyUsedApps || []
                use24HourClock = settings.use24HourClock !== undefined ? settings.use24HourClock : true
                useFahrenheit = settings.useFahrenheit !== undefined ? settings.useFahrenheit : false
                nightModeEnabled = settings.nightModeEnabled !== undefined ? settings.nightModeEnabled : false
                profileImage = settings.profileImage !== undefined ? settings.profileImage : ""
                weatherLocationOverride = settings.weatherLocationOverride !== undefined ? settings.weatherLocationOverride : "New York, NY"
                showFocusedWindow = settings.showFocusedWindow !== undefined ? settings.showFocusedWindow : true
                showWeather = settings.showWeather !== undefined ? settings.showWeather : true
                showMusic = settings.showMusic !== undefined ? settings.showMusic : true
                showClipboard = settings.showClipboard !== undefined ? settings.showClipboard : true
                showSystemResources = settings.showSystemResources !== undefined ? settings.showSystemResources : true
                showSystemTray = settings.showSystemTray !== undefined ? settings.showSystemTray : true
                appLauncherViewMode = settings.appLauncherViewMode !== undefined ? settings.appLauncherViewMode : "list"
                spotlightLauncherViewMode = settings.spotlightLauncherViewMode !== undefined ? settings.spotlightLauncherViewMode : "list"
                console.log("Loaded settings - themeIndex:", themeIndex, "isDynamic:", themeIsDynamic, "lightMode:", isLightMode, "transparency:", topBarTransparency, "recentApps:", recentlyUsedApps.length)
                
                applyStoredTheme()
            } else {
                console.log("Settings file is empty - applying default theme")
                applyStoredTheme()
            }
        } catch (e) {
            console.log("Could not parse settings, using defaults:", e)
            applyStoredTheme()
        }
    }
    
    function saveSettings() {
        settingsFile.setText(JSON.stringify({
            themeIndex,
            themeIsDynamic,
            isLightMode,
            topBarTransparency,
            popupTransparency,
            recentlyUsedApps,
            use24HourClock,
            useFahrenheit,
            nightModeEnabled,
            profileImage,
            weatherLocationOverride,
            showFocusedWindow,
            showWeather,
            showMusic,
            showClipboard,
            showSystemResources,
            showSystemTray,
            appLauncherViewMode,
            spotlightLauncherViewMode
        }, null, 2))
        console.log("Saving settings - themeIndex:", themeIndex, "isDynamic:", themeIsDynamic, "lightMode:", isLightMode, "transparency:", topBarTransparency, "recentApps:", recentlyUsedApps.length)
    }
    
    function applyStoredTheme() {
        console.log("Applying stored theme:", themeIndex, themeIsDynamic, "lightMode:", isLightMode)
        
        if (typeof Theme !== "undefined") {
            Theme.isLightMode = isLightMode
            Theme.switchTheme(themeIndex, themeIsDynamic, false)
        } else {
            Qt.callLater(() => {
                if (typeof Theme !== "undefined") {
                    Theme.isLightMode = isLightMode
                    Theme.switchTheme(themeIndex, themeIsDynamic, false)
                }
            })
        }
    }
    
    function setTheme(index, isDynamic) {
        console.log("Prefs setTheme called - themeIndex:", index, "isDynamic:", isDynamic)
        themeIndex = index
        themeIsDynamic = isDynamic
        saveSettings()
    }
    
    function setLightMode(lightMode) {
        console.log("Prefs setLightMode called - isLightMode:", lightMode)
        isLightMode = lightMode
        saveSettings()
    }
    
    function setTopBarTransparency(transparency) {
        console.log("Prefs setTopBarTransparency called - topBarTransparency:", transparency)
        topBarTransparency = transparency
        saveSettings()
    }
    
    function setPopupTransparency(transparency) {
        console.log("Prefs setPopupTransparency called - popupTransparency:", transparency)
        popupTransparency = transparency
        saveSettings()
    }
    
    function addRecentApp(app) {
        if (!app) return
        
        var execProp = app.execString || app.exec || ""
        if (!execProp) return
        
        var existingIndex = -1
        for (var i = 0; i < recentlyUsedApps.length; i++) {
            if (recentlyUsedApps[i].exec === execProp) {
                existingIndex = i
                break
            }
        }
        
        if (existingIndex >= 0) {
            // App exists, increment usage count
            recentlyUsedApps[existingIndex].usageCount = (recentlyUsedApps[existingIndex].usageCount || 1) + 1
            recentlyUsedApps[existingIndex].lastUsed = Date.now()
        } else {
            // New app, create entry
            var appData = {
                name: app.name || "",
                exec: execProp,
                icon: app.icon || "application-x-executable",
                comment: app.comment || "",
                usageCount: 1,
                lastUsed: Date.now()
            }
            recentlyUsedApps.push(appData)
        }
        
        // Sort by usage count (descending), then alphabetically by name
        var sortedApps = recentlyUsedApps.sort(function(a, b) {
            if (a.usageCount !== b.usageCount) {
                return b.usageCount - a.usageCount // Higher usage count first
            }
            return a.name.localeCompare(b.name) // Alphabetical tiebreaker
        })
        
        // Limit to 10 apps
        if (sortedApps.length > 10) {
            sortedApps = sortedApps.slice(0, 10)
        }
        
        // Reassign to trigger property change signal
        recentlyUsedApps = sortedApps
        
        saveSettings()
    }
    
    function getRecentApps() {
        return recentlyUsedApps
    }
    
    // New preference setters
    function setClockFormat(use24Hour) {
        console.log("Prefs setClockFormat called - use24HourClock:", use24Hour)
        use24HourClock = use24Hour
        saveSettings()
    }
    
    function setTemperatureUnit(fahrenheit) {
        console.log("Prefs setTemperatureUnit called - useFahrenheit:", fahrenheit)
        useFahrenheit = fahrenheit
        saveSettings()
    }
    
    function setNightModeEnabled(enabled) {
        console.log("Prefs setNightModeEnabled called - nightModeEnabled:", enabled)
        nightModeEnabled = enabled
        saveSettings()
    }
    
    function setProfileImage(imageUrl) {
        console.log("Prefs setProfileImage called - profileImage:", imageUrl)
        profileImage = imageUrl
        saveSettings()
    }
    
    // Widget visibility setters
    function setShowFocusedWindow(enabled) {
        console.log("Prefs setShowFocusedWindow called - showFocusedWindow:", enabled)
        showFocusedWindow = enabled
        saveSettings()
    }
    
    function setShowWeather(enabled) {
        console.log("Prefs setShowWeather called - showWeather:", enabled)
        showWeather = enabled
        saveSettings()
    }
    
    function setShowMusic(enabled) {
        console.log("Prefs setShowMusic called - showMusic:", enabled)
        showMusic = enabled
        saveSettings()
    }
    
    function setShowClipboard(enabled) {
        console.log("Prefs setShowClipboard called - showClipboard:", enabled)
        showClipboard = enabled
        saveSettings()
    }
    
    function setShowSystemResources(enabled) {
        console.log("Prefs setShowSystemResources called - showSystemResources:", enabled)
        showSystemResources = enabled
        saveSettings()
    }
    
    function setShowSystemTray(enabled) {
        console.log("Prefs setShowSystemTray called - showSystemTray:", enabled)
        showSystemTray = enabled
        saveSettings()
    }
    
    // View mode setters
    function setAppLauncherViewMode(mode) {
        console.log("Prefs setAppLauncherViewMode called - appLauncherViewMode:", mode)
        appLauncherViewMode = mode
        saveSettings()
    }
    
    function setSpotlightLauncherViewMode(mode) {
        console.log("Prefs setSpotlightLauncherViewMode called - spotlightLauncherViewMode:", mode)
        spotlightLauncherViewMode = mode
        saveSettings()
    }
    
    // Weather location override setter
    function setWeatherLocationOverride(location) {
        console.log("Prefs setWeatherLocationOverride called - weatherLocationOverride:", location)
        weatherLocationOverride = location
        saveSettings()
    }
}