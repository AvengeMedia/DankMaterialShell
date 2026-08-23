pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var mediaModel: null
    property bool isPlaying: mediaModel?.playing ?? false
    property color barColor: Theme.primary

    readonly property bool available: CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled
    readonly property bool live: visible && enabled && (Window.window?.visible ?? false) && root.isPlaying && root.available
    readonly property real maxBarHeight: Math.max(root.minBarHeight, height - 2)
    readonly property real minBarHeight: 3

    property vector4d bandsA: Qt.vector4d(0, 0, 0, 0)
    property vector2d bandsB: Qt.vector2d(0, 0)

    function applyIdleBands() {
        bandsA = Qt.vector4d(0.3, 0.55, 0.7, 0.7);
        bandsB = Qt.vector2d(0.55, 0.3);
    }

    function updateBands() {
        const values = CavaService.values;
        if (!values || values.length < 6)
            return;

        function normalized(index) {
            const value = Math.min(Math.max(values[index], 0), 100) / 100;
            return Math.round(Math.sqrt(value + 0.01) * 32) / 32;
        }

        const nextA = Qt.vector4d(normalized(0), normalized(1), normalized(2), normalized(3));
        const nextB = Qt.vector2d(normalized(4), normalized(5));
        if (nextA == bandsA && nextB == bandsB)
            return;
        bandsA = nextA;
        bandsB = nextB;
    }

    onLiveChanged: {
        if (live)
            updateBands();
        else
            applyIdleBands();
    }

    onAvailableChanged: {
        if (!available)
            return;
        if (live)
            updateBands();
        else
            applyIdleBands();
    }

    Component.onCompleted: {
        if (root.live)
            updateBands();
        else
            applyIdleBands();
    }

    Loader {
        active: root.live && root.available
        sourceComponent: Component {
            Ref {
                service: CavaService
            }
        }
    }

    Connections {
        target: CavaService
        enabled: root.live && root.available

        function onValuesChanged() {
            root.updateBands();
        }
    }

    Loader {
        active: root.available && root.live
        anchors.fill: parent
        sourceComponent: cavaShader
    }

    Component {
        id: cavaShader

        ShaderEffect {
            property real widthPx: width
            property real heightPx: height
            property real minH: root.minBarHeight
            property real maxH: root.maxBarHeight
            property vector4d bandsA: root.bandsA
            property vector2d bandsB: root.bandsB
            property vector4d fillColor: Qt.vector4d(root.barColor.r, root.barColor.g, root.barColor.b, root.barColor.a)

            opacity: root.live ? 1 : 0.45
            fragmentShader: Qt.resolvedUrl("../../../Shaders/qsb/viz_bars.frag.qsb")
        }
    }

    DankIcon {
        anchors.centerIn: parent
        visible: !root.available || !root.live
        name: "graphic_eq"
        size: Math.min(parent.width, parent.height)
        color: root.barColor
    }
}
