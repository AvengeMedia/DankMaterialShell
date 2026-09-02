pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property color accentColor: Theme.primary
    property bool playing: false
    property real animationScale: 1.0

    readonly property bool onScreen: visible && enabled && (Window.window?.visible ?? false)
    readonly property bool available: CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled
    readonly property bool blobActive: root.onScreen && root.playing && root.available

    readonly property real blobBaseRadiusFactor: 0.43
    readonly property real blobAmplitudeFactor: 0.115
    readonly property real blobOvershoot: 1.15
    readonly property real blobEnergySensitivity: 1.15
    readonly property real cavaFullScale: 45
    readonly property real blobAttack: 0.75
    readonly property real blobRelease: 0.2
    readonly property real blobBeatBoost: 2.5
    readonly property real blobBeatKick: 4
    readonly property real blobOnsetThreshold: 1.4
    readonly property real blobSpringStiffness: 220
    readonly property real blobSpringDamping: 19
    readonly property real blobMorphSpeed: 0.05
    readonly property real blobMorphBoost: 1.7
    readonly property real blobSpinSpeed: 0.03
    readonly property var fluxWeights: [1.0, 1.0, 0.6, 0.6, 0.35, 0.35]

    property var smoothedBands: [0, 0, 0, 0, 0, 0]
    property var slowBands: [0, 0, 0, 0, 0, 0]
    property var bandTargets: [0, 0, 0, 0, 0, 0]
    property var bandDisplay: [0, 0, 0, 0, 0, 0]
    property var prevLevels: [0, 0, 0, 0, 0, 0]
    property real fluxAvg: 0.02
    property real loudCtx: 0.1
    property int beatCooldown: 0
    property real energyTarget: 0
    property real energyPos: 0
    property real energyVel: 0

    function updateBands() {
        const vals = CavaService.values;
        if (!vals || vals.length < 6)
            return;

        const s = smoothedBands;
        const slow = slowBands;
        const out = bandTargets;
        const prev = prevLevels;
        const w = fluxWeights;
        let flux = 0;
        for (let i = 0; i < 6; i++) {
            const level = Math.min(Math.max(vals[i], 0), cavaFullScale) / cavaFullScale;
            flux += Math.max(0, level - prev[i]) * w[i];
            prev[i] = level;
            const alpha = level > s[i] ? blobAttack : blobRelease;
            s[i] += alpha * (level - s[i]);
            slow[i] += 0.05 * (level - slow[i]);
            const punch = Math.max(0, s[i] - slow[i]) * blobBeatBoost;
            out[i] = Math.min(1, (0.55 * s[i] + punch) * blobEnergySensitivity);
        }

        const ratio = flux / Math.max(fluxAvg, 0.004);
        fluxAvg += 0.06 * (flux - fluxAvg);
        if (beatCooldown > 0) {
            beatCooldown--;
        } else if (ratio > blobOnsetThreshold && flux > 0.008) {
            energyVel += blobBeatKick * Math.min(2.5, ratio - 1);
            beatCooldown = 3;
        }

        const loud = 0.7 * Math.max(prev[0], prev[1]) + 0.3 * Math.max(prev[2], prev[3]);
        loudCtx += 0.03 * (loud - loudCtx);
        const surge = Math.max(0, loud / Math.max(loudCtx, 0.05) - 1);
        energyTarget = Math.min(1, 0.5 * loud + 0.6 * Math.min(1, surge));
    }

    function stepBlob(dt) {
        energyVel += (blobSpringStiffness * (energyTarget - energyPos) - blobSpringDamping * energyVel) * dt;
        energyPos = Math.max(0, Math.min(blobOvershoot, energyPos + energyVel * dt));
        blobEffect.energy = energyPos;

        const d = bandDisplay;
        const t = bandTargets;
        const f = Math.min(1, dt * 14);
        for (let i = 0; i < 6; i++)
            d[i] += f * (t[i] - d[i]);
        blobEffect.bandsA = Qt.vector4d(d[0], d[1], d[2], d[3]);
        blobEffect.bandsB = Qt.vector2d(d[4], d[5]);

        const speed = 1 + energyPos * blobMorphBoost;
        blobEffect.phase = (blobEffect.phase + dt * blobMorphSpeed * speed) % 1;
        blobEffect.spin = (blobEffect.spin + dt * blobSpinSpeed) % 6.28318530718;
    }

    Loader {
        active: root.blobActive
        sourceComponent: Component {
            Ref {
                service: CavaService
            }
        }
    }

    Connections {
        target: CavaService
        enabled: root.blobActive

        function onValuesChanged() {
            root.updateBands();
        }
    }

    Timer {
        running: blobEffect.visible && root.onScreen
        interval: 33
        repeat: true
        onTriggered: root.stepBlob(0.033)
    }

    ShaderEffect {
        id: blobEffect

        readonly property real span: Math.min(root.width, root.height)

        width: span * (root.blobBaseRadiusFactor + root.blobAmplitudeFactor * root.blobOvershoot) * 2 * root.animationScale + 4
        height: width
        anchors.centerIn: parent
        visible: root.blobActive || activation > 0.004

        property real phase: 0
        property real spin: 0
        property real sizePx: width
        property real baseRadiusPx: span * root.blobBaseRadiusFactor * root.animationScale
        property real amplitudePx: span * root.blobAmplitudeFactor * root.animationScale
        property real activation: root.blobActive ? 1 : 0
        property real energy: 0
        property vector4d bandsA: Qt.vector4d(0, 0, 0, 0)
        property vector2d bandsB: Qt.vector2d(0, 0)
        property vector4d fillColor: Qt.vector4d(root.accentColor.r, root.accentColor.g, root.accentColor.b, root.accentColor.a)

        Behavior on activation {
            NumberAnimation {
                duration: 550
                easing.type: Easing.InOutQuad
            }
        }

        fragmentShader: Qt.resolvedUrl("../Shaders/qsb/blob.frag.qsb")
    }
}
