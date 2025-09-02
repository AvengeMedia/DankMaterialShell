import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property bool isActive: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    property real barHeight: 48
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal clicked

    width: notepadIcon.width + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground) return "transparent"
        const baseColor = notepadArea.containsMouse
                        || root.isActive ? Theme.primaryPressed : Theme.secondaryHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }

    DankIcon {
        id: notepadIcon
        anchors.centerIn: parent
        name: "assignment"
        size: Theme.iconSize - 6
        color: notepadArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText
    }

    Rectangle {
        width: 6
        height: 6
        radius: 3
        color: Theme.primary
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: SettingsData.topBarNoBackground ? 0 : 4
        anchors.topMargin: SettingsData.topBarNoBackground ? 0 : 4
        visible: SessionData.notepadContent.length > 0
        opacity: 0.8
    }

    MouseArea {
        id: notepadArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            root.clicked()
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}