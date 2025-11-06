.pragma library

function percentToUnit(v) {
    if (v === undefined || v === null) return undefined;
    return v > 1 ? v / 100 : v;
}

var SPEC = {
    currentThemeName: { def: "blue", onChange: "applyStoredTheme" },
    customThemeFile: { def: "" },
    matugenScheme: { def: "scheme-tonal-spot", onChange: "regenSystemThemes" },
    runUserMatugenTemplates: { def: true, onChange: "regenSystemThemes" },
    matugenTargetMonitor: { def: "", onChange: "regenSystemThemes" },

    dankBarTransparency: { def: 1.0, coerce: percentToUnit, migrate: ["topBarTransparency"] },
    dankBarWidgetTransparency: { def: 1.0, coerce: percentToUnit, migrate: ["topBarWidgetTransparency"] },
    popupTransparency: { def: 1.0, coerce: percentToUnit },
    dockTransparency: { def: 1.0, coerce: percentToUnit },

    widgetBackgroundColor: { def: "sch" },
    surfaceBase: { def: "s", onChange: "regenSystemThemes" },
    cornerRadius: { def: 12, onChange: "updateNiriLayout" },

    use24HourClock: { def: true },
    showSeconds: { def: false },
    useFahrenheit: { def: false },
    nightModeEnabled: { def: false },
    animationSpeed: { def: 1 },
    customAnimationDuration: { def: 500 },
    wallpaperFillMode: { def: "Fill" },
    blurredWallpaperLayer: { def: false },
    blurWallpaperOnOverview: { def: false },

    showLauncherButton: { def: true },
    showWorkspaceSwitcher: { def: true },
    showFocusedWindow: { def: true },
    showWeather: { def: true },
    showMusic: { def: true },
    showClipboard: { def: true },
    showCpuUsage: { def: true },
    showMemUsage: { def: true },
    showCpuTemp: { def: true },
    showGpuTemp: { def: true },
    selectedGpuIndex: { def: 0 },
    enabledGpuPciIds: { def: [] },
    showSystemTray: { def: true },
    showClock: { def: true },
    showNotificationButton: { def: true },
    showBattery: { def: true },
    showControlCenterButton: { def: true },

    controlCenterShowNetworkIcon: { def: true },
    controlCenterShowBluetoothIcon: { def: true },
    controlCenterShowAudioIcon: { def: true },
    controlCenterWidgets: { def: [
        { id: "volumeSlider", enabled: true, width: 50 },
        { id: "brightnessSlider", enabled: true, width: 50 },
        { id: "wifi", enabled: true, width: 50 },
        { id: "bluetooth", enabled: true, width: 50 },
        { id: "audioOutput", enabled: true, width: 50 },
        { id: "audioInput", enabled: true, width: 50 },
        { id: "nightMode", enabled: true, width: 50 },
        { id: "darkMode", enabled: true, width: 50 }
    ]},

    showWorkspaceIndex: { def: false },
    showWorkspacePadding: { def: false },
    workspaceScrolling: { def: false },
    showWorkspaceApps: { def: false },
    maxWorkspaceIcons: { def: 3 },
    workspacesPerMonitor: { def: true },
    dwlShowAllTags: { def: false },
    workspaceNameIcons: { def: {} },
    waveProgressEnabled: { def: true },
    clockCompactMode: { def: false },
    focusedWindowCompactMode: { def: false },
    runningAppsCompactMode: { def: true },
    keyboardLayoutNameCompactMode: { def: false },
    runningAppsCurrentWorkspace: { def: false },
    runningAppsGroupByApp: { def: false },
    clockDateFormat: { def: "" },
    lockDateFormat: { def: "" },
    mediaSize: { def: 1 },

    dankBarLeftWidgets: { def: ["launcherButton", "workspaceSwitcher", "focusedWindow"], migrate: ["topBarLeftWidgets"] },
    dankBarCenterWidgets: { def: ["music", "clock", "weather"], migrate: ["topBarCenterWidgets"] },
    dankBarRightWidgets: { def: ["systemTray", "clipboard", "cpuUsage", "memUsage", "notificationButton", "battery", "controlCenterButton"], migrate: ["topBarRightWidgets"] },
    dankBarWidgetOrder: { def: [] },

    appLauncherViewMode: { def: "list" },
    spotlightModalViewMode: { def: "list" },
    sortAppsAlphabetically: { def: false },

    weatherLocation: { def: "New York, NY" },
    weatherCoordinates: { def: "40.7128,-74.0060" },
    useAutoLocation: { def: false },
    weatherEnabled: { def: true },

    networkPreference: { def: "auto" },
    vpnLastConnected: { def: "" },

    iconTheme: { def: "System Default", onChange: "applyStoredIconTheme" },
    availableIconThemes: { def: ["System Default"], persist: false },
    systemDefaultIconTheme: { def: "", persist: false },
    qt5ctAvailable: { def: false, persist: false },
    qt6ctAvailable: { def: false, persist: false },
    gtkAvailable: { def: false, persist: false },

    launcherLogoMode: { def: "apps" },
    launcherLogoCustomPath: { def: "" },
    launcherLogoColorOverride: { def: "" },
    launcherLogoColorInvertOnMode: { def: false },
    launcherLogoBrightness: { def: 0.5 },
    launcherLogoContrast: { def: 1 },
    launcherLogoSizeOffset: { def: 0 },

    fontFamily: { def: "Inter Variable" },
    monoFontFamily: { def: "Fira Code" },
    fontWeight: { def: 400 },
    fontScale: { def: 1.0 },
    dankBarFontScale: { def: 1.0 },

    notepadUseMonospace: { def: true },
    notepadFontFamily: { def: "" },
    notepadFontSize: { def: 14 },
    notepadShowLineNumbers: { def: false },
    notepadTransparencyOverride: { def: -1 },
    notepadLastCustomTransparency: { def: 0.7 },

    soundsEnabled: { def: true },
    useSystemSoundTheme: { def: false },
    soundNewNotification: { def: true },
    soundVolumeChanged: { def: true },
    soundPluggedIn: { def: true },

    acMonitorTimeout: { def: 0 },
    acLockTimeout: { def: 0 },
    acSuspendTimeout: { def: 0 },
    acSuspendBehavior: { def: 0 },
    batteryMonitorTimeout: { def: 0 },
    batteryLockTimeout: { def: 0 },
    batterySuspendTimeout: { def: 0 },
    batterySuspendBehavior: { def: 0 },
    lockBeforeSuspend: { def: false },
    loginctlLockIntegration: { def: true },
    launchPrefix: { def: "" },
    brightnessDevicePins: { def: {} },

    gtkThemingEnabled: { def: false, onChange: "regenSystemThemes" },
    qtThemingEnabled: { def: false, onChange: "regenSystemThemes" },
    syncModeWithPortal: { def: true },

    showDock: { def: false },
    dockAutoHide: { def: false },
    dockGroupByApp: { def: false },
    dockOpenOnOverview: { def: false },
    dockPosition: { def: 1 },
    dockSpacing: { def: 4 },
    dockBottomGap: { def: 0 },
    dockIconSize: { def: 40 },
    dockIndicatorStyle: { def: "circle" },

    notificationOverlayEnabled: { def: false },
    dankBarAutoHide: { def: false, migrate: ["topBarAutoHide"] },
    dankBarOpenOnOverview: { def: false, migrate: ["topBarOpenOnOverview"] },
    dankBarVisible: { def: true, migrate: ["topBarVisible"] },
    overviewRows: { def: 2, persist: false },
    overviewColumns: { def: 5, persist: false },
    overviewScale: { def: 0.16, persist: false },
    dankBarSpacing: { def: 4, migrate: ["topBarSpacing"], onChange: "updateNiriLayout" },
    dankBarBottomGap: { def: 0, migrate: ["topBarBottomGap"] },
    dankBarInnerPadding: { def: 4, migrate: ["topBarInnerPadding"] },
    dankBarPosition: { def: 0, migrate: ["dankBarAtBottom", "topBarAtBottom"] },
    dankBarIsVertical: { def: false, persist: false },

    dankBarSquareCorners: { def: false, migrate: ["topBarSquareCorners"] },
    dankBarNoBackground: { def: false, migrate: ["topBarNoBackground"] },
    dankBarGothCornersEnabled: { def: false, migrate: ["topBarGothCornersEnabled"] },
    dankBarBorderEnabled: { def: false },
    dankBarBorderColor: { def: "surfaceText" },
    dankBarBorderOpacity: { def: 1.0 },
    dankBarBorderThickness: { def: 1 },

    popupGapsAuto: { def: true },
    popupGapsManual: { def: 4 },

    modalDarkenBackground: { def: true },

    lockScreenShowPowerActions: { def: true },
    enableFprint: { def: false },
    maxFprintTries: { def: 3 },
    fprintdAvailable: { def: false, persist: false },
    hideBrightnessSlider: { def: false },

    notificationTimeoutLow: { def: 5000 },
    notificationTimeoutNormal: { def: 5000 },
    notificationTimeoutCritical: { def: 0 },
    notificationPopupPosition: { def: 0 },

    osdAlwaysShowValue: { def: false },

    powerActionConfirm: { def: true },
    customPowerActionLock: { def: "" },
    customPowerActionLogout: { def: "" },
    customPowerActionSuspend: { def: "" },
    customPowerActionHibernate: { def: "" },
    customPowerActionReboot: { def: "" },
    customPowerActionPowerOff: { def: "" },

    updaterUseCustomCommand: { def: false },
    updaterCustomCommand: { def: "" },
    updaterTerminalAdditionalParams: { def: "" },

    screenPreferences: { def: {} },
    showOnLastDisplay: { def: {} }
};

function getValidKeys() {
    return Object.keys(SPEC).filter(function(k) { return SPEC[k].persist !== false; }).concat(["configVersion"]);
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
