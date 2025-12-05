import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property string iconName: ""
    property int iconSize: Theme.iconSize - 4
    property color iconColor: Theme.surfaceText
    property color backgroundColor: "transparent"
    property bool circular: true
    property bool enabled: true
    property int buttonSize: 32
    property var tooltipText: null

    signal clicked
    signal entered
    signal exited

    width: buttonSize
    height: buttonSize
    radius: Theme.cornerRadius
    color: backgroundColor

    DankIcon {
        anchors.centerIn: parent
        name: root.iconName
        size: root.iconSize
        color: root.iconColor
    }

    StateLayer {
        disabled: !root.enabled
        stateColor: Theme.primary
        cornerRadius: root.radius
        onClicked: root.clicked()
        onEntered: root.entered()
        onExited: root.exited()
        tooltipText: root.tooltipText
    }
}
