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

    readonly property string shotDir: Quickshell.env("DMS_FIXTURE_SHOTS")
    property bool captured: false
    property bool unexpectedReply: false
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
            for (let attempt = 0; attempt < 300 && !pending[nextId]; attempt++)
                input.wait(10);
            const callback = pending[nextId];
            if (!callback)
                throw new Error("no lyrics request is pending");
            delete pending[nextId];
            callback(result);
        }
    }

    TestCase {
        id: input
        when: false
        name: "media-lyrics"
    }

    Component {
        id: requestTimer
        Timer {
            interval: 20
            running: true
            onTriggered: root.unexpectedReply = true
        }
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
        for (let attempt = 0; attempt < 300 && !condition(); attempt++)
            input.wait(10);
        check(condition(), message);
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

    function capture(name) {
        if (!root.shotDir)
            return;
        captured = false;
        stage.grabToImage(result => {
            result.saveToFile(root.shotDir + "/lyrics-" + name + ".png");
            root.captured = true;
        });
        input.tryCompare(root, "captured", true, 3000);
    }

    function artCorners(artwork) {
        const surface = stage.parent;
        const rendered = input.grabImage(surface);
        const scale = rendered.width / surface.width;
        const origin = artwork.mapToItem(surface, 0, 0);
        const left = Math.ceil(origin.x * scale);
        const top = Math.ceil(origin.y * scale);
        const right = Math.floor((origin.x + artwork.width) * scale) - 1;
        const bottom = Math.floor((origin.y + artwork.height) * scale) - 1;
        return [[left, top], [right, top], [left, bottom], [right, bottom]].map(point => [rendered.red(point[0], point[1]), rendered.green(point[0], point[1]), rendered.blue(point[0], point[1])].join(",")).join(";");
    }

    function run() {
        try {
            check(!!media.activePlayer, "fixture player discovered");
            DMSService.capabilities = ["lyrics"];
            SettingsData.reduceMotion = true;
            SettingsData.dashOptions = {
                media: {
                    playerStyle: "zurvan",
                    lyrics: true
                }
            };
            MprisController.stableTitle = "Lyrics fixture";
            MprisController.stableArtist = "Fixture artist";
            MprisController.activePlayerStableLength = 180;
            TrackArtService.artwork = {
                url: media.activePlayer.trackArtUrl,
                key: "fixture",
                source: "fixture",
                colors: [Qt.rgba(0.89, 0.77, 0.43, 1)]
            };
            const nextButton = find(media, item => item.mediaAction === "next");
            check(!!nextButton && Qt.colorEqual(nextButton.containerColor, MediaAccentService.accentSecondaryContainer), "unchecked transport buttons follow the album accent");
            media.wallpaperEnabled = false;
            input.wait(30);
            let artwork = find(media, item => item.artRadius !== undefined);
            let corners = artCorners(artwork);
            media.lyricsOpen = true;
            input.tryCompare(backend, "calls", 1, 1500);
            check(backend.calls === 1, "metadata changes produce one lookup");
            check(JSON.stringify(backend.lastParams.providers) === '["betterlyrics","unison","lyricsplus","lrclib"]', "default provider priority reaches the backend");
            backend.respond({
                result: {
                    found: true,
                    synced: root.timed
                }
            });
            root.recordSeekIndices = true;
            source.position = 30;
            source.position = 10;
            input.wait(30);
            root.recordSeekIndices = false;
            check(root.seekIndices.length === 1 && root.seekIndices[0] === 1, "seek updates publish only the settled lyric line");
            check(media.lyrics.lines.length === 5 && media.lyrics.lines[2].x.includes("backing vocal"), "same-time lyrics stay together");
            let overlay = media.lyricsFocusTarget;
            check(overlay && overlay.activeFocus, "lyrics receives keyboard focus");
            check(overlay.width === artwork.width && overlay.height === artwork.height && overlay.radius === artwork.artRadius, "Zurvan lyrics stay within the artwork shape");
            const openCorners = artCorners(artwork);
            check(openCorners === corners, "opening lyrics leaves pixels outside the artwork untouched: " + corners + " -> " + openCorners);
            const line = find(overlay, item => item.text === root.longLine && item.truncated !== undefined);
            check(!!line && !line.truncated && line.lineCount > 2, "long lyrics wrap without eliding");
            const wrappedLineCount = line.lineCount;
            source.position = 20;
            input.wait(30);
            check(line.lineCount === wrappedLineCount, "lyric highlighting preserves line breaks");
            source.position = 10;
            input.wait(30);
            capture("zurvan");
            input.keyClick(Qt.Key_PageDown);
            input.wait(30);
            check(!overlay.following && find(overlay, item => item.text === "Follow playback")?.visible, "browsing pauses automatic following");
            find(overlay, item => item.text === "Follow playback" && typeof item.click === "function").click();
            input.wait(20);
            check(overlay.following, "follow action resumes synchronized scrolling");
            SettingsData.reduceMotion = false;
            source.position = 20;
            input.wait(Theme.expressiveDurations.expressiveDefaultSpatial + 20);
            capture("following");
            source.playbackState = MprisPlaybackState.Paused;
            input.wait(30);
            check(!media.lyrics.tick.running, "paused playback has no lyric timer");
            source.playbackState = MprisPlaybackState.Playing;
            input.wait(10);
            check(media.lyrics.tick.running, "resuming schedules the next line");
            source.position = 9.5;
            source.playbackState = MprisPlaybackState.Paused;
            input.wait(20);
            check(Math.abs(media.lyrics.currentTime() - 9.5) < 0.05 && media.lyrics.activeIndex === 0 && !media.lyrics.tick.running, "pausing immediately after a seek retains the seek target");
            source.playbackState = MprisPlaybackState.Playing;
            source.position = 0;
            input.wait(10);
            check(media.lyrics.activeIndex === 0, "seeking backwards restores the correct line");
            source.position = 30;
            input.tryCompare(media.lyrics, "wordTime", 30.25, 500);
            const wordText = find(overlay, item => item.Accessible.name === root.wordLine && item.textFormat !== undefined);
            check(wordText?.textFormat === Text.StyledText && wordText.text.includes("&lt;softly&gt; &amp;"), "word highlights preserve literal lyric text");
            source.playbackState = MprisPlaybackState.Paused;
            source.position = 30.3;
            input.wait(20);
            const wordRow = find(overlay, item => item.current && item.timedWords && item.wordProgress !== undefined);
            check(wordRow && Math.abs(wordRow.wordProgress - 0.2) < 0.01, "paused seeking restores progress within a word");
            const timedLineCount = wordText.lineCount;
            capture("words");
            source.position = 31;
            input.wait(20);
            check(Math.abs(wordRow.wordProgress - 0.25) < 0.01, "held words use their end timestamp");
            input.wait(40);
            check(Math.abs(wordRow.wordProgress - 0.25) < 0.01, "paused word highlights stay still");
            source.playbackState = MprisPlaybackState.Playing;
            const resumed = Date.now();
            waitFor(() => wordRow.wordProgress > 0.27, "word progress animates");
            const wordProgress = wordRow.wordProgress;
            // the word spans two seconds from 30.5, so progress may only advance as far as playback has
            check(wordProgress < 0.25 + (Date.now() - resumed) / 2000 + 0.05, "word progress follows playback instead of jumping");
            check(wordText.lineCount === timedLineCount, "word progress does not reflow the line");
            overlay.scrollBy(-10000);
            input.wait(20);
            const offscreenProgress = wordRow.wordProgress;
            check(!wordRow.inViewport && !wordRow.animateWords, "browsing away stops offscreen word animation");
            input.wait(80);
            check(wordRow.wordProgress === offscreenProgress, "offscreen highlights do not keep animating");
            overlay.following = true;
            overlay.snapToCurrent();
            input.wait(30);
            check(wordRow.animateWords && Math.abs(wordRow.wordProgress - (media.lyrics.currentTime() - 30.5) / 2) < 0.05, "returning to the active word samples current playback time");
            source.playbackState = MprisPlaybackState.Paused;
            source.position = 30.1;
            input.tryCompare(media.lyrics, "wordTime", 30, 100);
            source.playbackState = MprisPlaybackState.Playing;
            media.lyricsOpen = false;
            input.wait(20);
            check(!media.lyrics.tick.running && !media.lyricsFocusTarget, "closing releases the view and stops scheduling");
            media.lyricsOpen = true;
            input.wait(30);
            check(backend.calls === 1 && media.lyrics.state === "ready", "reopening reuses loaded lyrics");
            media.lyrics.request();
            const stale = backend.pending[backend.nextId];
            MprisController.stableTitle = "Next track";
            input.wait(10);
            check(backend.cancelled > 0, "track change cancels old response handler");
            stale({
                result: {
                    found: true,
                    plain: "stale lyrics"
                }
            });
            check(media.lyrics.state !== "ready", "late response cannot populate a new track");
            input.wait(DashMetrics.mediaLyricsLoadingDelay + 20);
            backend.respond({
                result: {
                    found: true,
                    plain: Array(20).fill(root.longLine).join("\n")
                }
            });
            input.wait(30);
            overlay = media.lyricsFocusTarget;
            input.keyClick(Qt.Key_End);
            input.wait(20);
            const list = find(overlay, item => typeof item.positionViewAtEnd === "function");
            check(list.contentY > 0 && !media.lyrics.synced, "plain lyrics scroll to the end");
            capture("plain");
            SettingsData.dashOptions = {
                media: {
                    playerStyle: "material",
                    lyrics: true
                }
            };
            input.wait(30);
            media.lyricsOpen = true;
            input.wait(40);
            overlay = media.lyricsFocusTarget;
            check(overlay.width > stage.width / 2, "Material gives lyrics the full header width");
            const materialLine = find(overlay, item => item.text === root.longLine && item.truncated !== undefined);
            check(materialLine && !materialLine.truncated, "Material preserves complete lyrics");
            const materialSeekbar = find(media, item => typeof item.seekTo === "function");
            check(materialSeekbar.visible && materialSeekbar.canSeek, "Material keeps the timeline available with lyrics open");
            input.mouseClick(materialSeekbar, materialSeekbar.width / 2, materialSeekbar.height / 2);
            input.tryVerify(() => media.activePlayer.position > 75, 1000, "lyrics do not intercept timeline input");
            capture("material");
            overlay.forceActiveFocus();
            input.keyClick(Qt.Key_Escape);
            input.wait(20);
            check(!media.lyricsOpen, "Escape closes lyrics");
            media.lyricsOpen = true;
            input.wait(20);
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
            input.tryCompare(backend, "calls", oldCalls + 1, 1000);
            check(JSON.stringify(backend.lastParams.providers) === '["lrclib","lyricsplus"]' && media.lyrics.state === "loading", "priority changes discard pending results and request enabled providers in order");
            SettingsData.mediaLyricsProviders = MediaOptions.lyricsProviders.map(provider => ({
                        id: provider.id,
                        enabled: false
                    }));
            input.tryCompare(backend, "calls", oldCalls + 2, 1000);
            check(backend.lastParams.providers.length === 0 && !backend.lastParams.allowNetwork, "disabling every provider requests local lyrics only");
            backend.respond({
                result: {
                    found: false
                }
            });
            check(media.lyrics.state === "ready" && !media.lyrics.synced, "embedded lyrics remain available with all providers off");
            SettingsData.dashOptions = {
                media: {
                    playerStyle: "zurvan",
                    lyrics: true,
                    artStyle: "circle"
                }
            };
            stage.width = 320;
            SessionData.locale = "ar";
            SettingsData.reduceMotion = true;
            input.wait(30);
            artwork = find(media, item => item.artRadius !== undefined);
            corners = artCorners(artwork);
            media.lyricsOpen = true;
            input.wait(30);
            overlay = media.lyricsFocusTarget;
            artwork = find(media, item => item.artRadius !== undefined);
            check(overlay.width === artwork.width && overlay.radius === artwork.width / 2, "compact circular lyrics preserve the artwork boundary");
            check(artCorners(artwork) === corners, "circular lyrics leave the artwork corners untouched");
            capture("compact-rtl");
            stage.width = 780;
            input.wait(30);
            capture("circle");
            SessionData.locale = "en";
            SettingsData.reduceMotion = false;
            SettingsData.dashOptions = {
                media: {
                    playerStyle: "zurvan",
                    lyrics: true
                }
            };
            input.wait(30);
            media.lyricsOpen = true;
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
            input.wait(30);
            overlay = media.lyricsFocusTarget;
            overlay.snapToCurrent();
            input.wait(20);
            const leadVocal = find(overlay, item => item.part?.x === "Lead held");
            const backingVocal = find(overlay, item => item.part?.x === "Echo");
            const replyVocal = find(overlay, item => item.part?.x === "Reply");
            check(leadVocal?.current && backingVocal?.current && replyVocal?.current, "both singers and backing vocals can be active together");
            check(Math.abs(leadVocal.wordProgress - 0.75) < 0.01 && Math.abs(backingVocal.wordProgress - 1 / 3) < 0.01 && Math.abs(replyVocal.wordProgress - 0.25) < 0.01, "each voice uses its own word duration");
            check(leadVocal.alignment === Text.AlignLeft && replyVocal.alignment === Text.AlignRight, "duet singers have stable opposing alignment");
            check(leadVocal.accent.toString() !== replyVocal.accent.toString() && backingVocal.accent.toString() === leadVocal.accent.toString(), "singers use distinct accents and backing vocals keep their singer's color");
            check(media.lyrics.lines[1].parts.length === 2, "backing vocals remain grouped with their lead");
            const leadText = find(leadVocal, item => item.Accessible.name === "Lead held");
            const backingText = find(backingVocal, item => item.Accessible.name === "Echo");
            check(backingText.font.pixelSize < leadText.font.pixelSize, "backing vocals use smaller text");
            capture("duet");
            const duetReplyY = replyVocal.mapToItem(overlay, 0, 0).y;
            source.position = 17;
            input.wait(20);
            check(leadVocal.current && !backingVocal.current && !replyVocal.current && media.lyrics.activeIndex === 2, "parts end independently without scrolling backwards");
            check(replyVocal.highlighted && replyVocal.wordProgress === 1, "completed words retain their highlight while the line stays in focus");
            check(Math.abs(replyVocal.mapToItem(overlay, 0, 0).y - duetReplyY) < 1, "vocals ending above the active line leave it in place");
            source.position = 18.5;
            const duetList = find(overlay, item => typeof item.positionViewAtEnd === "function");
            const replyLine = duetList.itemAtIndex(2);
            input.tryVerify(() => Math.abs(replyLine.y + replyLine.height / 2 - duetList.contentY - duetList.height / 2) < 2, 1000, "the active line centers once the overlapping line above it is done");
            source.position = 22.5;
            input.wait(20);
            const finishedLine = find(overlay, item => item.part?.x === "After the duet");
            check(!finishedLine.current && finishedLine.highlighted && finishedLine.textScale === 1, "completed line timing holds its highlight through the pause");
            source.position = 25.1;
            input.wait(20);
            check(!finishedLine.highlighted && finishedLine.textScale < 1, "the old line dims and shrinks when focus advances");
            source.position = 34;
            input.tryVerify(() => media.lyrics.sampleTime >= 33.9, 1000, "seek to 34 resynced");
            overlay.snapToCurrent();
            input.tryVerify(() => !!find(overlay, item => item.part?.x === "Held over"), 1000, "held line is realized");
            const heldOver = find(overlay, item => item.part?.x === "Held over");
            check(heldOver.highlighted, "overlapping lines from different singers stay colored together");
            source.position = 36.5;
            input.tryVerify(() => media.lyrics.sampleTime >= 36.4, 1000, "seek to 36.5 resynced");
            check(!heldOver.highlighted, "an overlapping line loses its color once it ends, before focus advances");
            source.position = 44;
            input.tryVerify(() => media.lyrics.sampleTime >= 43.9, 1000, "seek to 44 resynced");
            overlay.snapToCurrent();
            input.tryVerify(() => !!find(overlay, item => item.part?.x === "Overlong"), 1000, "overlong line is realized");
            const overlong = find(overlay, item => item.part?.x === "Overlong");
            check(overlong.part.e === 43, "a voice cannot hold a line past its own next line");
            check(!overlong.highlighted, "a stale provider end does not keep the previous line colored");
            source.position = 13;
            input.wait(20);
            check(backingVocal.current && replyVocal.current && Math.abs(replyVocal.wordProgress - 0.25) < 0.01, "seeking back restores every overlapping part");
            SessionData.locale = "ar";
            input.wait(20);
            const rtlLead = find(overlay, item => item.part?.x === "Lead held");
            const rtlReply = find(overlay, item => item.part?.x === "Reply");
            check(rtlLead.alignment === Text.AlignRight && rtlReply.alignment === Text.AlignLeft, "duet alignment mirrors in RTL: " + [I18n.isRtl, rtlLead.alignment, rtlReply.alignment]);
            check(find(rtlLead, item => item.Accessible.name === "Lead held").effectiveHorizontalAlignment === Text.AlignRight && find(rtlReply, item => item.Accessible.name === "Reply").effectiveHorizontalAlignment === Text.AlignLeft, "painted text mirrors exactly once");
            capture("duet-rtl");
            SessionData.locale = "en";
            SettingsData.dashOptions = {
                media: {
                    playerStyle: "material",
                    lyrics: true
                }
            };
            input.wait(30);
            media.lyricsOpen = true;
            input.wait(30);
            overlay = media.lyricsFocusTarget;
            check(find(overlay, item => item.part?.x === "Echo")?.current, "Material shares the same independent vocal renderer");
            overlay.snapToCurrent();
            input.wait(20);
            const materialList = find(overlay, item => typeof item.positionViewAtEnd === "function");
            const materialLead = find(overlay, item => item.part?.x === "Lead held");
            const materialReply = find(overlay, item => item.part?.x === "Reply");
            check(materialLead.mapToItem(materialList, 0, 0).y >= 0 && materialReply.mapToItem(materialList, 0, materialReply.height).y <= materialList.height, "Material keeps overlapping vocals in view when they fit together");
            capture("duet-material");
            TrackArtService.artwork = Object.assign({}, TrackArtService.artwork, {
                colors: [Qt.rgba(0.8, 0.1, 0.1, 1), Qt.rgba(0.1, 0.1, 0.8, 1)]
            });
            check(new Set(MediaAccentService.lyricsAccents.map(color => color.toString())).size === 3, "three singers keep distinct accents when artwork supplies a companion color");
            TrackArtService.artwork = Object.assign({}, TrackArtService.artwork, {
                colors: [Qt.rgba(0.5, 0.5, 0.5, 1)]
            });
            check(new Set(MediaAccentService.lyricsAccents.map(color => color.toString())).size === 3, "monochrome artwork still supplies distinct singer accents");
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
                input.wait(30);
                check(Math.abs(media.lyrics.currentTime() - media.activePlayer.position) < 0.05 && media.lyrics.activeIndex === media.lyrics.indexFor(target, media.lyrics.lines), "DMS seekbar resynchronizes against real MPRIS after forward and backward seeks");
            }
            const revisions = media.lyrics.wordRevision;
            input.wait(100);
            check(media.lyrics.wordRevision === revisions, "ordinary MPRIS progress notifications do not restart word highlights");
            const beforePause = media.lyrics.currentTime();
            media.activePlayer.pause();
            input.tryCompare(media.lyrics, "playing", false, 500);
            input.wait(30);
            check(media.lyrics.currentTime() >= beforePause - 0.05 && media.lyrics.currentTime() < beforePause + 0.15 && !media.lyrics.tick.running, "pausing freezes the current lyric clock without jumping backwards");
            seekbar.seekTo(30.3);
            input.wait(30);
            check(Math.abs(media.lyrics.currentTime() - 30.3) < 0.01 && media.lyrics.wordTime === 30.25, "DMS seekbar updates the current word while paused: " + [media.lyrics.currentTime(), media.lyrics.wordTime, media.activePlayer.position, media.lyrics.position, media.lyrics.playing]);
            media.activePlayer.play();
            input.tryCompare(media.lyrics, "playing", true, 500);
            input.wait(100);
            check(media.lyrics.currentTime() > 30.35 && Math.abs(media.lyrics.currentTime() - media.activePlayer.position) < 0.05, "resuming continues from the seek target");
            media.lyricsOpen = false;
            const requestId = "lyrics-cancellation-fixture";
            DMSService.pendingRequests[requestId] = () => root.unexpectedReply = true;
            DMSService.requestTimeouts[requestId] = requestTimer.createObject(root);
            DMSService.clipboardRequestIds[requestId] = true;
            DMSService.cancelRequest(requestId);
            check(DMSService.clipboardRequestIds[requestId], "cancelled clipboard replies retain their redaction marker");
            delete DMSService.clipboardRequestIds[requestId];
            DMSService.handleResponse({
                id: requestId,
                result: {}
            });
            input.wait(30);
            check(!root.unexpectedReply, "cancellation suppresses replies and removes timeout work");
            console.log("FIXTURE_PASS lyric wrapping, synchronized scrolling, browsing, lifecycle, stale replies and Material layout");
            Qt.quit();
        } catch (error) {
            console.error("FIXTURE_FAIL", error);
            Qt.exit(1);
        }
    }

    Timer {
        interval: 600
        running: true
        onTriggered: root.run()
    }
}
