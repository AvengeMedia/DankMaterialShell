import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.OSD
import qs.Modules.DankDash
import qs.DankCommon.Common as DC

ShellRoot {
    id: root
    property var cover: null
    property int coverChanges: 0
    property bool checkedNewMetadata: false
    property bool previousArtWasReady: false
    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }
    TestCase {
        id: input
        when: false
        name: "media-artwork"
    }
    FloatingWindow {
        visible: true
        implicitWidth: 800
        implicitHeight: 700
        MediaPlayerTab {
            id: tab
            anchors.fill: parent
        }
    }
    MediaPlaybackOSD {
        id: osd
        modelData: Quickshell.screens[0]
        autoHideInterval: 10000
    }
    Connections {
        target: root.cover
        function onArtUrlChanged() {
            root.coverChanges++;
        }
    }
    Connections {
        target: MprisController.activePlayer
        function onTrackTitleChanged() {
            root.checkedNewMetadata = true;
            root.previousArtWasReady = TrackArtService.artReadyFor(MprisController.activePlayer);
        }
    }
    function find(item, predicate) {
        if (!item)
            return null;
        if (predicate(item))
            return item;
        for (const child of item.children ?? []) {
            const found = find(child, predicate);
            if (found)
                return found;
        }
        return null;
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
    function committed(track) {
        const player = MprisController.activePlayer;
        return player.trackTitle === "Track " + track && TrackArtService.artReadyFor(player) && cover.artUrl === TrackArtService.resolvedArtUrl;
    }
    // a rapid skip commits the previous cover for a moment, so the state has to hold before it counts as settled
    function settle(track) {
        for (let attempt = 0; attempt < 40; attempt++) {
            input.wait(100);
            if (!committed(track))
                continue;
            input.wait(200);
            if (committed(track))
                return;
        }
    }
    function checkTrack(track, channel) {
        settle(track);
        const player = MprisController.activePlayer;
        check(player.trackTitle === "Track " + track, "expected player track");
        check(TrackArtService.artReadyFor(player), "current track artwork ready on track " + track);
        check(root.cover.artUrl === TrackArtService.resolvedArtUrl, "dash uses committed artwork");
        check(MediaAccentService.artUrl === root.cover.artUrl, "accent uses displayed artwork");
        waitFor(() => {
            const channels = [MediaAccentService.accent.r, MediaAccentService.accent.g, MediaAccentService.accent.b];
            return channels[channel] > 0.6 && channels.filter((value, index) => index !== channel).every(value => value < 0.3);
        }, "accent matches cover pixels on track " + track);
        check(osd.shouldBeVisible, "transport keeps OSD open on track " + track);
        const image = root.find(root.cover, item => item.status !== undefined && item.sourceSize !== undefined);
        check(image.visible && image.retainWhileLoading, "cover stays painted during loading");
        const play = root.find(osd.contentLoader.item, item => item.checkable === true && typeof item.click === "function");
        check(!play.tooltipText, "play/pause has no tooltip");
    }
    Timer {
        interval: 100
        running: true
        onTriggered: {
            try {
                root.cover = root.find(tab, item => item.artPixelSize !== undefined);
                root.check(!!root.cover, "dash artwork component");
                for (let attempt = 0; attempt < 40 && !TrackArtService.artReadyFor(MprisController.activePlayer); attempt++)
                    input.wait(50);
                const player = MprisController.activePlayer;
                root.check(!!player, "player discovered");
                SessionData.suppressOSD = false;
                osd.show();
                input.wait(300);
                root.checkTrack(1, 0);
                root.check(root.coverChanges <= 1, "initial cover is published at most once");
                root.coverChanges = 0;
                root.checkedNewMetadata = false;
                player.next();
                root.checkTrack(2, 2);
                root.check(root.checkedNewMetadata && !root.previousArtWasReady, "previous artwork is not ready for new metadata");
                root.check(root.coverChanges === 1, "duplicate cover files do not reload dash");
                root.coverChanges = 0;
                const previous = root.find(osd.contentLoader.item, item => item.iconName === "skip_previous");
                // the previous button rewinds instead of skipping back once playback passes eight seconds
                player.position = 0;
                input.wait(50);
                previous.click();
                root.checkTrack(1, 0);
                root.check(root.coverChanges === 1, "back publishes one matching cover");
                root.coverChanges = 0;
                player.next();
                input.wait(20);
                player.next();
                root.checkTrack(3, 1);
                root.check(root.coverChanges === 1, "rapid skips publish only the latest cover");
                root.coverChanges = 0;
                player.next();
                input.wait(130);
                player.next();
                root.checkTrack(5, 2);
                const smallerArt = TrackArtService.resolvedArtUrl;
                root.check(root.coverChanges === 1, "late file completion cannot replace newer art");
                const backdrop = root.find(tab, item => typeof item.syncArt === "function" && item.artOpacity !== undefined);
                root.check(!!backdrop, "dash backdrop");
                const x = Math.floor(backdrop.width / 2);
                const y = Math.floor(backdrop.height / 2);
                root.waitFor(() => !backdrop.transitioning, "backdrop settles before the same-cover commit");
                const reference = input.grabImage(backdrop).pixel(x, y);
                const canonicalArt = TrackArtService.resolvedArtUrl;
                TrackArtService._commit(player.trackArtUrl, TrackArtService._committedArtKey, player.trackArtUrl);
                for (let sample = 0; sample < 15; sample++) {
                    input.wait(20);
                    const pixel = input.grabImage(backdrop).pixel(x, y);
                    root.check(["r", "g", "b", "a"].every(channel => Math.abs(pixel[channel] - reference[channel]) < 0.01), "same-cover crossfade preserves brightness and opacity");
                }
                TrackArtService._commit(canonicalArt, TrackArtService._committedArtKey, player.trackArtUrl);
                input.wait(300);
                player.next();
                input.wait(300);
                root.check(player.trackTitle === "Track 6" && !TrackArtService.artReadyFor(player), "unchanged old cover is not accepted after the reuse delay");
                root.checkTrack(6, 1);
                tab.visible = false;
                root.check(!backdrop.transitioning, "hidden backdrop stops its fade");
                // Chrome attaches the previous track's late, smaller cover to the new track, and the two probes finish in either order
                const largerArt = TrackArtService.resolvedArtUrl;
                const key = TrackArtService._pendingArtKey;
                const sha = url => url.slice(url.lastIndexOf("art_") + 4);
                const forgetArt = () => {
                    TrackArtService.artwork = {
                        url: "",
                        key: "",
                        source: "",
                        colors: []
                    };
                    TrackArtService._largestArt = {
                        key: "",
                        url: "",
                        side: 0
                    };
                };
                forgetArt();
                TrackArtService._artProbed(player.trackArtUrl, key, TrackArtService._requestSerial, sha(largerArt) + " 128", 0);
                root.waitFor(() => TrackArtService.resolvedArtUrl === largerArt, "first cover commits");
                TrackArtService._requestSerial++;
                TrackArtService._artProbed(player.trackArtUrl, key, TrackArtService._requestSerial, sha(smallerArt) + " 100", 0);
                root.check(TrackArtService.resolvedArtUrl === largerArt && !TrackArtService._candidateArt, "late smaller cover does not replace the current one");
                forgetArt();
                TrackArtService._artProbed(player.trackArtUrl, key, TrackArtService._requestSerial, sha(smallerArt) + " 100", 0);
                TrackArtService._artProbed("file:///superseded", key, TrackArtService._requestSerial - 1, sha(largerArt) + " 128", 0);
                root.waitFor(() => TrackArtService.resolvedArtUrl === largerArt, "larger cover wins when its probe finishes after the late cover's");
                console.log("FIXTURE_PASS artwork readiness, matching accent, no duplicate cover reload, back, rapid skips, late completion, stale previous covers and constant backdrop opacity");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
