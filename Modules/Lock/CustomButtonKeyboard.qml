import QtQuick
import QtQuick.Controls

Button {
    id: customButtonKeyboard
    property string label: "test"
    property real buttonWidth: 40
    property real buttonHeight: 40
    property bool isShift: false
    text: qsTr(label)

    function setOpacity()
    {
        if(pressed)
            return 0.3
        return 1
    }

    function setBorderColor()
    {
        if(pressed)
            return "#589de8"
        return "transparent"
    }

    function setColor()
    {
        if(pressed)
            return "#afafaf"
        if(isShift)
            return "#589de8"
        return "white"
    }

    contentItem: Text {
        text: customButtonKeyboard.text
        font: customButtonKeyboard.font
        opacity: setOpacity()
        color: "black"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        implicitWidth: buttonWidth
        implicitHeight: buttonHeight
        color: setColor()
        border.color: setBorderColor()
        border.width: 1
        radius: 4
    }

}