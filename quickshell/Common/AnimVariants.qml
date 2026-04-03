pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

// AnimVariants — Central tuning for animation and Motion Effects variants
// (Material/Fluent/Dynamic) (Standard/Directional/Depth)

Singleton {
    id: root

    readonly property list<real> variantEnterCurve: {
        if (typeof SettingsData === "undefined")
            return Anims.expressiveDefaultSpatial;
        switch (SettingsData.animationVariant) {
        case 1:
            return Anims.standardDecel;
        case 2:
            return Anims.expressiveFastSpatial;
        default:
            return Anims.expressiveDefaultSpatial;
        }
    }

    readonly property list<real> variantExitCurve: {
        if (typeof SettingsData === "undefined")
            return Anims.emphasized;
        switch (SettingsData.animationVariant) {
        case 1:
            return Anims.standard;
        case 2:
            return Anims.emphasized;
        default:
            return Anims.emphasized;
        }
    }

    // Modal-specific entry curve
    readonly property list<real> variantModalEnterCurve: {
        if (typeof SettingsData === "undefined")
            return Anims.expressiveDefaultSpatial;
        if (isDirectionalEffect) {
            if (SettingsData.animationVariant === 1)
                return Anims.standardDecel;
            if (SettingsData.animationVariant === 2)
                return Anims.expressiveFastSpatial;
        }
        return variantEnterCurve;
    }

    readonly property list<real> variantModalExitCurve: {
        if (typeof SettingsData === "undefined")
            return Anims.emphasized;
        if (isDirectionalEffect) {
            if (SettingsData.animationVariant === 1)
                return Anims.emphasizedAccel;
            if (SettingsData.animationVariant === 2)
                return Anims.emphasizedAccel;
        }
        return variantExitCurve;
    }

    // Popout-specific entry curve
    readonly property list<real> variantPopoutEnterCurve: {
        if (typeof SettingsData === "undefined")
            return Anims.expressiveDefaultSpatial;
        if (isDirectionalEffect) {
            if (SettingsData.animationVariant === 1)
                return Anims.standardDecel;
            if (SettingsData.animationVariant === 2)
                return Anims.expressiveFastSpatial;
            return Anims.standardDecel;
        }
        return variantEnterCurve;
    }

    readonly property list<real> variantPopoutExitCurve: {
        if (typeof SettingsData === "undefined")
            return Anims.emphasized;
        if (isDirectionalEffect) {
            if (SettingsData.animationVariant === 1)
                return Anims.emphasizedAccel;
            if (SettingsData.animationVariant === 2)
                return Anims.emphasizedAccel;
        }
        return variantExitCurve;
    }

    readonly property real variantEnterDurationFactor: {
        if (typeof SettingsData === "undefined")
            return 1.0;
        switch (SettingsData.animationVariant) {
        case 1:
            return 0.9;
        case 2:
            return 1.08;
        default:
            return 1.0;
        }
    }

    readonly property real variantExitDurationFactor: {
        if (typeof SettingsData === "undefined")
            return 1.0;
        switch (SettingsData.animationVariant) {
        case 1:
            return 0.85;
        case 2:
            return 0.92;
        default:
            return 1.0;
        }
    }

    // Fluent: opacity at ~55% of duration; Material/Dynamic: 1:1 with position
    readonly property real variantOpacityDurationScale: {
        if (typeof SettingsData === "undefined")
            return 1.0;
        return SettingsData.animationVariant === 1 ? 0.55 : 1.0;
    }

    function variantDuration(baseDuration, entering) {
        const factor = entering ? variantEnterDurationFactor : variantExitDurationFactor;
        return Math.max(0, Math.round(baseDuration * factor));
    }

    function variantExitCleanupPadding() {
        if (typeof SettingsData === "undefined")
            return 50;
        switch (SettingsData.motionEffect) {
        case 1:
            return 8;
        case 2:
            return 24;
        default:
            return 50;
        }
    }

    function variantCloseInterval(baseDuration) {
        return variantDuration(baseDuration, false) + variantExitCleanupPadding();
    }

    readonly property bool isDirectionalEffect: isConnectedEffect
        || (typeof SettingsData !== "undefined" && SettingsData.motionEffect === 1)
    readonly property bool isDepthEffect: typeof SettingsData !== "undefined" && SettingsData.motionEffect === 2
    readonly property bool isConnectedEffect: typeof SettingsData !== "undefined"
        && SettingsData.frameEnabled
        && SettingsData.motionEffect === 1
        && SettingsData.directionalAnimationMode === 3

    readonly property real effectScaleCollapsed: {
        if (typeof SettingsData === "undefined")
            return 0.96;
        switch (SettingsData.motionEffect) {
        case 1:
            return 1.0;
        case 2:
            return 0.88;
        default:
            return 0.96;
        }
    }

    readonly property real effectAnimOffset: {
        if (typeof SettingsData === "undefined")
            return 16;
        switch (SettingsData.motionEffect) {
        case 1:
            return 144;
        case 2:
            return 56;
        default:
            return 16;
        }
    }
}
