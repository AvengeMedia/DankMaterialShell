pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland // ! Import is needed despite what qmlls says
import qs.Common
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("BlurService")

    property bool quickshellSupported: false
    property bool compositorSupported: false
    property bool available: quickshellSupported && compositorSupported
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

    function createBlurRegion(targetWindow) {
        if (!available)
            return null;

        try {
            const region = Qt.createQmlObject(`
                import Quickshell
                Region {}
            `, targetWindow, "BlurRegion");
            targetWindow.BackgroundEffect.blurRegion = region;
            return region;
        } catch (e) {
            log.warn("Failed to create blur region:", e);
            return null;
        }
    }

    function reapplyBlurRegion(targetWindow, region) {
        if (!region || !available)
            return;
        try {
            targetWindow.BackgroundEffect.blurRegion = region;
            region.changed();
        } catch (e) {}
    }

    function destroyBlurRegion(targetWindow, region) {
        if (!region)
            return;
        try {
            targetWindow.BackgroundEffect.blurRegion = null;
        } catch (e) {}
        region.destroy();
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

    Component.onCompleted: {
        try {
            const test = Qt.createQmlObject(`
                import Quickshell
                Region { radius: 0 }
            `, root, "BlurAvailabilityTest");
            test.destroy();
            quickshellSupported = true;
            log.info("Quickshell blur support available");
            blurProbe.running = true;
        } catch (e) {
            log.info("BackgroundEffect not available - blur disabled. Requires a newer version of Quickshell.");
        }
    }
}
