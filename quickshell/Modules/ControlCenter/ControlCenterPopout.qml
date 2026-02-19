import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Modules.ControlCenter.Details
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Components
import qs.Modules.ControlCenter.Models
import "./utils/state.js" as StateUtils

DankPopout {
    id: root

    layerNamespace: "dms:control-center"
    fullHeightSurface: true

    property string expandedSection: ""
    property var triggerScreen: null
    property bool editMode: false
    property int expandedWidgetIndex: -1
    property var expandedWidgetData: null
    property bool powerMenuOpen: powerMenuModalLoader?.item?.shouldBeVisible ?? false

    signal lockRequested

    function collapseAll() {
        expandedSection = "";
        expandedWidgetIndex = -1;
        expandedWidgetData = null;
    }

    onEditModeChanged: {
        if (editMode) {
            collapseAll();
        }
    }

    onVisibleChanged: {
        if (!visible) {
            collapseAll();
        }
    }

    readonly property color _containerBg: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    function openWithSection(section) {
        StateUtils.openWithSection(root, section);
    }

    function toggleSection(section) {
        StateUtils.toggleSection(root, section);
    }

    popupWidth: 550
    popupHeight: {
        const screenHeight = (triggerScreen?.height ?? 1080);
        const maxHeight = screenHeight - 100;
        const contentHeight = contentLoader.item && contentLoader.item.implicitHeight > 0 ? contentLoader.item.implicitHeight + 20 : 400;
        return Math.min(maxHeight, contentHeight);
    }
    triggerWidth: 80
    positioning: ""
    screen: triggerScreen
    shouldBeVisible: false

    property bool credentialsPromptOpen: NetworkService.credentialsRequested
    property bool wifiPasswordModalOpen: PopoutService.wifiPasswordModal?.visible ?? false
    property bool polkitModalOpen: PopoutService.polkitAuthModal?.visible ?? false
    property bool anyModalOpen: credentialsPromptOpen || wifiPasswordModalOpen || polkitModalOpen || powerMenuOpen

    backgroundInteractive: !anyModalOpen

    customKeyboardFocus: {
        if (!shouldBeVisible)
            return WlrKeyboardFocus.None;
        if (anyModalOpen)
            return WlrKeyboardFocus.None;
        if (CompositorService.useHyprlandFocusGrab)
            return WlrKeyboardFocus.OnDemand;
        return WlrKeyboardFocus.Exclusive;
    }

    onBackgroundClicked: close()

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            collapseAll();
            Qt.callLater(() => {
                if (NetworkService.activeService)
                    NetworkService.activeService.autoRefreshEnabled = NetworkService.wifiEnabled;
            });
        } else {
            Qt.callLater(() => {
                if (NetworkService.activeService) {
                    NetworkService.activeService.autoRefreshEnabled = false;
                }
                if (BluetoothService.adapter && BluetoothService.adapter.discovering)
                    BluetoothService.adapter.discovering = false;
                editMode = false;
            });
        }
    }

    WidgetModel {
        id: widgetModel
    }

    content: Component {
        Rectangle {
            id: controlContent

            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            implicitHeight: mainColumn.implicitHeight + Theme.spacingM
            property alias bluetoothCodecSelector: bluetoothCodecSelector

            color: "transparent"
            clip: true

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.6)
                radius: parent.radius
                visible: root.powerMenuOpen
                z: 5000

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Column {
                id: mainColumn
                width: parent.width - Theme.spacingL * 2
                x: Theme.spacingL
                y: Theme.spacingL
                spacing: Theme.spacingS

                HeaderPane {
                    id: headerPane
                    width: parent.width
                    editMode: root.editMode
                    onEditModeToggled: root.editMode = !root.editMode
                    onPowerButtonClicked: {
                        if (powerMenuModalLoader) {
                            powerMenuModalLoader.active = true;
                            if (powerMenuModalLoader.item) {
                                const bounds = Qt.rect(root.alignedX, root.alignedY, root.popupWidth, root.popupHeight);
                                powerMenuModalLoader.item.openFromControlCenter(bounds, root.screen);
                            }
                        }
                    }
                    onLockRequested: {
                        root.close();
                        root.lockRequested();
                    }
                    onSettingsButtonClicked: {
                        root.close();
                    }
                }

                DragDropGrid {
                    id: widgetGrid
                    width: parent.width
                    editMode: root.editMode
                    maxPopoutHeight: {
                        const screenHeight = (root.triggerScreen?.height ?? 1080);
                        return screenHeight - 100 - Theme.spacingL - headerPane.height - Theme.spacingS;
                    }
                    expandedSection: root.expandedSection
                    expandedWidgetIndex: root.expandedWidgetIndex
                    expandedWidgetData: root.expandedWidgetData
                    model: widgetModel
                    bluetoothCodecSelector: bluetoothCodecSelector
                    colorPickerModal: root.colorPickerModal
                    screenName: root.triggerScreen?.name || ""
                    screenModel: root.triggerScreen?.model || ""
                    parentScreen: root.triggerScreen
                    onExpandClicked: (widgetData, globalIndex) => {
                        root.expandedWidgetIndex = globalIndex;
                        root.expandedWidgetData = widgetData;
                        if (widgetData.id === "diskUsage") {
                            root.toggleSection("diskUsage_" + (widgetData.instanceId || "default"));
                        } else if (widgetData.id === "brightnessSlider") {
                            root.toggleSection("brightnessSlider_" + (widgetData.instanceId || "default"));
                        } else {
                            root.toggleSection(widgetData.id);
                        }
                    }
                    onRemoveWidget: index => widgetModel.removeWidget(index)
                    onMoveWidget: (fromIndex, toIndex) => widgetModel.moveWidget(fromIndex, toIndex)
                    onToggleWidgetSize: index => widgetModel.toggleWidgetSize(index)
                    onCollapseRequested: root.collapseAll()
                }

                EditControls {
                    width: parent.width
                    visible: editMode
                    popoutContent: controlContent
                    availableWidgets: {
                        if (!editMode)
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

            BluetoothCodecSelector {
                id: bluetoothCodecSelector
                anchors.fill: parent
                z: 10000
            }
        }
    }

    Component {
        id: networkDetailComponent
        NetworkDetail {}
    }

    Component {
        id: bluetoothDetailComponent
        BluetoothDetail {
            id: bluetoothDetail
            onShowCodecSelector: function (device) {
                if (contentLoader.item && contentLoader.item.bluetoothCodecSelector) {
                    contentLoader.item.bluetoothCodecSelector.show(device);
                    contentLoader.item.bluetoothCodecSelector.codecSelected.connect(function (deviceAddress, codecName) {
                        bluetoothDetail.updateDeviceCodecDisplay(deviceAddress, codecName);
                    });
                }
            }
        }
    }

    Component {
        id: audioOutputDetailComponent
        AudioOutputDetail {}
    }

    Component {
        id: audioInputDetailComponent
        AudioInputDetail {}
    }

    Component {
        id: batteryDetailComponent
        BatteryDetail {}
    }

    property var colorPickerModal: null
    property var powerMenuModalLoader: null
}
