import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Modules.ControlCenter.Details
import qs.Services
import qs.Widgets
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
        // The content now reports its own insets, so no popout-side padding.
        const naturalHeight = item.targetImplicitHeight !== undefined ? item.targetImplicitHeight : item.implicitHeight;
        return Math.max(300, naturalHeight);
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

    // Defer open one tick so screen-change geometry settles before the surface
    // maps; a synchronous open churns the surface and loses the blur on a switch.
    function present() {
        Qt.callLater(open);
    }

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
    property bool wifiPasswordModalOpen: PopoutService.wifiPasswordModal?.shouldBeVisible ?? false
    property bool polkitModalOpen: PopoutService.polkitAuthModal?.visible ?? false
    property bool anyModalOpen: credentialsPromptOpen || wifiPasswordModalOpen || polkitModalOpen || powerMenuOpen

    backgroundInteractive: !anyModalOpen
    hoverDismissSuspended: editMode || anyModalOpen

    onCredentialsPromptOpenChanged: {
        if (credentialsPromptOpen && shouldBeVisible)
            close();
    }

    onPolkitModalOpenChanged: {
        if (polkitModalOpen && shouldBeVisible)
            close();
    }

    customKeyboardFocus: anyModalOpen ? WlrKeyboardFocus.None : null

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

    content: Component {
        ControlCenterContent {
            host: root
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
            bluetoothCodecModalRef: contentLoader.item ? contentLoader.item.bluetoothCodecSelector : null
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
