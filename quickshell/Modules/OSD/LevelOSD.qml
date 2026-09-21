pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

DankOSD {
    id: root

    property string iconName: ""
    property string insetIconName: ""
    property string endIconName: ""
    property bool iconInteractive: false
    property string iconLabel: ""
    property color iconColor: Theme.onPrimary
    property color fillColor: Theme.primary
    property int value: 0
    property int minimum: 0
    property int maximum: 100
    property string unit: "%"
    property string displayText: ""
    property bool available: true

    signal levelRequested(int level)
    signal iconClicked

    readonly property real osdValueReserve: endIconName.length > 0 || SettingsData.osdAlwaysShowValue ? Theme.buttonHeightM : 0

    function requestLevel(level) {
        if (!available)
            return;
        levelRequested(level);
        resetHideTimer();
    }

    osdWidth: isVerticalLayout ? Theme.osdHeight : Math.min(Theme.osdLevelWidth + osdValueReserve, screenWidth - Theme.spacingM * 2)
    osdHeight: isVerticalLayout ? Math.min(Theme.osdLevelVerticalHeight, screenHeight - Theme.spacingM * 2) : Theme.buttonHeightS + Theme.spacingS * 2
    autoHideInterval: 3000
    enableMouseInteraction: true

    content: OsdLevelRow {
        vertical: root.isVerticalLayout
        sliderSize: root.isVerticalLayout ? "m" : "s"
        iconName: root.iconName
        insetIconName: root.insetIconName
        endIconName: root.endIconName
        iconInteractive: root.iconInteractive
        iconLabel: root.iconLabel
        iconColor: root.iconColor
        iconBackgroundColor: root.fillColor === Theme.error ? Theme.errorContainer : root.fillColor
        fillColor: root.fillColor
        value: root.value
        minimum: root.minimum
        maximum: root.maximum
        unit: root.unit
        displayText: root.displayText
        sliderEnabled: root.available
        onIconClicked: root.iconClicked()
        onHoverChanged: hovered => root.setChildHovered(hovered)
        onSliderValueChanged: newValue => root.requestLevel(newValue)
    }
}
