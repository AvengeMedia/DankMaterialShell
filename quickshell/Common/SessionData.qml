pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "settings/SessionSpec.js" as Spec
import "settings/SessionStore.js" as Store

Singleton {
    id: root

    readonly property int sessionConfigVersion: 2

    readonly property bool isGreeterMode: Quickshell.env("DMS_RUN_GREETER") === "1" || Quickshell.env("DMS_RUN_GREETER") === "true"
    property bool _parseError: false
    property bool _hasLoaded: false
    property bool _isReadOnly: false
    property bool _hasUnsavedChanges: false
    property var _loadedSessionSnapshot: null
    readonly property string _stateUrl: StandardPaths.writableLocation(StandardPaths.GenericStateLocation)
    readonly property string _stateDir: Paths.strip(_stateUrl)

    property bool isLightMode: false
    property bool doNotDisturb: false
    property bool isSwitchingMode: false
    property bool suppressOSD: true

    Timer {
        id: osdSuppressTimer
        interval: 2000
        running: true
        onTriggered: root.suppressOSD = false
    }

    function suppressOSDTemporarily() {
        suppressOSD = true;
        osdSuppressTimer.restart();
    }

    Connections {
        target: SessionService
        function onSessionResumed() {
            root.suppressOSD = true;
            osdSuppressTimer.restart();
        }
    }

    property string wallpaperPath: ""
    property bool perMonitorWallpaper: false
    property var monitorWallpapers: ({})
    property bool perModeWallpaper: false
    property string wallpaperPathLight: ""
    property string wallpaperPathDark: ""
    property var monitorWallpapersLight: ({})
    property var monitorWallpapersDark: ({})
    property string wallpaperTransition: "fade"
    readonly property var availableWallpaperTransitions: ["none", "fade", "wipe", "disc", "stripes", "iris bloom", "pixelate", "portal"]
    property var includedTransitions: availableWallpaperTransitions.filter(t => t !== "none")

    property bool wallpaperCyclingEnabled: false
    property string wallpaperCyclingMode: "interval"
    property int wallpaperCyclingInterval: 300
    property string wallpaperCyclingTime: "06:00"
    property var monitorCyclingSettings: ({})

    property bool nightModeEnabled: false
    property int nightModeTemperature: 4500
    property int nightModeHighTemperature: 6500
    property bool nightModeAutoEnabled: false
    property string nightModeAutoMode: "time"
    property int nightModeStartHour: 18
    property int nightModeStartMinute: 0
    property int nightModeEndHour: 6
    property int nightModeEndMinute: 0
    property real latitude: 0.0
    property real longitude: 0.0
    property bool nightModeUseIPLocation: false
    property string nightModeLocationProvider: ""

    property var pinnedApps: []
    property var hiddenTrayIds: []
    property var recentColors: []
    property bool showThirdPartyPlugins: false
    property string launchPrefix: ""
    property string lastBrightnessDevice: ""
    property var brightnessExponentialDevices: ({})
    property var brightnessUserSetValues: ({})
    property var brightnessExponentValues: ({})

    property int selectedGpuIndex: 0
    property bool nvidiaGpuTempEnabled: false
    property bool nonNvidiaGpuTempEnabled: false
    property var enabledGpuPciIds: []

    property string wifiDeviceOverride: ""
    property bool weatherHourlyDetailed: true

    property string weatherLocation: "New York, NY"
    property string weatherCoordinates: "40.7128,-74.0060"

    Component.onCompleted: {
        if (!isGreeterMode) {
            loadSettings();
        }
    }

    property var _pendingMigration: null

    function loadSettings() {
        _hasUnsavedChanges = false;
        _pendingMigration = null;

        if (isGreeterMode) {
            parseSettings(greeterSessionFile.text());
            return;
        }
        parseSettings(settingsFile.text());
        _checkSessionWritable();
    }

    function _checkSessionWritable() {
        sessionWritableCheckProcess.running = true;
    }

    function _onWritableCheckComplete(writable) {
        _isReadOnly = !writable;
        if (_isReadOnly) {
            console.info("SessionData: session.json is read-only (NixOS home-manager mode)");
        } else if (_pendingMigration) {
            settingsFile.setText(JSON.stringify(_pendingMigration, null, 2));
        }
        _pendingMigration = null;
    }

    function _checkForUnsavedChanges() {
        if (!_hasLoaded || !_loadedSessionSnapshot)
            return false;
        const current = getCurrentSessionJson();
        return current !== _loadedSessionSnapshot;
    }

    function getCurrentSessionJson() {
        return JSON.stringify(Store.toJson(root), null, 2);
    }

    function parseSettings(content) {
        _parseError = false;
        try {
            if (!content || !content.trim()) {
                _parseError = true;
                return;
            }

            let obj = JSON.parse(content);

            if (obj.brightnessLogarithmicDevices && !obj.brightnessExponentialDevices) {
                obj.brightnessExponentialDevices = obj.brightnessLogarithmicDevices;
            }

            if (obj.nightModeStartTime !== undefined) {
                const parts = obj.nightModeStartTime.split(":");
                obj.nightModeStartHour = parseInt(parts[0]) || 18;
                obj.nightModeStartMinute = parseInt(parts[1]) || 0;
            }
            if (obj.nightModeEndTime !== undefined) {
                const parts = obj.nightModeEndTime.split(":");
                obj.nightModeEndHour = parseInt(parts[0]) || 6;
                obj.nightModeEndMinute = parseInt(parts[1]) || 0;
            }

            const oldVersion = obj.configVersion ?? 0;
            if (oldVersion === 0) {
                migrateFromUndefinedToV1(obj);
            }

            if (oldVersion < sessionConfigVersion) {
                const settingsDataRef = (typeof SettingsData !== "undefined") ? SettingsData : null;
                const migrated = Store.migrateToVersion(obj, sessionConfigVersion, settingsDataRef);
                if (migrated) {
                    _pendingMigration = migrated;
                    obj = migrated;
                }
            }

            Store.parse(root, obj);

            if (wallpaperPath && wallpaperPath.startsWith("we:")) {
                console.warn("WallpaperEngine wallpaper detected, resetting wallpaper");
                wallpaperPath = "";
                Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "DMS", "-i", "dialog-warning", "WallpaperEngine Support Moved", "WallpaperEngine support has been moved to a plugin. Please enable the Linux Wallpaper Engine plugin in Settings → Plugins to continue using WallpaperEngine."]);
            }

            _hasLoaded = true;
            _loadedSessionSnapshot = getCurrentSessionJson();

            if (!isGreeterMode && typeof Theme !== "undefined") {
                Theme.generateSystemThemesFromCurrentTheme();
            }

            if (typeof WallpaperCyclingService !== "undefined") {
                WallpaperCyclingService.updateCyclingState();
            }
        } catch (e) {
            _parseError = true;
            const msg = e.message;
            console.error("SessionData: Failed to parse session.json - file will not be overwritten. Error:", msg);
            Qt.callLater(() => ToastService.showError(I18n.tr("Failed to parse session.json"), msg));
        }
    }

    function saveSettings() {
        if (isGreeterMode || _parseError || !_hasLoaded)
            return;
        if (_isReadOnly) {
            _hasUnsavedChanges = _checkForUnsavedChanges();
            return;
        }
        settingsFile.setText(getCurrentSessionJson());
    }

    function migrateFromUndefinedToV1(settings) {
        console.info("SessionData: Migrating configuration from undefined to version 1");
        if (typeof SettingsData !== "undefined") {
            if (settings.acMonitorTimeout !== undefined) {
                SettingsData.set("acMonitorTimeout", settings.acMonitorTimeout);
            }
            if (settings.acLockTimeout !== undefined) {
                SettingsData.set("acLockTimeout", settings.acLockTimeout);
            }
            if (settings.acSuspendTimeout !== undefined) {
                SettingsData.set("acSuspendTimeout", settings.acSuspendTimeout);
            }
            if (settings.acHibernateTimeout !== undefined) {
                SettingsData.set("acHibernateTimeout", settings.acHibernateTimeout);
            }
            if (settings.batteryMonitorTimeout !== undefined) {
                SettingsData.set("batteryMonitorTimeout", settings.batteryMonitorTimeout);
            }
            if (settings.batteryLockTimeout !== undefined) {
                SettingsData.set("batteryLockTimeout", settings.batteryLockTimeout);
            }
            if (settings.batterySuspendTimeout !== undefined) {
                SettingsData.set("batterySuspendTimeout", settings.batterySuspendTimeout);
            }
            if (settings.batteryHibernateTimeout !== undefined) {
                SettingsData.set("batteryHibernateTimeout", settings.batteryHibernateTimeout);
            }
            if (settings.lockBeforeSuspend !== undefined) {
                SettingsData.set("lockBeforeSuspend", settings.lockBeforeSuspend);
            }
            if (settings.loginctlLockIntegration !== undefined) {
                SettingsData.set("loginctlLockIntegration", settings.loginctlLockIntegration);
            }
            if (settings.launchPrefix !== undefined) {
                SettingsData.set("launchPrefix", settings.launchPrefix);
            }
        }
        if (typeof CacheData !== "undefined") {
            if (settings.wallpaperLastPath !== undefined) {
                CacheData.wallpaperLastPath = settings.wallpaperLastPath;
            }
            if (settings.profileLastPath !== undefined) {
                CacheData.profileLastPath = settings.profileLastPath;
            }
            CacheData.saveCache();
        }
    }

    function setLightMode(lightMode) {
        isSwitchingMode = true;
        isLightMode = lightMode;
        syncWallpaperForCurrentMode();
        saveSettings();
        Qt.callLater(() => {
            isSwitchingMode = false;
        });
    }

    function setDoNotDisturb(enabled) {
        doNotDisturb = enabled;
        saveSettings();
    }

    function setWallpaperPath(path) {
        wallpaperPath = path;
        saveSettings();
    }

    function setWallpaper(imagePath) {
        wallpaperPath = imagePath;
        if (perModeWallpaper) {
            if (isLightMode) {
                wallpaperPathLight = imagePath;
            } else {
                wallpaperPathDark = imagePath;
            }
        }
        saveSettings();

        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme();
        }
    }

    function setWallpaperColor(color) {
        wallpaperPath = color;
        if (perModeWallpaper) {
            if (isLightMode) {
                wallpaperPathLight = color;
            } else {
                wallpaperPathDark = color;
            }
        }
        saveSettings();

        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme();
        }
    }

    function clearWallpaper() {
        wallpaperPath = "";
        saveSettings();

        if (typeof Theme !== "undefined") {
            if (typeof SettingsData !== "undefined" && SettingsData.theme) {
                Theme.switchTheme(SettingsData.theme);
            } else {
                Theme.switchTheme("blue");
            }
        }
    }

    function setPerMonitorWallpaper(enabled) {
        perMonitorWallpaper = enabled;
        if (enabled && perModeWallpaper) {
            syncWallpaperForCurrentMode();
        }
        saveSettings();

        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme();
        }
    }

    function setPerModeWallpaper(enabled) {
        if (enabled && wallpaperCyclingEnabled) {
            setWallpaperCyclingEnabled(false);
        }
        if (enabled && perMonitorWallpaper) {
            var monitorCyclingAny = false;
            for (var key in monitorCyclingSettings) {
                if (monitorCyclingSettings[key].enabled) {
                    monitorCyclingAny = true;
                    break;
                }
            }
            if (monitorCyclingAny) {
                var newSettings = Object.assign({}, monitorCyclingSettings);
                for (var screenName in newSettings) {
                    newSettings[screenName].enabled = false;
                }
                monitorCyclingSettings = newSettings;
            }
        }

        perModeWallpaper = enabled;
        if (enabled) {
            if (perMonitorWallpaper) {
                monitorWallpapersLight = Object.assign({}, monitorWallpapers);
                monitorWallpapersDark = Object.assign({}, monitorWallpapers);
            } else {
                wallpaperPathLight = wallpaperPath;
                wallpaperPathDark = wallpaperPath;
            }
        } else {
            syncWallpaperForCurrentMode();
        }
        saveSettings();

        if (typeof Theme !== "undefined") {
            Theme.generateSystemThemesFromCurrentTheme();
        }
    }

    function setMonitorWallpaper(screenName, path) {
        var screen = null;
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === screenName) {
                screen = screens[i];
                break;
            }
        }

        if (!screen) {
            console.warn("SessionData: Screen not found:", screenName);
            return;
        }

        var identifier = typeof SettingsData !== "undefined" ? SettingsData.getScreenDisplayName(screen) : screen.name;

        var newMonitorWallpapers = {};
        for (var key in monitorWallpapers) {
            var isThisScreen = key === screen.name || (screen.model && key === screen.model);
            if (!isThisScreen) {
                newMonitorWallpapers[key] = monitorWallpapers[key];
            }
        }

        if (path && path !== "") {
            newMonitorWallpapers[identifier] = path;
        }

        monitorWallpapers = newMonitorWallpapers;

        if (perModeWallpaper) {
            if (isLightMode) {
                var newLight = {};
                for (var key in monitorWallpapersLight) {
                    var isThisScreen = key === screen.name || (screen.model && key === screen.model);
                    if (!isThisScreen) {
                        newLight[key] = monitorWallpapersLight[key];
                    }
                }
                if (path && path !== "") {
                    newLight[identifier] = path;
                }
                monitorWallpapersLight = newLight;
            } else {
                var newDark = {};
                for (var key in monitorWallpapersDark) {
                    var isThisScreen = key === screen.name || (screen.model && key === screen.model);
                    if (!isThisScreen) {
                        newDark[key] = monitorWallpapersDark[key];
                    }
                }
                if (path && path !== "") {
                    newDark[identifier] = path;
                }
                monitorWallpapersDark = newDark;
            }
        }

        saveSettings();

        if (typeof Theme !== "undefined" && typeof Quickshell !== "undefined" && typeof SettingsData !== "undefined") {
            var screens = Quickshell.screens;
            if (screens.length > 0) {
                var targetMonitor = (SettingsData.matugenTargetMonitor && SettingsData.matugenTargetMonitor !== "") ? SettingsData.matugenTargetMonitor : screens[0].name;
                if (screenName === targetMonitor) {
                    Theme.generateSystemThemesFromCurrentTheme();
                }
            }
        }
    }

    function setWallpaperTransition(transition) {
        wallpaperTransition = transition;
        saveSettings();
    }

    function setWallpaperCyclingEnabled(enabled) {
        wallpaperCyclingEnabled = enabled;
        saveSettings();
    }

    function setWallpaperCyclingMode(mode) {
        wallpaperCyclingMode = mode;
        saveSettings();
    }

    function setWallpaperCyclingInterval(interval) {
        wallpaperCyclingInterval = interval;
        saveSettings();
    }

    function setWallpaperCyclingTime(time) {
        wallpaperCyclingTime = time;
        saveSettings();
    }

    function setMonitorCyclingEnabled(screenName, enabled) {
        var screen = null;
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === screenName) {
                screen = screens[i];
                break;
            }
        }

        if (!screen) {
            console.warn("SessionData: Screen not found:", screenName);
            return;
        }

        var identifier = typeof SettingsData !== "undefined" ? SettingsData.getScreenDisplayName(screen) : screen.name;

        var newSettings = {};
        for (var key in monitorCyclingSettings) {
            var isThisScreen = key === screen.name || (screen.model && key === screen.model);
            if (!isThisScreen) {
                newSettings[key] = monitorCyclingSettings[key];
            }
        }

        if (!newSettings[identifier]) {
            newSettings[identifier] = {
                "enabled": false,
                "mode": "interval",
                "interval": 300,
                "time": "06:00"
            };
        }
        newSettings[identifier].enabled = enabled;
        monitorCyclingSettings = newSettings;
        saveSettings();
    }

    function setMonitorCyclingMode(screenName, mode) {
        var screen = null;
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === screenName) {
                screen = screens[i];
                break;
            }
        }

        if (!screen) {
            console.warn("SessionData: Screen not found:", screenName);
            return;
        }

        var identifier = typeof SettingsData !== "undefined" ? SettingsData.getScreenDisplayName(screen) : screen.name;

        var newSettings = {};
        for (var key in monitorCyclingSettings) {
            var isThisScreen = key === screen.name || (screen.model && key === screen.model);
            if (!isThisScreen) {
                newSettings[key] = monitorCyclingSettings[key];
            }
        }

        if (!newSettings[identifier]) {
            newSettings[identifier] = {
                "enabled": false,
                "mode": "interval",
                "interval": 300,
                "time": "06:00"
            };
        }
        newSettings[identifier].mode = mode;
        monitorCyclingSettings = newSettings;
        saveSettings();
    }

    function setMonitorCyclingInterval(screenName, interval) {
        var screen = null;
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === screenName) {
                screen = screens[i];
                break;
            }
        }

        if (!screen) {
            console.warn("SessionData: Screen not found:", screenName);
            return;
        }

        var identifier = typeof SettingsData !== "undefined" ? SettingsData.getScreenDisplayName(screen) : screen.name;

        var newSettings = {};
        for (var key in monitorCyclingSettings) {
            var isThisScreen = key === screen.name || (screen.model && key === screen.model);
            if (!isThisScreen) {
                newSettings[key] = monitorCyclingSettings[key];
            }
        }

        if (!newSettings[identifier]) {
            newSettings[identifier] = {
                "enabled": false,
                "mode": "interval",
                "interval": 300,
                "time": "06:00"
            };
        }
        newSettings[identifier].interval = interval;
        monitorCyclingSettings = newSettings;
        saveSettings();
    }

    function setMonitorCyclingTime(screenName, time) {
        var screen = null;
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === screenName) {
                screen = screens[i];
                break;
            }
        }

        if (!screen) {
            console.warn("SessionData: Screen not found:", screenName);
            return;
        }

        var identifier = typeof SettingsData !== "undefined" ? SettingsData.getScreenDisplayName(screen) : screen.name;

        var newSettings = {};
        for (var key in monitorCyclingSettings) {
            var isThisScreen = key === screen.name || (screen.model && key === screen.model);
            if (!isThisScreen) {
                newSettings[key] = monitorCyclingSettings[key];
            }
        }

        if (!newSettings[identifier]) {
            newSettings[identifier] = {
                "enabled": false,
                "mode": "interval",
                "interval": 300,
                "time": "06:00"
            };
        }
        newSettings[identifier].time = time;
        monitorCyclingSettings = newSettings;
        saveSettings();
    }

    function setNightModeEnabled(enabled) {
        nightModeEnabled = enabled;
        saveSettings();
    }

    function setNightModeTemperature(temperature) {
        nightModeTemperature = temperature;
        saveSettings();
    }

    function setNightModeHighTemperature(temperature) {
        nightModeHighTemperature = temperature;
        saveSettings();
    }

    function setNightModeAutoEnabled(enabled) {
        console.log("SessionData: Setting nightModeAutoEnabled to", enabled);
        nightModeAutoEnabled = enabled;
        saveSettings();
    }

    function setNightModeAutoMode(mode) {
        nightModeAutoMode = mode;
        saveSettings();
    }

    function setNightModeStartHour(hour) {
        nightModeStartHour = hour;
        saveSettings();
    }

    function setNightModeStartMinute(minute) {
        nightModeStartMinute = minute;
        saveSettings();
    }

    function setNightModeEndHour(hour) {
        nightModeEndHour = hour;
        saveSettings();
    }

    function setNightModeEndMinute(minute) {
        nightModeEndMinute = minute;
        saveSettings();
    }

    function setNightModeUseIPLocation(use) {
        nightModeUseIPLocation = use;
        saveSettings();
    }

    function setLatitude(lat) {
        console.log("SessionData: Setting latitude to", lat);
        latitude = lat;
        saveSettings();
    }

    function setLongitude(lng) {
        console.log("SessionData: Setting longitude to", lng);
        longitude = lng;
        saveSettings();
    }

    function setNightModeLocationProvider(provider) {
        nightModeLocationProvider = provider;
        saveSettings();
    }

    function setPinnedApps(apps) {
        pinnedApps = apps;
        saveSettings();
    }

    function addPinnedApp(appId) {
        if (!appId)
            return;
        var currentPinned = [...pinnedApps];
        if (currentPinned.indexOf(appId) === -1) {
            currentPinned.push(appId);
            setPinnedApps(currentPinned);
        }
    }

    function removePinnedApp(appId) {
        if (!appId)
            return;
        var currentPinned = pinnedApps.filter(id => id !== appId);
        setPinnedApps(currentPinned);
    }

    function isPinnedApp(appId) {
        return appId && pinnedApps.indexOf(appId) !== -1;
    }

    function hideTrayId(trayId) {
        if (!trayId)
            return;
        const current = [...hiddenTrayIds];
        if (current.indexOf(trayId) === -1) {
            current.push(trayId);
            hiddenTrayIds = current;
            saveSettings();
        }
    }

    function showTrayId(trayId) {
        if (!trayId)
            return;
        hiddenTrayIds = hiddenTrayIds.filter(id => id !== trayId);
        saveSettings();
    }

    function isHiddenTrayId(trayId) {
        return trayId && hiddenTrayIds.indexOf(trayId) !== -1;
    }

    function addRecentColor(color) {
        const colorStr = color.toString();
        let recent = recentColors.slice();
        recent = recent.filter(c => c !== colorStr);
        recent.unshift(colorStr);
        if (recent.length > 5)
            recent = recent.slice(0, 5);
        recentColors = recent;
        saveSettings();
    }

    function setShowThirdPartyPlugins(enabled) {
        showThirdPartyPlugins = enabled;
        saveSettings();
    }

    function setLaunchPrefix(prefix) {
        launchPrefix = prefix;
        saveSettings();
    }

    function setLastBrightnessDevice(device) {
        lastBrightnessDevice = device;
        saveSettings();
    }

    function setBrightnessExponential(deviceName, enabled) {
        var newSettings = Object.assign({}, brightnessExponentialDevices);
        if (enabled) {
            newSettings[deviceName] = true;
        } else {
            delete newSettings[deviceName];
        }
        brightnessExponentialDevices = newSettings;
        saveSettings();

        if (typeof DisplayService !== "undefined") {
            DisplayService.updateDeviceBrightnessDisplay(deviceName);
        }
    }

    function getBrightnessExponential(deviceName) {
        return brightnessExponentialDevices[deviceName] === true;
    }

    function setBrightnessUserSetValue(deviceName, value) {
        var newValues = Object.assign({}, brightnessUserSetValues);
        newValues[deviceName] = value;
        brightnessUserSetValues = newValues;
        saveSettings();
    }

    function getBrightnessUserSetValue(deviceName) {
        return brightnessUserSetValues[deviceName];
    }

    function clearBrightnessUserSetValue(deviceName) {
        var newValues = Object.assign({}, brightnessUserSetValues);
        delete newValues[deviceName];
        brightnessUserSetValues = newValues;
        saveSettings();
    }

    function setBrightnessExponent(deviceName, exponent) {
        var newValues = Object.assign({}, brightnessExponentValues);
        if (exponent !== undefined && exponent !== null) {
            newValues[deviceName] = exponent;
        } else {
            delete newValues[deviceName];
        }
        brightnessExponentValues = newValues;
        saveSettings();
    }

    function getBrightnessExponent(deviceName) {
        const value = brightnessExponentValues[deviceName];
        return value !== undefined ? value : 1.2;
    }

    function setSelectedGpuIndex(index) {
        selectedGpuIndex = index;
        saveSettings();
    }

    function setNvidiaGpuTempEnabled(enabled) {
        nvidiaGpuTempEnabled = enabled;
        saveSettings();
    }

    function setNonNvidiaGpuTempEnabled(enabled) {
        nonNvidiaGpuTempEnabled = enabled;
        saveSettings();
    }

    function setEnabledGpuPciIds(pciIds) {
        enabledGpuPciIds = pciIds;
        saveSettings();
    }

    function setWifiDeviceOverride(device) {
        wifiDeviceOverride = device || "";
        saveSettings();
    }

    function setWeatherHourlyDetailed(detailed) {
        weatherHourlyDetailed = detailed;
        saveSettings();
    }

    function setWeatherLocation(displayName, coordinates) {
        weatherLocation = displayName;
        weatherCoordinates = coordinates;
        saveSettings();
    }

    function syncWallpaperForCurrentMode() {
        if (!perModeWallpaper)
            return;
        if (perMonitorWallpaper) {
            monitorWallpapers = isLightMode ? Object.assign({}, monitorWallpapersLight) : Object.assign({}, monitorWallpapersDark);
            return;
        }

        wallpaperPath = isLightMode ? wallpaperPathLight : wallpaperPathDark;
    }

    function getMonitorWallpaper(screenName) {
        if (!perMonitorWallpaper) {
            return wallpaperPath;
        }

        var screen = null;
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === screenName) {
                screen = screens[i];
                break;
            }
        }

        if (!screen) {
            return monitorWallpapers[screenName] || wallpaperPath;
        }

        if (monitorWallpapers[screen.name]) {
            return monitorWallpapers[screen.name];
        }
        if (screen.model && monitorWallpapers[screen.model]) {
            return monitorWallpapers[screen.model];
        }

        return wallpaperPath;
    }

    function getMonitorCyclingSettings(screenName) {
        var screen = null;
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === screenName) {
                screen = screens[i];
                break;
            }
        }

        if (!screen) {
            return monitorCyclingSettings[screenName] || {
                "enabled": false,
                "mode": "interval",
                "interval": 300,
                "time": "06:00"
            };
        }

        if (monitorCyclingSettings[screen.name]) {
            return monitorCyclingSettings[screen.name];
        }
        if (screen.model && monitorCyclingSettings[screen.model]) {
            return monitorCyclingSettings[screen.model];
        }

        return {
            "enabled": false,
            "mode": "interval",
            "interval": 300,
            "time": "06:00"
        };
    }

    FileView {
        id: settingsFile

        path: isGreeterMode ? "" : StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/DankMaterialShell/session.json"
        blockLoading: isGreeterMode
        blockWrites: true
        watchChanges: !isGreeterMode
        onLoaded: {
            if (!isGreeterMode) {
                _hasUnsavedChanges = false;
                parseSettings(settingsFile.text());
            }
        }
    }

    FileView {
        id: greeterSessionFile

        path: {
            const greetCfgDir = Quickshell.env("DMS_GREET_CFG_DIR") || "/etc/greetd/.dms";
            return greetCfgDir + "/session.json";
        }
        preload: isGreeterMode
        blockLoading: false
        blockWrites: true
        watchChanges: false
        printErrors: true
        onLoaded: {
            if (isGreeterMode) {
                parseSettings(greeterSessionFile.text());
            }
        }
    }

    Process {
        id: sessionWritableCheckProcess

        property string sessionPath: Paths.strip(settingsFile.path)

        command: ["sh", "-c", "[ -w \"" + sessionPath + "\" ] && echo 'writable' || echo 'readonly'"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const result = text.trim();
                root._onWritableCheckComplete(result === "writable");
            }
        }
    }

    IpcHandler {
        target: "wallpaper"

        function get(): string {
            if (root.perMonitorWallpaper) {
                return "ERROR: Per-monitor mode enabled. Use getFor(screenName) instead.";
            }
            return root.wallpaperPath || "";
        }

        function set(path: string): string {
            if (root.perMonitorWallpaper) {
                return "ERROR: Per-monitor mode enabled. Use setFor(screenName, path) instead.";
            }

            if (!path) {
                return "ERROR: No path provided";
            }

            var absolutePath = path.startsWith("/") ? path : StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/" + path;

            try {
                root.setWallpaper(absolutePath);
                return "SUCCESS: Wallpaper set to " + absolutePath;
            } catch (e) {
                return "ERROR: Failed to set wallpaper: " + e.toString();
            }
        }

        function clear(): string {
            root.setWallpaper("");
            root.setPerMonitorWallpaper(false);
            root.monitorWallpapers = {};
            root.saveSettings();
            return "SUCCESS: All wallpapers cleared";
        }

        function next(): string {
            if (root.perMonitorWallpaper) {
                return "ERROR: Per-monitor mode enabled. Use nextFor(screenName) instead.";
            }

            if (!root.wallpaperPath) {
                return "ERROR: No wallpaper set";
            }

            try {
                WallpaperCyclingService.cycleNextManually();
                return "SUCCESS: Cycling to next wallpaper";
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper: " + e.toString();
            }
        }

        function prev(): string {
            if (root.perMonitorWallpaper) {
                return "ERROR: Per-monitor mode enabled. Use prevFor(screenName) instead.";
            }

            if (!root.wallpaperPath) {
                return "ERROR: No wallpaper set";
            }

            try {
                WallpaperCyclingService.cyclePrevManually();
                return "SUCCESS: Cycling to previous wallpaper";
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper: " + e.toString();
            }
        }

        function getFor(screenName: string): string {
            if (!screenName) {
                return "ERROR: No screen name provided";
            }
            return root.getMonitorWallpaper(screenName) || "";
        }

        function setFor(screenName: string, path: string): string {
            if (!screenName) {
                return "ERROR: No screen name provided";
            }

            if (!path) {
                return "ERROR: No path provided";
            }

            var absolutePath = path.startsWith("/") ? path : StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/" + path;

            try {
                if (!root.perMonitorWallpaper) {
                    root.setPerMonitorWallpaper(true);
                }
                root.setMonitorWallpaper(screenName, absolutePath);
                return "SUCCESS: Wallpaper set for " + screenName + " to " + absolutePath;
            } catch (e) {
                return "ERROR: Failed to set wallpaper for " + screenName + ": " + e.toString();
            }
        }

        function nextFor(screenName: string): string {
            if (!screenName) {
                return "ERROR: No screen name provided";
            }

            var currentWallpaper = root.getMonitorWallpaper(screenName);
            if (!currentWallpaper) {
                return "ERROR: No wallpaper set for " + screenName;
            }

            try {
                WallpaperCyclingService.cycleNextForMonitor(screenName);
                return "SUCCESS: Cycling to next wallpaper for " + screenName;
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper for " + screenName + ": " + e.toString();
            }
        }

        function prevFor(screenName: string): string {
            if (!screenName) {
                return "ERROR: No screen name provided";
            }

            var currentWallpaper = root.getMonitorWallpaper(screenName);
            if (!currentWallpaper) {
                return "ERROR: No wallpaper set for " + screenName;
            }

            try {
                WallpaperCyclingService.cyclePrevForMonitor(screenName);
                return "SUCCESS: Cycling to previous wallpaper for " + screenName;
            } catch (e) {
                return "ERROR: Failed to cycle wallpaper for " + screenName + ": " + e.toString();
            }
        }
    }
}
