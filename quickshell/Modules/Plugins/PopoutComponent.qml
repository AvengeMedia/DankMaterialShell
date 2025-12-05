import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    property string headerText: ""
    property string detailsText: ""
    property bool showCloseButton: false
    property var closePopout: null

    readonly property int headerHeight: popoutHeader.visible ? popoutHeader.height : 0
    readonly property int detailsHeight: popoutDetails.visible ? popoutDetails.implicitHeight : 0

    spacing: 0

    Item {
        id: popoutHeader
        width: parent.width
        height: 40
        visible: headerText.length > 0

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            text: root.headerText
            font.pixelSize: Theme.fontSizeLarge + 4
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        Rectangle {
            id: closeButton
            width: 32
            height: 32
            radius: 16
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: closeArea.containsMouse ? Theme.errorHover : "transparent"
            visible: root.showCloseButton

            DankIcon {
                anchors.centerIn: parent
                name: "close"
                size: Theme.iconSize - 4
                color: closeArea.containsMouse ? Theme.error : Theme.surfaceText
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: {
                    if (root.closePopout) {
                        root.closePopout();
                    }
                }
            }
        }
    }

    StyledText {
        id: popoutDetails
        width: parent.width
        leftPadding: Theme.spacingS
        bottomPadding: Theme.spacingS
        text: root.detailsText
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
        visible: detailsText.length > 0
        wrapMode: Text.WordWrap
    }
}
