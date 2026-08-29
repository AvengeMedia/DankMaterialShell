.pragma library

function readBoolOverride(envReader, names, fallbackValue) {
    for (let i = 0; i < names.length; i++) {
        const name = names[i];
        const raw = envReader(name);
        if (raw === undefined || raw === null || raw === "")
            continue;

        const normalized = String(raw).trim().toLowerCase();
        if (normalized === "1" || normalized === "true" || normalized === "yes" || normalized === "on")
            return true;
        if (normalized === "0" || normalized === "false" || normalized === "no" || normalized === "off")
            return false;

        console.warn("Invalid boolean override for", name + ":", raw, "- trying next override/fallback");
    }

    return fallbackValue;
}
