import QtQuick
import qs.Common
import qs.Modals.Settings
import qs.Widgets

Rectangle {
    id: sidebarContainer

    property int currentIndex: 0
    property var parentModal: null
    readonly property var sidebarItems: [{
        "text": "Personalization",
        "icon": "person"
    }, {
        "text": "Time & Date",
        "icon": "schedule"
    }, {
        "text": "Weather",
        "icon": "cloud"
    }, {
        "text": "Top Bar",
        "icon": "toolbar"
    }, {
        "text": "Widgets",
        "icon": "widgets"
    }, {
        "text": "Dock",
        "icon": "dock_to_bottom"
    }, {
        "text": "Displays",
        "icon": "monitor"
    }, {
        "text": "Recent Apps",
        "icon": "history"
    }, {
        "text": "Theme & Colors",
        "icon": "palette"
    }, {
        "text": "About",
        "icon": "info"
    }]

    width: 270
    height: parent.height
    color: Theme.surfaceContainer
    radius: Theme.cornerRadius

    Column {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingS
        anchors.rightMargin: Theme.spacingS
        anchors.bottomMargin: Theme.spacingS
        anchors.topMargin: Theme.spacingM + 2
        spacing: Theme.spacingXS

        ProfileSection {
            parentModal: sidebarContainer.parentModal
        }

        Rectangle {
            width: parent.width - Theme.spacingS * 2
            height: 1
            color: Theme.outline
            opacity: 0.2
        }

        Item {
            width: parent.width
            height: Theme.spacingL
        }

        Repeater {
            id: sidebarRepeater

            model: sidebarContainer.sidebarItems

            Rectangle {
                property bool isActive: sidebarContainer.currentIndex === index

                width: parent.width - Theme.spacingS * 2
                height: 44
                radius: Theme.cornerRadius
                color: isActive ? Theme.surfaceContainerHigh : tabMouseArea.containsMouse ? Theme.surfaceHover : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    DankIcon {
                        name: modelData.icon || ""
                        size: Theme.iconSize - 2
                        color: parent.parent.isActive ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: modelData.text || ""
                        font.pixelSize: Theme.fontSizeMedium
                        color: parent.parent.isActive ? Theme.primary : Theme.surfaceText
                        font.weight: parent.parent.isActive ? Font.Medium : Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

                MouseArea {
                    id: tabMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: () => {
                        sidebarContainer.currentIndex = index;
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }

                }

            }

        }

    }

}
