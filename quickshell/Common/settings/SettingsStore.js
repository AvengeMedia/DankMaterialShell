.pragma library

    .import "./SettingsSpec.js" as SpecModule
    .import "./SpecUtil.js" as Util

var PIN_KEYS = ["brightnessDevicePins", "wifiNetworkPins", "bluetoothDevicePins", "audioInputDevicePins", "audioOutputDevicePins"];

var SESSION_MOVED_KEYS = ["niriOutputSettings", "hyprlandOutputSettings", "activeDisplayProfile", "activeDisplayProfileModes", "desktopWidgetGridSettings", "greeterSyncPending", "greeterSyncBaseline", "lastAppliedIconTheme"];
var CACHE_MOVED_KEYS = ["browserUsageHistory", "filePickerUsageHistory"];
var SESSION_BACKED_PLUGIN_IDS = ["dankNotepadModule"];

// Superseded by desktopWidgetInstances at v4; nothing has written them since
var STALE_WIDGET_KEYS = ["desktopClockEnabled", "desktopClockStyle", "desktopClockTransparency", "desktopClockColorMode", "desktopClockCustomColor", "desktopClockShowDate", "desktopClockShowAnalogNumbers", "desktopClockShowAnalogSeconds", "desktopClockX", "desktopClockY", "desktopClockWidth", "desktopClockHeight", "desktopClockDisplayPreferences", "systemMonitorEnabled", "systemMonitorShowHeader", "systemMonitorTransparency", "systemMonitorColorMode", "systemMonitorCustomColor", "systemMonitorShowCpu", "systemMonitorShowCpuGraph", "systemMonitorShowCpuTemp", "systemMonitorShowGpuTemp", "systemMonitorGpuPciId", "systemMonitorShowMemory", "systemMonitorShowMemoryGraph", "systemMonitorShowNetwork", "systemMonitorShowNetworkGraph", "systemMonitorShowDisk", "systemMonitorShowTopProcesses", "systemMonitorTopProcessCount", "systemMonitorTopProcessSortBy", "systemMonitorGraphInterval", "systemMonitorLayoutMode", "systemMonitorX", "systemMonitorY", "systemMonitorWidth", "systemMonitorHeight", "systemMonitorDisplayPreferences", "systemMonitorVariants", "desktopWidgetPositions"];

var BAR_WIDGET_LIST_KEYS = ["leftWidgets", "centerWidgets", "rightWidgets"];

// v18: the shell-wide island settings became per-bar-config island* keys
var ISLAND_KEY_MOVES = {
    dankIslandFloating: "islandFloating",
    dankIslandUseOverlayLayer: "islandUseOverlayLayer",
    dankIslandReserveHeight: "islandReserveThickness",
    dankIslandCompactHeight: "islandCompactThickness",
    dankIslandOuterGap: "islandOuterGap",
    dankIslandHorizontalOffset: "islandAlongOffset",
    dankIslandInteractionMode: "islandInteractionMode",
    dankIslandHoverOpenDelay: "islandHoverOpenDelay",
    dankIslandHoverCloseDelay: "islandHoverCloseDelay",
    dankIslandPalette: "islandPalette",
    dankIslandTransparency: "islandTransparency",
    dankIslandCornerRadius: "islandCornerRadius",
    dankIslandHighContrast: "islandHighContrast",
    dankIslandMediaClockVisible: "islandMediaClockVisible",
    dankIslandNotificationBadgeClearOnOpen: "islandNotificationBadgeClearOnOpen",
    dankIslandNotificationExpand: "islandNotificationExpand",
    dankIslandHomeCompactTight: "islandHomeCompactTight",
    dankIslandHomeClockDisplay: "islandHomeClockDisplay",
    dankIslandHomeVolumeDisplay: "islandHomeVolumeDisplay",
    dankIslandHomeBrightnessDisplay: "islandHomeBrightnessDisplay",
    dankIslandHomeLayout: "islandHomeLayout",
    dankIslandBatteryStyle: "islandBatteryStyle",
    dankIslandSatellitesEnabled: "islandSatellitesEnabled",
    dankIslandSatellitePosition: "islandSatellitePosition",
    dankIslandSatelliteGap: "islandSatelliteGap",
    dankIslandSatelliteBackground: "islandSatelliteBackground",
    dankIslandSatelliteGothCorners: "islandSatelliteGothCorners",
    dankIslandSatelliteTransparency: "islandSatelliteTransparency",
    dankIslandSatelliteSwoopRadius: "islandSatelliteSwoopRadius",
    dankIslandReducedMotion: "islandReducedMotion",
    dankIslandSpringStiffness: "islandSpringStiffness",
    dankIslandSpringDamping: "islandSpringDamping",
    dankIslandSpringMass: "islandSpringMass"
};

function migrateBatteryPillStyle(target) {
    if (!target || typeof target !== "object" || target.batteryPillStyle === undefined)
        return;
    var pill = target.batteryPillStyle === true;
    delete target.batteryPillStyle;
    if (target.batteryStyle !== undefined && target.batteryStyle !== "icon")
        return;
    if (pill)
        target.batteryStyle = "solid";
}

function withoutInstancePositions(instances) {
    if (!Array.isArray(instances)) return instances;
    return instances.map(function (inst) {
        if (!inst || !inst.positions) return inst;
        var copy = Object.assign({}, inst);
        delete copy.positions;
        return copy;
    });
}

function withoutSessionBackedPluginState(pluginSettings) {
    if (!pluginSettings) return pluginSettings;
    var copy = Object.assign({}, pluginSettings);
    for (var i = 0; i < SESSION_BACKED_PLUGIN_IDS.length; i++) {
        delete copy[SESSION_BACKED_PLUGIN_IDS[i]];
    }
    return copy;
}

function extractSessionPayload(obj) {
    if (!obj) return null;

    var payload = {};
    for (var i = 0; i < SESSION_MOVED_KEYS.length; i++) {
        var key = SESSION_MOVED_KEYS[i];
        if (key in obj) payload[key] = obj[key];
    }

    var positions = {};
    var instances = Array.isArray(obj.desktopWidgetInstances) ? obj.desktopWidgetInstances : [];
    for (var i = 0; i < instances.length; i++) {
        var inst = instances[i];
        if (inst && inst.id && inst.positions && Object.keys(inst.positions).length > 0) {
            positions[inst.id] = inst.positions;
        }
    }
    if (Object.keys(positions).length > 0) payload.desktopWidgetInstancePositions = positions;

    var pluginState = {};
    for (var i = 0; i < SESSION_BACKED_PLUGIN_IDS.length; i++) {
        var id = SESSION_BACKED_PLUGIN_IDS[i];
        if (obj.builtInPluginSettings && obj.builtInPluginSettings[id]) {
            pluginState[id] = obj.builtInPluginSettings[id];
        }
    }
    if (Object.keys(pluginState).length > 0) payload.builtInPluginState = pluginState;

    return Object.keys(payload).length > 0 ? payload : null;
}

function extractCachePayload(obj) {
    if (!obj) return null;

    var payload = {};
    for (var i = 0; i < CACHE_MOVED_KEYS.length; i++) {
        var key = CACHE_MOVED_KEYS[i];
        if (obj[key] && Object.keys(obj[key]).length > 0) payload[key] = obj[key];
    }
    return Object.keys(payload).length > 0 ? payload : null;
}

function extractPins(obj) {
    if (!obj) return null;

    var pins = null;
    for (var i = 0; i < PIN_KEYS.length; i++) {
        var value = obj[PIN_KEYS[i]];
        if (!value || Object.keys(value).length === 0) continue;
        if (!pins) pins = {};
        pins[PIN_KEYS[i]] = value;
    }
    return pins;
}

function parse(root, jsonObj) {
    var SPEC = SpecModule.SPEC;

    if (!jsonObj) return;

    for (var k in SPEC) {
        if (k === "pluginSettings") continue;
        // Runtime-only keys are never in the JSON; resetting them here
        // would wipe values set by detection processes on every reload.
        if (SPEC[k].persist === false) continue;
        if (!(k in jsonObj)) {
            root[k] = Util.cloneDef(SPEC[k].def);
        }
    }

    for (var k in jsonObj) {
        if (!SPEC[k]) continue;
        if (k === "pluginSettings") continue;
        var raw = jsonObj[k];
        var spec = SPEC[k];
        var coerce = spec.coerce;
        root[k] = coerce ? (coerce(raw) !== undefined ? coerce(raw) : root[k]) : raw;
    }
}

function toJson(root) {
    var SPEC = SpecModule.SPEC;
    var out = {};
    for (var k in SPEC) {
        if (SPEC[k].persist === false) continue;
        if (k === "pluginSettings") continue;
        var value = root[k];
        if (k === "desktopWidgetInstances") value = withoutInstancePositions(value);
        if (k === "builtInPluginSettings") value = withoutSessionBackedPluginState(value);
        if (Util.isDefault(value, SPEC[k].def)) continue;
        out[k] = value;
    }
    out.configVersion = root.settingsConfigVersion;
    return out;
}

function migrateToVersion(obj, targetVersion) {
    if (!obj) return null;

    var settings = JSON.parse(JSON.stringify(obj));
    var currentVersion = settings.configVersion || 0;

    if (currentVersion >= targetVersion) {
        return null;
    }

    if (currentVersion < 2) {
        console.info("Migrating settings from version", currentVersion, "to version 2");

        if (settings.barConfigs === undefined) {
            var position = 0;
            if (settings.dankBarAtBottom !== undefined || settings.topBarAtBottom !== undefined) {
                var atBottom = settings.dankBarAtBottom !== undefined ? settings.dankBarAtBottom : settings.topBarAtBottom;
                position = atBottom ? 1 : 0;
            } else if (settings.dankBarPosition !== undefined) {
                position = settings.dankBarPosition;
            }

            var defaultConfig = {
                id: "default",
                name: "Main Bar",
                enabled: true,
                position: position,
                screenPreferences: ["all"],
                showOnLastDisplay: true,
                leftWidgets: settings.dankBarLeftWidgets || ["launcherButton", "workspaceSwitcher", "focusedWindow"],
                centerWidgets: settings.dankBarCenterWidgets || ["music", "clock", "weather"],
                rightWidgets: settings.dankBarRightWidgets || ["systemTray", "clipboard", "cpuUsage", "memUsage", "notificationButton", "battery", "controlCenterButton"],
                spacing: settings.dankBarSpacing !== undefined ? settings.dankBarSpacing : 4,
                innerPadding: settings.dankBarInnerPadding !== undefined ? settings.dankBarInnerPadding : 4,
                bottomGap: settings.dankBarBottomGap !== undefined ? settings.dankBarBottomGap : 0,
                transparency: settings.dankBarTransparency !== undefined ? settings.dankBarTransparency : 1.0,
                widgetTransparency: settings.dankBarWidgetTransparency !== undefined ? settings.dankBarWidgetTransparency : 1.0,
                squareCorners: settings.dankBarSquareCorners !== undefined ? settings.dankBarSquareCorners : false,
                noBackground: settings.dankBarNoBackground !== undefined ? settings.dankBarNoBackground : false,
                gothCornersEnabled: settings.dankBarGothCornersEnabled !== undefined ? settings.dankBarGothCornersEnabled : false,
                gothCornerRadiusOverride: settings.dankBarGothCornerRadiusOverride !== undefined ? settings.dankBarGothCornerRadiusOverride : false,
                gothCornerRadiusValue: settings.dankBarGothCornerRadiusValue !== undefined ? settings.dankBarGothCornerRadiusValue : 12,
                borderEnabled: settings.dankBarBorderEnabled !== undefined ? settings.dankBarBorderEnabled : false,
                borderColor: settings.dankBarBorderColor || "surfaceText",
                borderOpacity: settings.dankBarBorderOpacity !== undefined ? settings.dankBarBorderOpacity : 1.0,
                borderThickness: settings.dankBarBorderThickness !== undefined ? settings.dankBarBorderThickness : 1,
                fontScale: settings.dankBarFontScale !== undefined ? settings.dankBarFontScale : 1.0,
                autoHide: settings.dankBarAutoHide !== undefined ? settings.dankBarAutoHide : false,
                autoHideDelay: settings.dankBarAutoHideDelay !== undefined ? settings.dankBarAutoHideDelay : 250,
                openOnOverview: settings.dankBarOpenOnOverview !== undefined ? settings.dankBarOpenOnOverview : false,
                visible: settings.dankBarVisible !== undefined ? settings.dankBarVisible : true,
                popupGapsAuto: settings.popupGapsAuto !== undefined ? settings.popupGapsAuto : true,
                popupGapsManual: settings.popupGapsManual !== undefined ? settings.popupGapsManual : 4
            };

            settings.barConfigs = [defaultConfig];

            var legacyKeys = [
                "dankBarLeftWidgets", "dankBarCenterWidgets", "dankBarRightWidgets",
                "dankBarWidgetOrder", "dankBarAutoHide", "dankBarAutoHideDelay",
                "dankBarOpenOnOverview", "dankBarVisible", "dankBarSpacing",
                "dankBarBottomGap", "dankBarInnerPadding", "dankBarPosition",
                "dankBarSquareCorners", "dankBarNoBackground", "dankBarGothCornersEnabled",
                "dankBarGothCornerRadiusOverride", "dankBarGothCornerRadiusValue",
                "dankBarBorderEnabled", "dankBarBorderColor", "dankBarBorderOpacity",
                "dankBarBorderThickness", "popupGapsAuto", "popupGapsManual",
                "dankBarAtBottom", "topBarAtBottom", "dankBarTransparency", "dankBarWidgetTransparency"
            ];

            for (var i = 0; i < legacyKeys.length; i++) {
                delete settings[legacyKeys[i]];
            }

            console.info("Migrated single bar settings to barConfigs");
        }

        settings.configVersion = 2;
    }

    if (currentVersion < 3) {
        console.info("Migrating settings from version", currentVersion, "to version 3");
        console.info("Per-widget controlCenterButton config now supported via widgetData properties");
        settings.configVersion = 3;
    }

    if (currentVersion < 4) {
        console.info("Migrating settings from version", currentVersion, "to version 4");
        console.info("Migrating desktop widgets to unified desktopWidgetInstances");

        var instances = [];

        if (settings.desktopClockEnabled) {
            var clockPositions = {};
            if (settings.desktopClockX !== undefined && settings.desktopClockX >= 0) {
                clockPositions["default"] = {
                    x: settings.desktopClockX,
                    y: settings.desktopClockY,
                    width: settings.desktopClockWidth || 280,
                    height: settings.desktopClockHeight || 180
                };
            }

            instances.push({
                id: "dw_clock_primary",
                widgetType: "desktopClock",
                name: "Desktop Clock",
                enabled: true,
                config: {
                    style: settings.desktopClockStyle || "analog",
                    transparency: settings.desktopClockTransparency !== undefined ? settings.desktopClockTransparency : 0.8,
                    colorMode: settings.desktopClockColorMode || "primary",
                    customColor: settings.desktopClockCustomColor || "#ffffff",
                    showDate: settings.desktopClockShowDate !== false,
                    showAnalogNumbers: settings.desktopClockShowAnalogNumbers || false,
                    showAnalogSeconds: settings.desktopClockShowAnalogSeconds !== false,
                    displayPreferences: settings.desktopClockDisplayPreferences || ["all"]
                },
                positions: clockPositions
            });
        }

        if (settings.systemMonitorEnabled) {
            var sysmonPositions = {};
            if (settings.systemMonitorX !== undefined && settings.systemMonitorX >= 0) {
                sysmonPositions["default"] = {
                    x: settings.systemMonitorX,
                    y: settings.systemMonitorY,
                    width: settings.systemMonitorWidth || 320,
                    height: settings.systemMonitorHeight || 480
                };
            }

            instances.push({
                id: "dw_sysmon_primary",
                widgetType: "systemMonitor",
                name: "System Monitor",
                enabled: true,
                config: {
                    showHeader: settings.systemMonitorShowHeader !== false,
                    transparency: settings.systemMonitorTransparency !== undefined ? settings.systemMonitorTransparency : 0.8,
                    colorMode: settings.systemMonitorColorMode || "primary",
                    customColor: settings.systemMonitorCustomColor || "#ffffff",
                    showCpu: settings.systemMonitorShowCpu !== false,
                    showCpuGraph: settings.systemMonitorShowCpuGraph !== false,
                    showCpuTemp: settings.systemMonitorShowCpuTemp !== false,
                    showGpuTemp: settings.systemMonitorShowGpuTemp || false,
                    gpuPciId: settings.systemMonitorGpuPciId || "",
                    showMemory: settings.systemMonitorShowMemory !== false,
                    showMemoryGraph: settings.systemMonitorShowMemoryGraph !== false,
                    showNetwork: settings.systemMonitorShowNetwork !== false,
                    showNetworkGraph: settings.systemMonitorShowNetworkGraph !== false,
                    showDisk: settings.systemMonitorShowDisk !== false,
                    showTopProcesses: settings.systemMonitorShowTopProcesses || false,
                    topProcessCount: settings.systemMonitorTopProcessCount || 3,
                    topProcessSortBy: settings.systemMonitorTopProcessSortBy || "cpu",
                    layoutMode: settings.systemMonitorLayoutMode || "auto",
                    graphInterval: settings.systemMonitorGraphInterval || 60,
                    displayPreferences: settings.systemMonitorDisplayPreferences || ["all"]
                },
                positions: sysmonPositions
            });
        }

        var variants = settings.systemMonitorVariants || [];
        for (var i = 0; i < variants.length; i++) {
            var v = variants[i];
            instances.push({
                id: v.id,
                widgetType: "systemMonitor",
                name: v.name || ("System Monitor " + (i + 2)),
                enabled: true,
                config: v.config || {},
                positions: v.positions || {}
            });
        }

        settings.desktopWidgetInstances = instances;
        settings.configVersion = 4;
    }

    if (currentVersion < 5) {
        console.info("Migrating settings from version", currentVersion, "to version 5");
        console.info("Moving sensitive data (weather location, coordinates) to session.json");

        delete settings.weatherLocation;
        delete settings.weatherCoordinates;

        settings.configVersion = 5;
    }

    if (currentVersion < 6) {
        console.info("Migrating settings from version", currentVersion, "to version 6");

        if (settings.barElevationEnabled === undefined) {
            var legacyBars = Array.isArray(settings.barConfigs) ? settings.barConfigs : [];
            var hadLegacyBarShadowEnabled = false;
            for (var j = 0; j < legacyBars.length; j++) {
                var legacyIntensity = Number(legacyBars[j] && legacyBars[j].shadowIntensity);
                if (!isNaN(legacyIntensity) && legacyIntensity > 0) {
                    hadLegacyBarShadowEnabled = true;
                    break;
                }
            }
            settings.barElevationEnabled = hadLegacyBarShadowEnabled;
        }

        settings.configVersion = 6;
    }

    if (currentVersion < 11) {
        settings.configVersion = 11;
    }

    if (currentVersion < 12) {
        console.info("Migrating settings from version", currentVersion, "to version 12");
        if (settings.batteryNotificationType !== undefined) {
            settings.batteryChargeLimitNotificationType = settings.batteryNotificationType;
            settings.batteryLowNotificationType = settings.batteryNotificationType;
            settings.batteryCriticalNotificationType = settings.batteryNotificationType;
            delete settings.batteryNotificationType;
        }
        settings.configVersion = 12;
    }

    if (currentVersion < 13) {
        console.info("Migrating settings from version", currentVersion, "to version 13");
        console.info("Moving device and network pins to cache.json");

        for (var p = 0; p < PIN_KEYS.length; p++) {
            delete settings[PIN_KEYS[p]];
        }

        settings.configVersion = 13;
    }

    if (currentVersion < 14) {
        console.info("Migrating settings from version", currentVersion, "to version 14");
        console.info("Dropping keys that match defaults; settings.json now stores only changed values");

        Util.stripDefaults(settings, SpecModule.SPEC);
        settings.configVersion = 14;
    }

    if (currentVersion < 15) {
        console.info("Migrating settings from version", currentVersion, "to version 15");
        console.info("Moving machine-specific state to session.json and usage histories to cache.json");

        var movedKeys = SESSION_MOVED_KEYS.concat(CACHE_MOVED_KEYS, STALE_WIDGET_KEYS);
        for (var i = 0; i < movedKeys.length; i++) {
            delete settings[movedKeys[i]];
        }

        if (Array.isArray(settings.desktopWidgetInstances)) {
            settings.desktopWidgetInstances = withoutInstancePositions(settings.desktopWidgetInstances);
        }
        if (settings.builtInPluginSettings) {
            settings.builtInPluginSettings = withoutSessionBackedPluginState(settings.builtInPluginSettings);
        }

        settings.configVersion = 15;
    }

    if (currentVersion < 16) {
        console.info("Migrating settings from version", currentVersion, "to version 16");
        console.info("Moving Niri overview close behavior to the window focus setting");

        if (settings.closeNiriOverviewOnWindowFocus === undefined && settings.spotlightCloseNiriOverview !== undefined) {
            settings.closeNiriOverviewOnWindowFocus = settings.spotlightCloseNiriOverview;
        }
        delete settings.spotlightCloseNiriOverview;

        settings.configVersion = 16;
    }

    if (currentVersion < 17) {
        console.info("Migrating settings from version", currentVersion, "to version 17");
        console.info("Converting batteryPillStyle to batteryStyle");

        migrateBatteryPillStyle(settings);
        var bars = Array.isArray(settings.barConfigs) ? settings.barConfigs : [];
        for (var b = 0; b < bars.length; b++) {
            for (var k = 0; k < BAR_WIDGET_LIST_KEYS.length; k++) {
                var widgets = bars[b] && bars[b][BAR_WIDGET_LIST_KEYS[k]];
                if (!Array.isArray(widgets))
                    continue;
                for (var w = 0; w < widgets.length; w++)
                    migrateBatteryPillStyle(widgets[w]);
            }
        }

        settings.configVersion = 17;
    }

    if (currentVersion < 18) {
        console.info("Migrating settings from version", currentVersion, "to version 18");
        console.info("Moving the shell-wide Dank Island onto its bar config as a per-instance mode");

        var islandId = settings.dankIslandBarId;
        var islandBars = Array.isArray(settings.barConfigs) ? settings.barConfigs : [];
        for (var ib = 0; ib < islandBars.length; ib++) {
            if (!islandBars[ib] || islandBars[ib].id !== islandId)
                continue;
            islandBars[ib].island = true;
            for (var oldKey in ISLAND_KEY_MOVES) {
                if (!(oldKey in settings))
                    continue;
                islandBars[ib][ISLAND_KEY_MOVES[oldKey]] = settings[oldKey];
            }
        }
        for (var dropKey in ISLAND_KEY_MOVES)
            delete settings[dropKey];
        delete settings.dankIslandBarId;

        settings.configVersion = 18;
    }

    return settings;
}
