pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {

    id: root

    property bool isLightMode: false
    property string wallpaperPath: ""
    property string wallpaperLastPath: ""
    property string profileLastPath: ""
    property bool perMonitorWallpaper: false
    property var monitorWallpapers: ({})
    property bool doNotDisturb: false
    property bool nightModeEnabled: false
    property int nightModeTemperature: 4500
    property bool nightModeAutoEnabled: false
    property string nightModeAutoMode: "time"
    
    property bool hasTriedDefaultSession: false
    readonly property string _stateUrl: StandardPaths.writableLocation(StandardPaths.GenericStateLocation)
    readonly property string _stateDir: _stateUrl.startsWith("file://") ? _stateUrl.substring(7) : _stateUrl
    property int nightModeStartHour: 18
    property int nightModeStartMinute: 0
    property int nightModeEndHour: 6
    property int nightModeEndMinute: 0
    property real latitude: 0.0
    property real longitude: 0.0
    property string nightModeLocationProvider: ""
    property var pinnedApps: []
    property int selectedGpuIndex: 0
    property bool nvidiaGpuTempEnabled: false
    property bool nonNvidiaGpuTempEnabled: false
    property var enabledGpuPciIds: []
    property bool wallpaperCyclingEnabled: false
    property string wallpaperCyclingMode: "interval" // "interval" or "time"
    property int wallpaperCyclingInterval: 300 // seconds (5 minutes)
    property string wallpaperCyclingTime: "06:00" // HH:mm format
    property string lastBrightnessDevice: ""
    property string notepadContent: ""
    property string notepadCurrentFileName: ""
    property string notepadCurrentFileUrl: ""
    property string notepadLastSavedContent: ""

    Component.onCompleted: {
        loadSettings()
    }

    function loadSettings() {
        parseSettings(settingsFile.text())
    }

    function parseSettings(content) {
        try {
            if (content && content.trim()) {
                var settings = JSON.parse(content)
                isLightMode = settings.isLightMode !== undefined ? settings.isLightMode : false
                wallpaperPath = settings.wallpaperPath !== undefined ? settings.wallpaperPath : ""
                wallpaperLastPath = settings.wallpaperLastPath !== undefined ? settings.wallpaperLastPath : ""
                profileLastPath = settings.profileLastPath !== undefined ? settings.profileLastPath : ""
                perMonitorWallpaper = settings.perMonitorWallpaper !== undefined ? settings.perMonitorWallpaper : false
                monitorWallpapers = settings.monitorWallpapers !== undefined ? settings.monitorWallpapers : {}
                doNotDisturb = settings.doNotDisturb !== undefined ? settings.doNotDisturb : false
                nightModeEnabled = settings.nightModeEnabled !== undefined ? settings.nightModeEnabled : false
                nightModeTemperature = settings.nightModeTemperature !== undefined ? settings.nightModeTemperature : 4500
                nightModeAutoEnabled = settings.nightModeAutoEnabled !== undefined ? settings.nightModeAutoEnabled : false
                nightModeAutoMode = settings.nightModeAutoMode !== undefined ? settings.nightModeAutoMode : "time"
                // Handle legacy time format
                if (settings.nightModeStartTime !== undefined) {
                    const parts = settings.nightModeStartTime.split(":")
                    nightModeStartHour = parseInt(parts[0]) || 18
                    nightModeStartMinute = parseInt(parts[1]) || 0
                } else {
                    nightModeStartHour = settings.nightModeStartHour !== undefined ? settings.nightModeStartHour : 18
                    nightModeStartMinute = settings.nightModeStartMinute !== undefined ? settings.nightModeStartMinute : 0
                }
                if (settings.nightModeEndTime !== undefined) {
                    const parts = settings.nightModeEndTime.split(":")
                    nightModeEndHour = parseInt(parts[0]) || 6
                    nightModeEndMinute = parseInt(parts[1]) || 0
                } else {
                    nightModeEndHour = settings.nightModeEndHour !== undefined ? settings.nightModeEndHour : 6
                    nightModeEndMinute = settings.nightModeEndMinute !== undefined ? settings.nightModeEndMinute : 0
                }
                latitude = settings.latitude !== undefined ? settings.latitude : 0.0
                longitude = settings.longitude !== undefined ? settings.longitude : 0.0
                nightModeLocationProvider = settings.nightModeLocationProvider !== undefined ? settings.nightModeLocationProvider : ""
                pinnedApps = settings.pinnedApps !== undefined ? settings.pinnedApps : []
                selectedGpuIndex = settings.selectedGpuIndex !== undefined ? settings.selectedGpuIndex : 0
                nvidiaGpuTempEnabled = settings.nvidiaGpuTempEnabled !== undefined ? settings.nvidiaGpuTempEnabled : false
                nonNvidiaGpuTempEnabled = settings.nonNvidiaGpuTempEnabled !== undefined ? settings.nonNvidiaGpuTempEnabled : false
                enabledGpuPciIds = settings.enabledGpuPciIds !== undefined ? settings.enabledGpuPciIds : []
                wallpaperCyclingEnabled = settings.wallpaperCyclingEnabled !== undefined ? settings.wallpaperCyclingEnabled : false
                wallpaperCyclingMode = settings.wallpaperCyclingMode !== undefined ? settings.wallpaperCyclingMode : "interval"
                wallpaperCyclingInterval = settings.wallpaperCyclingInterval !== undefined ? settings.wallpaperCyclingInterval : 300
                wallpaperCyclingTime = settings.wallpaperCyclingTime !== undefined ? settings.wallpaperCyclingTime : "06:00"
                lastBrightnessDevice = settings.lastBrightnessDevice !== undefined ? settings.lastBrightnessDevice : ""
                notepadContent = settings.notepadContent !== undefined ? settings.notepadContent : ""
                
                // Generate system themes but don't override user's theme choice
                if (typeof Theme !== "undefined") {
                    Theme.generateSystemThemesFromCurrentTheme()
                }
                notepadCurrentFileName = settings.notepadCurrentFileName !== undefined ? settings.notepadCurrentFileName : ""
                notepadCurrentFileUrl = settings.notepadCurrentFileUrl !== undefined ? settings.notepadCurrentFileUrl : ""
                notepadLastSavedContent = settings.notepadLastSavedContent !== undefined ? settings.notepadLastSavedContent : ""
            }
        } catch (e) {

        }
    }

    function saveSettings() {
        settingsFile.setText(JSON.stringify({
                                                "isLightMode": isLightMode,
                                                "wallpaperPath": wallpaperPath,
                                                "wallpaperLastPath": wallpaperLastPath,
                                                "profileLastPath": profileLastPath,
                                                "perMonitorWallpaper": perMonitorWallpaper,
                                                "monitorWallpapers": monitorWallpapers,
                                                "doNotDisturb": doNotDisturb,
                                                "nightModeEnabled": nightModeEnabled,
                                                "nightModeTemperature": nightModeTemperature,
                                                "nightModeAutoEnabled": nightModeAutoEnabled,
                                                "nightModeAutoMode": nightModeAutoMode,
                                                "nightModeStartHour": nightModeStartHour,
                                                "nightModeStartMinute": nightModeStartMinute,
                                                "nightModeEndHour": nightModeEndHour,
                                                "nightModeEndMinute": nightModeEndMinute,
                                                "latitude": latitude,
                                                "longitude": longitude,
                                                "nightModeLocationProvider": nightModeLocationProvider,
                                                "pinnedApps": pinnedApps,
                                                "selectedGpuIndex": selectedGpuIndex,
                                                "nvidiaGpuTempEnabled": nvidiaGpuTempEnabled,
                                                "nonNvidiaGpuTempEnabled": nonNvidiaGpuTempEnabled,
                                                "enabledGpuPciIds": enabledGpuPciIds,
                                                "wallpaperCyclingEnabled": wallpaperCyclingEnabled,
                                                "wallpaperCyclingMode": wallpaperCyclingMode,
                                                "wallpaperCyclingInterval": wallpaperCyclingInterval,
                                                "wallpaperCyclingTime": wallpaperCyclingTime,
                                                "lastBrightnessDevice": lastBrightnessDevice,
                                                "notepadContent": notepadContent,
                                                "notepadCurrentFileName": notepadCurrentFileName,
                                                "notepadCurrentFileUrl": notepadCurrentFileUrl,
                                                "notepadLastSavedContent": notepadLastSavedContent
                                            }, null, 2))
    }

    function setLightMode(lightMode) {
        isLightMode = lightMode
        saveSettings()
    }

    function setDoNotDisturb(enabled) {
        doNotDisturb = enabled
        saveSettings()
    }

    function setNightModeEnabled(enabled) {
        nightModeEnabled = enabled
        saveSettings()
    }

    function setNightModeTemperature(temperature) {
        nightModeTemperature = temperature
        saveSettings()
    }

    function setNightModeAutoEnabled(enabled) {
        console.log("SessionData: Setting nightModeAutoEnabled to", enabled)
        nightModeAutoEnabled = enabled
        saveSettings()
    }

    function setNightModeAutoMode(mode) {
        nightModeAutoMode = mode
        saveSettings()
    }

    function setNightModeStartHour(hour) {
        nightModeStartHour = hour
        saveSettings()
    }

    function setNightModeStartMinute(minute) {
        nightModeStartMinute = minute
        saveSettings()
    }

    function setNightModeEndHour(hour) {
        nightModeEndHour = hour
        saveSettings()
    }

    function setNightModeEndMinute(minute) {
        nightModeEndMinute = minute
        saveSettings()
    }

    function setLatitude(lat) {
        console.log("SessionData: Setting latitude to", lat)
        latitude = lat
        saveSettings()
    }

    function setLongitude(lng) {
        console.log("SessionData: Setting longitude to", lng)
        longitude = lng
        saveSettings()
    }

    function setNightModeLocationProvider(provider) {
        nightModeLocationProvider = provider
        saveSettings()
    }

    function setWallpaperPath(path) {
        wallpaperPath = path
        saveSettings()
    }

    function setWallpaper(imagePath) {
        wallpaperPath = imagePath
        saveSettings()

        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function setWallpaperColor(color) {
        wallpaperPath = color
        saveSettings()

        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function clearWallpaper() {
        wallpaperPath = ""
        saveSettings()

        if (typeof Theme !== "undefined") {
            if (typeof SettingsData !== "undefined" && SettingsData.theme) {
                Theme.switchTheme(SettingsData.theme)
            } else {
                Theme.switchTheme("blue")
            }
        }
    }

    function setWallpaperLastPath(path) {
        wallpaperLastPath = path
        saveSettings()
    }

    function setProfileLastPath(path) {
        profileLastPath = path
        saveSettings()
    }

    function setPinnedApps(apps) {
        pinnedApps = apps
        saveSettings()
    }

    function addPinnedApp(appId) {
        if (!appId)
            return
        var currentPinned = [...pinnedApps]
        if (currentPinned.indexOf(appId) === -1) {
            currentPinned.push(appId)
            setPinnedApps(currentPinned)
        }
    }

    function removePinnedApp(appId) {
        if (!appId)
            return
        var currentPinned = pinnedApps.filter(id => id !== appId)
        setPinnedApps(currentPinned)
    }

    function isPinnedApp(appId) {
        return appId && pinnedApps.indexOf(appId) !== -1
    }

    function setSelectedGpuIndex(index) {
        selectedGpuIndex = index
        saveSettings()
    }

    function setNvidiaGpuTempEnabled(enabled) {
        nvidiaGpuTempEnabled = enabled
        saveSettings()
    }

    function setNonNvidiaGpuTempEnabled(enabled) {
        nonNvidiaGpuTempEnabled = enabled
        saveSettings()
    }

    function setEnabledGpuPciIds(pciIds) {
        enabledGpuPciIds = pciIds
        saveSettings()
    }

    function setWallpaperCyclingEnabled(enabled) {
        wallpaperCyclingEnabled = enabled
        saveSettings()
    }

    function setWallpaperCyclingMode(mode) {
        wallpaperCyclingMode = mode
        saveSettings()
    }

    function setWallpaperCyclingInterval(interval) {
        wallpaperCyclingInterval = interval
        saveSettings()
    }

    function setWallpaperCyclingTime(time) {
        wallpaperCyclingTime = time
        saveSettings()
    }

    function setPerMonitorWallpaper(enabled) {
        perMonitorWallpaper = enabled
        
        // Disable automatic cycling when per-monitor mode is enabled
        if (enabled && wallpaperCyclingEnabled) {
            wallpaperCyclingEnabled = false
        }
        
        saveSettings()

        // Refresh dynamic theming when per-monitor mode changes
        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function setMonitorWallpaper(screenName, path) {
        var newMonitorWallpapers = Object.assign({}, monitorWallpapers)
        if (path && path !== "") {
            newMonitorWallpapers[screenName] = path
        } else {
            delete newMonitorWallpapers[screenName]
        }
        monitorWallpapers = newMonitorWallpapers
        saveSettings()

        // Trigger dynamic theming if this is the first monitor and dynamic theming is enabled
        if (typeof Theme !== "undefined" && typeof Quickshell !== "undefined") {
            var screens = Quickshell.screens
            if (screens.length > 0 && screenName === screens[0].name) {
                if (typeof SettingsData !== "undefined" && SettingsData.wallpaperDynamicTheming) {
                    Theme.switchTheme("dynamic")
                    Theme.extractColors()
                }
                Theme.generateSystemThemesFromCurrentTheme()
            }
        }
    }

    function getMonitorWallpaper(screenName) {
        if (!perMonitorWallpaper) {
            return wallpaperPath
        }
        return monitorWallpapers[screenName] || wallpaperPath
    }

    function setLastBrightnessDevice(device) {
        lastBrightnessDevice = device
        saveSettings()
    }

    FileView {
        id: settingsFile

        path: StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/DankMaterialShell/session.json"
        blockLoading: true
        blockWrites: true
        watchChanges: true
        onLoaded: {
            parseSettings(settingsFile.text())
            hasTriedDefaultSession = false
        }
        onLoadFailed: error => {
            if (!hasTriedDefaultSession) {
                hasTriedDefaultSession = true
                defaultSessionCheckProcess.running = true
            }
        }
    }

    Process {
        id: defaultSessionCheckProcess

        command: ["sh", "-c", "CONFIG_DIR=\"" + _stateDir
            + "/DankMaterialShell\"; if [ -f \"$CONFIG_DIR/default-session.json\" ] && [ ! -f \"$CONFIG_DIR/session.json\" ]; then cp \"$CONFIG_DIR/default-session.json\" \"$CONFIG_DIR/session.json\" && echo 'copied'; else echo 'not_found'; fi"]
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("Copied default-session.json to session.json")
                settingsFile.reload()
            }
        }
    }

    IpcHandler {
        target: "wallpaper"

        function get(): string {
            if (root.perMonitorWallpaper) {
                return "ERROR: Per-monitor mode enabled. Use getFor(screenName) instead."
            }
            return root.wallpaperPath || ""
        }

        function set(path: string): string {
            if (root.perMonitorWallpaper) {
                return "ERROR: Per-monitor mode enabled. Use setFor(screenName, path) instead."
            }

            if (!path) {
                return "ERROR: No path provided"
            }

            var absolutePath = path.startsWith("/") ? path : StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/" + path

            try {
                root.setWallpaper(absolutePath)
                return "SUCCESS: Wallpaper set to " + absolutePath
            } catch (e) {
                return "ERROR: Failed to set wallpaper: " + e.toString()
            }
        }

        function clear(): string {
            root.setWallpaper("")
            root.setPerMonitorWallpaper(false)
            root.monitorWallpapers = {}
            root.saveSettings()
            return "SUCCESS: All wallpapers cleared"
        }

        function next(): string {
            if (root.perMonitorWallpaper) {
                return "ERROR: Per-monitor mode enabled. Use nextFor(screenName) instead."
            }

            if (!root.wallpaperPath) {
                return "ERROR: No wallpaper set"
            }

            try {
                WallpaperCyclingService.cycleNextManually()
                return "SUCCESS: Cycling to next wallpaper"
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper: " + e.toString()
            }
        }

        function prev(): string {
            if (root.perMonitorWallpaper) {
                return "ERROR: Per-monitor mode enabled. Use prevFor(screenName) instead."
            }

            if (!root.wallpaperPath) {
                return "ERROR: No wallpaper set"
            }

            try {
                WallpaperCyclingService.cyclePrevManually()
                return "SUCCESS: Cycling to previous wallpaper"
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper: " + e.toString()
            }
        }

        function getFor(screenName: string): string {
            if (!screenName) {
                return "ERROR: No screen name provided"
            }
            return root.getMonitorWallpaper(screenName) || ""
        }

        function setFor(screenName: string, path: string): string {
            if (!screenName) {
                return "ERROR: No screen name provided"
            }

            if (!path) {
                return "ERROR: No path provided"
            }

            var absolutePath = path.startsWith("/") ? path : StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/" + path

            try {
                if (!root.perMonitorWallpaper) {
                    root.setPerMonitorWallpaper(true)
                }
                root.setMonitorWallpaper(screenName, absolutePath)
                return "SUCCESS: Wallpaper set for " + screenName + " to " + absolutePath
            } catch (e) {
                return "ERROR: Failed to set wallpaper for " + screenName + ": " + e.toString()
            }
        }

        function nextFor(screenName: string): string {
            if (!screenName) {
                return "ERROR: No screen name provided"
            }

            var currentWallpaper = root.getMonitorWallpaper(screenName)
            if (!currentWallpaper) {
                return "ERROR: No wallpaper set for " + screenName
            }

            try {
                WallpaperCyclingService.cycleNextForMonitor(screenName)
                return "SUCCESS: Cycling to next wallpaper for " + screenName
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper for " + screenName + ": " + e.toString()
            }
        }

        function prevFor(screenName: string): string {
            if (!screenName) {
                return "ERROR: No screen name provided"
            }

            var currentWallpaper = root.getMonitorWallpaper(screenName)
            if (!currentWallpaper) {
                return "ERROR: No wallpaper set for " + screenName
            }

            try {
                WallpaperCyclingService.cyclePrevForMonitor(screenName)
                return "SUCCESS: Cycling to previous wallpaper for " + screenName
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper for " + screenName + ": " + e.toString()
            }
        }
    }
}
