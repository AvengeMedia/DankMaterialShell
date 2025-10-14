pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankActionButton {
    id: customButtonKeyboard
    circular: false
    property string text: ""
    width: 40
    height: 40
    property bool isShift: false
    color: Theme.surface

    StyledText {
        id: contentItem
        anchors.centerIn: parent
        text: parent.text
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeXLarge
        font.weight: Font.Normal
    }
}
