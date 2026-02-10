import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string mountPath: "/"
    property string instanceId: ""

    property var selectedMount: {
        if (!DgopService.diskMounts || DgopService.diskMounts.length === 0)
            return null;
        const targetMount = DgopService.diskMounts.find(mount => mount.mount === mountPath);
        return targetMount || DgopService.diskMounts.find(mount => mount.mount === "/") || DgopService.diskMounts[0];
    }

    property real usagePercent: {
        if (!selectedMount?.percent)
            return 0;
        return parseFloat(selectedMount.percent.replace("%", "")) || 0;
    }

    property bool enabled: DgopService.dgopAvailable

    signal clicked

    width: parent ? ((parent.width - parent.spacing * 3) / 4) : 48
    height: 48
    radius: Theme.cornerRadius + 4

    function hoverTint(base) {
        const factor = 1.2;
        return Theme.isLightMode ? Qt.darker(base, factor) : Qt.lighter(base, factor);
    }

    readonly property color _tileBg: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    color: mouseArea.containsMouse ? Theme.primaryPressed : _tileBg
    border.color: "transparent"
    border.width: 0
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
        spacing: Theme.spacingXS

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "storage"
            size: Theme.iconSizeSmall
            color: {
                if (root.usagePercent > 90)
                    return Theme.error;
                if (root.usagePercent > 75)
                    return Theme.warning;
                return Theme.ccTileInactiveIcon;
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                text: root.selectedMount?.mount || root.mountPath
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, root.width - Theme.iconSizeSmall - Theme.spacingM)
                horizontalAlignment: Text.AlignLeft
            }

            StyledText {
                text: `${root.usagePercent.toFixed(0)}%`
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                color: {
                    if (root.usagePercent > 90)
                        return Theme.error;
                    if (root.usagePercent > 75)
                        return Theme.warning;
                    return Theme.ccTileInactiveIcon;
                }
            }
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

    Component.onCompleted: {
        DgopService.addRef(["diskmounts"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["diskmounts"]);
    }
}
