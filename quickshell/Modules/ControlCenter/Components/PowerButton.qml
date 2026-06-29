import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string iconName: ""
    property string text: ""

    signal pressed

    height: 34
    radius: Theme.cornerRadius
    color: mouseArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.surfaceVariant, 0.5)

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            name: root.iconName
            size: Theme.fontSizeSmall
            color: mouseArea.containsMouse ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Typography {
            text: root.text
            style: Typography.Style.Button
            color: mouseArea.containsMouse ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
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
        onPressed: mouse => {
            ripple.trigger(mouse.x, mouse.y);
            root.pressed();
        }
    }
}
