pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.Settings
import qs.Widgets

Rectangle {
    id: sidebarContainer

    property int currentIndex: 0
    property var parentModal: null
    readonly property var sidebarItems: [{
        "text": I18n.tr("Personalization"),
        "icon": "person"
    }, {
        "text": I18n.tr("Time & Weather"),
        "icon": "schedule"
    }, {
        "text": I18n.tr("Dank Bar"),
        "icon": "toolbar"
    }, {
        "text": I18n.tr("Widgets"),
        "icon": "widgets"
    }, {
        "text": I18n.tr("Dock"),
        "icon": "dock_to_bottom"
    }, {
        "text": I18n.tr("Displays"),
        "icon": "monitor"
    }, {
        "text": I18n.tr("Launcher"),
        "icon": "apps"
    }, {
        "text": I18n.tr("Theme & Colors"),
        "icon": "palette"
    }, {
        "text": I18n.tr("Power & Security"),
        "icon": "power"
    }, {
        "text": I18n.tr("Plugins"),
        "icon": "extension"
    }, {
        "text": I18n.tr("About"),
        "icon": "info"
    }]

    function navigateNext() {
        currentIndex = (currentIndex + 1) % sidebarItems.length
    }

    function navigatePrevious() {
        currentIndex = (currentIndex - 1 + sidebarItems.length) % sidebarItems.length
    }

    width: 270
    height: parent.height
    color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    radius: Theme.cornerRadius

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: sidebarColumn.implicitHeight

        Column {
            id: sidebarColumn

            width: parent.width
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

                delegate: Rectangle {
                    required property int index
                    required property var modelData

                    property bool isActive: sidebarContainer.currentIndex === index

                    width: sidebarColumn.width - Theme.spacingS * 2
                    height: 44
                    radius: Theme.cornerRadius
                    color: isActive ? Theme.primary : tabMouseArea.containsMouse ? Theme.surfaceHover : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        DankIcon {
                            name: modelData.icon || ""
                            size: Theme.iconSize - 2
                            color: parent.parent.isActive ? Theme.primaryText : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: modelData.text || ""
                            font.pixelSize: Theme.fontSizeMedium
                            color: parent.parent.isActive ? Theme.primaryText : Theme.surfaceText
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

}
