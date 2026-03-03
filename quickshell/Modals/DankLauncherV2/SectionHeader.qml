pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var section: null
    property var controller: null
    property string viewMode: "list"
    property bool canChangeViewMode: true
    property bool canCollapse: true
    property bool isSticky: false

    signal viewModeToggled

    width: parent?.width ?? 200
    height: 32
    color: isSticky ? "transparent" : (hoverArea.containsMouse ? Theme.surfaceHover : "transparent")
    radius: Theme.cornerRadius

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Row {
        id: leftContent
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS

        // Whether the apps category picker should replace the plain title
        readonly property bool hasAppCategories: root.section?.id === "apps" && (root.controller?.appCategories?.length ?? 0) > 0

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            // Hide section icon when the category chip already shows one
            visible: !leftContent.hasAppCategories
            name: root.section?.icon ?? "folder"
            size: 16
            color: Theme.surfaceVariantText
        }

        // Plain title — hidden when the category chip is shown
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !leftContent.hasAppCategories
            text: root.section?.title ?? ""
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceVariantText
        }

        // Compact inline category chip — only visible on the apps section
        Item {
            id: categoryChip
            visible: leftContent.hasAppCategories
            anchors.verticalCenter: parent.verticalCenter
            // Size to content with a fixed-min width so it doesn't jump around
            width: chipRow.implicitWidth + Theme.spacingM * 2
            height: 24

            readonly property string currentCategory: root.controller?.appCategory || (root.controller?.appCategories?.length > 0 ? root.controller.appCategories[0] : "")
            readonly property var iconMap: {
                const cats = root.controller?.appCategories ?? [];
                const m = {};
                cats.forEach(c => { m[c] = AppSearchService.getCategoryIcon(c); });
                return m;
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: chipArea.containsMouse || categoryPopup.visible ? Theme.surfaceContainerHigh : "transparent"
                border.color: categoryPopup.visible ? Theme.primary : Theme.outlineMedium
                border.width: categoryPopup.visible ? 2 : 1
            }

            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: categoryChip.iconMap[categoryChip.currentCategory] ?? "apps"
                    size: 14
                    color: Theme.surfaceText
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: categoryChip.currentCategory
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: categoryPopup.visible ? "expand_less" : "expand_more"
                    size: 14
                    color: Theme.surfaceVariantText
                }
            }

            MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (categoryPopup.visible) {
                        categoryPopup.close();
                    } else {
                        const pos = categoryChip.mapToItem(Overlay.overlay, 0, 0);
                        categoryPopup.x = pos.x;
                        categoryPopup.y = pos.y + categoryChip.height + 4;
                        categoryPopup.open();
                    }
                }
            }

            Popup {
                id: categoryPopup
                parent: Overlay.overlay
                width: Math.max(categoryChip.width, 180)
                padding: 0
                modal: true
                dim: false
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                background: Rectangle { color: "transparent" }

                contentItem: Rectangle {
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 1)
                    border.color: Theme.primary
                    border.width: 2

                    ElevationShadow {
                        anchors.fill: parent
                        z: -1
                        level: Theme.elevationLevel2
                        fallbackOffset: 4
                        targetRadius: parent.radius
                        targetColor: parent.color
                        borderColor: parent.border.color
                        borderWidth: parent.border.width
                        shadowEnabled: Theme.elevationEnabled && SettingsData.popoutElevationEnabled
                    }

                    ListView {
                        id: categoryList
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        model: root.controller?.appCategories ?? []
                        spacing: 2
                        clip: true
                        interactive: contentHeight > height
                        implicitHeight: contentHeight

                        delegate: Rectangle {
                            id: catDelegate
                            required property string modelData
                            required property int index
                            width: categoryList.width
                            height: 32
                            radius: Theme.cornerRadius
                            readonly property bool isCurrent: categoryChip.currentCategory === modelData
                            color: isCurrent ? Theme.primaryHover : catArea.containsMouse ? Theme.primaryHoverLight : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS

                                DankIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: categoryChip.iconMap[catDelegate.modelData] ?? "apps"
                                    size: 16
                                    color: catDelegate.isCurrent ? Theme.primary : Theme.surfaceText
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: catDelegate.modelData
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: catDelegate.isCurrent ? Theme.primary : Theme.surfaceText
                                    font.weight: catDelegate.isCurrent ? Font.Medium : Font.Normal
                                }
                            }

                            MouseArea {
                                id: catArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.controller)
                                        root.controller.setAppCategory(catDelegate.modelData);
                                    categoryPopup.close();
                                }
                            }
                        }
                    }
                }

                // Size to list content, cap at 10 visible items
                height: Math.min((root.controller?.appCategories?.length ?? 0) * 34, 10 * 34) + Theme.spacingS * 2 + 4
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.section?.items?.length ?? 0
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.outlineButton
        }
    }

    Row {
        id: rightContent
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS

        Row {
            id: viewModeRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            visible: root.canChangeViewMode && !root.section?.collapsed

            Repeater {
                model: [
                    {
                        mode: "list",
                        icon: "view_list"
                    },
                    {
                        mode: "grid",
                        icon: "grid_view"
                    },
                    {
                        mode: "tile",
                        icon: "view_module"
                    }
                ]

                Rectangle {
                    required property var modelData
                    required property int index

                    width: 20
                    height: 20
                    radius: 4
                    color: root.viewMode === modelData.mode ? Theme.primaryHover : modeArea.containsMouse ? Theme.surfaceHover : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: parent.modelData.icon
                        size: 14
                        color: root.viewMode === parent.modelData.mode ? Theme.primary : Theme.surfaceVariantText
                    }

                    MouseArea {
                        id: modeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.viewMode !== parent.modelData.mode && root.controller && root.section) {
                                root.controller.setSectionViewMode(root.section.id, parent.modelData.mode);
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: collapseButton
            width: root.canCollapse ? 24 : 0
            height: 24
            visible: root.canCollapse
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                anchors.centerIn: parent
                name: root.section?.collapsed ? "expand_more" : "expand_less"
                size: 16
                color: collapseArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
            }

            MouseArea {
                id: collapseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.controller && root.section) {
                        root.controller.toggleSection(root.section.id);
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: rightContent.width + Theme.spacingS
        cursorShape: root.canCollapse ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.canCollapse
        onClicked: {
            if (root.canCollapse && root.controller && root.section) {
                root.controller.toggleSection(root.section.id);
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.outlineMedium
        visible: root.isSticky
    }
}
