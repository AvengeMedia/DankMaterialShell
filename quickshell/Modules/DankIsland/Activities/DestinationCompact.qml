pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property var controller
    required property string activityId
    required property string label
    property string iconName: ""
    property color iconColor: Theme.primary
    property Component leading: null

    function pushMeasuredWidth() {
        root.controller.setDestinationContentWidth(root.activityId, compactRow.implicitWidth);
    }

    Component.onCompleted: root.pushMeasuredWidth()

    Row {
        id: compactRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        onImplicitWidthChanged: root.pushMeasuredWidth()

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            active: root.leading !== null
            visible: active
            sourceComponent: root.leading
        }

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconName !== ""
            name: root.iconName
            size: Theme.iconSizeSmall
            color: root.iconColor
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
        }
    }
}
