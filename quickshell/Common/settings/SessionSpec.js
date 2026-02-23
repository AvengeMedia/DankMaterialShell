.pragma library

var SPEC = {
    isLightMode: { def: false },
    doNotDisturb: { def: false },

    wallpaperPath: { def: "" },
    perMonitorWallpaper: { def: false },
    monitorWallpapers: { def: {} },
    perModeWallpaper: { def: false },
    wallpaperPathLight: { def: "" },
    wallpaperPathDark: { def: "" },
    monitorWallpapersLight: { def: {} },
    monitorWallpapersDark: { def: {} },
    monitorWallpaperFillModes: { def: {} },
    wallpaperTransition: { def: "fade" },
    includedTransitions: { def: ["fade", "wipe", "disc", "stripes", "iris bloom", "pixelate", "portal"] },

    wallpaperCyclingEnabled: { def: false },
    wallpaperCyclingMode: { def: "interval" },
    wallpaperCyclingInterval: { def: 300 },
    wallpaperCyclingTime: { def: "06:00" },
    monitorCyclingSettings: { def: {} },

    nightModeEnabled: { def: false },
    nightModeTemperature: { def: 4500 },
    nightModeHighTemperature: { def: 6500 },
    nightModeAutoEnabled: { def: false },
    nightModeAutoMode: { def: "time" },
    nightModeStartHour: { def: 18 },
    nightModeStartMinute: { def: 0 },
    nightModeEndHour: { def: 6 },
    nightModeEndMinute: { def: 0 },
    latitude: { def: 0.0 },
    longitude: { def: 0.0 },
    nightModeUseIPLocation: { def: false },
    nightModeLocationProvider: { def: "" },

    themeModeAutoEnabled: { def: false },
    themeModeAutoMode: { def: "time" },
    themeModeStartHour: { def: 18 },
    themeModeStartMinute: { def: 0 },
    themeModeEndHour: { def: 6 },
    themeModeEndMinute: { def: 0 },
    themeModeShareGammaSettings: { def: true },

    weatherLocation: { def: "New York, NY" },
    weatherCoordinates: { def: "40.7128,-74.0060" },

    pinnedApps: { def: [] },
    barPinnedApps: { def: [] },
    dockLauncherPosition: { def: 0 },
    hiddenTrayIds: { def: [] },
    trayItemOrder: { def: [] },
    recentColors: { def: [] },
    showThirdPartyPlugins: { def: false },
    launchPrefix: { def: "" },
    lastBrightnessDevice: { def: "" },

    brightnessExponentialDevices: { def: {} },
    brightnessUserSetValues: { def: {} },
    brightnessExponentValues: { def: {} },

    selectedGpuIndex: { def: 0 },
    nvidiaGpuTempEnabled: { def: false },
    nonNvidiaGpuTempEnabled: { def: false },
    enabledGpuPciIds: { def: [] },

    wifiDeviceOverride: { def: "" },
    weatherHourlyDetailed: { def: true },

    hiddenApps: { def: [] },
    appOverrides: { def: {} },
    searchAppActions: { def: true },

    vpnLastConnected: { def: "" },

    deviceMaxVolumes: { def: {} },
    hiddenOutputDeviceNames: { def: [] },
    hiddenInputDeviceNames: { def: [] },

    launcherLastMode: { def: "all" },
    appDrawerLastMode: { def: "apps" },
    niriOverviewLastMode: { def: "apps" }
};

function getValidKeys() {
    return Object.keys(SPEC).concat(["configVersion"]);
}

function set(root, key, value, saveFn, hooks) {
    if (!(key in SPEC)) return;
    root[key] = value;
    var hookName = SPEC[key].onChange;
    if (hookName && hooks && hooks[hookName]) {
        hooks[hookName](root);
    }
    saveFn();
}
