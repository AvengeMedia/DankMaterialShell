.pragma library

.import "./SettingsSpec.js" as SpecModule

function parse(root, jsonObj) {
    var SPEC = SpecModule.SPEC;
    for (var k in SPEC) {
        var spec = SPEC[k];
        root[k] = spec.def;
    }

    if (!jsonObj) return;

    for (var k in jsonObj) {
        if (!SPEC[k]) continue;
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
        out[k] = root[k];
    }
    out.configVersion = root.settingsConfigVersion;
    return out;
}

function migrate(root, jsonObj) {
    var SPEC = SpecModule.SPEC;
    if (!jsonObj) return;

    if (jsonObj.themeIndex !== undefined || jsonObj.themeIsDynamic !== undefined) {
        var themeNames = ["blue", "deepBlue", "purple", "green", "orange", "red", "cyan", "pink", "amber", "coral"];
        if (jsonObj.themeIsDynamic) {
            root.currentThemeName = "dynamic";
        } else if (jsonObj.themeIndex >= 0 && jsonObj.themeIndex < themeNames.length) {
            root.currentThemeName = themeNames[jsonObj.themeIndex];
        }
        console.info("Auto-migrated theme from index", jsonObj.themeIndex, "to", root.currentThemeName);
    }

    if ((jsonObj.dankBarWidgetOrder && jsonObj.dankBarWidgetOrder.length > 0) ||
        (jsonObj.topBarWidgetOrder && jsonObj.topBarWidgetOrder.length > 0)) {
        if (jsonObj.dankBarLeftWidgets === undefined && jsonObj.dankBarCenterWidgets === undefined && jsonObj.dankBarRightWidgets === undefined) {
            var widgetOrder = jsonObj.dankBarWidgetOrder || jsonObj.topBarWidgetOrder;
            root.dankBarLeftWidgets = widgetOrder.filter(function(w) { return ["launcherButton", "workspaceSwitcher", "focusedWindow"].indexOf(w) >= 0; });
            root.dankBarCenterWidgets = widgetOrder.filter(function(w) { return ["clock", "music", "weather"].indexOf(w) >= 0; });
            root.dankBarRightWidgets = widgetOrder.filter(function(w) { return ["systemTray", "clipboard", "systemResources", "notificationButton", "battery", "controlCenterButton"].indexOf(w) >= 0; });
        }
    }

    if (jsonObj.useOSLogo !== undefined) {
        root.launcherLogoMode = jsonObj.useOSLogo ? "os" : "apps";
        root.launcherLogoColorOverride = jsonObj.osLogoColorOverride !== undefined ? jsonObj.osLogoColorOverride : "";
        root.launcherLogoBrightness = jsonObj.osLogoBrightness !== undefined ? jsonObj.osLogoBrightness : 0.5;
        root.launcherLogoContrast = jsonObj.osLogoContrast !== undefined ? jsonObj.osLogoContrast : 1;
    }

    if (jsonObj.mediaCompactMode !== undefined && jsonObj.mediaSize === undefined) {
        root.mediaSize = jsonObj.mediaCompactMode ? 0 : 1;
    }

    for (var k in SPEC) {
        var spec = SPEC[k];
        if (!spec.migrate) continue;
        for (var i = 0; i < spec.migrate.length; i++) {
            var oldKey = spec.migrate[i];
            if (jsonObj[oldKey] !== undefined && jsonObj[k] === undefined) {
                var raw = jsonObj[oldKey];
                var coerce = spec.coerce;
                root[k] = coerce ? (coerce(raw) !== undefined ? coerce(raw) : root[k]) : raw;
                break;
            }
        }
    }

    if (jsonObj.dankBarAtBottom !== undefined || jsonObj.topBarAtBottom !== undefined) {
        var atBottom = jsonObj.dankBarAtBottom !== undefined ? jsonObj.dankBarAtBottom : jsonObj.topBarAtBottom;
        root.dankBarPosition = atBottom ? 1 : 0;
    }

    if (jsonObj.pluginSettings !== undefined) {
        root.pluginSettings = jsonObj.pluginSettings;
        return true;
    }

    return false;
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
                console.log("SettingsData: Removing unused key:", key);
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
