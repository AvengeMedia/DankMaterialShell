.pragma library

function classify(content, overrideMode) {
    if (overrideMode === "text" || overrideMode === "ascii")
        return overrideMode;

    const value = content || "";
    const lines = value.split("\n");
    if (lines.length >= 3)
        return "ascii";

    const drawingCharacters = value.match(/[|\\/_[\]{}()<>+=*#@%:;.-]/g) || [];
    const nonWhitespace = value.replace(/\s/g, "").length;
    if (lines.length > 1 && nonWhitespace > 0 && drawingCharacters.length / nonWhitespace > 0.16)
        return "ascii";

    return "text";
}

function lines(content) {
    return (content || "").split("\n");
}
