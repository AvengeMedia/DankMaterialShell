pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Item {
    id: root

    required property int reserveHeight

    readonly property alias inputMaskItem: inputEnvelope
    readonly property var activeMotion: engineMode === "native" ? nativeMotion : vectorMotion
    readonly property list<string> targetStates: ["home", "compact", "expanded", "offset-test"]
    readonly property var log: Log.scoped("DankIslandMotionLab")
    readonly property bool hudEnabled: Quickshell.env("DMS_DANKISLAND_LAB_HUD") !== "0"
    readonly property bool metricsLogEnabled: Quickshell.env("DMS_DANKISLAND_LAB_LOG") === "1"

    property string engineMode: Quickshell.env("DMS_DANKISLAND_LAB_ENGINE") === "native" ? "native" : "vector"
    property string targetState: "home"
    property bool stressRunning: Quickshell.env("DMS_DANKISLAND_LAB_STRESS") === "1"
    property real lastFrameMs: 0
    property real smoothFrameMs: 0
    property real peakFrameMs: 0
    property real currentPeakFrameMs: 0
    property int metricFrameCount: 0
    property string statusText: ""

    function targetForState(state) {
        switch (state) {
        case "compact":
            return {
                "width": 252,
                "height": 48,
                "offsetX": 0,
                "offsetY": 8,
                "topLeftRadius": 24,
                "topRightRadius": 24,
                "bottomLeftRadius": 24,
                "bottomRightRadius": 24
            };
        case "expanded":
            return {
                "width": 448,
                "height": 176,
                "offsetX": 0,
                "offsetY": 8,
                "topLeftRadius": 26,
                "topRightRadius": 26,
                "bottomLeftRadius": 32,
                "bottomRightRadius": 32
            };
        case "offset-test":
            return {
                "width": 520,
                "height": 132,
                "offsetX": -72,
                "offsetY": 14,
                "topLeftRadius": 22,
                "topRightRadius": 30,
                "bottomLeftRadius": 44,
                "bottomRightRadius": 18
            };
        default:
            return {
                "width": 176,
                "height": 42,
                "offsetX": 0,
                "offsetY": 8,
                "topLeftRadius": 21,
                "topRightRadius": 21,
                "bottomLeftRadius": 21,
                "bottomRightRadius": 21
            };
        }
    }

    function motionSnapshot(motion) {
        return {
            "width": motion.currentWidth,
            "height": motion.currentHeight,
            "offsetX": motion.currentOffsetX,
            "offsetY": motion.currentOffsetY,
            "topLeftRadius": motion.currentTopLeftRadius,
            "topRightRadius": motion.currentTopRightRadius,
            "bottomLeftRadius": motion.currentBottomLeftRadius,
            "bottomRightRadius": motion.currentBottomRightRadius
        };
    }

    function applyState(state) {
        targetState = state;
        activeMotion.setTarget(targetForState(state));
    }

    function cycleState(direction) {
        const currentIndex = targetStates.indexOf(targetState);
        const nextIndex = (currentIndex + direction + targetStates.length) % targetStates.length;
        applyState(targetStates[nextIndex]);
    }

    function toggleEngine() {
        const snapshot = motionSnapshot(activeMotion);
        const target = targetForState(targetState);
        if (engineMode === "vector") {
            nativeMotion.snapTo(snapshot);
            engineMode = "native";
            nativeMotion.setTarget(target);
        } else {
            vectorMotion.snapTo(snapshot);
            engineMode = "vector";
            vectorMotion.setTarget(target);
        }
        peakFrameMs = 0;
        currentPeakFrameMs = 0;
        metricFrameCount = 0;
    }

    function updateStatusText() {
        if (!hudEnabled)
            return;

        const engineLabel = engineMode === "vector" ? "VECTOR" : "NATIVE";
        const motionLabel = activeMotion.running ? "MOVING" : "SETTLED";
        const stressLabel = stressRunning ? " · STRESS" : "";
        statusText = engineLabel + " · " + targetState.toUpperCase() + " · " + motionLabel + stressLabel + "\n" + Math.round(activeMotion.currentWidth) + "×"
            + Math.round(activeMotion.currentHeight) + " · " + smoothFrameMs.toFixed(2) + " ms smooth · " + peakFrameMs.toFixed(2) + " ms peak";
    }

    Component.onCompleted: {
        const home = targetForState("home");
        nativeMotion.snapTo(home);
        vectorMotion.snapTo(home);
        updateStatusText();
    }

    NativeSpringMotion {
        id: nativeMotion
        enabled: root.engineMode === "native"
    }

    VectorSpringMotion {
        id: vectorMotion
        enabled: root.engineMode === "vector"
        reducedMotion: SettingsData.dankIslandReducedMotion || SettingsData.animationSpeed === SettingsData.AnimationSpeed.None
        stiffness: Math.max(100, Math.min(1200, SettingsData.dankIslandSpringStiffness))
        damping: Math.max(10, Math.min(100, SettingsData.dankIslandSpringDamping))
        mass: Math.max(0.25, Math.min(3, SettingsData.dankIslandSpringMass))
    }

    Timer {
        interval: 110
        repeat: true
        running: root.stressRunning
        onTriggered: root.cycleState(1)
    }

    Timer {
        interval: 200
        repeat: true
        running: root.hudEnabled
        triggeredOnStart: true
        onTriggered: root.updateStatusText()
    }

    FrameAnimation {
        running: root.activeMotion.running || root.stressRunning

        onRunningChanged: {
            if (running) {
                root.peakFrameMs = 0;
                root.currentPeakFrameMs = 0;
                root.metricFrameCount = 0;
            }
        }

        onTriggered: {
            root.lastFrameMs = frameTime * 1000;
            root.smoothFrameMs = smoothFrameTime * 1000;
            root.metricFrameCount++;
            if (root.metricFrameCount > 8)
                root.currentPeakFrameMs = Math.max(root.currentPeakFrameMs, root.lastFrameMs);
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.hudEnabled || root.metricsLogEnabled
        onTriggered: {
            root.peakFrameMs = root.currentPeakFrameMs;
            root.currentPeakFrameMs = 0;
            if (root.metricsLogEnabled)
                root.log.info("DankIslandLabMetrics engine=" + root.engineMode + " state=" + root.targetState + " moving=" + root.activeMotion.running + " frameMs=" + root.lastFrameMs.toFixed(3) + " smoothMs=" + root.smoothFrameMs.toFixed(3) + " peakMs=" + root.peakFrameMs.toFixed(3));
        }
    }

    readonly property real currentVisualX: (width - activeMotion.currentWidth) / 2 + activeMotion.currentOffsetX
    readonly property real currentVisualY: activeMotion.currentOffsetY
    readonly property real targetVisualX: (width - activeMotion.targetWidth) / 2 + activeMotion.targetOffsetX
    readonly property real targetVisualY: activeMotion.targetOffsetY

    Item {
        id: inputEnvelope

        x: Math.min(root.currentVisualX, root.targetVisualX)
        y: Math.min(root.currentVisualY, root.targetVisualY)
        width: Math.max(root.currentVisualX + root.activeMotion.currentWidth, root.targetVisualX + root.activeMotion.targetWidth) - x
        height: Math.max(root.currentVisualY + root.activeMotion.currentHeight, root.targetVisualY + root.activeMotion.targetHeight) - y
    }

    Rectangle {
        x: 0
        y: root.reserveHeight - 1
        width: root.width
        height: 1
        color: Theme.outline
        opacity: 0.22
        visible: root.hudEnabled
    }

    Rectangle {
        id: island

        x: root.currentVisualX
        y: root.currentVisualY
        width: root.activeMotion.currentWidth
        height: root.activeMotion.currentHeight
        topLeftRadius: Math.max(0, root.activeMotion.currentTopLeftRadius)
        topRightRadius: Math.max(0, root.activeMotion.currentTopRightRadius)
        bottomLeftRadius: Math.max(0, root.activeMotion.currentBottomLeftRadius)
        bottomRightRadius: Math.max(0, root.activeMotion.currentBottomRightRadius)
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.28)

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 2
            color: root.engineMode === "vector" ? Theme.primary : Theme.tertiary
            opacity: 0.85
        }

        Column {
            anchors.centerIn: parent
            spacing: 2
            visible: root.hudEnabled

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.statusText.split("\n")[0] ?? ""
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.statusText.split("\n")[1] ?? ""
                color: Theme.withAlpha(Theme.surfaceText, 0.72)
                font.pixelSize: Math.max(9, Theme.fontSizeSmall - 2)
                visible: island.width >= 230
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "left: next · right: engine · middle: stress · wheel: retarget"
                color: Theme.withAlpha(Theme.surfaceText, 0.62)
                font.pixelSize: Math.max(9, Theme.fontSizeSmall - 2)
                visible: island.width >= 400 && island.height >= 100
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.toggleEngine();
                } else if (mouse.button === Qt.MiddleButton) {
                    root.stressRunning = !root.stressRunning;
                } else {
                    root.cycleState(1);
                }
            }

            onWheel: wheel => {
                root.cycleState(wheel.angleDelta.y >= 0 ? 1 : -1);
                wheel.accepted = true;
            }
        }
    }
}
