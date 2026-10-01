pragma Singleton

import QtQuick
import Quickshell
import qs.Common

Singleton {
    readonly property real compactPillThickness: Theme.barHeight - Theme.iconSizeMedium
    readonly property real pressedRadius: Theme.cornerRadiusS
    readonly property real segmentInnerRadius: Theme.cornerRadiusS
    readonly property real segmentPressedInnerRadius: Theme.cornerRadiusXS
    readonly property real segmentGap: Theme.groupedListGap
    readonly property real pillGap: Theme.spacingXS
    readonly property real bareGap: Theme.spacingXXS
    readonly property real fittsReach: 1000
    readonly property real iconSlot: Theme.iconSizeSmall + Theme.spacingXXS
    readonly property real indicatorDot: Theme.spacingS - Theme.spacingXXS
    readonly property real badgeSize: Theme.spacingS
    readonly property real badgeInset: Theme.spacingXS
    readonly property real mediaControlSize: Theme.iconSizeMedium
    readonly property real menuRowHeight: Theme.menuItemHeight
    readonly property real menuItemRadius: Theme.cornerRadiusS
    readonly property real popoutRowHeight: Theme.listItemHeight
    readonly property real popoutRowTwoLineHeight: Theme.listItemTwoLineHeight
    readonly property var elevationLevel: Theme.elevationLevel2

    function pillRadius(thickness, style) {
        if (style === "flat")
            return Math.min(Theme.cornerRadiusS, thickness / 2);
        if (thickness < compactPillThickness)
            return Math.min(Theme.cornerRadiusM, thickness / 2);
        return Theme.fullRadius(thickness, thickness);
    }

    function cornerRadius(thickness, style, joined, pressProgress) {
        const resting = joined ? Math.min(segmentInnerRadius, thickness / 2) : pillRadius(thickness, style);
        const pressed = Math.min(resting, joined || style === "flat" ? segmentPressedInnerRadius : pressedRadius);
        return Math.max(0, resting + (pressed - resting) * Math.max(0, Math.min(1, pressProgress)));
    }

    function widgetStyle(barConfig) {
        return barConfig?.widgetStyle ?? "pills";
    }

    // islandBandFit is the inverse of compactFaceThickness; both read these.
    readonly property real islandFaceBloomSmall: 2
    readonly property real islandFaceBloomLarge: 4
    readonly property real islandLargeFaceCompact: 40
    readonly property real islandMinFace: 16
    readonly property real islandMinBandFace: 20

    function widgetFill(barConfig) {
        const transparency = SettingsData.barWidgetTransparency(barConfig);
        return Theme.widgetBackgroundHasAlpha ? Theme.blendAlpha(Theme.widgetBaseBackgroundColor, transparency) : Theme.withAlpha(Theme.widgetBaseBackgroundColor, transparency);
    }

    function compactFaceThickness(compact) {
        return compact + (compact < islandLargeFaceCompact ? islandFaceBloomSmall : islandFaceBloomLarge);
    }

    function islandBandFit(bandThickness, gap) {
        const fittedGap = Math.max(1, Math.min(gap, Math.floor((bandThickness - islandMinBandFace) / 2)));
        const face = Math.max(islandMinFace, Math.round(bandThickness) - fittedGap * 2);
        const large = face - islandFaceBloomLarge;
        return {
            "gap": fittedGap,
            "compact": large >= islandLargeFaceCompact ? large : Math.min(islandLargeFaceCompact - 1, face - islandFaceBloomSmall)
        };
    }
}
