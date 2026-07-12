pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.Common
import qs.Services

// Accent color extracted from the current track's album art via ColorQuantizer,
// falling back to Theme.primary when no usable accent is available.
Singleton {
    id: root

    readonly property bool hasAccent: SettingsData.mediaUseAlbumArtAccent ? _accent !== null : true
    readonly property color accent: SettingsData.mediaUseAlbumArtAccent && _accent !== null ? _accent : Theme.primary

    readonly property color onAccent: SettingsData.mediaUseAlbumArtAccent && _accent !== null ? (() => {
        const lum = 0.2126 * _accent.r + 0.7152 * _accent.g + 0.0722 * _accent.b;
        return lum > 0.6 ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(1, 1, 1, 1);
    })() : Theme.onPrimary

    readonly property color accentHover: Theme.withAlpha(accent, 0.12)
    readonly property color accentPressed: Theme.withAlpha(accent, Theme.transparentBlurLayers ? 0.24 : 0.16)

    readonly property color accentTrack: Theme.withAlpha(accent, 0.28)
    readonly property color accentSubtle: Theme.withAlpha(accent, 0.55)

    // Prefer the validated url, but fall back to the live mpris art so quantization
    // starts as soon as the cover exists instead of waiting on the commit pipeline.
    readonly property string artUrl: {
        const resolved = TrackArtService.resolvedArtUrl;
        if (resolved !== "")
            return resolved;
        const p = MprisController.activePlayer;
        if (!p)
            return "";
        if (p.trackArtUrl)
            return p.trackArtUrl;
        const m = p.metadata;
        return m && m["mpris:artUrl"] ? m["mpris:artUrl"].toString() : "";
    }

    // Hold the last accent across the brief artUrl blank between tracks; never reset to primary.
    property var _accent: null

    ColorQuantizer {
        id: quantizer
        source: root.artUrl
        depth: 4
        rescaleSize: 64
        onColorsChanged: {
            // Hold last accent only across the blank-art gap; else always recompute.
            if (!colors || colors.length === 0)
                return;
            root._accent = root._pickAccent(colors);
        }
    }

    function _pickAccent(colors) {
        if (!colors || colors.length === 0)
            return null;

        let best = null;
        let bestScore = -1;
        for (let i = 0; i < colors.length; i++) {
            const c = colors[i];
            const s = c.hsvSaturation;
            const v = c.hsvValue;
            if (v < 0.22 || v > 0.96 || s < 0.22)
                continue;
            const score = s * (1 - Math.abs(v - 0.68));
            if (score > bestScore) {
                bestScore = score;
                best = c;
            }
        }

        if (best)
            return _normalize(best);

        // Monochrome art: pick a neutral tone instead of keeping the last accent.
        return _pickNeutral(colors);
    }

    function _pickNeutral(colors) {
        let best = null;
        let bestScore = -1;
        for (let i = 0; i < colors.length; i++) {
            const c = colors[i];
            const v = c.hsvValue;
            const score = (1 - Math.abs(v - 0.6)) + c.hsvSaturation * 0.5;
            if (score > bestScore) {
                bestScore = score;
                best = c;
            }
        }

        const hue = best.hsvHue < 0 ? 0 : best.hsvHue;
        const s = Math.min(best.hsvSaturation, 0.18);
        const v = Math.min(Math.max(best.hsvValue, 0.6), 0.82);
        return Qt.hsva(hue, s, v, 1);
    }

    function _normalize(c) {
        const hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        const s = Math.min(1, c.hsvSaturation * 1.05);
        const v = Math.max(c.hsvValue, 0.62);
        return Qt.hsva(hue, s, v, 1);
    }
}
