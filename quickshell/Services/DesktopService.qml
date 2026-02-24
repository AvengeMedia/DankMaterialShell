pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var _cache: ({})

    function resolveIconPath(moddedAppId) {
        if (!moddedAppId)
            return "";

        if (_cache[moddedAppId] !== undefined)
            return _cache[moddedAppId];

        const result = (function() {
        // 1. Try heuristic lookup (standard)
        const entry = DesktopEntries.heuristicLookup(moddedAppId);
        let icon = Quickshell.iconPath(entry?.icon, true);
        if (icon && icon !== "")
            return icon;

        // 2. Try the appId itself as an icon name
        icon = Quickshell.iconPath(moddedAppId, true);
        if (icon && icon !== "")
            return icon;

        // 3. Try variations of the appId (lowercase, last part)
        const appIds = [moddedAppId.toLowerCase()];
        const lastPart = moddedAppId.split('.').pop();
        if (lastPart && lastPart !== moddedAppId) {
            appIds.push(lastPart);
            appIds.push(lastPart.toLowerCase());
        }

        for (const id of appIds) {
            icon = Quickshell.iconPath(id, true);
            if (icon && icon !== "")
                return icon;
        }

        // 4. Deep search in all desktop entries (if the above fail)
        // This is slow-ish but only happens once for failed icons
        const strippedId = moddedAppId.replace(/-bin$/, "").toLowerCase();
        const allEntries = DesktopEntries.applications.values;
        for (let i = 0; i < allEntries.length; i++) {
            const e = allEntries[i];
            const eId = (e.id || "").toLowerCase();
            const eName = (e.name || "").toLowerCase();
            const eExec = (e.execString || "").toLowerCase();

            if (eId.includes(strippedId) || eName.includes(strippedId) || eExec.includes(strippedId)) {
                icon = Quickshell.iconPath(e.icon, true);
                if (icon && icon !== "")
                    return icon;
            }
        }

        // 5. Nix/Guix specific store check (as a last resort)
        for (const appId of appIds) {
            let execPath = entry?.execString?.replace(/\/bin.*/, "");
            if (!execPath)
                continue;

            if (execPath.startsWith("/nix/store/") || execPath.startsWith("/gnu/store/")) {
                const basePath = execPath;
                const sizes = ["256x256", "128x128", "64x64", "48x48", "32x32", "24x24", "16x16"];

                let iconPath = `${basePath}/share/icons/hicolor/scalable/apps/${appId}.svg`;
                icon = Quickshell.iconPath(iconPath, true);
                if (icon && icon !== "")
                    return icon;

                for (const size of sizes) {
                    iconPath = `${basePath}/share/icons/hicolor/${size}/apps/${appId}.png`;
                    icon = Quickshell.iconPath(iconPath, true);
                    if (icon && icon !== "")
                        return icon;
                }
            }
        }

        return "";
        })();

        _cache[moddedAppId] = result;
        return result;
    }
}
