pragma Singleton

import QtQuick
import Quickshell
import qs.Common

Singleton {
    readonly property real rowHeight: Theme.listItemHeight
    readonly property real rowPadding: Theme.spacingL
    readonly property real rowGap: Theme.groupedListGap
    readonly property real tileSize: Theme.launcherTileSize
    readonly property real tileGap: Theme.spacingXS
    readonly property real tileLabelHeight: Theme.spacingXL
    readonly property real tileImageRatio: Theme.launcherImageRatio
    readonly property real pillHeight: Theme.listItemHeight
    readonly property real sectionHeight: Theme.buttonHeightXS + Theme.spacingXS * 2
    readonly property real iconSize: Theme.avatarSize
    readonly property real gridIconSize: Theme.iconSizeLarge + Theme.spacingL
    readonly property real previewWidth: Theme.listItemHeight
    readonly property real previewHeight: Theme.avatarSize
    readonly property real footerHeight: Theme.buttonHeightXS
    readonly property real footerChipHeight: footerHeight - Theme.spacingXS * 2
    readonly property int maxVisibleRows: Theme.launcherMaxVisibleRows
    readonly property real maxResultsHeight: maxVisibleRows * (rowHeight + rowGap) + sectionHeight
    readonly property real minSearchWidth: Theme.fieldDefaultWidth
    readonly property int selectionDuration: Theme.shorterDuration
    readonly property real screenMargin: Theme.launcherScreenMargin
    readonly property real spotlightWidth: Theme.launcherWidthWide
    readonly property real spotlightTopFraction: 0.33
    readonly property real spotlightInset: Theme.spacingS

    function sizeWidth(size) {
        switch (size) {
        case "micro":
            return Theme.launcherWidthMicro;
        case "medium":
            return Theme.launcherWidthWide;
        case "large":
            return Theme.launcherWidthLarge;
        default:
            return Theme.launcherWidthDefault;
        }
    }

    function sizeHeight(size) {
        switch (size) {
        case "micro":
            return Theme.smallBreakpoint;
        case "medium":
            return Theme.launcherWidthWide;
        case "large":
            return Theme.launcherWidthLarge;
        default:
            return Theme.launcherHeightDefault;
        }
    }

    function spotlightRadius(width) {
        return Theme.fullRadius(width, pillHeight);
    }

    function spotlightBottomRadius(width, contentHeight) {
        const pill = spotlightRadius(width);
        const t = Math.max(0, Math.min(1, (contentHeight - pillHeight) / Theme.windowRadius));
        return pill + (Theme.windowRadius - pill) * t;
    }

    function spotlightY(screenHeight, insetTop, insetBottom) {
        const usable = Math.max(pillHeight, screenHeight - insetTop - insetBottom);
        const preferred = insetTop + Math.max(0, usable * spotlightTopFraction - pillHeight / 2);
        const maxY = Math.max(insetTop, screenHeight - insetBottom - pillHeight);
        return Math.max(insetTop, Math.min(preferred, maxY));
    }
}
