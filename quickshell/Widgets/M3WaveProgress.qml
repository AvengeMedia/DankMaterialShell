import QtQuick
import QtQuick.Shapes
import qs.Common

Item {
    id: root

    property real value: 0
    property real actualValue: value
    property bool showActualPlaybackState: false
    property real lineWidth: 2
    property real wavelength: 20
    property real amp: 1.6
    property real phase: 0.0
    property bool isPlaying: false
    property real currentAmp: 1.6
    property color trackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
    property color fillColor: Theme.primary
    property color playheadColor: Theme.primary
    property color actualProgressColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)

    property real dpr: (root.window ? root.window.devicePixelRatio : 1)
    function snap(v) {
        return Math.round(v * dpr) / dpr;
    }

    readonly property real playX: snap(root.width * root.value)
    readonly property real actualX: snap(root.width * root.actualValue)
    readonly property real midY: snap(height / 2)
    readonly property bool previewAhead: root.showActualPlaybackState && root.value > root.actualValue
    readonly property bool previewBehind: root.showActualPlaybackState && root.value < root.actualValue
    readonly property real previewGapStartX: Math.min(root.playX, root.actualX)
    readonly property real previewGapEndX: Math.max(root.playX, root.actualX)

    Behavior on currentAmp {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }
    onIsPlayingChanged: currentAmp = isPlaying ? amp : 0

    Shape {
        id: flatTrack
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: snap(root.lineWidth)
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"
            PathMove {
                id: flatStart
                x: Math.min(root.width, snap(root.playX + playhead.width / 2))
                y: root.midY
            }
            PathLine {
                id: flatEnd
                x: root.width
                y: root.midY
            }
        }
    }

    Item {
        id: waveClip
        anchors.fill: parent
        clip: true

        readonly property real startX: snap(root.lineWidth / 2)
        readonly property real aaBias: (0.25 / root.dpr)
        readonly property real endX: root.previewAhead ? Math.max(startX, Math.min(root.actualX - aaBias, width)) : Math.max(startX, Math.min(root.playX - startX - aaBias, width))
        readonly property real gapStartX: root.previewAhead ? Math.max(startX, Math.min(root.actualX + aaBias, width)) : Math.max(startX, Math.min(root.playX + playhead.width / 2, width))
        readonly property real gapEndX: root.previewAhead ? Math.max(gapStartX, Math.min(root.playX - playhead.width / 2 - aaBias, width)) : Math.max(gapStartX, Math.min(root.actualX - aaBias, width))

        Rectangle {
            id: mask
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: 0
            width: waveClip.endX
            color: "transparent"
            clip: true

            Shape {
                id: waveShape
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width + 4 * root.wavelength
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                x: waveOffsetX

                ShapePath {
                    id: wavePath
                    strokeColor: root.fillColor
                    strokeWidth: snap(root.lineWidth)
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    fillColor: "transparent"
                    PathSvg {
                        id: waveSvg
                        path: ""
                    }
                }
            }
        }

        Rectangle {
            id: actualMask
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: waveClip.gapStartX
            width: Math.max(0, waveClip.gapEndX - waveClip.gapStartX)
            color: "transparent"
            clip: true
            visible: (root.previewBehind || root.previewAhead) && width > 0

            Shape {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.width + 4 * root.wavelength
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                x: waveOffsetX

                ShapePath {
                    strokeColor: root.actualProgressColor
                    strokeWidth: snap(root.lineWidth)
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    fillColor: "transparent"
                    PathSvg {
                        path: waveSvg.path
                    }
                }
            }
        }

        Rectangle {
            id: startCap
            width: snap(root.lineWidth)
            height: snap(root.lineWidth)
            radius: width / 2
            color: root.fillColor
            x: waveClip.startX - width / 2
            y: waveY(waveClip.startX) - height / 2
            visible: waveClip.endX > waveClip.startX
            z: 2
        }

        Rectangle {
            id: endCap
            width: snap(root.lineWidth)
            height: snap(root.lineWidth)
            radius: width / 2
            color: root.fillColor
            x: waveClip.endX - width / 2
            y: waveY(waveClip.endX) - height / 2
            visible: waveClip.endX > waveClip.startX
            z: 2
        }

        Rectangle {
            id: actualEndCap
            width: snap(root.lineWidth)
            height: snap(root.lineWidth)
            radius: width / 2
            color: root.actualProgressColor
            x: waveClip.gapEndX - width / 2
            y: waveY(waveClip.gapEndX) - height / 2
            visible: (root.previewBehind || root.previewAhead) && actualMask.width > 0
            z: 2
        }

        Rectangle {
            id: actualMarker
            width: 2
            height: Math.max(root.lineWidth + 4, 10)
            radius: width / 2
            color: root.actualProgressColor
            x: root.actualX - width / 2
            y: root.midY - height / 2
            visible: root.showActualPlaybackState
            z: 2
        }
    }

    Rectangle {
        id: playhead
        width: 3.5
        height: Math.max(root.lineWidth + 12, 16)
        radius: width / 2
        color: root.playheadColor
        x: root.playX - width / 2
        y: root.midY - height / 2
        z: 3
    }

    property real k: (2 * Math.PI) / Math.max(1e-6, wavelength)
    function wrapMod(a, m) {
        let r = a % m;
        return r < 0 ? r + m : r;
    }
    function waveY(x, amplitude = root.currentAmp, phaseOffset = root.phase) {
        return root.midY + amplitude * Math.sin((x / root.wavelength) * 2 * Math.PI + phaseOffset);
    }

    readonly property real waveOffsetX: -wrapMod(phase / k, wavelength)

    FrameAnimation {
        running: root.visible && (root.isPlaying || root.currentAmp > 0)
        onTriggered: {
            if (root.isPlaying)
                root.phase += 0.03 * frameTime * 60;
            startCap.y = waveY(waveClip.startX) - startCap.height / 2;
            endCap.y = waveY(waveClip.endX) - endCap.height / 2;
            actualEndCap.y = waveY(waveClip.gapEndX) - actualEndCap.height / 2;
        }
    }

    function buildStaticWave() {
        const start = waveClip.startX - 2 * root.wavelength;
        const end = width + 2 * root.wavelength;
        if (end <= start) {
            waveSvg.path = "";
            return;
        }

        const kLocal = k;
        const halfPeriod = root.wavelength / 2;
        function y0(x) {
            return root.midY + root.currentAmp * Math.sin(kLocal * x);
        }
        function dy0(x) {
            return root.currentAmp * Math.cos(kLocal * x) * kLocal;
        }

        let x0 = start;
        let d = `M ${x0} ${y0(x0)}`;
        while (x0 < end) {
            const x1 = Math.min(x0 + halfPeriod, end);
            const dx = x1 - x0;
            const yA = y0(x0), yB = y0(x1);
            const dyA = dy0(x0), dyB = dy0(x1);
            const c1x = x0 + dx / 3;
            const c1y = yA + (dyA * dx) / 3;
            const c2x = x1 - dx / 3;
            const c2y = yB - (dyB * dx) / 3;
            d += ` C ${c1x} ${c1y} ${c2x} ${c2y} ${x1} ${yB}`;
            x0 = x1;
        }
        waveSvg.path = d;
    }

    Component.onCompleted: {
        currentAmp = isPlaying ? amp : 0;
        buildStaticWave();
    }
    onWidthChanged: {
        flatEnd.x = width;
        buildStaticWave();
    }
    onHeightChanged: buildStaticWave()
    onCurrentAmpChanged: buildStaticWave()
    onWavelengthChanged: {
        k = (2 * Math.PI) / Math.max(1e-6, wavelength);
        buildStaticWave();
    }
}
