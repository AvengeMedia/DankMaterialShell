import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property bool isActive: false
    property bool enabled: true
    property real iconRotation: 0

    signal clicked()
    signal iconRotationCompleted()

    width: parent ? ((parent.width - parent.spacing * 3) / 4) : 48
    height: 48
    radius: {
        if (Theme.cornerRadius === 0) return 0
        return isActive ? Theme.cornerRadius : Theme.cornerRadius + 4
    }

    function hoverTint(base) {
        const factor = 1.2
        return Theme.isLightMode ? Qt.darker(base, factor) : Qt.lighter(base, factor)
    }

    readonly property color _tileBgActive: Theme.primary
    readonly property color _tileBgInactive: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    readonly property color _tileRingActive:
        Qt.rgba(Theme.primaryText.r, Theme.primaryText.g, Theme.primaryText.b, 0.22)
    readonly property color _tileIconActive: Theme.primaryText
    readonly property color _tileIconInactive: Theme.primary

    color: {
        if (isActive) return _tileBgActive
        const baseColor = mouseArea.containsMouse ? Theme.widgetBaseHoverColor : _tileBgInactive
        return baseColor
    }
    border.color: isActive ? _tileRingActive : "transparent"
    border.width: isActive ? 1 : 0
    antialiasing: true
    opacity: enabled ? 1.0 : 0.6

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: hoverTint(root.color)
        opacity: mouseArea.pressed ? 0.3 : (mouseArea.containsMouse ? 0.2 : 0.0)
        visible: opacity > 0
        antialiasing: true
        Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
    }

    DankIcon {
        anchors.centerIn: parent
        name: iconName
        size: Theme.iconSize
        color: isActive ? _tileIconActive : _tileIconInactive
        rotation: iconRotation
        onRotationCompleted: root.iconRotationCompleted()
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.clicked()
    }

    Behavior on radius {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}