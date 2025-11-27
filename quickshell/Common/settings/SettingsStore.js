.pragma library

.import "./SettingsSpec.js" as SpecModule

function parse(root, jsonObj) {
    var SPEC = SpecModule.SPEC;
    for (var k in SPEC) {
        if (k === "pluginSettings") continue;
        var spec = SPEC[k];
        root[k] = spec.def;
    }

    if (!jsonObj) return;

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
        out[k] = root[k];
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

    return settings;
}

function cleanup(fileText) {
    var getValidKeys = SpecModule.getValidKeys;
    if (!fileText || !fileText.trim()) return;

    try {
        var settings = JSON.parse(fileText);
        var validKeys = getValidKeys();
        var needsSave = false;

        for (var key in settings) {
            if (validKeys.indexOf(key) < 0) {
                delete settings[key];
                needsSave = true;
            }
        }

        return needsSave ? JSON.stringify(settings, null, 2) : null;
    } catch (e) {
        console.warn("SettingsData: Failed to cleanup unused keys:", e.message);
        return null;
    }
}
