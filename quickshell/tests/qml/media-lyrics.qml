import QtQuick
import QtTest
import Quickshell
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Modules.DankDash
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property bool recordSeekIndices: false
    property var seekIndices: []
    readonly property int lyricIndex: media.lyrics.activeIndex
    onLyricIndexChanged: {
        if (recordSeekIndices)
            seekIndices.push(lyricIndex);
    }
    readonly property string longLine: "A complete lyric line that keeps every word visible, even when the player is narrow and the sentence needs several lines to fit."
    readonly property string wordLine: "Sing <softly> & stay"
    readonly property var timed: [
        {
            t: 0,
            x: "The first line starts here"
        },
        {
            t: 10,
            x: longLine
        },
        {
            t: 20,
            x: "The next line moves into view"
        },
        {
            t: 20,
            x: "And its backing vocal stays with it"
        },
        {
            t: 30,
            x: wordLine,
            w: [
                {
                    t: 30,
                    e: 30.25,
                    x: "Sing "
                },
                {
                    t: 30.25,
                    e: 30.5,
                    x: "<softly> & "
                },
                {
                    t: 30.5,
                    e: 32.5,
                    x: "stay"
                }
            ]
        },
        {
            t: 40,
            x: "The final line is here"
        }
    ]

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        media.lyrics.backend = backend;
        media.lyrics.player = lyricsPlayer;
    }

    QtObject {
        id: lyricsPlayer
        property var presentation: media.presentation
        property QtObject activePlayer: QtObject {
            id: source
            property real position: 0
            property real rate: 1
            property int playbackState: MprisPlaybackState.Playing
            property var metadata: ({})
        }
    }

    QtObject {
        id: backend
        property int nextId: 0
        property int calls: 0
        property int cancelled: 0
        property var pending: ({})
        property var lastParams: null
        function sendRequest(method, params, callback, timeout) {
            calls++;
            lastParams = params;
            pending[++nextId] = callback;
            return nextId;
        }
        function cancelRequest(id) {
            if (pending[id])
                cancelled++;
            delete pending[id];
        }
        function respond(result) {
            root.waitFor(() => !!pending[nextId], "a lyrics request is pending");
            const callback = pending[nextId];
            delete pending[nextId];
            callback(result);
        }
    }

    TestCase {
        id: input
        when: false
        name: "media-lyrics"
    }

    FloatingWindow {
        visible: true
        implicitWidth: 900
        implicitHeight: 700
        Item {
            id: stage
            anchors.centerIn: parent
            width: 780
            height: media.implicitHeight
            MediaPlayerTab {
                id: media
                anchors.fill: parent
                live: true
            }
        }
    }

    function check(value, message) {
        if (!value)
            throw new Error(message);
    }

    function waitFor(condition, message) {
        const deadline = Date.now() + 20000;
        while (!condition()) {
            check(Date.now() < deadline, "timed out: " + message);
            input.wait(10);
        }
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

    function seekPaused(position) {
        source.position = position;
        waitFor(() => Math.abs(media.lyrics.sampleTime - position) < 0.01, "lyrics resync to " + position);
    }

    function vocal(overlay, text) {
        waitFor(() => !!find(overlay, item => item.part?.x === text), text + " is realized");
        return find(overlay, item => item.part?.x === text);
    }

    function run() {
        try {
            waitFor(() => !!media.activePlayer, "fixture player discovered");
            DMSService.capabilities = ["lyrics"];
            SettingsData.reduceMotion = true;
            SettingsData.dashOptions = {
                media: {
                    playerStyle: "bento",
                    lyrics: true
                }
            };
            MprisController.stableTitle = "Lyrics fixture";
            MprisController.stableArtist = "Fixture artist";
            MprisController.activePlayerStableLength = 180;
            media.wallpaperEnabled = false;
            media.lyricsOpen = true;
            waitFor(() => backend.calls > 0, "lyrics lookup starts");
            check(backend.calls === 1, "metadata changes produce one lookup");
            backend.respond({
                result: {
                    found: true,
                    synced: root.timed
                }
            });
            root.recordSeekIndices = true;
            source.position = 30;
            source.position = 10;
            waitFor(() => media.lyrics.activeIndex === 1, "seek lands on the second line");
            root.recordSeekIndices = false;
            check(root.seekIndices.length === 1 && root.seekIndices[0] === 1, "seek updates publish only the settled lyric line");
            check(media.lyrics.lines.length === 5 && media.lyrics.lines[2].x.includes("backing vocal"), "same-time lyrics stay together");
            waitFor(() => media.lyricsFocusTarget?.activeFocus, "lyrics receives keyboard focus");
            let overlay = media.lyricsFocusTarget;
            const line = find(overlay, item => item.text === root.longLine && item.truncated !== undefined);
            check(!!line && !line.truncated && line.lineCount > 2, "long lyrics wrap without eliding");
            input.keyClick(Qt.Key_PageDown);
            check(!overlay.following && input.findChild(overlay, "followPlayback")?.visible, "browsing pauses automatic following");
            input.findChild(overlay, "followPlayback").click();
            check(overlay.following, "follow action resumes synchronized scrolling");
            source.playbackState = MprisPlaybackState.Paused;
            check(!media.lyrics.tick.running, "paused playback has no lyric timer");
            source.playbackState = MprisPlaybackState.Playing;
            check(media.lyrics.tick.running, "resuming schedules the next line");
            source.position = 9.5;
            source.playbackState = MprisPlaybackState.Paused;
            check(Math.abs(media.lyrics.currentTime() - 9.5) < 0.05 && media.lyrics.activeIndex === 0 && !media.lyrics.tick.running, "pausing immediately after a seek retains the seek target");
            SettingsData.reduceMotion = false;
            seekPaused(30.3);
            const wordText = find(overlay, item => item.Accessible.name === root.wordLine && item.textFormat !== undefined);
            check(wordText?.textFormat === Text.StyledText && wordText.text.includes("&lt;softly&gt; &amp;"), "word highlights preserve literal lyric text");
            const wordRow = find(overlay, item => item.current && item.timedWords && item.wordProgress !== undefined);
            check(wordRow && Math.abs(wordRow.wordProgress - 0.2) < 0.01, "paused seeking restores progress within a word");
            seekPaused(31);
            check(Math.abs(wordRow.wordProgress - 0.25) < 0.01, "held words use their end timestamp");
            input.wait(40);
            check(Math.abs(wordRow.wordProgress - 0.25) < 0.01, "paused word highlights stay still");
            source.playbackState = MprisPlaybackState.Playing;
            media.lyricsOpen = false;
            waitFor(() => !media.lyricsFocusTarget, "closing releases the view");
            check(!media.lyrics.tick.running, "closing stops scheduling");
            media.lyricsOpen = true;
            waitFor(() => !!media.lyricsFocusTarget, "reopened lyrics load");
            check(backend.calls === 1 && media.lyrics.state === "ready", "reopening reuses loaded lyrics");
            media.lyrics.request();
            const stale = backend.pending[backend.nextId];
            MprisController.stableTitle = "Next track";
            waitFor(() => backend.cancelled > 0, "track change cancels old response handler");
            stale({
                result: {
                    found: true,
                    plain: "stale lyrics"
                }
            });
            check(media.lyrics.state !== "ready", "late response cannot populate a new track");
            backend.respond({
                result: {
                    found: true,
                    plain: Array(20).fill(root.longLine).join("\n")
                }
            });
            waitFor(() => !!media.lyricsFocusTarget, "plain lyrics load");
            overlay = media.lyricsFocusTarget;
            overlay.forceActiveFocus();
            input.keyClick(Qt.Key_End);
            const list = find(overlay, item => typeof item.positionViewAtEnd === "function");
            waitFor(() => list.contentY > 0, "plain lyrics scroll to the end");
            check(!media.lyrics.synced, "plain lyrics are not synchronized");
            input.keyClick(Qt.Key_Escape);
            check(!media.lyricsOpen, "Escape closes lyrics");
            media.lyricsOpen = true;
            source.metadata = {
                "xesam:asText": "Embedded text remains available offline"
            };
            media.lyrics.request();
            backend.respond({
                error: "offline"
            });
            check(media.lyrics.state === "ready" && media.lyrics.plainLines[0] === source.metadata["xesam:asText"], "network errors fall back to embedded lyrics");
            media.lyrics.request();
            const oldProviderReply = backend.pending[backend.nextId];
            const oldCalls = backend.calls;
            SettingsData.mediaLyricsProviders = [
                {
                    id: "lrclib",
                    enabled: true
                },
                {
                    id: "betterlyrics",
                    enabled: false
                },
                {
                    id: "lyricsplus",
                    enabled: true
                }
            ];
            oldProviderReply({
                result: {
                    found: true,
                    plain: "stale provider lyrics"
                }
            });
            waitFor(() => backend.calls === oldCalls + 1, "provider change requests again");
            check(JSON.stringify(backend.lastParams.providers) === '["lrclib","lyricsplus"]' && media.lyrics.state === "loading", "priority changes discard pending results and request enabled providers in order");
            SettingsData.mediaLyricsProviders = MediaOptions.lyricsProviders.map(provider => ({
                        id: provider.id,
                        enabled: false
                    }));
            waitFor(() => backend.calls === oldCalls + 2, "disabling providers requests again");
            check(backend.lastParams.providers.length === 0 && !backend.lastParams.allowNetwork, "disabling every provider requests local lyrics only");
            backend.respond({
                result: {
                    found: false
                }
            });
            check(media.lyrics.state === "ready" && !media.lyrics.synced, "embedded lyrics remain available with all providers off");
            source.playbackState = MprisPlaybackState.Paused;
            source.position = 13;
            media.lyrics.request();
            backend.respond({
                result: {
                    found: true,
                    voices: {
                        a: {
                            name: "First singer",
                            type: "person"
                        },
                        b: {
                            name: "Second singer",
                            type: "person"
                        }
                    },
                    synced: [
                        {
                            t: 0,
                            e: 2,
                            x: "Before the duet"
                        },
                        {
                            t: 10,
                            e: 18,
                            x: "Lead held",
                            voice: "a",
                            group: 1,
                            w: [
                                {
                                    t: 10,
                                    e: 14,
                                    x: "Lead "
                                },
                                {
                                    t: 14,
                                    e: 18,
                                    x: "held"
                                }
                            ]
                        },
                        {
                            t: 11,
                            e: 17,
                            x: "Echo",
                            voice: "a",
                            group: 1,
                            background: true,
                            w: [
                                {
                                    t: 11,
                                    e: 17,
                                    x: "Echo"
                                }
                            ]
                        },
                        {
                            t: 12,
                            e: 16,
                            x: "Reply",
                            voice: "b",
                            w: [
                                {
                                    t: 12,
                                    e: 16,
                                    x: "Reply"
                                }
                            ]
                        },
                        {
                            t: 20,
                            e: 22,
                            x: "After the duet",
                            voice: "b"
                        },
                        {
                            t: 25,
                            e: 28,
                            x: "The next verse",
                            voice: "a"
                        },
                        {
                            t: 30,
                            e: 36,
                            x: "Held over",
                            voice: "a"
                        },
                        {
                            t: 33,
                            e: 38,
                            x: "Starts early",
                            voice: "b"
                        },
                        {
                            t: 40,
                            e: 48,
                            x: "Overlong",
                            voice: "a"
                        },
                        {
                            t: 43,
                            e: 46,
                            x: "Same singer next",
                            voice: "a"
                        }
                    ]
                }
            });
            waitFor(() => !!media.lyricsFocusTarget && media.lyrics.synced, "duet lyrics load");
            overlay = media.lyricsFocusTarget;
            overlay.snapToCurrent();
            const leadVocal = vocal(overlay, "Lead held");
            const backingVocal = vocal(overlay, "Echo");
            const replyVocal = vocal(overlay, "Reply");
            check(leadVocal.current && backingVocal.current && replyVocal.current, "both singers and backing vocals can be active together");
            check(Math.abs(leadVocal.wordProgress - 0.75) < 0.01 && Math.abs(backingVocal.wordProgress - 1 / 3) < 0.01 && Math.abs(replyVocal.wordProgress - 0.25) < 0.01, "each voice uses its own word duration");
            check(media.lyrics.lines[1].parts.length === 2, "backing vocals remain grouped with their lead");
            seekPaused(17);
            check(leadVocal.current && !backingVocal.current && !replyVocal.current && media.lyrics.activeIndex === 2, "parts end independently without scrolling backwards");
            check(replyVocal.highlighted && replyVocal.wordProgress === 1, "completed words retain their highlight while the line stays in focus");
            seekPaused(22.5);
            const finishedLine = vocal(overlay, "After the duet");
            check(!finishedLine.current && finishedLine.highlighted, "completed line timing holds its highlight through the pause");
            seekPaused(25.1);
            check(!finishedLine.highlighted, "the old line loses its highlight when focus advances");
            seekPaused(34);
            overlay.snapToCurrent();
            const heldOver = vocal(overlay, "Held over");
            check(heldOver.highlighted, "overlapping lines from different singers stay colored together");
            seekPaused(36.5);
            check(!heldOver.highlighted, "an overlapping line loses its color once it ends, before focus advances");
            seekPaused(44);
            overlay.snapToCurrent();
            const overlong = vocal(overlay, "Overlong");
            check(overlong.part.e === 43, "a voice cannot hold a line past its own next line");
            check(!overlong.highlighted, "a stale provider end does not keep the previous line colored");
            seekPaused(13);
            check(backingVocal.current && replyVocal.current && Math.abs(replyVocal.wordProgress - 0.25) < 0.01, "seeking back restores every overlapping part");
            MprisController._syncStableMeta();
            media.lyrics.player = media;
            media.lyrics.request();
            backend.respond({
                result: {
                    found: true,
                    synced: root.timed
                }
            });
            const seekbar = find(media, item => typeof item.seekTo === "function");
            for (const target of [31, 10.3, 20.2, 31.4]) {
                seekbar.seekTo(target);
                waitFor(() => media.activePlayer.position >= target - 0.05 && media.activePlayer.position < target + 5 && Math.abs(media.lyrics.currentTime() - media.activePlayer.position) < 0.05 && media.lyrics.activeIndex === media.lyrics.indexFor(target, media.lyrics.lines), "DMS seekbar resynchronizes against real MPRIS after seeking to " + target);
            }
            media.activePlayer.pause();
            waitFor(() => !media.lyrics.playing, "real MPRIS pause reaches lyrics");
            seekbar.seekTo(30.3);
            waitFor(() => Math.abs(media.lyrics.currentTime() - 30.3) < 0.01 && media.lyrics.wordTime === 30.25, "DMS seekbar updates the current word while paused");
            media.activePlayer.play();
            waitFor(() => media.lyrics.currentTime() > 30.35 && Math.abs(media.lyrics.currentTime() - media.activePlayer.position) < 0.05, "resuming continues from the seek target");
            console.log("FIXTURE_PASS lyric lookup, seeking, word timing, overlapping vocals, stale replies and provider fallback");
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
