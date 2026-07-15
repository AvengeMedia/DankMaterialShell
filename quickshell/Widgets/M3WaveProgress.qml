import QtQuick
import qs.Common

// Wave progress indicator: track, animated fill, seek preview and playhead are
// all drawn in a single fragment shader (Shaders/frag/wave_progress.frag).
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
    property color trackColor: Theme.withAlpha(Theme.surfaceVariant, 0.40)
    property color fillColor: Theme.primary
    property color playheadColor: Theme.primary
    property color actualProgressColor: Theme.onSurface_38

    Behavior on currentAmp {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }
    onIsPlayingChanged: currentAmp = isPlaying ? amp : 0
    Component.onCompleted: currentAmp = isPlaying ? amp : 0

    ShaderEffect {
        anchors.fill: parent
        blending: true

        readonly property real widthPx: width
        readonly property real heightPx: height
        readonly property real value: root.value
        readonly property real actualValue: root.actualValue
        readonly property real phase: root.phase
        readonly property real ampPx: root.currentAmp
        readonly property real wavelengthPx: root.wavelength
        readonly property real lineWidthPx: root.lineWidth
        readonly property real showActual: root.showActualPlaybackState ? 1.0 : 0.0
        readonly property color fillColor: root.fillColor
        readonly property color trackColor: root.trackColor
        readonly property color playheadColor: root.playheadColor
        readonly property color actualColor: root.actualProgressColor

        fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wave_progress.frag.qsb")
    }

    signal frameTicked

    FrameAnimation {
        running: root.visible && (root.isPlaying || root.currentAmp > 0) && (root.Window.window?.visible ?? false)
        onTriggered: {
            if (!root.isPlaying)
                return;
            root.phase = (root.phase + 0.03 * frameTime * 60) % 6.28318530718;
            root.frameTicked();
        }
    }
}
