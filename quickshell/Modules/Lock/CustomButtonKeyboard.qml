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

    property bool isIcon: text === "keyboard_hide" || text === "Backspace" || text === "Enter"

    DankIcon {
        anchors.centerIn: parent
        name: {
            if (parent.text === "keyboard_hide")
                return "keyboard_hide";
            if (parent.text === "Backspace")
                return "backspace";
            if (parent.text === "Enter")
                return "keyboard_return";
            return "";
        }
        size: 20
        color: Theme.surfaceText
        visible: parent.isIcon
    }

    StyledText {
        id: contentItem
        anchors.centerIn: parent
        text: parent.text
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeXLarge
        font.weight: Font.Normal
        visible: !parent.isIcon
    }
}
