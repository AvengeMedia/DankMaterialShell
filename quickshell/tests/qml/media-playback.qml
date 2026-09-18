import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.OSD
import qs.Modules.DankDash
import qs.DankCommon.Common as DC
import "DankCommon/Common/Contrast.js" as Contrast

ShellRoot {
    id: root
    property bool tracking: false
    property int playerLosses: 0
    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }
    TestCase {
        id: input
        when: false
        name: "media"
    }
    Connections {
        target: MprisController
        function onActivePlayerChanged() {
            if (root.tracking && !MprisController.activePlayer)
                root.playerLosses++;
        }
    }
    MediaPlaybackOSD {
        id: osd
        modelData: Quickshell.screens[0]
        autoHideInterval: 10000
    }
    DankDashPopout {
        id: dash
        triggerScreen: Quickshell.screens[0]
    }
    function check(value, message) {
        if (!value)
            throw new Error(message);
    }
    function waitFor(condition, message) {
        for (let attempt = 0; attempt < 200 && !condition(); attempt++)
            input.wait(10);
        check(condition(), message);
    }
    function find(item) {
        if (!item)
            return null;
        if (item.checkable === true && typeof item.click === "function")
            return item;
        for (const child of item.children ?? []) {
            const found = find(child);
            if (found)
                return found;
        }
        return null;
    }
    function checkAccentPairs() {
        for (let hue = 0; hue < 12; hue++) {
            for (const saturation of [0.1, 0.35, 0.6, 1]) {
                MediaAccentService._accent = Qt.hsva(hue / 12, saturation, 0.7, 1);
                const container = MediaAccentService.accentContainer;
                const onContainer = MediaAccentService.onAccentContainer;
                const label = " at hue " + hue + " saturation " + saturation;
                check(Contrast.ratio(container, onContainer) >= 4.5, "accent container pair clears 4.5:1" + label);
                check(Contrast.ratio(container, Theme.surfaceContainerHigh) >= 1.25, "accent container separates from the card" + label);
                const secondary = MediaAccentService.accentSecondaryContainer;
                check(Contrast.ratio(secondary, MediaAccentService.onAccentSecondaryContainer) >= 4.5, "accent secondary pair clears 4.5:1" + label);
                check(!Qt.colorEqual(secondary, Theme.secondaryContainer), "transport buttons follow the album, not the theme" + label);
                check(Contrast.ratio(MediaAccentService.accent, MediaAccentService.onAccent) >= 4.5, "accent foreground clears 4.5:1" + label);
            }
        }
    }
    function checkAccent(button, enabled) {
        SettingsData.dashOptions = Object.assign({}, SettingsData.dashOptions, {
            media: Object.assign({}, SettingsData.dashOptions?.media, {
                albumArtAccent: enabled
            })
        });
        input.wait(20);
        const rawSurface = osd.useVertical;
        const hasArt = enabled && MediaAccentService._accent !== null;
        const fill = rawSurface ? osd.surfaceColor : button.backgroundColor;
        const expectedFill = rawSurface ? (hasArt ? MediaAccentService._accent : Theme.primary) : (hasArt ? MediaAccentService.accentContainer : Theme.primaryContainer);
        const expectedText = rawSurface ? MediaAccentService.onAccent : MediaAccentService.onAccentContainer;
        check(Qt.colorEqual(fill, expectedFill), "play/pause follows album art preference");
        check(Qt.colorEqual(button.iconColor, expectedText), "play/pause uses matching foreground");
        if (hasArt)
            check(Contrast.ratio(expectedFill, expectedText) >= 4.5, "play/pause foreground clears 4.5:1");
    }
    Timer {
        interval: 1000
        running: true
        onTriggered: {
            try {
                const player = MprisController.activePlayer;
                root.check(!!player, "player discovered");
                root.check(MediaOptions.albumArtAccent, "album art accent defaults on");
                root.tracking = true;
                dash.requestTab("media");
                dash.dashVisible = true;
                player.next();
                input.wait(250);
                root.check(root.playerLosses === 0, "playing track transition retains player");
                root.waitFor(() => dash.shouldBeVisible, "track transition leaves dash open");
                const orientations = [];
                for (const position of [SettingsData.Position.BottomCenter, SettingsData.Position.LeftCenter]) {
                    SettingsData.osdPosition = position;
                    SessionData.suppressOSD = false;
                    osd.show();
                    root.waitFor(() => osd.shouldBeVisible && !!osd.contentLoader.item, "OSD presents at " + position);
                    orientations.push(osd.useVertical);
                    const button = root.find(osd.contentLoader.item);
                    root.check(!!button, "shared play button " + position);
                    MediaAccentService._accent = Qt.rgba(0.2, 0.7, 0.4, 1);
                    root.checkAccent(button, false);
                    root.checkAccent(button, true);
                    const wasPlaying = player.isPlaying;
                    button.click();
                    root.waitFor(() => player.isPlaying !== wasPlaying, "play/pause updates player " + position);
                    root.checkAccent(button, true);
                    root.checkAccent(button, false);
                    MediaAccentService._accent = null;
                    root.checkAccent(button, true);
                    root.check(osd.shouldBeVisible, "play/pause keeps OSD open " + position);
                    root.check(dash.shouldBeVisible, "OSD leaves dash open " + position);
                }
                root.check(orientations.includes(true) && orientations.includes(false), "both OSD layouts exercised");
                root.checkAccentPairs();
                player.togglePlaying();
                input.wait(100);
                player.next();
                input.wait(200);
                root.check(root.playerLosses === 0, "paused track transition retains player");
                player.stop();
                for (let attempt = 0; attempt < 120 && MprisController.activePlayer; attempt++)
                    input.wait(25);
                root.check(MprisController.activePlayer === null, "stopped player clears after grace");
                console.log("FIXTURE_PASS media player continuity, popout retained, album art accent in both OSD layouts");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
