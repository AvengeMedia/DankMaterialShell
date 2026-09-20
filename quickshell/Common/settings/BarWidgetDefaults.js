.pragma library

var CONTROL_CENTER_GROUP_ORDER = ["network", "vpn", "bluetooth", "audio", "microphone", "brightness", "battery", "printer", "screenSharing", "idleInhibitor", "doNotDisturb"];

var DEFAULTS = {
    spacer: {
        size: 20
    },
    workspaceSwitcher: {
        workspaceIndicatorStyle: "pills",
        showWorkspaceIndex: false,
        showWorkspaceName: false,
        showWorkspacePadding: false,
        workspacePaddingCount: 3,
        showWorkspaceApps: false,
        workspaceDragReorder: true,
        maxWorkspaceIcons: 3,
        workspaceAppIconSizeOffset: 0,
        groupWorkspaceApps: true,
        groupActiveWorkspaceApps: false,
        workspaceFollowFocus: false,
        showOccupiedWorkspacesOnly: false,
        showSpecialWorkspaces: false,
        reverseScrolling: false,
        dwlShowAllTags: false,
        workspaceActiveAppHighlightEnabled: false,
        workspaceColorMode: "default",
        workspaceFocusedCustomColor: "#6750A4",
        workspaceOccupiedColorMode: "none",
        workspaceOccupiedCustomColor: "#625B71",
        workspaceUnfocusedColorMode: "default",
        workspaceUnfocusedCustomColor: "#49454E",
        workspaceUrgentColorMode: "default",
        workspaceUrgentCustomColor: "#B3261E",
        workspaceFocusedBorderEnabled: false,
        workspaceFocusedBorderColor: "primary",
        workspaceFocusedBorderCustomColor: "#6750A4",
        workspaceFocusedBorderThickness: 2,
        workspaceUnfocusedMonitorSeparateAppearance: false,
        workspaceUnfocusedMonitorColorMode: "default",
        workspaceUnfocusedMonitorFocusedCustomColor: "#6750A4",
        workspaceUnfocusedMonitorOccupiedColorMode: "none",
        workspaceUnfocusedMonitorOccupiedCustomColor: "#625B71",
        workspaceUnfocusedMonitorUnfocusedColorMode: "default",
        workspaceUnfocusedMonitorUnfocusedCustomColor: "#49454E",
        workspaceUnfocusedMonitorUrgentColorMode: "default",
        workspaceUnfocusedMonitorUrgentCustomColor: "#B3261E",
        workspaceUnfocusedMonitorBorderEnabled: false,
        workspaceUnfocusedMonitorBorderColor: "primary",
        workspaceUnfocusedMonitorBorderCustomColor: "#6750A4",
        workspaceUnfocusedMonitorBorderThickness: 2
    },
    clock: {
        clockCompactMode: false,
        clockDateOrder: "timeFirst"
    },
    music: {
        mediaSize: 1,
        mediaAdaptiveWidthEnabled: true,
        audioScrollMode: "volume"
    },
    focusedWindow: {
        focusedWindowCompactMode: false,
        focusedWindowShowIcon: true,
        focusedWindowSize: 1
    },
    runningApps: {
        runningAppsCompactMode: true,
        runningAppsGroupByApp: false,
        runningAppsCurrentWorkspace: true,
        runningAppsCurrentMonitor: false
    },
    appsDock: {
        barMaxVisibleApps: 0,
        barMaxVisibleRunningApps: 0,
        barShowOverflowBadge: true,
        runningAppsCompactMode: true,
        runningAppsCurrentWorkspace: true,
        appsDockHideIndicators: true,
        appsDockColorizeActive: false,
        appsDockActiveColorMode: "primary",
        appsDockEnlargeOnHover: false,
        appsDockEnlargePercentage: 125,
        appsDockIconSizePercentage: 125,
        appsDockSpacing: 4
    },
    systemTray: {
        trayUseInlineExpansion: false,
        trayPopupSingleLine: true,
        trayAutoOverflow: true,
        trayMaxVisibleItems: 0,
        trayIconSpacing: 0
    },
    battery: {
        showBatteryPercent: true,
        showBatteryPercentOnlyOnBattery: false,
        showBatteryTime: false,
        showBatteryTimeOnlyOnBattery: false,
        showBatteryPowerCharging: false,
        showBatteryPowerDischarging: false,
        batteryStyle: "icon"
    },
    controlCenterButton: {
        showNetworkIcon: true,
        showVpnIcon: true,
        showBluetoothIcon: true,
        showAudioIcon: true,
        showAudioPercent: false,
        showMicIcon: false,
        showMicPercent: false,
        showBrightnessIcon: false,
        showBrightnessPercent: false,
        showBatteryIcon: false,
        showPrinterIcon: false,
        showScreenSharingIcon: true,
        showIdleInhibitorIcon: false,
        showDoNotDisturbIcon: false,
        controlCenterGroupOrder: CONTROL_CENTER_GROUP_ORDER
    },
    privacyIndicator: {
        privacyShowMicIcon: false,
        privacyShowCameraIcon: false,
        privacyShowScreenShareIcon: false
    },
    keyboard_layout_name: {
        keyboardLayoutNameCompactMode: false,
        keyboardLayoutNameShowIcon: false
    },
    cpuUsage: {
        minimumWidth: true
    },
    cpuTemp: {
        minimumWidth: true
    },
    memUsage: {
        minimumWidth: true,
        showSwap: false,
        showInGb: false
    },
    gpuTemp: {
        minimumWidth: true,
        selectedGpuIndex: 0,
        pciId: ""
    },
    diskUsage: {
        minimumWidth: true,
        mountPath: "/",
        diskUsageMode: 0,
        showMountPath: true
    },
    systemUpdate: {
        hideWhenIdle: false
    }
};

// entry key -> settings.json key that held the value before config version 18
var MIGRATED_GLOBALS = {
    workspaceSwitcher: sameNames(["showWorkspaceIndex", "showWorkspaceName", "showWorkspacePadding", "workspacePaddingCount", "showWorkspaceApps", "workspaceDragReorder", "maxWorkspaceIcons", "workspaceAppIconSizeOffset", "groupWorkspaceApps", "groupActiveWorkspaceApps", "workspaceFollowFocus", "showOccupiedWorkspacesOnly", "reverseScrolling", "dwlShowAllTags", "workspaceActiveAppHighlightEnabled", "workspaceColorMode", "workspaceFocusedCustomColor", "workspaceOccupiedColorMode", "workspaceOccupiedCustomColor", "workspaceUnfocusedColorMode", "workspaceUnfocusedCustomColor", "workspaceUrgentColorMode", "workspaceUrgentCustomColor", "workspaceFocusedBorderEnabled", "workspaceFocusedBorderColor", "workspaceFocusedBorderCustomColor", "workspaceFocusedBorderThickness", "workspaceUnfocusedMonitorSeparateAppearance", "workspaceUnfocusedMonitorColorMode", "workspaceUnfocusedMonitorFocusedCustomColor", "workspaceUnfocusedMonitorOccupiedColorMode", "workspaceUnfocusedMonitorOccupiedCustomColor", "workspaceUnfocusedMonitorUnfocusedColorMode", "workspaceUnfocusedMonitorUnfocusedCustomColor", "workspaceUnfocusedMonitorUrgentColorMode", "workspaceUnfocusedMonitorUrgentCustomColor", "workspaceUnfocusedMonitorBorderEnabled", "workspaceUnfocusedMonitorBorderColor", "workspaceUnfocusedMonitorBorderCustomColor", "workspaceUnfocusedMonitorBorderThickness"]),
    clock: sameNames(["clockCompactMode"]),
    music: sameNames(["mediaSize", "mediaAdaptiveWidthEnabled", "audioScrollMode"]),
    focusedWindow: sameNames(["focusedWindowCompactMode", "focusedWindowShowIcon", "focusedWindowSize"]),
    runningApps: sameNames(["runningAppsCompactMode", "runningAppsGroupByApp", "runningAppsCurrentWorkspace", "runningAppsCurrentMonitor"]),
    appsDock: sameNames(["barMaxVisibleApps", "barMaxVisibleRunningApps", "barShowOverflowBadge", "runningAppsCompactMode", "runningAppsCurrentWorkspace", "appsDockHideIndicators", "appsDockColorizeActive", "appsDockActiveColorMode", "appsDockEnlargeOnHover", "appsDockEnlargePercentage", "appsDockIconSizePercentage"]),
    systemTray: sameNames(["trayPopupSingleLine", "trayAutoOverflow", "trayMaxVisibleItems", "trayIconSpacing"]),
    battery: sameNames(["showBatteryPercent", "showBatteryPercentOnlyOnBattery", "showBatteryTime", "showBatteryTimeOnlyOnBattery", "showBatteryPowerCharging", "showBatteryPowerDischarging", "batteryStyle"]),
    controlCenterButton: {
        showNetworkIcon: "controlCenterShowNetworkIcon",
        showVpnIcon: "controlCenterShowVpnIcon",
        showBluetoothIcon: "controlCenterShowBluetoothIcon",
        showAudioIcon: "controlCenterShowAudioIcon",
        showAudioPercent: "controlCenterShowAudioPercent",
        showMicIcon: "controlCenterShowMicIcon",
        showMicPercent: "controlCenterShowMicPercent",
        showBrightnessIcon: "controlCenterShowBrightnessIcon",
        showBrightnessPercent: "controlCenterShowBrightnessPercent",
        showBatteryIcon: "controlCenterShowBatteryIcon",
        showPrinterIcon: "controlCenterShowPrinterIcon",
        showScreenSharingIcon: "controlCenterShowScreenSharingIcon",
        showIdleInhibitorIcon: "controlCenterShowIdleInhibitorIcon",
        showDoNotDisturbIcon: "controlCenterShowDoNotDisturbIcon"
    },
    privacyIndicator: sameNames(["privacyShowMicIcon", "privacyShowCameraIcon", "privacyShowScreenShareIcon"]),
    keyboard_layout_name: sameNames(["keyboardLayoutNameCompactMode", "keyboardLayoutNameShowIcon"])
};

var LEGACY_GLOBAL_DEFAULTS = { appsDockHideIndicators: false, appsDockIconSizePercentage: 100 };

function sameNames(keys) {
    var map = {};
    for (var i = 0; i < keys.length; i++)
        map[keys[i]] = keys[i];
    return map;
}

function removedGlobals() {
    var out = [];
    for (var type in MIGRATED_GLOBALS) {
        var map = MIGRATED_GLOBALS[type];
        for (var key in map) {
            var globalKey = map[key];
            if (out.indexOf(globalKey) === -1)
                out.push(globalKey);
        }
    }
    return out;
}

function option(widgetType, data, key) {
    if (data && data[key] !== undefined)
        return data[key];
    var defaults = DEFAULTS[widgetType];
    return defaults ? defaults[key] : undefined;
}
