pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property var controller

    function pushMeasuredWidth() {
        root.controller.setDestinationContentWidth("controlcenter", compactRow.implicitWidth);
    }

    Component.onCompleted: root.pushMeasuredWidth()

    Row {
        id: compactRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        onImplicitWidthChanged: root.pushMeasuredWidth()

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "tune"
            size: Theme.iconSizeSmall
            color: Theme.primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("Control Center")
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
        }
    }
}
