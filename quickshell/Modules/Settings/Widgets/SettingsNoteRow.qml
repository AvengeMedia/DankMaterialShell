import QtQuick
import qs.Common
import qs.Widgets

SettingsRow {
    id: root

    property string text: ""
    property string noteIconName: "warning"
    property color tint: Theme.warning
    property color tintBackground: Theme.warningHover

    body: Rectangle {
        width: parent.width
        height: noteRow.implicitHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: root.tintBackground

        Row {
            id: noteRow
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: Theme.spacingS

            DankIcon {
                name: root.noteIconName
                size: Theme.iconSizeSmall
                color: root.tint
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                width: parent.width - parent.spacing - Theme.iconSizeSmall
                text: root.text
                font.pixelSize: Theme.fontSizeSmall
                color: root.tint
                wrapMode: Text.WordWrap
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
