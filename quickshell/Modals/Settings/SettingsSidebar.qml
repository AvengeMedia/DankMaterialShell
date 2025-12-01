pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.Settings
import qs.Services
import qs.Widgets

Rectangle {
    id: sidebarContainer

    property int currentIndex: 0
    property var parentModal: null
    readonly property var allSidebarItems: [
        {
            "text": I18n.tr("Personalization"),
            "icon": "person",
            "tabIndex": 0
        },
        {
            "text": I18n.tr("Time & Weather"),
            "icon": "schedule",
            "tabIndex": 1
        },
        {
            "text": I18n.tr("Dank Bar"),
            "icon": "toolbar",
            "tabIndex": 2
        },
        {
            "text": I18n.tr("Widgets"),
            "icon": "widgets",
            "tabIndex": 3
        },
        {
            "text": I18n.tr("Dock"),
            "icon": "dock_to_bottom",
            "tabIndex": 4
        },
        {
            "text": I18n.tr("Displays"),
            "icon": "monitor",
            "tabIndex": 5
        },
        {
            "text": I18n.tr("Network"),
            "icon": "wifi",
            "dmsOnly": true,
            "tabIndex": 6
        },
        {
            "text": I18n.tr("Printers"),
            "icon": "print",
            "cupsOnly": true,
            "tabIndex": 7
        },
        {
            "text": I18n.tr("Launcher"),
            "icon": "apps",
            "tabIndex": 8
        },
        {
            "text": I18n.tr("Theme & Colors"),
            "icon": "palette",
            "tabIndex": 9
        },
        {
            "text": I18n.tr("Audio"),
            "icon": "headphones",
            "tabIndex": 10
        },
        {
            "text": I18n.tr("Power & Security"),
            "icon": "power",
            "tabIndex": 11
        },
        {
            "text": I18n.tr("Plugins"),
            "icon": "extension",
            "tabIndex": 12
        },
        {
            "text": I18n.tr("About"),
            "icon": "info",
            "tabIndex": 13
        }
    ]
    readonly property var sidebarItems: allSidebarItems.filter(item => {
        if (item.dmsOnly && NetworkService.usingLegacy)
            return false;
        if (item.cupsOnly && !CupsService.cupsAvailable)
            return false;
        return true;
    })

    function navigateNext() {
        const currentItemIndex = sidebarItems.findIndex(item => item.tabIndex === currentIndex);
        const nextIndex = (currentItemIndex + 1) % sidebarItems.length;
        currentIndex = sidebarItems[nextIndex].tabIndex;
    }

    function navigatePrevious() {
        const currentItemIndex = sidebarItems.findIndex(item => item.tabIndex === currentIndex);
        const prevIndex = (currentItemIndex - 1 + sidebarItems.length) % sidebarItems.length;
        currentIndex = sidebarItems[prevIndex].tabIndex;
    }

    width: 270
    height: parent.height
    color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    radius: Theme.cornerRadius

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: sidebarColumn.height

        Column {
            id: sidebarColumn

            width: parent.width
            leftPadding: Theme.spacingS
            rightPadding: Theme.spacingS
            bottomPadding: Theme.spacingL
            topPadding: Theme.spacingM + 2
            spacing: Theme.spacingXS

            ProfileSection {
                width: parent.width - parent.leftPadding - parent.rightPadding
                parentModal: sidebarContainer.parentModal
            }

            Rectangle {
                width: parent.width - parent.leftPadding - parent.rightPadding
                height: 1
                color: Theme.outline
                opacity: 0.2
            }

            Item {
                width: parent.width - parent.leftPadding - parent.rightPadding
                height: Theme.spacingL
            }

            Repeater {
                id: sidebarRepeater

                model: sidebarContainer.sidebarItems

                delegate: Rectangle {
                    required property int index
                    required property var modelData

                    property bool isActive: sidebarContainer.currentIndex === modelData.tabIndex

                    width: parent.width - parent.leftPadding - parent.rightPadding
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
                            sidebarContainer.currentIndex = modelData.tabIndex;
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
