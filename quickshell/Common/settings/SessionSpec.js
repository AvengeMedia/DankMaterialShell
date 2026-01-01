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

    weatherLocation: { def: "New York, NY" },
    weatherCoordinates: { def: "40.7128,-74.0060" },

    pinnedApps: { def: [] },
    hiddenTrayIds: { def: [] },
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
    weatherHourlyDetailed: { def: true }
};

function getValidKeys() {
    return Object.keys(SPEC).concat(["configVersion"]);
}
