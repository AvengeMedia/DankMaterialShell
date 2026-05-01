import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property real iconSize: 24
    property int overflowCount: 0
    property bool overflowExpanded: false
    property bool isVertical: false
    property bool showBadge: true

    signal clicked

    Rectangle {
        id: buttonBackground
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, mouseArea.containsMouse ? 0.2 : 0.1)

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
            }
        }

        DankIcon {
            id: arrowIcon
            anchors.centerIn: parent
            size: root.iconSize * 0.6
            name: "expand_more"
            color: Theme.widgetIconColor
            rotation: isVertical ? (overflowExpanded ? 180 : 0) : (overflowExpanded ? 90 : -90)

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Rectangle {
        visible: overflowCount > 0 && !overflowExpanded && root.showBadge
        anchors.right: buttonBackground.right
        anchors.top: buttonBackground.top
        anchors.rightMargin: -4
        anchors.topMargin: -4
        width: Math.max(18, badgeText.width + 8)
        height: 18
        radius: 9
        color: Theme.primary
        z: 10

        StyledText {
            id: badgeText
            anchors.centerIn: parent
            text: `+${overflowCount}`
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            color: Theme.onPrimary
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
