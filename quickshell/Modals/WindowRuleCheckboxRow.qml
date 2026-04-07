import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: checkboxRow

    property alias checked: checkbox.checked
    property alias label: labelText.text
    property bool indeterminate: false

    spacing: Theme.spacingS
    height: 24

    Rectangle {
        id: checkbox
        property bool checked: false
        width: 20
        height: 20
        radius: 4
        color: checkboxRow.indeterminate ? Theme.surfaceVariant : (checked ? Theme.primary : "transparent")
        border.color: checkboxRow.indeterminate ? Theme.outlineButton : (checked ? Theme.primary : Theme.outlineButton)
        border.width: 2
        anchors.verticalCenter: parent.verticalCenter

        DankIcon {
            anchors.centerIn: parent
            name: checkboxRow.indeterminate ? "remove" : "check"
            size: 12
            color: checkboxRow.indeterminate ? Theme.surfaceVariantText : Theme.background
            visible: parent.checked || checkboxRow.indeterminate
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (checkboxRow.indeterminate) {
                    checkboxRow.indeterminate = false;
                    checkbox.checked = true;
                } else {
                    checkbox.checked = !checkbox.checked;
                }
            }
        }
    }

    StyledText {
        id: labelText
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceText
        anchors.verticalCenter: parent.verticalCenter
    }
}
