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
    property real targetPopupHeight: 400
    property bool _heightUpdatePending: false

    signal lockRequested

    function _maxPopupHeight() {
        const screenHeight = (triggerScreen?.height ?? 1080);
        return screenHeight - 100;
    }

    function _contentTargetHeight() {
        const item = contentLoader.item;
        if (!item)
            return 400;
        const naturalHeight = item.targetImplicitHeight !== undefined ? item.targetImplicitHeight : item.implicitHeight;
        return Math.max(300, naturalHeight + 20);
    }

    function updateTargetPopupHeight() {
        const target = Math.min(_maxPopupHeight(), _contentTargetHeight());
        if (Math.abs(targetPopupHeight - target) < 0.5)
            return;
        targetPopupHeight = target;
    }

    function queueTargetPopupHeightUpdate() {
        if (_heightUpdatePending)
            return;
        _heightUpdatePending = true;
        Qt.callLater(() => {
            _heightUpdatePending = false;
            updateTargetPopupHeight();
        });
    }

    function collapseAll() {
        expandedSection = "";
        expandedWidgetIndex = -1;
        expandedWidgetData = null;
        queueTargetPopupHeightUpdate();
    }

    onEditModeChanged: {
        if (editMode) {
            collapseAll();
        }
        queueTargetPopupHeightUpdate();
    }

    onVisibleChanged: {
        if (!visible) {
            collapseAll();
        }
    }

    readonly property color _containerBg: Theme.nestedSurface

    function openWithSection(section) {
        StateUtils.openWithSection(root, section);
    }

    function toggleSection(section) {
        StateUtils.toggleSection(root, section);
    }

    popupWidth: 550
    popupHeight: targetPopupHeight
    triggerWidth: 80
    positioning: ""
    screen: triggerScreen
    shouldBeVisible: false

    property bool credentialsPromptOpen: NetworkService.credentialsRequested
    property bool wifiPasswordModalOpen: PopoutService.wifiPasswordModal?.visible ?? false
    property bool polkitModalOpen: PopoutService.polkitAuthModal?.visible ?? false
    property bool anyModalOpen: credentialsPromptOpen || wifiPasswordModalOpen || polkitModalOpen || powerMenuOpen

    backgroundInteractive: !anyModalOpen

    onCredentialsPromptOpenChanged: {
        if (credentialsPromptOpen && shouldBeVisible)
            close();
    }

    onPolkitModalOpenChanged: {
        if (polkitModalOpen && shouldBeVisible)
            close();
    }

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
            queueTargetPopupHeightUpdate();
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

    onExpandedSectionChanged: queueTargetPopupHeightUpdate()
    onExpandedWidgetIndexChanged: queueTargetPopupHeightUpdate()
    onTriggerScreenChanged: queueTargetPopupHeightUpdate()

    Connections {
        target: contentLoader
        function onLoaded() {
            root.queueTargetPopupHeightUpdate();
        }
    }

    Connections {
        target: contentLoader.item
        ignoreUnknownSignals: true
        function onTargetImplicitHeightChanged() {
            root.queueTargetPopupHeightUpdate();
        }
        function onImplicitHeightChanged() {
            root.queueTargetPopupHeightUpdate();
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

            readonly property real targetImplicitHeight: {
                let total = headerPane.implicitHeight + Theme.spacingS + widgetGrid.targetImplicitHeight;
                if (editControls.visible)
                    total += Theme.spacingS + editControls.height;
                return total + Theme.spacingM;
            }
            implicitHeight: targetImplicitHeight
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
                    enabled: !Theme.isDirectionalEffect
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.shouldBeVisible ? Theme.variantPopoutEnterCurve : Theme.variantPopoutExitCurve
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
                            return screenHeight - 100 - Theme.spacingL - headerPane.implicitHeight - Theme.spacingS;
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
                        id: editControls
                        width: parent.width
                        visible: editMode
                        popupScreen: root.screen
                        popoutX: root.alignedX
                        popoutY: root.alignedY
                        popoutWidth: root.alignedWidth
                        popoutHeight: root.alignedHeight
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
