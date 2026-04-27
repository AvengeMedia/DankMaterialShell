import QtQuick
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

    readonly property bool isHovered: mouseArea.containsMouse
    readonly property bool showTooltip: mouseArea.containsMouse
    readonly property string tooltipText: TrashService.isEmpty ? I18n.tr("Trash") : (I18n.tr("Trash") + " (" + TrashService.count + ")")

    readonly property bool isVertical: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right
    readonly property real animationDistance: actualIconSize
    readonly property real animationDirection: {
        switch (SettingsData.dockPosition) {
        case SettingsData.Position.Top:
        case SettingsData.Position.Left:
            return 1;
        case SettingsData.Position.Bottom:
        case SettingsData.Position.Right:
        default:
            return -1;
        }
    }

    onIsHoveredChanged: {
        if (mouseArea.pressed)
            return;
        if (!isHovered) {
            bounceAnimation.stop();
            exitAnimation.restart();
            return;
        }
        exitAnimation.stop();
        if (!bounceAnimation.running)
            bounceAnimation.restart();
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
            switch (mouse.button) {
            case Qt.LeftButton:
                TrashService.openTrash();
                break;
            case Qt.RightButton:
                if (contextMenu)
                    contextMenu.showForButton(root, root.height, parentDockScreen, dockApps);
                break;
            }
        }
    }

    Item {
        anchors.fill: parent

        transform: Translate {
            x: isVertical ? hoverAnimOffset : 0
            y: isVertical ? 0 : hoverAnimOffset
        }

        Item {
            anchors.centerIn: parent
            width: actualIconSize - 4
            height: actualIconSize - 4

            readonly property string iconPath: Paths.resolveIconPath(TrashService.isEmpty ? "user-trash" : "user-trash-full")

            IconImage {
                id: trashIcon
                anchors.fill: parent
                source: parent.iconPath
                backer.sourceSize: Qt.size(parent.width * 2, parent.height * 2)
                smooth: true
                mipmap: true
                asynchronous: true
                visible: status === Image.Ready
            }

            DankIcon {
                anchors.centerIn: parent
                visible: parent.iconPath === "" || trashIcon.status !== Image.Ready
                name: "delete"
                size: actualIconSize - 8
                color: TrashService.isEmpty ? Theme.surfaceText : Theme.primary
            }
        }
    }
}
