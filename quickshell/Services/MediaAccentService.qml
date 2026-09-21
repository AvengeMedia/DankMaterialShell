pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.Common
import qs.Services
import "../DankCommon/Common/Contrast.js" as Contrast
import "../DankCommon/Common/Hct.js" as Hct

Singleton {
    id: root

    readonly property bool hasAccent: MediaOptions.albumArtAccent ? _accent !== null : true
    readonly property color accent: MediaOptions.albumArtAccent && _accent !== null ? _accent : Theme.primary
    readonly property var lyricsHues: _lyricsHues()
    readonly property var lyricsAccents: lyricsHues.map(color => _readableLyricColor(color))
    readonly property color lyricsGroupAccent: _readableLyricColor(_mixHues(lyricsHues[0], lyricsHues[1], lyricsHues[2]))
    readonly property real lyricsChromaMin: 36
    readonly property real lyricsContrast: 4.5

    readonly property color accentContainer: _container(Theme.primaryContainer, Theme.isLightMode ? 0.3 : 0.55, Theme.isLightMode ? 0.9 : 0.42, 1.25)
    readonly property color accentSecondaryContainer: _container(Theme.secondaryContainer, Theme.isLightMode ? 0.12 : 0.22, Theme.isLightMode ? 0.94 : 0.3, 1.08)
    readonly property color readableAccent: contrastTo(accent, Theme.onSurface, Theme.surfaceContainerHigh, 4.5)

    property color onAccent
    property color onAccentContainer
    property color onAccentSecondaryContainer

    Binding {
        target: root
        property: "onAccent"
        value: {
            if (!MediaOptions.albumArtAccent || root._accent === null)
                return Theme.onPrimary;
            const color = root._accent;
            return Contrast.ratio(color, Theme.contrastDark) >= Contrast.ratio(color, Theme.contrastLight) ? Theme.contrastDark : Theme.contrastLight;
        }
    }

    Binding {
        target: root
        property: "onAccentContainer"
        value: root._onContainer(Theme.onPrimaryContainer, 0.3, root.accentContainer)
    }

    Binding {
        target: root
        property: "onAccentSecondaryContainer"
        value: root._onContainer(Theme.onSecondaryContainer, 0.12, root.accentSecondaryContainer)
    }

    readonly property color accentHover: Theme.withAlpha(accent, 0.12)
    readonly property color accentPressed: Theme.withAlpha(accent, Theme.transparentBlurLayers ? 0.24 : 0.16)

    readonly property color accentTrack: Theme.withAlpha(accent, 0.28)
    readonly property color accentSubtle: Theme.withAlpha(accent, 0.55)

    readonly property string artUrl: TrackArtService.resolvedArtUrl
    property var _accent: _pickAccent(TrackArtService.artwork.colors)

    function _lyricsHues() {
        if (!MediaOptions.albumArtAccent)
            return [Theme.primary, Theme.tertiary, Theme.secondary];
        const base = accent;
        const neutral = base.hsvSaturation < 0.18 || base.hsvHue < 0;
        const hue = neutral ? Theme.tertiary.hsvHue : base.hsvHue;
        const saturation = Math.max(0.28, Math.min(0.6, base.hsvSaturation));
        const value = Math.max(0.78, base.hsvValue);
        const lead = neutral ? Qt.hsva(hue, saturation, value, 1) : base;
        let companion = Qt.hsva((Math.max(0, hue) + 1 / 3) % 1, saturation, value, 1);
        let score = 0;
        for (const candidate of TrackArtService.artwork.colors) {
            const difference = Math.abs(candidate.hsvHue - hue);
            const separation = Math.min(difference, 1 - difference);
            if (candidate.hsvSaturation < 0.18 || candidate.hsvValue < 0.3 || separation < 1 / 6)
                continue;
            const candidateScore = separation * candidate.hsvSaturation * candidate.hsvValue;
            if (candidateScore <= score)
                continue;
            score = candidateScore;
            companion = candidate;
        }
        const companionOffset = (companion.hsvHue - Math.max(0, hue) + 1) % 1;
        const thirdOffset = companionOffset > 0.5 ? companionOffset / 2 : (companionOffset + 1) / 2;
        const third = Qt.hsva((Math.max(0, hue) + thirdOffset) % 1, saturation, value, 1);
        return [lead, companion, third];
    }

    function _mixHues(first, second, fallback) {
        const a = Math.max(0, first.hsvHue) * 2 * Math.PI;
        const b = Math.max(0, second.hsvHue) * 2 * Math.PI;
        const x = Math.cos(a) + Math.cos(b);
        const y = Math.sin(a) + Math.sin(b);
        if (x * x + y * y < 0.0001)
            return fallback;
        const hue = (Math.atan2(y, x) / (2 * Math.PI) + 1) % 1;
        return Qt.hsva(hue, Math.max(first.hsvSaturation, second.hsvSaturation), Math.max(first.hsvValue, second.hsvValue), 1);
    }

    function contrastTo(color, toward, background, target) {
        if (Contrast.ratio(color, background) >= target)
            return color;
        let low = 0;
        let high = 1;
        for (let i = 0; i < 10; i++) {
            const amount = (low + high) / 2;
            if (Contrast.ratio(Theme.blend(color, toward, amount), background) >= target)
                high = amount;
            else
                low = amount;
        }
        return Theme.blend(color, toward, high);
    }

    function _container(fallback, saturationCap, value, cardContrast) {
        if (!MediaOptions.albumArtAccent || _accent === null)
            return fallback;
        const seed = Qt.hsva(Math.max(0, _accent.hsvHue), Math.min(_accent.hsvSaturation, saturationCap), value, 1);
        return contrastTo(seed, Theme.onSurface, Theme.surfaceContainerHigh, cardContrast);
    }

    function _onContainer(fallback, saturationCap, container) {
        if (!MediaOptions.albumArtAccent || _accent === null)
            return fallback;
        const light = Theme.isLightMode;
        const seed = Qt.hsva(Math.max(0, _accent.hsvHue), Math.min(_accent.hsvSaturation, saturationCap), light ? 0.25 : 0.95, 1);
        return contrastTo(seed, light ? Theme.contrastDark : Theme.contrastLight, container, 4.5);
    }

    // Blending toward onSurface desaturates into the onSurfaceVariant lyric text, so shift tone in HCT instead.
    function _readableLyricColor(color) {
        const background = Theme.surfaceContainerLowest;
        const hct = Hct.toHct(color);
        const chroma = Math.max(hct.chroma, lyricsChromaMin);
        const backgroundTone = Hct.toHct(background).tone;
        const light = Theme.isLightMode;
        const limit = light ? Hct.darkerTone(backgroundTone, lyricsContrast) : Hct.lighterTone(backgroundTone, lyricsContrast);
        let tone = limit < 0 ? hct.tone : light ? Math.min(hct.tone, limit) : Math.max(hct.tone, limit);
        let result = Hct.fromHct(hct.hue, chroma, tone);
        while (tone > 0 && tone < 100 && Contrast.ratio(result, background) < lyricsContrast) {
            tone += light ? -1 : 1;
            result = Hct.fromHct(hct.hue, chroma, tone);
        }
        return result;
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
