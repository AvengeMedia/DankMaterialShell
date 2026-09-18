import QtQuick
import QtTest
import Quickshell
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
        for (let attempt = 0; attempt < 200 && !condition(); attempt++)
            input.wait(10);
        check(condition(), label);
    }

    function waitStable(sample, label) {
        // a starved runner can hold the old layout past the sampling window below
        const surface = media.Window.window;
        check(!input.isPolishScheduled(surface) || input.waitForPolish(surface, 5000), label);
        let value = sample();
        let repeats = 0;
        for (let attempt = 0; attempt < 200 && repeats < 3; attempt++) {
            input.wait(10);
            const current = sample();
            repeats = current === value ? repeats + 1 : 0;
            value = current;
        }
        check(repeats >= 3, label);
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
            const player = MprisController.activePlayer;
            check(!!player, "fixture player discovered");
            SettingsData.reduceMotion = true;
            MprisController.activePlayerStableLength = 180;
            input.wait(30);
            const seekbar = find(media, item => typeof item.seekTo === "function");
            const next = find(media, item => item.iconName === "skip_next" && typeof item.click === "function");
            const sheet = find(viewport, item => item.dismissible !== undefined);
            check(seekbar?.visible && next?.visible && !!sheet, "playback controls and sheet loaded");
            const cover = find(media, item => item.artPixelSize !== undefined);
            check(cover.artPixelSize < Math.max(cover.width, cover.height) * 2, "art decodes at the render scale, not a fixed 2x oversample");
            const height = waitStable(() => media.implicitHeight, "card height settles before the player drops");
            const position = next.mapToItem(media, 0, 0);
            media.activePlayer = null;
            input.wait(50);
            check(next.visible && !next.enabled && seekbar.visible, "brief player loss preserves controls but disables actions");
            waitFor(() => next.mapToItem(media, 0, 0).y === position.y && media.implicitHeight === height, "brief player loss preserves layout");
            media.activePlayer = player;
            MprisController.activePlayerStableLength = 0;
            input.wait(50);
            check(seekbar.visible && !seekbar.enabled, "duration gap retains a noninteractive timeline");
            waitFor(() => next.mapToItem(media, 0, 0).y === position.y, "duration gap does not move transport");
            MprisController.activePlayerStableLength = 180;
            MprisController.stableTitle = "A much longer title that cannot fit in the title row";
            input.wait(20);
            waitFor(() => next.mapToItem(media, 0, 0).y === position.y, "long track titles preserve transport alignment");
            const title = find(media, item => item.loop === true && item.text === MprisController.stableTitle);
            check(!!title && title.needsScrolling && !title.scrollActive, "reduced motion keeps overflowing titles still");
            check(count(title, item => item !== title && item.text === title.text) === 2, "a looping title renders its trailing copy");
            check(title.layer.enabled && !!find(title, item => item.gradient !== undefined), "faded edges arm the mask");
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
            check(repeat.visible && !repeat.checked && repeat.iconName === "repeat", "repeat starts unchecked");
            repeat.click();
            waitFor(() => repeat.checked, "clicking repeat turns it on");
            check(repeat.iconName === "repeat", "the first repeat step loops the playlist");
            repeat.click();
            waitFor(() => repeat.iconName === "repeat_one", "the second repeat step shows the single-track icon");
            check(repeat.checked, "the second repeat step loops one track");
            repeat.click();
            waitFor(() => !repeat.checked, "the third repeat step turns looping off");
            check(repeat.iconName === "repeat", "the third repeat step returns to no loop");
            media.live = false;
            input.wait(20);
            check(!title.scrollActive && title.scrollOffset === 0, "hidden player stops and resets scrolling");
            media.live = true;
            SettingsData.reduceMotion = true;
            media.showPanel("players");
            player.stop();
            input.wait(80);
            const row = find(sheet, item => item.title === player.identity && item.selected === true);
            check(!!row && row.visible, "stopped transition keeps active player in picker");
            const rowBottom = row.mapToItem(viewport, 0, row.height).y;
            check(rowBottom <= viewport.height, "sheet stays within a shorter viewport");
            input.keyClick(Qt.Key_Escape);
            input.wait(20);
            waitFor(() => media.panel === "" && media.implicitHeight === height, "sheet dismisses without resizing card");
            media.activePlayer = null;
            input.wait(30);
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
            const materialPlay = find(media, item => item.iconName === "pause" || item.iconName === "play_arrow");
            const materialPrevious = find(media, item => item.iconName === "skip_previous");
            check(materialPlay.mapToItem(media, 0, 0).x < materialPrevious.mapToItem(media, 0, 0).x, "Material preserves the original button order");
            const materialHeight = media.implicitHeight;
            media.showPanel("players");
            input.wait(30);
            const materialSheet = find(viewport, item => item.dismissible !== undefined);
            check(materialSheet.opened && materialSheet.containsItem(materialSheet.windowFocusItem), "Material uses the shared sheet with focus");
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
                    playerStyle: "zurvan"
                }
            };
            input.wait(30);
            check(!!find(media, item => item.loop === true), "switching back restores Zurvan");
            media.lyricsOpen = false;
            media.playerPaneOpen = false;
            input.wait(30);
            const artView = find(media, item => item.artRadius !== undefined);
            const chrome = find(media, item => item.splitPanes !== undefined);
            const artPos = artView.mapToItem(chrome, 0, 0);
            const centeredX = (chrome.width - artView.width) / 2;
            check(Math.abs(artPos.x - centeredX) <= 1, "both panes off centers the art, x=" + artPos.x + " expected " + centeredX);
            check(Math.abs(artPos.y + artView.height / 2 - chrome.height / 2) <= chrome.height / 2, "both panes off keeps the art inside the card");
            media.playerPaneOpen = true;
            input.wait(30);
            SettingsData.dashOptions = {
                media: {
                    playerStyle: "zurvan",
                    lyrics: false
                }
            };
            DMSService.capabilities = ["lyrics"];
            input.wait(30);
            const lyricsToggle = find(media, item => item.selectionMode === "single" && item.checkEnabled === false);
            check(!!lyricsToggle && !lyricsToggle.visible, "lyrics option gates the button");
            SettingsData.dashOptions = {
                media: {
                    playerStyle: "zurvan",
                    lyrics: true
                }
            };
            input.wait(30);
            check(lyricsToggle.visible && !media.lyricsFocusTarget, "an enabled lyrics button does not load the overlay");
            media.lyricsOpen = true;
            for (const locale of ["ar", "en"]) {
                SessionData.locale = locale;
                waitFor(() => I18n.isRtl === (locale === "ar"), "locale direction updates");
                check(lyricsToggle.isSelected(1), "locale changes preserve the lyrics selection");
            }
            for (const locale of ["en", "ar"]) {
                SessionData.locale = locale;
                waitFor(() => I18n.isRtl === (locale === "ar"), "layout uses the requested text direction");
                for (const width of [780, 420, 320]) {
                    viewport.width = width;
                    media.playerPaneOpen = true;
                    media.lyricsOpen = false;
                    input.wait(30);
                    const source = find(media, item => item.panelId === "players");
                    const layout = () => {
                        const origin = source.mapToItem(media, 0, 0);
                        return media.implicitHeight + ":" + origin.x + ":" + origin.y;
                    };
                    waitStable(layout, "card settles at " + width + " in " + locale);
                    const cardHeight = media.implicitHeight;
                    const sourcePosition = source.mapToItem(media, 0, 0);
                    for (const panes of [[true, false], [true, true], [false, true], [false, false]]) {
                        media.playerPaneOpen = panes[0];
                        media.lyricsOpen = panes[1];
                        input.wait(30);
                        waitFor(() => {
                            const position = source.mapToItem(media, 0, 0);
                            return media.implicitHeight === cardHeight && position.x === sourcePosition.x && position.y === sourcePosition.y;
                        }, "view combinations keep the card height and the source in place at " + width + " in " + locale);
                        check(source.visible === (panes[0] || panes[1]), "source hides only in artwork view");
                        check(lyricsToggle.isSelected(1) === panes[1], "toggle selection follows the lyrics state");
                        check(!!media.lyricsFocusTarget === panes[1], "lyrics focus follows the visible pane");
                        check(count(media, item => item.following !== undefined && item.followSnap !== undefined) === (panes[1] ? 1 : 0), "only one lyrics overlay is loaded");
                        const artworkPosition = artView.mapToItem(media, 0, 0);
                        check(artworkPosition.x >= 0 && artworkPosition.x + artView.width <= media.width, "artwork stays inside narrow and mirrored cards");
                        const togglePosition = lyricsToggle.mapToItem(media, 0, 0);
                        check(togglePosition.x >= artworkPosition.x && togglePosition.x + lyricsToggle.width <= artworkPosition.x + artView.width, "view buttons stay inside the artwork horizontally");
                        check(togglePosition.y >= artworkPosition.y && togglePosition.y + lyricsToggle.height <= artworkPosition.y + artView.height, "view buttons stay inside the artwork vertically");
                        if (panes[0] || panes[1])
                            continue;
                        check(Math.abs(artworkPosition.x + artView.width / 2 - media.width / 2) <= 1, "artwork-only view centers the cover");
                        const artPlay = find(media, item => item.mediaAction === "play" && item.visible);
                        check(!!artPlay, "artwork view keeps a playback focus target");
                        artPlay.forceActiveFocus(Qt.TabFocusReason);
                        input.wait(20);
                        const floatingTransport = find(media, item => item.focusWithin !== undefined);
                        check(floatingTransport.opacity === 1, "keyboard focus reveals artwork playback");
                    }
                }
            }
            SessionData.locale = "en";
            viewport.width = 780;
            media.playerPaneOpen = true;
            media.lyricsOpen = false;
            input.wait(30);
            const artworkSegment = find(lyricsToggle, item => item.Accessible.name === I18n.tr("Artwork") && typeof item.click === "function");
            const lyricsSegment = find(lyricsToggle, item => item.Accessible.name === I18n.tr("Lyrics", "Media player lyrics button") && typeof item.click === "function");
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
            input.wait(30);
            check(media.lyricsOpen && !!media.lyricsFocusTarget, "lyrics button loads the overlay");
            const wasPlaying = player.isPlaying;
            check(media.handleKeyEvent({
                key: Qt.Key_Space,
                modifiers: 0
            }), "space is handled while lyrics are open");
            input.wait(50);
            check(player.isPlaying !== wasPlaying, "non-modal lyrics let playback keys through");
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
            input.wait(30);
            check(!media.lyricsFocusTarget, "closing lyrics destroys the overlay");
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
        interval: 500
        running: true
        onTriggered: root.run()
    }
}
