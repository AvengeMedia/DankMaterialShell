import QtQuick
import qs.Common
import qs.DCommon.Widgets

// One label/value line inside a SettingsGroup; the group paints the row and its corners.
Item {
    id: root

    property string label: ""
    property string value: ""
    property string tooltip: ""

    height: Theme.iconButtonSize

    StyledText {
        id: labelText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.width / 2)
        text: root.label
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
    }

    NumericText {
        anchors.left: labelText.right
        anchors.leftMargin: Theme.spacingM
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        isMonospace: false
        text: root.value || "—"
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceText
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }

    MouseArea {
        id: rowHover
        anchors.fill: parent
        enabled: root.tooltip !== ""
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: containsMouse ? tip.schedule() : tip.dismiss()
    }

    DTooltipHost {
        id: tip
        target: root
        hoverArea: rowHover
        text: root.tooltip
    }
}
