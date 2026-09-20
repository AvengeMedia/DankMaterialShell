pragma Singleton

import QtQuick
import Quickshell
import qs.Common

Singleton {
    readonly property real sheetWidthDefault: sheetWidthFor(defaultColumns)
    readonly property int defaultColumns: 8
    readonly property int minimumColumns: 6
    readonly property real sheetPadding: PopoutMetrics.contentPadding
    readonly property real columnWidth: tileHeight
    readonly property real gridStep: 0.5
    property int columnPreview: 0
    readonly property int gridColumns: columnPreview > 0 ? columnPreview : clampColumns(SettingsData.controlCenterColumns)
    readonly property real sheetWidth: sheetWidthFor(gridColumns)

    function clampColumns(value) {
        const columns = Math.round(Number(value));
        if (!Number.isFinite(columns) || columns <= 0)
            return defaultColumns;
        return Math.max(minimumColumns, columns);
    }

    function columnCapFor(availableWidth) {
        return Math.max(1, Math.floor((availableWidth - sheetPadding * 2 + gridGap) / (columnWidth + gridGap)));
    }

    function rowCapFor(availableHeight, cellHeight = gridRowUnit) {
        return Math.max(1, Math.floor((availableHeight + gridGap) / (cellHeight + gridGap)));
    }

    function sheetWidthFor(columns) {
        return sheetPadding * 2 + columns * columnWidth + (columns - 1) * gridGap;
    }
    readonly property real maxHeightInset: 100
    readonly property real minHeight: 300
    readonly property real fallbackScreenHeight: 1080
    readonly property real triggerWidth: 80

    readonly property real tileHeight: 64
    readonly property real gridRowUnit: tileHeight
    readonly property real expandedTileMinWidth: columnWidth * 3 + gridGap * 2
    readonly property real sliderRowHeight: Theme.minimumTouchTargetSize
    readonly property real gridGap: Theme.spacingS
    readonly property real tilePaddingH: Theme.spacingL
    readonly property real iconScale: SettingsData.controlCenterIconScale
    readonly property real tileIconSize: Theme.iconSizeLarge * iconScale
    readonly property real iconBoxSize: Theme.minimumTouchTargetSize * iconScale
    readonly property real tileActiveRadius: Theme.scaledRadius(24, tileHeight / 2)
    readonly property real tallTileRadius: Theme.cornerRadiusXL
    readonly property real iconBoxActiveRadius: Theme.cornerRadiusL
    readonly property real iconBoxIconSize: Theme.iconSize * iconScale
    readonly property real tallMeterThickness: 28
    readonly property real tileTextGap: Theme.spacingM
    readonly property real headerActionSize: Theme.iconButtonSize * iconScale
    readonly property real headerActionIconSize: Theme.iconSize * iconScale

    readonly property real headerAvatarSize: 56
    readonly property real headerHeight: tileHeight

    readonly property real pageHeaderHeight: Theme.fontSizeXXLarge + Theme.spacingM * 2
    readonly property real pageTitleSize: Theme.fontSizeXXLarge
    readonly property real detailHeightList: 350
    readonly property real detailHeightBrightness: 400
    readonly property real detailHeightDefault: 250
    readonly property int transitionDuration: Theme.expressiveDurations.expressiveFastSpatial
    readonly property int fadeDuration: Theme.expressiveDurations.expressiveEffects

    readonly property real rowPaddingH: Theme.spacingL
    readonly property real rowPaddingV: Theme.spacingM
    readonly property real detailContentGap: Theme.spacingS
    readonly property real sectionLabelTopGap: Theme.spacingS
    readonly property real sectionLabelBottomGap: Theme.spacingXS
    readonly property color rowColor: Theme.foregroundColor(Theme.cardSurface)
    readonly property int maxPins: 3
    readonly property real statusDotSize: 8
    readonly property real spinnerStroke: 2
    readonly property real emptyStateIconSize: Theme.iconSizeLarge
    readonly property real emptyStateMinHeight: 100

    readonly property real menuMinWidth: 180
    readonly property real dialogWidth: 320
    readonly property real libraryPanelWidth: 400
    readonly property real libraryPanelHeight: 400
    readonly property real configMenuWidth: 260
    readonly property real vpnPopoutListHeight: 200
    readonly property real headerDropdownWidth: 120
    readonly property real rowDropdownWidth: 160
    readonly property real headerPopupWidth: 200
    readonly property real brightnessLowMax: 33
    readonly property int wifiSignalBucket: 25
    readonly property real diskWarnPercent: 75
    readonly property real diskCriticalPercent: 90
    readonly property int dndRefreshInterval: 1000
    readonly property int wifiSignalStrong: 50
    readonly property real brightnessMediumMax: 66
    readonly property real brightnessExponentMin: 1.0
    readonly property real brightnessExponentMax: 2.5
    readonly property real brightnessExponentStep: 0.1
    readonly property int overlayZ: 10000
    readonly property real popupEnterScale: 0.92

    readonly property color tileActiveColor: Theme.ccTileActiveBg
    readonly property color tileActiveContent: Theme.ccTileActiveText
    readonly property color tileInactiveColor: Theme.ccPillInactiveBg
    readonly property color tileInactiveContent: Theme.surfaceText
    readonly property color tileInactiveSubtitle: Theme.surfaceVariantText
    readonly property color tileInactiveIcon: Theme.primary

    readonly property bool animationsEnabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None

    function preferredDetailHeight(section, pluginHeight) {
        if (!section)
            return 0;
        if (section.startsWith("plugin_"))
            return pluginHeight > 0 ? pluginHeight : detailHeightDefault;
        if (section.startsWith("brightnessSlider_"))
            return detailHeightBrightness;
        switch (section) {
        case "wifi":
        case "network":
        case "bluetooth":
        case "battery":
        case "builtin_vpn":
        case "builtin_tailscale":
        case "audioOutput":
        case "audioInput":
        case "diskUsage":
            return detailHeightList;
        default:
            return detailHeightDefault;
        }
    }
}
