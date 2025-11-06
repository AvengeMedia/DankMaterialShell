import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property string text: ""
    property bool isActive: false
    property bool enabled: true
    property string secondaryText: ""
    property real iconRotation: 0

    signal clicked()
    signal iconRotationCompleted()

    width: parent ? parent.width : 200
    height: 60
    radius: {
        if (Theme.cornerRadius === 0) return 0
        return isActive ? Theme.cornerRadius : Theme.cornerRadius + 4
    }

    readonly property color _tileBgActive: Theme.primary
    readonly property color _tileBgInactive: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    readonly property color _tileRingActive:
        Qt.rgba(Theme.primaryText.r, Theme.primaryText.g, Theme.primaryText.b, 0.22)

    color: {
        if (isActive) return _tileBgActive
        const baseColor = mouseArea.containsMouse ? Theme.widgetBaseHoverColor : _tileBgInactive
        return baseColor
    }
    border.color: isActive ? _tileRingActive : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0
    opacity: enabled ? 1.0 : 0.6

    function hoverTint(base) {
        const factor = 1.2
        return Theme.isLightMode ? Qt.darker(base, factor) : Qt.lighter(base, factor)
    }

    readonly property color _containerBg: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: mouseArea.containsMouse ? hoverTint(_containerBg) : Theme.withAlpha(_containerBg, 0)
        opacity: mouseArea.containsMouse ? 0.08 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: Theme.shortDuration }
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
            color: isActive ? Theme.primaryText : Theme.primary
            anchors.verticalCenter: parent.verticalCenter
            rotation: root.iconRotation
            onRotationCompleted: root.iconRotationCompleted()
        }

        Item {
            width: parent.width - Theme.iconSize - parent.spacing
            height: parent.height

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    width: parent.width
                    text: root.text
                    font.pixelSize: Theme.fontSizeMedium
                    color: isActive ? Theme.primaryText : Theme.surfaceText
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                StyledText {
                    width: parent.width
                    text: root.secondaryText
                    font.pixelSize: Theme.fontSizeSmall
                    color: isActive ? Theme.primaryText : Theme.surfaceVariantText
                    visible: text.length > 0
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
            }
        }
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