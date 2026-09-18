pragma Singleton

import QtQuick
import Quickshell
import qs.Common

Singleton {
    readonly property real sidebarWidth: 320
    readonly property real compactBreakpoint: 700
    readonly property real contentMaxWidth: 640
    readonly property real windowWidth: 1000
    readonly property real windowHeight: 940
    readonly property real windowMinWidth: 500
    readonly property real windowMinHeight: 400
    readonly property real pagePaddingH: 40
    readonly property real pagePaddingV: 32
    readonly property real scrollGutter: 32
    readonly property real pageHeaderHeight: Theme.fontSizeXXLarge + Theme.spacingXL + Theme.spacingM
    readonly property real rowPaddingH: 20
    readonly property real rowPaddingV: 16
    readonly property real rowContentSpacing: Theme.spacingL
    readonly property real sectionLabelTopGap: Theme.spacingS
    readonly property real sectionLabelBottomGap: Theme.spacingM
    readonly property real navIconSize: Theme.avatarSize
    readonly property real navItemMinHeight: Theme.listItemHeight
    readonly property real sidebarGroupGap: Theme.spacingS
    readonly property real avatarSize: 64
    readonly property real splitDividerHeight: Theme.iconSize
    readonly property real buttonGroupCompactThreshold: 200
    readonly property real choiceCardPreviewRatio: 10 / 16
    readonly property real wallpaperThumbRatio: 10 / 16
    readonly property real disabledOpacity: 0.38
    readonly property real highlightBlend: 0.2
    readonly property real activeHintAlpha: 0.8
    readonly property real bannerTextMinWidth: 100
    readonly property real fontMenuExtraWidth: 100
    readonly property color rowColor: Theme.foregroundColor(Theme.surfaceContainerHigh, true)
    readonly property color rowHighlightColor: Theme.withAlpha(Theme.primary, highlightBlend)
    readonly property int transitionDuration: Theme.expressiveDurations.expressiveFastSpatial
    readonly property int fadeDuration: Theme.expressiveDurations.expressiveEffects
}
