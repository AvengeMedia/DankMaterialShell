import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var widgetData: ({})
    property var widgetDef: null
    property var host: null
    property bool live: true
    property bool interactive: true
    property bool compact: false
    property string iconName: ""
    property string sliderLabel: ""
    property alias insetIconClickable: slider.insetIconClickable
    property alias insetIconLabel: slider.insetIconLabel
    property alias slider: slider
    property alias minimum: slider.minimum
    property alias maximum: slider.maximum
    property alias unit: slider.unit
    property alias valueOverride: slider.valueOverride
    property bool sliderEnabled: true
    property alias isDragging: slider.isDragging

    signal insetIconClicked
    signal sliderValueChanged(int newValue)

    width: parent?.width ?? 0
    height: CcMetrics.sliderRowHeight

    DankSlider {
        id: slider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        enabled: root.sliderEnabled && root.interactive
        size: "m"
        insetIcon: root.iconName
        Accessible.name: root.sliderLabel
        showValue: true
        onInsetIconClicked: root.insetIconClicked()
        onSliderValueChanged: newValue => root.sliderValueChanged(newValue)
    }
}
