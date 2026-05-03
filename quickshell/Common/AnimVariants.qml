pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

// AnimVariants — central tuning for animation variants (Material/Fluent/Dynamic)
// and motion effects (Standard/Directional/Depth). Lookups are indexed by enum
// value: animationVariant 0=Material, 1=Fluent, 2=Dynamic; motionEffect
// 0=Standard, 1=Directional, 2=Depth.

Singleton {
    id: root

    readonly property int _variant: (typeof SettingsData === "undefined") ? 0 : SettingsData.animationVariant
    readonly property int _effect: (typeof SettingsData === "undefined") ? 0 : SettingsData.motionEffect

    readonly property var _enterCurves: [Anims.expressiveDefaultSpatial, Anims.standardDecel, Anims.expressiveFastSpatial]
    readonly property var _exitCurves: [Anims.emphasized, Anims.standard, Anims.emphasized]
    readonly property var _directionalExitCurves: [Anims.emphasized, Anims.emphasizedAccel, Anims.emphasizedAccel]
    readonly property var _enterDurationFactors: [1.0, 0.9, 1.08]
    readonly property var _exitDurationFactors: [1.0, 0.85, 0.92]
    readonly property var _cleanupPaddings: [50, 8, 24]
    readonly property var _effectScaleCollapsed: [0.96, 1.0, 0.88]
    readonly property var _effectAnimOffsets: [16, 144, 56]

    readonly property list<real> variantEnterCurve: _enterCurves[_variant] || _enterCurves[0]
    readonly property list<real> variantExitCurve: _exitCurves[_variant] || _exitCurves[0]

    readonly property list<real> variantModalEnterCurve: isDirectionalEffect && _variant !== 0 ? (_enterCurves[_variant] || _enterCurves[0]) : variantEnterCurve
    readonly property list<real> variantModalExitCurve: isDirectionalEffect ? (_directionalExitCurves[_variant] || _exitCurves[0]) : variantExitCurve

    readonly property list<real> variantPopoutEnterCurve: isDirectionalEffect ? (_variant === 0 ? Anims.standardDecel : (_enterCurves[_variant] || _enterCurves[0])) : variantEnterCurve
    readonly property list<real> variantPopoutExitCurve: isDirectionalEffect ? (_directionalExitCurves[_variant] || _exitCurves[0]) : variantExitCurve

    readonly property real variantEnterDurationFactor: _enterDurationFactors[_variant] !== undefined ? _enterDurationFactors[_variant] : 1.0
    readonly property real variantExitDurationFactor: _exitDurationFactors[_variant] !== undefined ? _exitDurationFactors[_variant] : 1.0

    // Fluent: opacity at ~55% of duration; Material/Dynamic: 1:1 with position
    readonly property real variantOpacityDurationScale: _variant === 1 ? 0.55 : 1.0

    function variantDuration(baseDuration, entering) {
        const factor = entering ? variantEnterDurationFactor : variantExitDurationFactor;
        return Math.max(0, Math.round(baseDuration * factor));
    }

    function variantExitCleanupPadding() {
        return _cleanupPaddings[_effect] !== undefined ? _cleanupPaddings[_effect] : 50;
    }

    function variantCloseInterval(baseDuration) {
        return variantDuration(baseDuration, false) + variantExitCleanupPadding();
    }

    readonly property bool isDirectionalEffect: isConnectedEffect || _effect === 1
    readonly property bool isDepthEffect: _effect === 2
    readonly property bool isConnectedEffect: (typeof SettingsData !== "undefined") && SettingsData.connectedFrameModeActive

    readonly property real effectScaleCollapsed: _effectScaleCollapsed[_effect] !== undefined ? _effectScaleCollapsed[_effect] : 0.96
    readonly property real effectAnimOffset: _effectAnimOffsets[_effect] !== undefined ? _effectAnimOffsets[_effect] : 16
}
