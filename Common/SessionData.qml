pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {

    id: root

    readonly property bool isGreeterMode: Quickshell.env("DMS_RUN_GREETER") === "1" || Quickshell.env("DMS_RUN_GREETER") === "true"

    property bool isLightMode: false
    property string wallpaperPath: ""
    property string wallpaperLastPath: ""
    property string profileLastPath: ""
    property bool perMonitorWallpaper: false
    property var monitorWallpapers: ({})
    property bool perModeWallpaper: false
    property string wallpaperPathLight: ""
    property string wallpaperPathDark: ""
    property var monitorWallpapersLight: ({})
    property var monitorWallpapersDark: ({})
    property bool doNotDisturb: false
    property bool nightModeEnabled: false
    property int nightModeTemperature: 4500
    property bool nightModeAutoEnabled: false
    property string nightModeAutoMode: "time"
    
    property bool hasTriedDefaultSession: false
    readonly property string _stateUrl: StandardPaths.writableLocation(StandardPaths.GenericStateLocation)
    readonly property string _stateDir: Paths.strip(_stateUrl)
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
    property var monitorCyclingSettings: ({})
    property string lastBrightnessDevice: ""
    property string launchPrefix: ""
    property string wallpaperTransition: "fade"
    readonly property var availableWallpaperTransitions: ["none", "fade", "wipe", "disc", "stripes", "iris bloom", "pixelate", "portal"]
    property var includedTransitions: availableWallpaperTransitions.filter(t => t !== "none")

    // Power management settings - AC Power
    property int acMonitorTimeout: 0 // Never
    property int acLockTimeout: 0 // Never
    property int acSuspendTimeout: 0 // Never
    property int acHibernateTimeout: 0 // Never

    // Power management settings - Battery
    property int batteryMonitorTimeout: 0 // Never
    property int batteryLockTimeout: 0 // Never
    property int batterySuspendTimeout: 0 // Never
    property int batteryHibernateTimeout: 0 // Never

    property bool lockBeforeSuspend: false
    property var recentColors: []
    property bool showThirdPartyPlugins: false


    Component.onCompleted: {
        if (!isGreeterMode) {
            loadSettings()
        }
    }

    function loadSettings() {
        if (isGreeterMode) {
            parseSettings(greeterSessionFile.text())
        } else {
            parseSettings(settingsFile.text())
        }
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
                perModeWallpaper = settings.perModeWallpaper !== undefined ? settings.perModeWallpaper : false
                wallpaperPathLight = settings.wallpaperPathLight !== undefined ? settings.wallpaperPathLight : ""
                wallpaperPathDark = settings.wallpaperPathDark !== undefined ? settings.wallpaperPathDark : ""
                monitorWallpapersLight = settings.monitorWallpapersLight !== undefined ? settings.monitorWallpapersLight : {}
                monitorWallpapersDark = settings.monitorWallpapersDark !== undefined ? settings.monitorWallpapersDark : {}
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
                monitorCyclingSettings = settings.monitorCyclingSettings !== undefined ? settings.monitorCyclingSettings : {}
                lastBrightnessDevice = settings.lastBrightnessDevice !== undefined ? settings.lastBrightnessDevice : ""
                launchPrefix = settings.launchPrefix !== undefined ? settings.launchPrefix : ""
                wallpaperTransition = settings.wallpaperTransition !== undefined ? settings.wallpaperTransition : "fade"
                includedTransitions = settings.includedTransitions !== undefined ? settings.includedTransitions : availableWallpaperTransitions.filter(t => t !== "none")

                acMonitorTimeout = settings.acMonitorTimeout !== undefined ? settings.acMonitorTimeout : 0
                acLockTimeout = settings.acLockTimeout !== undefined ? settings.acLockTimeout : 0
                acSuspendTimeout = settings.acSuspendTimeout !== undefined ? settings.acSuspendTimeout : 0
                acHibernateTimeout = settings.acHibernateTimeout !== undefined ? settings.acHibernateTimeout : 0
                batteryMonitorTimeout = settings.batteryMonitorTimeout !== undefined ? settings.batteryMonitorTimeout : 0
                batteryLockTimeout = settings.batteryLockTimeout !== undefined ? settings.batteryLockTimeout : 0
                batterySuspendTimeout = settings.batterySuspendTimeout !== undefined ? settings.batterySuspendTimeout : 0
                batteryHibernateTimeout = settings.batteryHibernateTimeout !== undefined ? settings.batteryHibernateTimeout : 0
                lockBeforeSuspend = settings.lockBeforeSuspend !== undefined ? settings.lockBeforeSuspend : false
                recentColors = settings.recentColors !== undefined ? settings.recentColors : []
                showThirdPartyPlugins = settings.showThirdPartyPlugins !== undefined ? settings.showThirdPartyPlugins : false

                if (!isGreeterMode) {
                    if (typeof Theme !== "undefined") {
                        Theme.generateSystemThemesFromCurrentTheme()
                    }
                }
            }
        } catch (e) {

        }
    }

    function saveSettings() {
        if (isGreeterMode) return
        settingsFile.setText(JSON.stringify({
                                                "isLightMode": isLightMode,
                                                "wallpaperPath": wallpaperPath,
                                                "wallpaperLastPath": wallpaperLastPath,
                                                "profileLastPath": profileLastPath,
                                                "perMonitorWallpaper": perMonitorWallpaper,
                                                "monitorWallpapers": monitorWallpapers,
                                                "perModeWallpaper": perModeWallpaper,
                                                "wallpaperPathLight": wallpaperPathLight,
                                                "wallpaperPathDark": wallpaperPathDark,
                                                "monitorWallpapersLight": monitorWallpapersLight,
                                                "monitorWallpapersDark": monitorWallpapersDark,
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
                                                "monitorCyclingSettings": monitorCyclingSettings,
                                                "lastBrightnessDevice": lastBrightnessDevice,
                                                "launchPrefix": launchPrefix,
                                                "wallpaperTransition": wallpaperTransition,
                                                "includedTransitions": includedTransitions,
                                                "acMonitorTimeout": acMonitorTimeout,
                                                "acLockTimeout": acLockTimeout,
                                                "acSuspendTimeout": acSuspendTimeout,
                                                "acHibernateTimeout": acHibernateTimeout,
                                                "batteryMonitorTimeout": batteryMonitorTimeout,
                                                "batteryLockTimeout": batteryLockTimeout,
                                                "batterySuspendTimeout": batterySuspendTimeout,
                                                "batteryHibernateTimeout": batteryHibernateTimeout,
                                                "lockBeforeSuspend": lockBeforeSuspend,
                                                "recentColors": recentColors,
                                                "showThirdPartyPlugins": showThirdPartyPlugins
                                            }, null, 2))
    }

    function setLightMode(lightMode) {
        isLightMode = lightMode
        syncWallpaperForCurrentMode()
        saveSettings()
    }

    function syncWallpaperForCurrentMode() {
        if (!perModeWallpaper) return

        if (perMonitorWallpaper) {
            monitorWallpapers = isLightMode ? Object.assign({}, monitorWallpapersLight) : Object.assign({}, monitorWallpapersDark)
            return
        }

        wallpaperPath = isLightMode ? wallpaperPathLight : wallpaperPathDark
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
        if (perModeWallpaper) {
            if (isLightMode) {
                wallpaperPathLight = imagePath
            } else {
                wallpaperPathDark = imagePath
            }
        }
        saveSettings()

        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function setWallpaperColor(color) {
        wallpaperPath = color
        if (perModeWallpaper) {
            if (isLightMode) {
                wallpaperPathLight = color
            } else {
                wallpaperPathDark = color
            }
        }
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

    function addRecentColor(color) {
        const colorStr = color.toString()
        let recent = recentColors.slice()
        recent = recent.filter(c => c !== colorStr)
        recent.unshift(colorStr)
        if (recent.length > 5) recent = recent.slice(0, 5)
        recentColors = recent
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

    function getMonitorCyclingSettings(screenName) {
        return monitorCyclingSettings[screenName] || {
            enabled: false,
            mode: "interval",
            interval: 300,
            time: "06:00"
        }
    }

    function setMonitorCyclingEnabled(screenName, enabled) {
        var newSettings = Object.assign({}, monitorCyclingSettings)
        if (!newSettings[screenName]) {
            newSettings[screenName] = { enabled: false, mode: "interval", interval: 300, time: "06:00" }
        }
        newSettings[screenName].enabled = enabled
        monitorCyclingSettings = newSettings
        saveSettings()
    }

    function setMonitorCyclingMode(screenName, mode) {
        var newSettings = Object.assign({}, monitorCyclingSettings)
        if (!newSettings[screenName]) {
            newSettings[screenName] = { enabled: false, mode: "interval", interval: 300, time: "06:00" }
        }
        newSettings[screenName].mode = mode
        monitorCyclingSettings = newSettings
        saveSettings()
    }

    function setMonitorCyclingInterval(screenName, interval) {
        var newSettings = Object.assign({}, monitorCyclingSettings)
        if (!newSettings[screenName]) {
            newSettings[screenName] = { enabled: false, mode: "interval", interval: 300, time: "06:00" }
        }
        newSettings[screenName].interval = interval
        monitorCyclingSettings = newSettings
        saveSettings()
    }

    function setMonitorCyclingTime(screenName, time) {
        var newSettings = Object.assign({}, monitorCyclingSettings)
        if (!newSettings[screenName]) {
            newSettings[screenName] = { enabled: false, mode: "interval", interval: 300, time: "06:00" }
        }
        newSettings[screenName].time = time
        monitorCyclingSettings = newSettings
        saveSettings()
    }

    function setPerMonitorWallpaper(enabled) {
        perMonitorWallpaper = enabled
        if (enabled && perModeWallpaper) {
            syncWallpaperForCurrentMode()
        }
        saveSettings()

        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme()
        }
    }

    function setPerModeWallpaper(enabled) {
        if (enabled && wallpaperCyclingEnabled) {
            setWallpaperCyclingEnabled(false)
        }
        if (enabled && perMonitorWallpaper) {
            var monitorCyclingAny = false
            for (var key in monitorCyclingSettings) {
                if (monitorCyclingSettings[key].enabled) {
                    monitorCyclingAny = true
                    break
                }
            }
            if (monitorCyclingAny) {
                var newSettings = Object.assign({}, monitorCyclingSettings)
                for (var screenName in newSettings) {
                    newSettings[screenName].enabled = false
                }
                monitorCyclingSettings = newSettings
            }
        }

        perModeWallpaper = enabled
        if (enabled) {
            if (perMonitorWallpaper) {
                monitorWallpapersLight = Object.assign({}, monitorWallpapers)
                monitorWallpapersDark = Object.assign({}, monitorWallpapers)
            } else {
                wallpaperPathLight = wallpaperPath
                wallpaperPathDark = wallpaperPath
            }
        } else {
            syncWallpaperForCurrentMode()
        }
        saveSettings()

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

        if (perModeWallpaper) {
            if (isLightMode) {
                var newLight = Object.assign({}, monitorWallpapersLight)
                if (path && path !== "") {
                    newLight[screenName] = path
                } else {
                    delete newLight[screenName]
                }
                monitorWallpapersLight = newLight
            } else {
                var newDark = Object.assign({}, monitorWallpapersDark)
                if (path && path !== "") {
                    newDark[screenName] = path
                } else {
                    delete newDark[screenName]
                }
                monitorWallpapersDark = newDark
            }
        }

        saveSettings()

        if (typeof Theme !== "undefined" && typeof Quickshell !== "undefined") {
            var screens = Quickshell.screens
            if (screens.length > 0 && screenName === screens[0].name) {
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

    function setLaunchPrefix(prefix) {
        launchPrefix = prefix
        saveSettings()
    }

    function setWallpaperTransition(transition) {
        wallpaperTransition = transition
        saveSettings()
    }

    function setAcMonitorTimeout(timeout) {
        acMonitorTimeout = timeout
        saveSettings()
    }

    function setAcLockTimeout(timeout) {
        acLockTimeout = timeout
        saveSettings()
    }

    function setAcSuspendTimeout(timeout) {
        acSuspendTimeout = timeout
        saveSettings()
    }

    function setBatteryMonitorTimeout(timeout) {
        batteryMonitorTimeout = timeout
        saveSettings()
    }

    function setBatteryLockTimeout(timeout) {
        batteryLockTimeout = timeout
        saveSettings()
    }

    function setBatterySuspendTimeout(timeout) {
        batterySuspendTimeout = timeout
        saveSettings()
    }

    function setAcHibernateTimeout(timeout) {
        acHibernateTimeout = timeout
        saveSettings()
    }

    function setBatteryHibernateTimeout(timeout) {
        batteryHibernateTimeout = timeout
        saveSettings()
    }

    function setLockBeforeSuspend(enabled) {
        lockBeforeSuspend = enabled
        saveSettings()
    }

    function setShowThirdPartyPlugins(enabled) {
        showThirdPartyPlugins = enabled
        saveSettings()
    }

    FileView {
        id: settingsFile

        path: isGreeterMode ? "" : StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/DankMaterialShell/session.json"
        blockLoading: isGreeterMode
        blockWrites: true
        watchChanges: !isGreeterMode
        onLoaded: {
            if (!isGreeterMode) {
                parseSettings(settingsFile.text())
                hasTriedDefaultSession = false
            }
        }
        onLoadFailed: error => {
            if (!isGreeterMode && !hasTriedDefaultSession) {
                hasTriedDefaultSession = true
                defaultSessionCheckProcess.running = true
            }
        }
    }

    FileView {
        id: greeterSessionFile

        path: {
            const greetCfgDir = Quickshell.env("DMS_GREET_CFG_DIR") || "/etc/greetd/.dms"
            return greetCfgDir + "/session.json"
        }
        preload: isGreeterMode
        blockLoading: false
        blockWrites: true
        watchChanges: false
        printErrors: true
        onLoaded: {
            if (isGreeterMode) {
                parseSettings(greeterSessionFile.text())
            }
        }
    }

    Process {
        id: defaultSessionCheckProcess

        command: ["sh", "-c", "CONFIG_DIR=\"" + _stateDir
            + "/DankMaterialShell\"; if [ -f \"$CONFIG_DIR/default-session.json\" ] && [ ! -f \"$CONFIG_DIR/session.json\" ]; then cp --no-preserve=mode \"$CONFIG_DIR/default-session.json\" \"$CONFIG_DIR/session.json\" && echo 'copied'; else echo 'not_found'; fi"]
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
