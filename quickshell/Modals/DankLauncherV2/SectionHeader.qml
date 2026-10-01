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
    readonly property var viewModes: [
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
    ]

    signal viewModeToggled

    width: parent?.width ?? Theme.fieldDefaultWidth
    height: LauncherMetrics.sectionHeight
    clip: true

    readonly property string categoryLabel: controller?.appCategory || (controller?.appCategories?.[0] ?? "")

    Item {
        id: labelArea
        anchors.left: parent.left
        anchors.right: controls.left
        anchors.leftMargin: LauncherMetrics.headerInset
        anchors.rightMargin: Theme.spacingS
        height: parent.height

        Row {
            id: labelContent
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.hasAppCategories ? AppSearchService.getCategoryIcon(root.categoryLabel) : (root.section?.icon ?? "folder")
                size: Theme.iconSizeSmall
                color: Theme.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, labelArea.width - Theme.iconSizeSmall - Theme.spacingS - (chevron.visible ? chevron.width + Theme.spacingS : 0))
                text: root.hasAppCategories ? root.categoryLabel : (root.section?.title ?? "")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                color: Theme.primary
                elide: Text.ElideRight
            }

            DankIcon {
                id: chevron
                visible: root.hasAppCategories
                anchors.verticalCenter: parent.verticalCenter
                name: "arrow_drop_down"
                size: Theme.iconSizeSmall
                color: Theme.primary
            }
        }

        MouseArea {
            anchors.fill: labelContent
            enabled: root.hasAppCategories
            cursorShape: Qt.PointingHandCursor
            onClicked: categoryDropdown.item?.openDropdownMenu()
        }

        Loader {
            id: categoryDropdown
            active: root.hasAppCategories
            sourceComponent: DankDropdown {
                showTrigger: false
                focusPolicy: Qt.NoFocus
                popupWidth: Math.min(Theme.fieldDefaultWidth, root.width)
                compactMode: true
                options: root.controller?.appCategories ?? []
                optionIcons: options.map(category => AppSearchService.getCategoryIcon(category))
                currentValue: root.categoryLabel
                openUpwards: root.popupAbove
                popupAnchorItem: root.popupAbove ? root.popupAboveItem : labelContent
                focusReturnTarget: root.focusReturnTarget
                transientSurfaceTracker: root.transientSurfaceTracker
                maxPopupHeight: LauncherMetrics.maxVisibleRows * Theme.menuItemHeight
                onValueChanged: value => root.controller?.setAppCategory(value)
            }
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.rightMargin: 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.groupedListGap

        DankActionButton {
            readonly property var current: root.viewModes.find(entry => entry.mode === root.viewMode) ?? root.viewModes[0]
            focusPolicy: Qt.NoFocus
            visible: root.canChangeViewMode && !root.section?.collapsed
            iconName: current.icon
            tooltipText: current.label
            iconSize: Theme.iconSizeSmall
            onClicked: {
                if (!root.controller || !root.section)
                    return;
                const index = root.viewModes.indexOf(current);
                root.controller.setSectionViewMode(root.section.id, root.viewModes[(index + 1) % root.viewModes.length].mode);
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
