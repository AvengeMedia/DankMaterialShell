pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

DankIconButton {
    id: root

    required property var player
    required property string mediaAction

    readonly property var presentation: root.player.presentation
    readonly property var activePlayer: root.player.activePlayer
    readonly property bool playing: !!root.presentation?.playing
    readonly property bool repeatingTrack: root.presentation?.loopState === MprisLoopState.Track

    checkable: root.mediaAction === "shuffle" || root.mediaAction === "play" || root.mediaAction === "repeat"

    iconName: {
        switch (root.mediaAction) {
        case "shuffle":
            return "shuffle";
        case "previous":
            return "skip_previous";
        case "play":
            return root.playing ? "pause" : "play_arrow";
        case "next":
            return "skip_next";
        case "repeat":
            return root.repeatingTrack ? "repeat_one" : "repeat";
        }
        return "";
    }

    Accessible.name: {
        switch (root.mediaAction) {
        case "shuffle":
            return I18n.tr("Shuffle", "Shuffle media playback");
        case "previous":
            return I18n.tr("Previous", "button going to the previous track, page, day, month or match");
        case "play":
            return root.playing ? I18n.tr("Pause", "verb, button pausing media playback or a printer or print job") : I18n.tr("Play", "verb, media play button accessible name");
        case "next":
            return I18n.tr("Next");
        case "repeat":
            return I18n.tr("Repeat", "verb, media player repeat mode button", true);
        }
        return "";
    }

    visible: {
        switch (root.mediaAction) {
        case "shuffle":
            return !!root.presentation?.shuffle;
        case "previous":
            return !!root.presentation?.previous;
        case "play":
            return !!root.presentation?.play;
        case "next":
            return !!root.presentation?.next;
        case "repeat":
            return !!root.presentation?.repeat;
        }
        return false;
    }

    enabled: {
        switch (root.mediaAction) {
        case "shuffle":
            return !!root.activePlayer?.shuffleSupported && !!root.activePlayer?.canControl;
        case "previous":
            return !!root.activePlayer?.canGoPrevious || !!root.activePlayer?.canSeek;
        case "play":
            return !!root.activePlayer?.canTogglePlaying;
        case "next":
            return !!root.activePlayer?.canGoNext;
        case "repeat":
            return !!root.activePlayer?.loopSupported && !!root.activePlayer?.canControl;
        }
        return false;
    }

    checked: {
        switch (root.mediaAction) {
        case "shuffle":
            return !!root.presentation?.shuffleEnabled;
        case "play":
            return root.playing;
        case "repeat":
            return !!root.presentation && root.presentation.loopState !== MprisLoopState.None;
        }
        return false;
    }

    onClicked: {
        switch (root.mediaAction) {
        case "shuffle":
            root.activePlayer.shuffle = !root.activePlayer.shuffle;
            return;
        case "previous":
            MprisController.previousOrRewind();
            return;
        case "play":
            root.activePlayer.togglePlaying();
            return;
        case "next":
            MprisController.next();
            return;
        case "repeat":
            root.player.cycleLoopState();
            return;
        }
    }
}
