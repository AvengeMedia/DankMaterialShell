pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.OSD

Item {
    id: root

    required property var systemModel
    property real iconSize: 36

    OsdLevelRow {
        anchors.fill: parent
        iconName: root.systemModel.iconName
        iconSize: Math.min(Theme.iconSize, root.iconSize)
        iconColor: root.systemModel.volumeActivity ? Theme.surfaceText : Theme.primary
        iconInteractive: root.systemModel.volumeActivity
        value: Math.round(root.systemModel.value)
        minimum: root.systemModel.minimum
        maximum: Math.max(root.systemModel.minimum + 1, Math.round(root.systemModel.maximum))
        unit: root.systemModel.unit
        displayText: root.systemModel.displayValue
        sliderEnabled: root.systemModel.available
        thumbOutlineColor: Theme.surfaceContainerHigh
        onIconClicked: root.systemModel.toggleMute()
        onSliderValueChanged: newValue => root.systemModel.setRatio(newValue / Math.max(1, Math.round(root.systemModel.maximum)))
    }
}
