import QtQuick
import QtQuick.Shapes
import Quickshell.Services.Mpris
import qs.Common
import qs.Services

Item {
    id: root

    property MprisPlayer activePlayer
    property string artUrl: (activePlayer?.trackArtUrl) || ""
    property string lastValidArtUrl: ""
    property alias albumArtStatus: albumArt.imageStatus
    property real albumSize: Math.min(width, height) * 0.88
    property bool showAnimation: true
    property real animationScale: 1.0

    onArtUrlChanged: {
        if (artUrl && albumArt.status !== Image.Error) {
            lastValidArtUrl = artUrl;
        }
    }

    Loader {
        active: activePlayer?.playbackState === MprisPlaybackState.Playing && showAnimation
        sourceComponent: Component {
            Ref {
                service: CavaService
            }
        }
    }

    Shape {
        id: morphingBlob
        width: parent.width * 1.1
        height: parent.height * 1.1
        anchors.centerIn: parent
        visible: CavaService.cavaAvailable && activePlayer?.playbackState === MprisPlaybackState.Playing && showAnimation
        asynchronous: false
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        z: 0
        layer.enabled: false

        readonly property real centerX: width / 2
        readonly property real centerY: height / 2
        readonly property real baseRadius: Math.min(width, height) * 0.41 * root.animationScale
        readonly property int segments: 28

        property var audioLevels: {
            if (!CavaService.cavaAvailable || CavaService.values.length === 0) {
                return [0.5, 0.3, 0.7, 0.4, 0.6, 0.5, 0.8, 0.2, 0.9, 0.6];
            }
            return CavaService.values;
        }

        property var smoothedLevels: [0.5, 0.3, 0.7, 0.4, 0.6, 0.5, 0.8, 0.2, 0.9, 0.6]
        property var cubics: []

        Connections {
            target: CavaService
            function onValuesChanged() {
                if (morphingBlob.visible) {
                    morphingBlob.updatePath();
                }
            }
        }

        Component {
            id: cubicSegment
            PathCubic {}
        }

        Component.onCompleted: {
            shapePath.pathElements.push(Qt.createQmlObject('import QtQuick; import QtQuick.Shapes; PathMove {}', shapePath));

            for (let i = 0; i < segments; i++) {
                const seg = cubicSegment.createObject(shapePath);
                shapePath.pathElements.push(seg);
                cubics.push(seg);
            }

            updatePath();
        }

        function updatePath() {
            if (cubics.length === 0)
                return;

            const alpha = 0.35;
            const minLen = Math.min(smoothedLevels.length, audioLevels.length);
            for (let i = 0; i < minLen; i++) {
                smoothedLevels[i] += alpha * (audioLevels[i] - smoothedLevels[i]);
            }

            const angleStep = 2 * Math.PI / segments;
            const tension3 = 0.16666667;
            const startMove = shapePath.pathElements[0];

            const points = new Array(segments);
            for (let i = 0; i < segments; i++) {
                const angle = i * angleStep;
                const audioIndex = i % 10;
                const rawLevel = smoothedLevels[audioIndex] || 0;
                const clampedLevel = rawLevel < 0 ? 0 : (rawLevel > 100 ? 100 : rawLevel);
                const audioLevel = Math.max(0.15, Math.sqrt(clampedLevel * 0.01)) * 0.5;
                const radius = baseRadius * (1.0 + audioLevel);
                points[i] = {
                    x: centerX + Math.cos(angle) * radius,
                    y: centerY + Math.sin(angle) * radius
                };
            }

            startMove.x = points[0].x;
            startMove.y = points[0].y;

            for (let i = 0; i < segments; i++) {
                const p0 = points[(i + segments - 1) % segments];
                const p1 = points[i];
                const p2 = points[(i + 1) % segments];
                const p3 = points[(i + 2) % segments];

                const seg = cubics[i];
                seg.control1X = p1.x + (p2.x - p0.x) * tension3;
                seg.control1Y = p1.y + (p2.y - p0.y) * tension3;
                seg.control2X = p2.x - (p3.x - p1.x) * tension3;
                seg.control2Y = p2.y - (p3.y - p1.y) * tension3;
                seg.x = p2.x;
                seg.y = p2.y;
            }
        }

        ShapePath {
            id: shapePath
            fillColor: Theme.primary
            strokeColor: "transparent"
            strokeWidth: 0
            joinStyle: ShapePath.RoundJoin
            fillRule: ShapePath.WindingFill
        }
    }

    DankCircularImage {
        id: albumArt
        width: albumSize
        height: albumSize
        anchors.centerIn: parent
        z: 1

        imageSource: artUrl || lastValidArtUrl || ""
        fallbackIcon: "album"
        border.color: Theme.primary
        border.width: 2

        onImageSourceChanged: {
            if (imageSource && imageStatus !== Image.Error) {
                lastValidArtUrl = imageSource;
            }
        }
    }
}
