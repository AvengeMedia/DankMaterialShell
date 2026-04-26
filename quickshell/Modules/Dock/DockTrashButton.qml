import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    clip: false

    property var dockApps: null
    property var contextMenu: null
    property var parentDockScreen: null
    property real actualIconSize: 40
    property real hoverAnimOffset: 0

    property bool isHovered: mouseArea.containsMouse
    property bool showTooltip: mouseArea.containsMouse
    readonly property string tooltipText: TrashService.isEmpty ? I18n.tr("Trash") : (I18n.tr("Trash") + " (" + TrashService.count + ")")

    readonly property bool isVertical: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right
    readonly property real animationDistance: actualIconSize
    readonly property real animationDirection: {
        if (SettingsData.dockPosition === SettingsData.Position.Bottom)
            return -1;
        if (SettingsData.dockPosition === SettingsData.Position.Top)
            return 1;
        if (SettingsData.dockPosition === SettingsData.Position.Right)
            return -1;
        if (SettingsData.dockPosition === SettingsData.Position.Left)
            return 1;
        return -1;
    }

    onIsHoveredChanged: {
        if (mouseArea.pressed)
            return;
        if (isHovered) {
            exitAnimation.stop();
            if (!bounceAnimation.running)
                bounceAnimation.restart();
        } else {
            bounceAnimation.stop();
            exitAnimation.restart();
        }
    }

    SequentialAnimation {
        id: bounceAnimation

        running: false

        NumberAnimation {
            target: root
            property: "hoverAnimOffset"
            to: animationDirection * animationDistance * 0.25
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedAccel
        }

        NumberAnimation {
            target: root
            property: "hoverAnimOffset"
            to: animationDirection * animationDistance * 0.2
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedDecel
        }
    }

    NumberAnimation {
        id: exitAnimation

        running: false
        target: root
        property: "hoverAnimOffset"
        to: 0
        duration: Anims.durShort
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Anims.emphasizedDecel
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                TrashService.openTrash();
            } else if (mouse.button === Qt.RightButton) {
                if (contextMenu) {
                    contextMenu.showForButton(root, root.height, parentDockScreen, dockApps);
                }
            }
        }
    }

    Item {
        id: visualContent
        anchors.fill: parent

        transform: Translate {
            x: !isVertical ? 0 : hoverAnimOffset
            y: !isVertical ? hoverAnimOffset : 0
        }

        Item {
            anchors.centerIn: parent
            width: actualIconSize
            height: actualIconSize

            IconImage {
                id: trashIcon
                anchors.centerIn: parent
                width: actualIconSize - 4
                height: actualIconSize - 4
                smooth: true
                asynchronous: true
                source: Quickshell.iconPath(TrashService.isEmpty ? "user-trash" : "user-trash-full", "user-trash")

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
