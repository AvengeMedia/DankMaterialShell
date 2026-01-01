import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string text: ""
    property string iconName: ""
    property int iconSize: Theme.iconSizeSmall
    property bool enabled: true
    property bool hovered: mouseArea.containsMouse
    property bool pressed: mouseArea.pressed
    property color backgroundColor: Theme.primary
    property color textColor: Theme.primaryText
    property int buttonHeight: 40
    property int horizontalPadding: Theme.spacingL

    signal clicked

    width: Math.max(contentRow.implicitWidth + horizontalPadding * 2, 64)
    height: buttonHeight
    radius: Theme.cornerRadius
    color: backgroundColor
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: stateLayer
        anchors.fill: parent
        radius: parent.radius
        color: {
            if (pressed)
                return Theme.withAlpha(root.textColor, 0.20);
            if (hovered)
                return Theme.withAlpha(root.textColor, 0.12);
            return "transparent";
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.shorterDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.spacingS

        DankIcon {
            name: root.iconName
            size: root.iconSize
            color: root.textColor
            visible: root.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.text
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: root.textColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
