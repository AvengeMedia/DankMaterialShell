import QtQuick
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Settings.Widgets

Column {
    id: root
    readonly property var log: Log.scoped("WidgetsTabSection")

    property var items: []
    property var allWidgets: []
    property string title: ""
    property string sectionId: ""

    signal itemEnabledChanged(string sectionId, string itemId, bool enabled)
    signal itemOrderChanged(string sectionId, var indices)
    signal addWidget(string sectionId)
    signal removeWidget(string sectionId, int widgetIndex)
    signal spacerSizeChanged(string sectionId, int widgetIndex, int newSize)
    signal configureWidget(string sectionId, int widgetIndex)

    signal dragStarted(string sectionId, string itemId)

    property var reorderGroup: null
    property string highlightedId: ""
    property string highlightedSection: ""

    width: parent.width
    height: implicitHeight
    spacing: Theme.spacingM

    SettingsSectionLabel {
        text: root.title
        actions: [
            DankActionButton {
                buttonSize: Theme.buttonHeightXXS
                iconName: "format_list_numbered"
                tooltipText: I18n.tr("Index centering")
                iconSize: Theme.iconSizeSmall
                iconColor: SettingsData.centeringMode === "index" ? Theme.primary : Theme.outline
                visible: root.sectionId === "center"
                onClicked: SettingsData.set("centeringMode", "index")
            },
            DankActionButton {
                buttonSize: Theme.buttonHeightXXS
                iconName: "center_focus_weak"
                tooltipText: I18n.tr("Geometric centering")
                iconSize: Theme.iconSizeSmall
                iconColor: SettingsData.centeringMode === "geometric" ? Theme.primary : Theme.outline
                visible: root.sectionId === "center"
                onClicked: SettingsData.set("centeringMode", "geometric")
            }
        ]
    }

    SettingsReorderList {
        id: reorderArea

        model: root.items
        group: root.reorderGroup
        groupKey: root.sectionId
        dropArea: root
        onReordered: indices => root.itemOrderChanged(root.sectionId, indices)
        onDragStarted: (index, position) => root.dragStarted(root.sectionId, root.items[index].id)

        delegate: SettingsReorderRow {
            id: widgetRow

            required property var modelData

            readonly property bool configurable: BarWidgetCatalog.hasOptions(modelData.id) || !!modelData.pluginId
            readonly property bool highlighted: root.highlightedId === modelData.id && root.highlightedSection === root.sectionId

            reorderList: reorderArea
            opacity: dragging && reorderArea.crossSectionActive ? 0 : 1
            title: modelData.text
            iconName: modelData.icon
            iconColor: modelData.enabled ? Theme.primary : Theme.onSurfaceVariant
            titleColor: modelData.enabled ? Theme.onSurface : Theme.onSurfaceVariant
            subtitle: {
                if (modelData.id !== "gpuTemp")
                    return modelData.description ?? "";
                const selectedIndex = modelData.selectedGpuIndex ?? 0;
                const gpu = DgopService.availableGpus?.[selectedIndex];
                if (!gpu)
                    return I18n.tr("No GPU detected", "empty state when no graphics card is found");
                return gpu.driver?.toUpperCase() ?? "";
            }
            clickable: configurable
            onClicked: root.configureWidget(root.sectionId, index)

            Item {
                width: Theme.iconButtonSize
                height: Theme.iconButtonSize
                visible: !!widgetRow.modelData.warning
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: "warning"
                    size: Theme.iconSizeMedium
                    color: Theme.error
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: warningArea
                    anchors.fill: parent
                    hoverEnabled: true
                }

                DankTooltipHost {
                    text: widgetRow.modelData.warning
                    target: parent
                    hoverArea: warningArea
                }
            }

            DankIcon {
                name: "chevron_right"
                size: Theme.iconSize
                color: Theme.onSurfaceVariant
                rotation: I18n.isRtl ? 180 : 0
                visible: widgetRow.configurable
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: Theme.dividerWidth
                height: SettingsMetrics.splitDividerHeight
                color: Theme.outlineVariant
                visible: widgetRow.configurable
                anchors.verticalCenter: parent.verticalCenter
            }

            DankNumberStepper {
                visible: widgetRow.modelData.id === "spacer"
                anchors.verticalCenter: parent.verticalCenter
                text: (widgetRow.modelData.size || 20).toString()
                decrementEnabled: (widgetRow.modelData.size || 20) > 5
                incrementEnabled: (widgetRow.modelData.size || 20) < 5000
                onDecrement: () => root.spacerSizeChanged(root.sectionId, widgetRow.index, Math.max(5, (widgetRow.modelData.size || 20) - 5))
                onIncrement: () => root.spacerSizeChanged(root.sectionId, widgetRow.index, Math.min(5000, (widgetRow.modelData.size || 20) + 5))
            }

            DankToggle {
                hideText: true
                visible: widgetRow.modelData.id !== "spacer"
                checked: widgetRow.modelData.enabled
                anchors.verticalCenter: parent.verticalCenter
                onToggled: value => root.itemEnabledChanged(root.sectionId, widgetRow.modelData.id, value)
            }

            DankActionButton {
                iconName: "close"
                iconColor: Theme.error
                Accessible.name: I18n.tr("Remove")
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.removeWidget(root.sectionId, widgetRow.index)
            }

            Rectangle {
                parent: widgetRow
                anchors.fill: parent
                anchors.margins: Theme.focusRingWidth / 2
                topLeftRadius: Math.max(0, widgetRow.topRadius - Theme.focusRingWidth / 2)
                topRightRadius: topLeftRadius
                bottomLeftRadius: Math.max(0, widgetRow.bottomRadius - Theme.focusRingWidth / 2)
                bottomRightRadius: bottomLeftRadius
                color: "transparent"
                border.width: Theme.focusRingWidth
                border.color: Theme.focusRingColor
                visible: widgetRow.highlighted && !widgetRow.dragging
            }
        }
    }

    DankButton {
        anchors.horizontalCenter: parent.horizontalCenter
        text: I18n.tr("Add widget")
        iconName: "add"
        backgroundColor: Theme.secondaryContainer
        textColor: Theme.onSecondaryContainer
        onClicked: root.addWidget(root.sectionId)
    }
}
