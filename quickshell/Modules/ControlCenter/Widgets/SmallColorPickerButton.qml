import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var colorPickerModal: null

    signal clicked

    width: parent ? ((parent.width - parent.spacing * 3) / 4) : 48
    height: 48
    radius: Theme.cornerRadius === 0 ? 0 : Theme.cornerRadius

    function hoverTint(base) {
        const factor = 1.2;
        return Theme.isLightMode ? Qt.darker(base, factor) : Qt.lighter(base, factor);
    }

    color: Theme.primary
    border.color: Theme.ccTileRing
    border.width: 1
    antialiasing: true

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: hoverTint(root.color)
        opacity: mouseArea.pressed ? 0.3 : (mouseArea.containsMouse ? 0.2 : 0.0)
        visible: opacity > 0
        antialiasing: true
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }
    }

    DankIcon {
        anchors.centerIn: parent
        name: "palette"
        size: Theme.iconSize
        color: Theme.primaryText
    }

    DankRipple {
        id: ripple
        cornerRadius: root.radius
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
        onClicked: root.clicked()
    }
}
