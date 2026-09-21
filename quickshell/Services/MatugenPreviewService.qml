pragma Singleton

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Singleton {
    id: root

    property var previews: CacheData.matugenPreviews.previews ?? ({})
    property string requestKey: ""
    property string loadedKey: CacheData.matugenPreviews.key ?? ""
    property bool failed: false

    readonly property string source: SettingsData.matugenSeedColor || Theme.getMatugenColor("source_color", Theme.primary).toString()
    readonly property string image: (!SettingsData.matugenSeedColor && Theme.rawWallpaperPath && !Theme.rawWallpaperPath.startsWith("#")) ? Theme.rawWallpaperPath : ""
    readonly property string key: source + "|" + (SettingsData.matugenContrast ?? 0) + "|" + image + "|" + SettingsData.matugenSpec
    readonly property bool ready: loadedKey === key || failed || !Theme.matugenAvailable
    readonly property var schemeOptions: {
        const mode = SessionData.isLightMode ? "light" : "dark";
        const options = [];
        for (const option of Theme.availableMatugenSchemes) {
            if (option.value === "scheme-smart" && !DMSService.matugenSmartSupported)
                continue;
            const colors = (previews[option.value] ?? previews["scheme-tonal-spot"])?.[mode];
            // a dms binary older than the tri-color preview returns the primary hex as a plain string
            const primary = typeof colors === "string" ? colors : (colors?.primary ?? Theme.primary.toString());
            options.push({
                "value": option.value,
                "label": option.label,
                "primary": primary,
                "secondary": colors?.secondary ?? primary,
                "tertiary": colors?.tertiary ?? primary
            });
        }
        return options;
    }

    function refresh() {
        if (!Theme.matugenAvailable)
            return;
        const wanted = key;
        if (wanted === loadedKey || wanted === requestKey)
            return;
        requestKey = wanted;
        failed = false;

        const args = [Proc.dmsBin, "matugen", "preview", "--source-color", source, "--contrast", String(SettingsData.matugenContrast ?? 0)];
        if (image)
            args.push("--image", image);
        if (SettingsData.matugenSpec === "2025")
            args.push("--spec", "2025");
        Proc.runCommand("", args, (output, exitCode) => {
            if (wanted !== root.requestKey)
                return;
            root.requestKey = "";
            if (exitCode !== 0) {
                root.failed = true;
                return;
            }
            try {
                root.previews = JSON.parse(output.trim());
                root.loadedKey = wanted;
                CacheData.matugenPreviews = {
                    "key": wanted,
                    "previews": root.previews
                };
                CacheData.saveCache();
            } catch (e) {
                root.failed = true;
            }
        });
    }
}
