pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("BlurService")

    property bool compositorSupported: false
    readonly property bool available: compositorSupported
    readonly property bool enabled: available && (SettingsData.blurEnabled ?? false)

    readonly property color borderColor: {
        if (!enabled)
            return "transparent";
        const opacity = SettingsData.blurBorderOpacity ?? 0.35;
        switch (SettingsData.blurBorderColor ?? "outline") {
        case "primary":
            return Theme.withAlpha(Theme.primary, opacity);
        case "secondary":
            return Theme.withAlpha(Theme.secondary, opacity);
        case "surfaceText":
            return Theme.withAlpha(Theme.surfaceText, opacity);
        case "custom":
            return Theme.withAlpha(SettingsData.blurBorderCustomColor ?? "#ffffff", opacity);
        default:
            return Theme.withAlpha(Theme.outline, opacity);
        }
    }
    readonly property int borderWidth: enabled ? 1 : 0

    function hoverColor(baseColor, hoverAlpha) {
        if (!enabled)
            return baseColor;
        return Theme.withAlpha(baseColor, hoverAlpha ?? 0.15);
    }

    Process {
        id: blurProbe
        running: false
        command: ["dms", "blur", "check"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.compositorSupported = text.trim() === "supported";
                if (root.compositorSupported)
                    log.info("Compositor supports ext-background-effect-v1");
                else
                    log.info("Compositor does not support ext-background-effect-v1");
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                log.warn("blur probe failed with code:", exitCode);
        }
    }

    Component.onCompleted: blurProbe.running = true
}
