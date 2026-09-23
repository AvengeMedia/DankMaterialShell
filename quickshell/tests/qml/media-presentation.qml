import QtQuick
import QtTest
import Quickshell
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Modules.DankDash
import qs.Modules.DankDash.Media
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    TestCase {
        id: input
        when: false
        name: "media-presentation"
    }

    FloatingWindow {
        visible: true
        implicitWidth: 780
        implicitHeight: 500

        Item {
            id: viewport
            width: 780
            height: 350

            MediaPlayerTab {
                id: media
                width: parent.width
                height: implicitHeight
                contentViewport: viewport
                live: true
            }
        }
    }

    QtObject {
        id: capabilities
        property var presentation: null
        property var activePlayer: null
    }

    Component {
        id: transportProbe

        MediaTransportButton {
            player: capabilities
        }
    }

    function check(value, label) {
        if (!value)
            throw new Error(label);
    }

    function waitFor(condition, label) {
        const deadline = Date.now() + 20000;
        while (!condition()) {
            check(Date.now() < deadline, "timed out: " + label);
            input.wait(10);
        }
    }

    function waitStable(sample, label) {
        const surface = media.Window.window;
        check(!input.isPolishScheduled(surface) || input.waitForPolish(surface, 20000), label);
        const deadline = Date.now() + 20000;
        let value = sample();
        let repeats = 0;
        while (repeats < 3) {
            check(Date.now() < deadline, "timed out: " + label);
            input.wait(10);
            const current = sample();
            repeats = current === value ? repeats + 1 : 0;
            value = current;
        }
        return value;
    }

    function count(item, predicate) {
        let total = predicate(item) ? 1 : 0;
        for (const child of item.children ?? [])
            total += count(child, predicate);
        return total;
    }

    function find(item, predicate) {
        if (predicate(item))
            return item;
        for (const child of item.children ?? []) {
            const result = find(child, predicate);
            if (result)
                return result;
        }
        return null;
    }

    function run() {
        try {
            waitFor(() => !!MprisController.activePlayer, "fixture player discovered");
            const player = MprisController.activePlayer;
            SettingsData.reduceMotion = true;
            MprisController.activePlayerStableLength = 180;
            waitFor(() => find(media, item => typeof item.seekTo === "function")?.visible && find(media, item => item.mediaAction === "next" && typeof item.click === "function")?.visible && !!find(viewport, item => item.dismissible !== undefined), "playback controls and sheet loaded");
            const seekbar = find(media, item => typeof item.seekTo === "function");
            const next = find(media, item => item.mediaAction === "next" && typeof item.click === "function");
            const sheet = find(viewport, item => item.dismissible !== undefined);
            const cover = find(media, item => item.artPixelSize !== undefined);
            check(cover.artPixelSize < Math.max(cover.width, cover.height) * 2, "art decodes at the render scale, not a fixed 2x oversample");
            const height = waitStable(() => media.implicitHeight, "card height settles before the player drops");
            const position = next.mapToItem(media, 0, 0);
            media.activePlayer = null;
            check(next.visible && !next.enabled && seekbar.visible, "brief player loss preserves controls but disables actions");
            waitFor(() => next.mapToItem(media, 0, 0).y === position.y && media.implicitHeight === height, "brief player loss preserves layout");
            media.activePlayer = player;
            MprisController.activePlayerStableLength = 0;
            check(seekbar.visible && !seekbar.enabled, "duration gap retains a noninteractive timeline");
            waitFor(() => next.mapToItem(media, 0, 0).y === position.y, "duration gap does not move transport");
            MprisController.activePlayerStableLength = 180;
            MprisController.stableTitle = "A much longer title that cannot fit in the title row";
            input.wait(20);
            waitFor(() => next.mapToItem(media, 0, 0).y === position.y, "long track titles preserve transport alignment");
            const title = find(media, item => item.loop === true && item.text === MprisController.stableTitle);
            check(!!title && title.needsScrolling && !title.scrollActive, "reduced motion keeps overflowing titles still");
            check(count(title, item => item !== title && item.text === title.text) === 2, "a looping title renders its trailing copy");
            SettingsData.reduceMotion = false;
            title.scrollHoldMs = 0;
            waitFor(() => title.scrollOffset > 0, "overflowing title scrolls during playback");
            title.scrollOffset = title.maxScrollOffset - 1;
            title.stepScroll(1000);
            check(title.scrollOffset >= 0 && title.scrollOffset < title.maxScrollOffset, "a looping title wraps instead of running off");
            check(title.scrollDirection === 1, "a looping title never reverses");
            const shuffle = find(media, item => item.mediaAction === "shuffle");
            const repeat = find(media, item => item.mediaAction === "repeat");
            check(shuffle.visible && shuffle.enabled && !shuffle.checked, "a player advertising shuffle shows an unchecked toggle");
            shuffle.click();
            waitFor(() => shuffle.checked, "clicking shuffle turns it on");
            check(repeat.visible && !repeat.checked, "repeat starts unchecked");
            repeat.click();
            waitFor(() => repeat.checked, "clicking repeat turns it on");
            repeat.click();
            waitFor(() => player.loopState === MprisLoopState.Track, "the second repeat step loops one track");
            check(repeat.checked, "the second repeat step loops one track");
            repeat.click();
            waitFor(() => !repeat.checked, "the third repeat step turns looping off");
            media.live = false;
            input.wait(20);
            check(!title.scrollActive && title.scrollOffset === 0, "hidden player stops and resets scrolling");
            media.live = true;
            SettingsData.reduceMotion = true;
            media.showPanel("players");
            player.stop();
            waitFor(() => player.playbackState === MprisPlaybackState.Stopped, "player stops");
            const row = find(sheet, item => item.title === player.identity && item.selected === true);
            check(!!row && row.visible, "stopped transition keeps active player in picker");
            const rowBottom = row.mapToItem(viewport, 0, row.height).y;
            check(rowBottom <= viewport.height, "sheet stays within a shorter viewport");
            input.keyClick(Qt.Key_Escape);
            input.wait(20);
            waitFor(() => media.panel === "" && media.implicitHeight === height, "sheet dismisses without resizing card");
            media.activePlayer = null;
            check(next.visible && seekbar.visible, "player loss holds controls through the grace period");
            waitFor(() => !next.visible && !seekbar.visible, "genuine player loss eventually clears controls");
            media.activePlayer = player;
            media.showPanel("players");
            media.isSeeking = true;
            SettingsData.dashOptions = {
                media: {
                    playerStyle: "material"
                }
            };
            input.wait(30);
            check(media.playerStyle === "material" && media.panel === "" && !media.isSeeking, "style switch closes open sheet and clears seeking");
            const materialHeight = media.implicitHeight;
            media.showPanel("players");
            waitFor(() => {
                const sheet = find(viewport, item => item.dismissible !== undefined);
                return sheet?.opened && sheet.containsItem(sheet.windowFocusItem);
            }, "Material uses the shared sheet with focus");
            waitFor(() => media.implicitHeight === materialHeight, "Material sheet does not expand the card");
            input.keyClick(Qt.Key_Escape);
            input.wait(20);
            check(media.panel === "", "Material sheet dismisses");
            viewport.width = 320;
            input.wait(20);
            const materialSeekbar = find(media, item => typeof item.seekTo === "function");
            check(materialSeekbar.width > 0, "Material retains a usable timeline at narrow widths");
            viewport.width = 780;
            SettingsData.dashOptions = {
                media: {
                    playerStyle: "bento"
                }
            };
            waitFor(() => !!find(media, item => item.loop === true), "switching back restores Bento");
            media.lyricsOpen = false;
            media.playerPaneOpen = false;
            input.wait(30);
            const artView = find(media, item => item.artRadius !== undefined);
            const chrome = find(media, item => item.splitPanes !== undefined);
            const artPos = artView.mapToItem(chrome, 0, 0);
            check(Math.abs(artPos.y + artView.height / 2 - chrome.height / 2) <= chrome.height / 2, "both panes off keeps the art inside the card");
            media.playerPaneOpen = true;
            input.wait(30);
            SettingsData.dashOptions = {
                media: {
                    playerStyle: "bento",
                    lyrics: false
                }
            };
            DMSService.capabilities = ["lyrics"];
            waitFor(() => !!find(media, item => item.selectionMode === "single" && item.checkEnabled === false), "view buttons load");
            const lyricsToggle = find(media, item => item.selectionMode === "single" && item.checkEnabled === false);
            check(!lyricsToggle.visible, "lyrics option gates the button");
            SettingsData.dashOptions = {
                media: {
                    playerStyle: "bento",
                    lyrics: true
                }
            };
            input.wait(30);
            check(lyricsToggle.visible && !media.lyricsFocusTarget, "an enabled lyrics button does not load the overlay");
            media.playerPaneOpen = true;
            media.lyricsOpen = false;
            input.wait(30);
            const artworkSegment = find(lyricsToggle, item => item.visualFirst === true && typeof item.click === "function");
            const lyricsSegment = find(lyricsToggle, item => item.visualLast === true && typeof item.click === "function");
            check(!!artworkSegment && !!lyricsSegment, "both view buttons are available");
            lyricsToggle.forceActiveFocus(Qt.TabFocusReason);
            check(artworkSegment.activeFocus || lyricsSegment.activeFocus, "tab entry focuses a view button");
            input.mouseClick(lyricsSegment, lyricsSegment.width / 2, lyricsSegment.height / 2);
            input.wait(30);
            check(media.lyricsOpen && media.playerPaneOpen, "lyrics button opens lyrics over the artwork");
            media.live = false;
            media.live = true;
            check(media.lyricsOpen, "the lyrics view returns when the dash reopens");
            input.mouseClick(artworkSegment, artworkSegment.width / 2, artworkSegment.height / 2);
            input.wait(30);
            check(!media.lyricsOpen && media.playerPaneOpen, "artwork button closes only the lyrics");
            check(!artworkSegment.visualFocus && !lyricsSegment.visualFocus, "mouse selection does not restore a keyboard focus ring");
            media.playerPaneOpen = false;
            input.wait(30);
            lyricsToggle.requestFocus(false);
            check(media.cycleFocus(false), "focus advances from the group to artwork playback");
            check(find(media, item => item.focusWithin !== undefined).focusWithin, "artwork playback receives cycled focus");
            check(media.cycleFocus(true) && (artworkSegment.activeFocus || lyricsSegment.activeFocus), "backward focus returns to the group");
            media.playerPaneOpen = true;
            lyricsToggle.selectItem(1);
            waitFor(() => media.lyricsOpen && !!media.lyricsFocusTarget, "lyrics button loads the overlay");
            const wasPlaying = player.isPlaying;
            check(media.handleKeyEvent({
                key: Qt.Key_Space,
                modifiers: 0
            }), "space is handled while lyrics are open");
            waitFor(() => player.isPlaying !== wasPlaying, "non-modal lyrics let playback keys through");
            media.showPanel("players");
            input.wait(30);
            check(media.handleKeyEvent({
                key: Qt.Key_Escape,
                modifiers: 0
            }) && media.panel === "" && media.lyricsOpen, "escape closes the sheet before lyrics");
            check(media.handleKeyEvent({
                key: Qt.Key_Escape,
                modifiers: 0
            }) && !media.lyricsOpen, "escape then closes lyrics");
            check(!media.handleKeyEvent({
                key: Qt.Key_Escape,
                modifiers: 0
            }), "escape falls through once nothing is open");
            waitFor(() => !media.lyricsFocusTarget, "closing lyrics destroys the overlay");
            DMSService.capabilities = [];
            input.wait(30);
            check(!lyricsToggle.visible, "lyrics button hides against a core without the capability");
            const probe = transportProbe.createObject(viewport, {
                mediaAction: "previous"
            });
            capabilities.presentation = {
                previous: true
            };
            capabilities.activePlayer = {
                canGoPrevious: true,
                canSeek: false
            };
            check(probe.visible && probe.enabled, "an advertised control is visible and enabled");
            capabilities.presentation = {
                previous: false
            };
            capabilities.activePlayer = {
                canGoPrevious: false,
                canSeek: false
            };
            check(!probe.visible, "an unsupported control is hidden rather than greyed out");
            probe.mediaAction = "nonsense";
            check(!probe.visible && !probe.enabled && !probe.checked && probe.iconName === "", "an unknown action renders nothing");
            probe.destroy();
            console.log("FIXTURE_PASS media track gaps, stable layout, marquee lifecycle, style switching, shared sheets and lyrics");
            Qt.quit();
        } catch (error) {
            console.error("FIXTURE_FAIL", error);
            Qt.exit(1);
        }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: root.run()
    }
}
