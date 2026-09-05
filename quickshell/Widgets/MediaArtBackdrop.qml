import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.Common
import qs.Services

Item {
    id: root

    property MprisPlayer activePlayer
    property real radius: Theme.cornerRadius
    property real artOpacity: 0.7
    property real surfaceTint: 0.3
    property real stableHeight: 0

    readonly property bool pinned: root.stableHeight > 0
    readonly property real anchorHeight: root.pinned ? root.stableHeight : root.height

    signal artReady

    // Fall back to the live mpris url so the backdrop is never blank.
    readonly property string curArt: {
        const resolved = TrackArtService.resolvedArtUrl;
        if (resolved !== "")
            return resolved;
        const p = root.activePlayer;
        if (!p)
            return "";
        if (p.trackArtUrl)
            return p.trackArtUrl;
        const m = p.metadata;
        return m && m["mpris:artUrl"] ? m["mpris:artUrl"].toString() : "";
    }
    // Two layers crossfade: new art loads into the hidden one and fades in once decoded.
    property bool _showA: true

    visible: layerA.ready || layerB.ready

    onCurArtChanged: syncArt()
    Component.onCompleted: syncArt()

    function syncArt() {
        if (curArt === "")
            return;
        const front = _showA ? layerA : layerB;
        const back = _showA ? layerB : layerA;
        if (front.art == curArt)
            return;
        if (back.art == curArt) {
            if (back.ready)
                _showA = !_showA;
            return;
        }
        back.art = curArt;
    }

    // Flip only when the hidden layer holds the current art, ignoring stale Ready re-emits.
    function promote(layer) {
        const back = _showA ? layerB : layerA;
        if (layer !== back || layer.art != curArt)
            return;
        _showA = (layer === layerA);
        root.artReady();
    }

    BgBlurLayer {
        id: layerA
        front: root._showA
        onLoaded: root.promote(layerA)
    }

    BgBlurLayer {
        id: layerB
        front: !root._showA
        onLoaded: root.promote(layerB)
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.surface
        opacity: root.surfaceTint
    }

    component BgBlurLayer: ClippingRectangle {
        id: layer
        property alias art: layerImg.source
        readonly property bool ready: layerImg.status === Image.Ready && layerImg.source != ""
        property bool front: false
        signal loaded

        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        antialiasing: true
        opacity: front ? root.artOpacity : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 350
                easing.type: Easing.InOutQuad
            }
        }

        Image {
            id: layerImg
            width: Math.max(parent.width, root.anchorHeight) * 1.1
            height: width
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
            onStatusChanged: {
                if (status === Image.Ready && source != "")
                    layer.loaded();
            }
        }

        MultiEffect {
            x: (parent.width - width) / 2
            y: root.pinned ? 0 : (parent.height - height) / 2
            width: layerImg.width
            height: layerImg.height
            source: layerImg
            blurEnabled: true
            blurMax: 64
            blur: 0.8
            saturation: -0.2
            brightness: -0.25
        }
    }
}
