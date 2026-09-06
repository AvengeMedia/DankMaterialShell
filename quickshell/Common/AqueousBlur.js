const beginMarker = "# BEGIN DMS BACKGROUND BLUR\n";
const endMarker = "# END DMS BACKGROUND BLUR\n";

function rules(source, enabled, frameEnabled, protocolSupported) {
    if (typeof source !== "string")
        throw new Error("missing Aqueous rules snapshot");
    const managed = source.startsWith(beginMarker);
    let remaining = source;
    if (managed) {
        const end = source.indexOf(endMarker, beginMarker.length);
        if (end < 0)
            throw new Error("incomplete DMS blur rules block");
        remaining = source.slice(end + endMarker.length);
    }
    if (remaining.includes(beginMarker.trim()) || remaining.includes(endMarker.trim()))
        throw new Error("DMS blur rules block must occur once at the start of rules.toml");
    if (protocolSupported)
        return remaining;
    if (!enabled && !managed)
        return source;

    const firstStatement = remaining.split("\n").map(line => line.trim()).find(line => line && !line.startsWith("#"));
    if (firstStatement && !firstStatement.startsWith("["))
        throw new Error("cannot prepend DMS blur rules before root assignments");

    const excluded = [
        "dms:*:clickcatcher", "dms:*:dismiss", "dms:*-exclusion",
        "dms:frame-launcher-hover", "dms:blurwallpaper", "dms:fade-to-*",
        "dms:desktop-widget*", "dms:monitor-identify"
    ];
    if (!frameEnabled)
        excluded.push("dms:frame");
    const rule = (namespace, value) => "[[layer]]\nnamespace = \"" + namespace + "\"\nblur = " + value + "\nblur_popups = " + value + "\n\n";
    return beginMarker + excluded.map(namespace => rule(namespace, false)).join("") + rule("dms:*", enabled) + endMarker + remaining;
}
