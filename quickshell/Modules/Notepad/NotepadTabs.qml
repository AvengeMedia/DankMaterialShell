pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    property var currentTab: NotepadStorageService.tabs.length > NotepadStorageService.currentTabIndex ? NotepadStorageService.tabs[NotepadStorageService.currentTabIndex] : null
    property bool contentLoaded: false

    signal tabSwitched(int tabIndex)
    signal tabClosed(int tabIndex)
    signal newTabRequested

    function hasUnsavedChangesForTab(tab) {
        if (!tab)
            return false;

        if (tab.id === currentTab?.id) {
            return root.parent?.hasUnsavedChanges ? root.parent.hasUnsavedChanges() : false;
        }
        return false;
    }

    spacing: Theme.spacingXS

    Row {
        width: parent.width
        height: 36
        spacing: Theme.spacingXS

        ScrollView {
            width: parent.width - newTabButton.width - Theme.spacingXS
            height: parent.height
            clip: true

            ScrollBar.horizontal.visible: false
            ScrollBar.vertical.visible: false

            Row {
                spacing: Theme.spacingXS

                Repeater {
                    model: NotepadStorageService.tabs

                    delegate: Rectangle {
                        required property int index
                        required property var modelData

                        readonly property bool isActive: NotepadStorageService.currentTabIndex === index
                        readonly property bool isHovered: tabMouseArea.containsMouse && !closeMouseArea.containsMouse
                        readonly property real calculatedWidth: {
                            const textWidth = tabText.paintedWidth || 100;
                            const closeButtonWidth = NotepadStorageService.tabs.length > 1 ? 20 : 0;
                            const spacing = Theme.spacingXS;
                            const padding = Theme.spacingM * 2;
                            return Math.max(120, Math.min(200, textWidth + closeButtonWidth + spacing + padding));
                        }

                        width: calculatedWidth
                        height: 32
                        radius: Theme.cornerRadius
                        color: isActive ? Theme.primaryPressed : isHovered ? Theme.primaryHoverLight : Theme.withAlpha(Theme.primaryPressed, 0)
                        border.width: isActive ? 0 : 1
                        border.color: Theme.outlineMedium

                        MouseArea {
                            id: tabMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton

                            onClicked: root.tabSwitched(index)
                        }

                        Row {
                            id: tabContent
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            StyledText {
                                id: tabText
                                text: {
                                    var prefix = "";
                                    if (hasUnsavedChangesForTab(modelData)) {
                                        prefix = "● ";
                                    }
                                    return prefix + (modelData.title || "Untitled");
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: isActive ? Theme.primary : Theme.surfaceText
                                font.weight: isActive ? Font.Medium : Font.Normal
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                id: tabCloseButton
                                width: 20
                                height: 20
                                radius: Theme.cornerRadius
                                color: closeMouseArea.containsMouse ? Theme.surfaceTextHover : Theme.withAlpha(Theme.surfaceTextHover, 0)
                                visible: NotepadStorageService.tabs.length > 1
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    name: "close"
                                    size: 14
                                    color: Theme.surfaceTextMedium
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: closeMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    z: 100

                                    onClicked: {
                                        root.tabClosed(index);
                                    }
                                }
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

        DankActionButton {
            id: newTabButton
            width: 32
            height: 32
            iconName: "add"
            iconSize: Theme.iconSize - 4
            iconColor: Theme.surfaceText
            onClicked: root.newTabRequested()
        }
    }
}
