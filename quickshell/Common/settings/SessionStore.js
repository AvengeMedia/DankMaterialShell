.pragma library

    .import "./SessionSpec.js" as SpecModule
    .import "./SpecUtil.js" as Util

function parse(root, jsonObj) {
    var SPEC = SpecModule.SPEC;

    if (!jsonObj) return;

    for (var k in SPEC) {
        if (!(k in jsonObj)) {
            root[k] = Util.cloneDef(SPEC[k].def);
        }
    }

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
        if (Util.isDefault(root[k], SPEC[k].def)) continue;
        out[k] = root[k];
    }
    out.configVersion = root.sessionConfigVersion;
    return out;
}

function migrateToVersion(obj, targetVersion, settingsData) {
    if (!obj) return null;

    var session = JSON.parse(JSON.stringify(obj));
    var currentVersion = session.configVersion || 0;

    if (currentVersion >= targetVersion) {
        return null;
    }

    if (currentVersion < 2) {
        console.info("SessionData: Migrating session from version", currentVersion, "to version 2");
        console.info("SessionData: Importing weather location and coordinates from settings");

        if (settingsData && typeof settingsData !== "undefined") {
            if (session.weatherLocation === undefined || session.weatherLocation === "New York, NY") {
                var settingsWeatherLocation = settingsData._legacyWeatherLocation;
                if (settingsWeatherLocation && settingsWeatherLocation !== "New York, NY") {
                    session.weatherLocation = settingsWeatherLocation;
                    console.info("SessionData: Migrated weatherLocation:", settingsWeatherLocation);
                }
            }

            if (session.weatherCoordinates === undefined || session.weatherCoordinates === "40.7128,-74.0060") {
                var settingsWeatherCoordinates = settingsData._legacyWeatherCoordinates;
                if (settingsWeatherCoordinates && settingsWeatherCoordinates !== "40.7128,-74.0060") {
                    session.weatherCoordinates = settingsWeatherCoordinates;
                    console.info("SessionData: Migrated weatherCoordinates:", settingsWeatherCoordinates);
                }
            }
        }

        session.configVersion = 2;
    }

    if (currentVersion < 3) {
        console.info("SessionData: Migrating session to version 3");
        session.configVersion = 3;
    }

    if (currentVersion < 4) {
        console.info("SessionData: Migrating session to version 4");
        console.info("SessionData: Dropping keys that match defaults; session.json now stores only changed values");

        Util.stripDefaults(session, SpecModule.SPEC);
        session.configVersion = 4;
    }

    return session;
}
