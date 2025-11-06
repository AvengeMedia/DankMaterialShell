import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property string text: ""
    property string secondaryText: ""
    property bool isActive: false
    property bool enabled: true
    property int widgetIndex: 0
    property var widgetData: null
    property bool editMode: false

    signal clicked()

    width: parent ? parent.width : 200
    height: 60
    radius: {
        if (Theme.cornerRadius === 0) return 0
        return isActive ? Theme.cornerRadius : Theme.cornerRadius + 4
    }

    readonly property color _tileBgActive: Theme.primary
    readonly property color _tileBgInactive:
        Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    readonly property color _tileRingActive:
        Qt.rgba(Theme.primaryText.r, Theme.primaryText.g, Theme.primaryText.b, 0.22)

    color: isActive ? _tileBgActive : _tileBgInactive
    border.color: isActive ? _tileRingActive : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: isActive ? 1 : 1
    opacity: enabled ? 1.0 : 0.6

    function hoverTint(base) {
        const factor = 1.2
        return Theme.isLightMode ? Qt.darker(base, factor) : Qt.lighter(base, factor)
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: mouseArea.containsMouse ? hoverTint(root.color) : "transparent"
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
                    color: isActive ? Theme.primaryText : Theme.surfaceText
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                Typography {
                    width: parent.width
                    text: root.secondaryText
                    style: Typography.Style.Caption
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