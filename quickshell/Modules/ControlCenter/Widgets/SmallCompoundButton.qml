import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string iconName: ""
    property bool isActive: false
    property bool iconBlinking: false

    // Left click toggles the widget, right click opens the detail/menu.
    signal toggled
    signal expandClicked
    signal wheelEvent(var wheelEvent)

    width: parent ? ((parent.width - parent.spacing * 3) / 4) : 48
    height: 48
    radius: {
        if (Theme.cornerRadius === 0)
            return 0;
        return isActive ? Theme.cornerRadius : Theme.cornerRadius + 4;
    }

    function hoverTint(base) {
        const factor = 1.2;
        return Theme.isLightMode ? Qt.darker(base, factor) : Qt.lighter(base, factor);
    }

    readonly property color _tileBgActive: Theme.ccTileActiveBg
    readonly property color _tileBgInactive: Theme.ccPillInactiveBg
    readonly property color _tileRingActive: Theme.ccTileRing
    readonly property color _tileIconActive: Theme.ccTileActiveText
    readonly property color _tileIconInactive: Theme.ccTileInactiveIcon

    color: {
        if (isActive)
            return _tileBgActive;
        const baseColor = mouseArea.containsMouse ? Theme.ccPillInactiveHoverBg : _tileBgInactive;
        return baseColor;
    }
    border.color: isActive ? _tileRingActive : Theme.outlineMedium
    border.width: isActive ? 1 : Theme.layerOutlineWidth
    antialiasing: true
    opacity: enabled ? 1.0 : 0.6

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
        id: tileIcon
        anchors.centerIn: parent
        name: iconName
        size: Theme.iconSize
        color: isActive ? _tileIconActive : _tileIconInactive

        DankBlink {
            target: tileIcon
            running: root.iconBlinking
        }
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: root.enabled
        onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.toggled();
            else
                root.expandClicked();
        }
        onWheel: function (ev) {
            root.wheelEvent(ev);
        }
    }

    Behavior on radius {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
