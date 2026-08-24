pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Components
import qs.Modules.ControlCenter.Models
import qs.Modules.ControlCenter.Details
import qs.Widgets

Rectangle {
    id: root

    required property var host

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property real targetImplicitHeight: {
        let total = Theme.spacingL + headerPane.implicitHeight + Theme.spacingS + widgetGrid.targetImplicitHeight;
        if (editControls.visible)
            total += Theme.spacingS + editControls.height;
        return total + Theme.spacingL;
    }
    property alias bluetoothCodecSelector: bluetoothCodecSelector
    property alias audioPortSelector: audioPortSelector

    implicitHeight: targetImplicitHeight
    color: "transparent"
    clip: true

    WidgetModel {
        id: widgetModel
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        radius: parent.radius
        visible: root.host.powerMenuOpen
        z: 5000

        Behavior on opacity {
            enabled: !Theme.isDirectionalEffect
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.host.shouldBeVisible ? Theme.variantPopoutEnterCurve : Theme.variantPopoutExitCurve
            }
        }
    }

    DankFlickable {
        id: contentFlickable

        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, mainColumn.implicitHeight + Theme.spacingM)
        interactive: contentHeight > height

        Column {
            id: mainColumn

            width: contentFlickable.width - Theme.spacingL * 2
            x: Theme.spacingL
            y: Theme.spacingL
            spacing: Theme.spacingS

            HeaderPane {
                id: headerPane

                width: parent.width
                editMode: root.host.editMode
                tapToClose: root.host.headerTogglesClose ?? false
                onHeaderTapped: root.host.close()
                onEditModeToggled: root.host.editMode = !root.host.editMode
                onPowerButtonClicked: {
                    const loader = root.host.powerMenuModalLoader;
                    if (!loader)
                        return;
                    loader.active = true;
                    if (loader.item) {
                        const bounds = Qt.rect(root.host.alignedX, root.host.alignedY, root.host.popupWidth, root.host.popupHeight);
                        loader.item.openFromControlCenter(bounds, root.host.screen);
                    }
                }
                onLockRequested: {
                    root.host.close();
                    root.host.lockRequested();
                }
                onSettingsButtonClicked: root.host.close()
            }

            DragDropGrid {
                id: widgetGrid

                width: parent.width
                editMode: root.host.editMode
                maxPopoutHeight: {
                    const screenHeight = (root.host.triggerScreen?.height ?? 1080);
                    return screenHeight - 100 - Theme.spacingL - headerPane.implicitHeight - Theme.spacingS;
                }
                expandedSection: root.host.expandedSection
                expandedWidgetIndex: root.host.expandedWidgetIndex
                expandedWidgetData: root.host.expandedWidgetData
                model: widgetModel
                bluetoothCodecSelector: bluetoothCodecSelector
                audioPortSelector: audioPortSelector
                colorPickerModal: root.host.colorPickerModal
                screenName: root.host.triggerScreen?.name || ""
                screenModel: root.host.triggerScreen?.model || ""
                parentScreen: root.host.triggerScreen
                onExpandClicked: (widgetData, globalIndex) => {
                    root.host.expandedWidgetIndex = globalIndex;
                    root.host.expandedWidgetData = widgetData;
                    if (widgetData.id === "diskUsage") {
                        root.host.toggleSection("diskUsage_" + (widgetData.instanceId || "default"));
                    } else if (widgetData.id === "brightnessSlider") {
                        root.host.toggleSection("brightnessSlider_" + (widgetData.instanceId || "default"));
                    } else {
                        root.host.toggleSection(widgetData.id);
                    }
                }
                onRemoveWidget: index => widgetModel.removeWidget(index)
                onMoveWidget: (fromIndex, toIndex) => widgetModel.moveWidget(fromIndex, toIndex)
                onToggleWidgetSize: index => widgetModel.toggleWidgetSize(index)
                onCollapseRequested: root.host.collapseAll()
                onConfigRequested: (idx, data, anchor) => widgetConfigOverlay.open(idx, data, anchor)
            }

            EditControls {
                id: editControls

                width: parent.width
                visible: root.host.editMode
                popupScreen: root.host.screen
                popoutX: root.host.alignedX
                popoutY: root.host.alignedY
                popoutWidth: root.host.alignedWidth
                popoutHeight: root.host.alignedHeight
                availableWidgets: {
                    if (!root.host.editMode)
                        return [];
                    const existingIds = (SettingsData.controlCenterWidgets || []).map(w => w.id);
                    const allWidgets = widgetModel.baseWidgetDefinitions.concat(widgetModel.getPluginWidgets());
                    return allWidgets.filter(w => w.allowMultiple || !existingIds.includes(w.id));
                }
                onAddWidget: widgetId => widgetModel.addWidget(widgetId)
                onResetToDefault: () => widgetModel.resetToDefault()
                onClearAll: () => widgetModel.clearAll()
            }
        }
    }

    BluetoothCodecSelector {
        id: bluetoothCodecSelector

        anchors.fill: parent
        z: 10000
    }

    AudioPortSelector {
        id: audioPortSelector

        anchors.fill: parent
        z: 10000
    }

    WidgetConfigOverlay {
        id: widgetConfigOverlay

        anchors.fill: parent
    }
}
