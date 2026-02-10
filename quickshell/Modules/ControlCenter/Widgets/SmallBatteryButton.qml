import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property bool isActive: BatteryService.batteryAvailable && (BatteryService.isCharging || BatteryService.isPluggedIn)
    property bool enabled: BatteryService.batteryAvailable

    signal clicked

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
    readonly property color _tileBgInactive: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    readonly property color _tileRingActive: Theme.ccTileRing
    readonly property color _tileIconActive: Theme.ccTileActiveText
    readonly property color _tileIconInactive: Theme.ccTileInactiveIcon

    color: {
        if (isActive)
            return _tileBgActive;
        const baseColor = mouseArea.containsMouse ? Theme.primaryPressed : _tileBgInactive;
        return baseColor;
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
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 4

        DankIcon {
            name: BatteryService.getBatteryIcon()
            size: parent.parent.width * 0.25
            color: {
                if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                    return Theme.error;
                }
                return isActive ? _tileIconActive : _tileIconInactive;
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: BatteryService.batteryAvailable ? `${BatteryService.batteryLevel}%` : ""
            font.pixelSize: parent.parent.width * 0.15
            font.weight: Font.Medium
            color: {
                if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                    return Theme.error;
                }
                return isActive ? _tileIconActive : _tileIconInactive;
            }
            anchors.verticalCenter: parent.verticalCenter
            visible: BatteryService.batteryAvailable
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
        enabled: root.enabled
        onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
        onClicked: root.clicked()
    }

    Behavior on radius {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
