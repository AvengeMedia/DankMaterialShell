pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root

    readonly property int _effect: (typeof SettingsData === "undefined") ? 0 : SettingsData.motionEffect

    readonly property var _cleanupPaddings: [50, 8, 24, 50]
    readonly property var _effectScaleCollapsed: [0.96, 1.0, 0.88, 0.96]
    readonly property var _effectAnimOffsets: [16, 144, 56, 16]

    readonly property list<real> variantEnterCurve: Anims.expressiveDefaultSpatial
    readonly property list<real> variantExitCurve: Anims.emphasized

    readonly property list<real> variantModalEnterCurve: variantEnterCurve
    readonly property list<real> variantModalExitCurve: variantExitCurve

    readonly property list<real> variantPopoutEnterCurve: isDirectionalEffect ? Anims.standardDecel : variantEnterCurve
    readonly property list<real> variantPopoutExitCurve: variantExitCurve
    readonly property list<real> variantPopoutResizeCurve: Anims.emphasized

    readonly property real variantEnterDurationFactor: 1.0
    readonly property real variantExitDurationFactor: 1.0
    readonly property real variantOpacityDurationScale: 1.0

    function variantDuration(baseDuration, entering) {
        return Math.max(0, Math.round(baseDuration));
    }

    function variantExitCleanupPadding() {
        return _cleanupPaddings[_effect] !== undefined ? _cleanupPaddings[_effect] : 50;
    }

    function variantCloseInterval(baseDuration) {
        return variantDuration(baseDuration, false) + variantExitCleanupPadding();
    }

    readonly property bool isDirectionalEffect: isConnectedEffect || _effect === SettingsData.AnimationEffect.Directional
    readonly property bool isFluidEffect: _effect === SettingsData.AnimationEffect.Fluid
    readonly property bool isDepthEffect: _effect === SettingsData.AnimationEffect.Depth
    readonly property bool isConnectedEffect: (typeof FrameTransitionState !== "undefined") && FrameTransitionState.effectiveConnectedFrameModeActive

    readonly property real effectScaleCollapsed: _effectScaleCollapsed[_effect] !== undefined ? _effectScaleCollapsed[_effect] : 0.96
    readonly property real effectAnimOffset: _effectAnimOffsets[_effect] !== undefined ? _effectAnimOffsets[_effect] : 16
}
