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
    property var recentlyUsedApps: []
    
    
    Component.onCompleted: loadSettings()
    
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
            console.log("Settings file content:", content)
            if (content && content.trim()) {
                var settings = JSON.parse(content)
                themeIndex = settings.themeIndex !== undefined ? settings.themeIndex : 0
                themeIsDynamic = settings.themeIsDynamic !== undefined ? settings.themeIsDynamic : false
                isLightMode = settings.isLightMode !== undefined ? settings.isLightMode : false
                topBarTransparency = settings.topBarTransparency !== undefined ? 
                    (settings.topBarTransparency > 1 ? settings.topBarTransparency / 100.0 : settings.topBarTransparency) : 0.75
                recentlyUsedApps = settings.recentlyUsedApps || []
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
            recentlyUsedApps
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
    
    function addRecentApp(app) {
        var existingIndex = -1
        for (var i = 0; i < recentlyUsedApps.length; i++) {
            if (recentlyUsedApps[i].exec === app.exec) {
                existingIndex = i
                break
            }
        }
        
        if (existingIndex >= 0) {
            recentlyUsedApps.splice(existingIndex, 1)
        }
        
        recentlyUsedApps.unshift(app)
        
        if (recentlyUsedApps.length > 10) {
            recentlyUsedApps = recentlyUsedApps.slice(0, 10)
        }
        
        saveSettings()
    }
    
    function getRecentApps() {
        return recentlyUsedApps
    }
}