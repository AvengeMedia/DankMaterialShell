pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services

Singleton {
    id: root

    readonly property var log: Log.scoped("LayerShell")

    function _toLayer(name) {
        switch (name) {
        case "background":
            return WlrLayer.Background;
        case "bottom":
            return WlrLayer.Bottom;
        case "top":
            return WlrLayer.Top;
        case "overlay":
            return WlrLayer.Overlay;
        }
        return undefined;
    }

    function _toName(layer) {
        switch (layer) {
        case WlrLayer.Background:
            return "background";
        case WlrLayer.Bottom:
            return "bottom";
        case WlrLayer.Top:
            return "top";
        case WlrLayer.Overlay:
            return "overlay";
        }
        return "top";
    }

    // Resolve a WlrLayer from a DMS_*_LAYER env override.
    //   name:     env var to read, e.g. "DMS_OSD_LAYER"
    //   fallback: WlrLayer used when the var is unset or unrecognized
    //   opts (optional):
    //     allow:        array of honored layer names; recognized names outside it
    //                   are treated as invalid
    //     invalidLayer: WlrLayer used for a recognized-but-disallowed value
    //                   (default: fallback)
    //     label:        context for the diagnostic, e.g. "OSDs"; omit to stay silent
    //     error:        log at error level instead of warn
    function fromEnv(name, fallback, opts) {
        const value = Quickshell.env(name);
        if (!value)
            return fallback;

        const requested = _toLayer(value);
        if (requested === undefined)
            return fallback;

        const allow = opts?.allow;
        if (!allow || allow.indexOf(value) !== -1)
            return requested;

        const invalid = opts?.invalidLayer ?? fallback;
        if (opts?.label) {
            const msg = `'${value}' layer is not valid for ${opts.label}. Defaulting to '${_toName(invalid)}' layer.`;
            if (opts?.error)
                log.error(msg);
            else
                log.warn(msg);
        }
        return invalid;
    }

    // For call sites that only need "is the override the overlay layer?".
    // Honors "overlay" (true) and bottom/background/top (false); anything else
    // returns `fallback`.
    function envUsesOverlay(name, fallback) {
        switch (Quickshell.env(name)) {
        case "overlay":
            return true;
        case "bottom":
        case "background":
        case "top":
            return false;
        default:
            return fallback;
        }
    }
}
