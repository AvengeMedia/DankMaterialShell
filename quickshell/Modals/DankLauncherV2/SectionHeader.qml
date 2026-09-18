pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.DankLauncherV2.Components

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var section: null
    property var controller: null
    property string viewMode: "list"
    property bool canChangeViewMode: true
    property bool canCollapse: true
    property bool popupAbove: false
    property Item popupAboveItem: null
    property Item focusReturnTarget: null
    property var transientSurfaceTracker: null
    readonly property bool hasAppCategories: section?.id === "apps" && (controller?.appCategories?.length ?? 0) > 0

    signal viewModeToggled

    width: parent?.width ?? Theme.fieldDefaultWidth
    height: LauncherMetrics.sectionHeight
    clip: true

    Row {
        anchors.left: parent.left
        anchors.right: controls.left
        anchors.leftMargin: root.hasAppCategories ? 0 : Theme.spacingS
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS

        Loader {
            active: root.hasAppCategories
            visible: active
            width: Math.min(Theme.fieldDefaultWidth, parent.width)
            height: LauncherMetrics.sectionHeight
            sourceComponent: DankDropdown {
                focusPolicy: Qt.NoFocus
                triggerHeight: Theme.buttonHeightXS
                dropdownWidth: width
                compactMode: true
                options: root.controller?.appCategories ?? []
                optionIcons: options.map(category => AppSearchService.getCategoryIcon(category))
                currentValue: root.controller?.appCategory || options[0] || ""
                openUpwards: root.popupAbove
                popupAnchorItem: root.popupAboveItem
                focusReturnTarget: root.focusReturnTarget
                transientSurfaceTracker: root.transientSurfaceTracker
                maxPopupHeight: LauncherMetrics.maxVisibleRows * Theme.menuItemHeight
                onValueChanged: value => root.controller?.setAppCategory(value)
            }
        }

        DankIcon {
            visible: !root.hasAppCategories
            anchors.verticalCenter: parent.verticalCenter
            name: root.section?.icon ?? "folder"
            size: Theme.iconSizeSmall
            color: Theme.primary
        }

        StyledText {
            visible: !root.hasAppCategories
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - Theme.iconSizeSmall - Theme.spacingS)
            text: root.section?.title ?? ""
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: Theme.primary
            elide: Text.ElideRight
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.groupedListGap

        Repeater {
            model: root.canChangeViewMode && !root.section?.collapsed ? [
                {
                    mode: "list",
                    icon: "view_list",
                    label: I18n.tr("List", "noun, list view mode option")
                },
                {
                    mode: "grid",
                    icon: "grid_view",
                    label: I18n.tr("Grid", "noun, grid view mode and layout option")
                },
                {
                    mode: "tile",
                    icon: "view_module",
                    label: I18n.tr("Tile")
                }
            ] : []

            DankActionButton {
                required property var modelData
                focusPolicy: Qt.NoFocus
                iconName: modelData.icon
                tooltipText: modelData.label
                iconSize: Theme.iconSizeSmall
                backgroundColor: root.viewMode === modelData.mode ? Theme.secondaryContainer : "transparent"
                iconColor: root.viewMode === modelData.mode ? Theme.onSecondaryContainer : Theme.onSurfaceVariant
                onClicked: {
                    if (!root.controller || !root.section || root.viewMode === modelData.mode)
                        return;
                    root.controller.setSectionViewMode(root.section.id, modelData.mode);
                }
            }
        }

        DankActionButton {
            focusPolicy: Qt.NoFocus
            visible: root.canCollapse
            iconName: root.section?.collapsed ? "expand_more" : "expand_less"
            Accessible.name: root.section?.collapsed ? I18n.tr("Expand") : I18n.tr("Collapse")
            iconSize: Theme.iconSizeSmall
            onClicked: {
                if (!root.controller || !root.section)
                    return;
                root.controller.toggleSection(root.section.id);
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: controls.width + Theme.spacingS
        enabled: root.canCollapse && !root.hasAppCategories
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.controller || !root.section)
                return;
            root.controller.toggleSection(root.section.id);
        }
    }
}
