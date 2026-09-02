import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services

Item {
    id: root

    property MprisPlayer activePlayer
    property string artUrl: ""
    property color accentColor: Theme.primary
    property string lastValidArtUrl: ""
    // Live mpris url — always valid for the current track; fallback so art is never blank.
    readonly property string rawArtUrl: {
        const p = activePlayer;
        if (!p)
            return "";
        if (p.trackArtUrl)
            return p.trackArtUrl;
        const m = p.metadata;
        return m && m["mpris:artUrl"] ? m["mpris:artUrl"].toString() : "";
    }
    readonly property string curArt: artUrl || lastValidArtUrl || rawArtUrl
    property string _prevArt: ""
    property bool _fadePending: false
    property string _srcOverride: "" // forces the live url when the resolved one fails
    readonly property string _mainSrc: _srcOverride !== "" ? _srcOverride : curArt
    readonly property int albumArtStatus: mainArt.imageStatus
    property real albumSize: Math.min(width, height) * 0.88
    property bool showAnimation: true
    property real animationScale: 1.0

    readonly property bool onScreen: visible && (Window.window?.visible ?? false)
    readonly property bool playing: activePlayer?.playbackState === MprisPlaybackState.Playing

    onActivePlayerChanged: {
        lastValidArtUrl = "";
    }

    onCurArtChanged: {
        _srcOverride = "";
        // Keep the outgoing art covering mainArt until the new art decodes, then fade —
        // hides mainArt's placeholder base so no primary circle flashes mid-load.
        if (_prevArt !== "" && _prevArt !== curArt) {
            fadeArt.imageSource = _prevArt;
            fadeArt.opacity = 1;
            _fadePending = true;
            fadeSafety.restart();
            Qt.callLater(_maybeStartFade); // catch cached (synchronous) loads
        }
        _prevArt = curArt;
    }

    function _maybeStartFade() {
        if (!_fadePending)
            return;
        if (mainArt.imageStatus !== Image.Ready && mainArt.imageStatus !== Image.Error)
            return;
        _fadePending = false;
        fadeSafety.stop();
        fadeOut.restart();
    }

    Timer {
        id: fadeSafety
        interval: 1200
        onTriggered: {
            if (root._fadePending) {
                root._fadePending = false;
                fadeOut.restart();
            }
        }
    }

    NumberAnimation {
        id: fadeOut
        target: fadeArt
        property: "opacity"
        from: 1
        to: 0
        duration: 300
        easing.type: Easing.InOutQuad
    }

    MediaBlobHalo {
        anchors.fill: parent
        z: 0
        accentColor: root.accentColor
        animationScale: root.animationScale
        playing: root.playing && root.showAnimation && root.albumArtStatus === Image.Ready
    }

    DankCircularImage {
        id: mainArt
        width: albumSize
        height: albumSize
        anchors.centerIn: parent
        z: 1
        imageSource: root._mainSrc
        fallbackIcon: "album"
        border.color: root.accentColor
        border.width: 2

        onImageStatusChanged: {
            if (imageStatus === Image.Ready && imageSource !== "")
                root.lastValidArtUrl = imageSource;
            else if (imageStatus === Image.Error && root._srcOverride === "" && root.rawArtUrl !== "" && root.rawArtUrl !== imageSource)
                root._srcOverride = root.rawArtUrl; // resolved url dead → use live mpris url
            root._maybeStartFade();
        }
    }

    // Apple Music animated cover, layered over the static art which stays as fallback.
    Loader {
        readonly property bool wantsAnimatedArt: root.onScreen && root.playing && AppleMusicArtService.animatedArtUrl !== ""

        width: albumSize
        height: albumSize
        anchors.centerIn: parent
        z: 1
        active: wantsAnimatedArt && MultimediaService.available
        source: "DankAnimatedAlbumArt.qml"

        onWantsAnimatedArtChanged: {
            if (!wantsAnimatedArt)
                return;
            MultimediaService.ensureProbed();
        }
    }

    // Outgoing art, shown on top only while fading out over the new mainArt.
    DankCircularImage {
        id: fadeArt
        width: albumSize
        height: albumSize
        anchors.centerIn: parent
        z: 2
        fallbackIcon: ""
        border.color: root.accentColor
        border.width: 2
        opacity: 0
        visible: opacity > 0
    }
}
