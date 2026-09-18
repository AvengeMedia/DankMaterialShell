pragma Singleton

import Quickshell
import qs.Common

Singleton {
    id: root

    readonly property var defaults: ({
            seekbar: true,
            waveProgress: true,
            albumArtBackdrop: true,
            albumArtAccent: true,
            animatedArt: false,
            lyrics: true
        })

    readonly property string defaultPlayerStyle: "zurvan"
    readonly property var playerStyles: [
        {
            "value": "zurvan",
            "text": "Zurvan"
        },
        {
            "value": "material",
            "text": "Material"
        }
    ]

    readonly property var titleFontDefaults: ({
            zurvan: "Notable",
            material: "ui"
        })

    readonly property var stored: SettingsData.dashOptions?.media ?? ({})
    readonly property string defaultTitleFont: titleFontDefaults[stored.playerStyle ?? defaultPlayerStyle] ?? "ui"
    readonly property bool waveProgress: stored.waveProgress ?? defaults.waveProgress
    readonly property bool albumArtBackdrop: stored.albumArtBackdrop ?? defaults.albumArtBackdrop
    readonly property bool albumArtAccent: stored.albumArtAccent ?? defaults.albumArtAccent
    readonly property bool animatedArt: stored.animatedArt ?? defaults.animatedArt

    readonly property var lyricsProviderCatalog: [
        {
            id: "betterlyrics",
            text: I18n.tr("Better Lyrics", "Lyrics provider name")
        },
        {
            id: "unison",
            text: I18n.tr("Unison", "Lyrics provider name")
        },
        {
            id: "lyricsplus",
            text: I18n.tr("LyricsPlus", "Lyrics provider name")
        },
        {
            id: "lrclib",
            text: I18n.tr("LRCLIB", "Lyrics provider name")
        }
    ]
    readonly property var lyricsProviders: {
        const saved = Array.isArray(SettingsData.mediaLyricsProviders) ? SettingsData.mediaLyricsProviders : [];
        const rows = [];
        const seen = new Set();
        for (const entry of saved) {
            const provider = lyricsProviderCatalog.find(provider => provider.id === entry?.id);
            if (!provider || seen.has(provider.id))
                continue;
            seen.add(provider.id);
            rows.push({
                id: provider.id,
                text: provider.text,
                enabled: entry.enabled === true
            });
        }
        for (const provider of lyricsProviderCatalog) {
            if (!seen.has(provider.id))
                rows.push({
                    id: provider.id,
                    text: provider.text,
                    enabled: false
                });
        }
        return rows;
    }
    readonly property var enabledLyricsProviders: lyricsProviders.filter(provider => provider.enabled).map(provider => provider.id)
    readonly property string lyricsProviderOrder: lyricsProviders.map(provider => provider.id).join(",")

    function setLyricsProviderEnabled(id, enabled) {
        SettingsData.set("mediaLyricsProviders", lyricsProviders.map(provider => ({
                    id: provider.id,
                    enabled: provider.id === id ? enabled : provider.enabled
                })));
    }

    function reorderLyricsProviders(indices) {
        SettingsData.set("mediaLyricsProviders", indices.map(index => ({
                    id: lyricsProviders[index].id,
                    enabled: lyricsProviders[index].enabled
                })));
    }
}
