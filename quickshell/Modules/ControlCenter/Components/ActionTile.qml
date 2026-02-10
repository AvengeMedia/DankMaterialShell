import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string iconName: ""
    property string text: ""
    property string secondaryText: ""
    property bool isActive: false
    property bool enabled: true
    property int widgetIndex: 0
    property var widgetData: null
    property bool editMode: false

    signal clicked

    width: parent ? parent.width : 200
    height: 60
    radius: {
        if (Theme.cornerRadius === 0)
            return 0;
        return isActive ? Theme.cornerRadius : Theme.cornerRadius + 4;
    }

    readonly property color _tileBgActive: Theme.ccTileActiveBg
    readonly property color _tileBgInactive: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    readonly property color _tileRingActive: Theme.ccTileRing

    color: isActive ? _tileBgActive : _tileBgInactive
    border.color: isActive ? _tileRingActive : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: isActive ? 1 : 1
    opacity: enabled ? 1.0 : 0.6

    function hoverTint(base) {
        const factor = 1.2;
        return Theme.isLightMode ? Qt.darker(base, factor) : Qt.lighter(base, factor);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: mouseArea.containsMouse ? hoverTint(root.color) : "transparent"
        opacity: mouseArea.containsMouse ? 0.08 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingL + 2
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingM

        DankIcon {
            name: root.iconName
            size: Theme.iconSize
            color: isActive ? Theme.ccTileActiveText : Theme.ccTileInactiveIcon
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: parent.width - Theme.iconSize - parent.spacing
            height: parent.height

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Typography {
                    width: parent.width
                    text: root.text
                    style: Typography.Style.Body
                    color: isActive ? Theme.ccTileActiveText : Theme.surfaceText
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    horizontalAlignment: Text.AlignLeft
                }

                Typography {
                    width: parent.width
                    text: root.secondaryText
                    style: Typography.Style.Caption
                    color: isActive ? Theme.ccTileActiveText : Theme.surfaceVariantText
                    visible: text.length > 0
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    horizontalAlignment: Text.AlignLeft
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

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on radius {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
