import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string primaryMessage: ""
    property string secondaryMessage: ""

    radius: Theme.cornerRadius
    color: Theme.warningHover
    border.color: Theme.warning
    border.width: 1

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingXS

        DankIcon {
            name: "warning"
            size: 16
            color: Theme.warning
            anchors.top: parent.top
            anchors.topMargin: 2
        }

        Column {
            width: parent.width - 16 - parent.spacing
            spacing: Theme.spacingXS

            StyledText {
                width: parent.width
                text: root.primaryMessage
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.warning
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft
            }

            StyledText {
                width: parent.width
                text: root.secondaryMessage
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.warning
                visible: text.length > 0
                horizontalAlignment: Text.AlignLeft
            }
        }
    }
}
