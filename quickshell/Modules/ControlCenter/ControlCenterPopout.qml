import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

DankPopout {
    id: root

    layerNamespace: "dms:control-center"
    fullHeightSurface: true
    resizeCurve: Theme.expressiveCurves.standard
    resizeDuration: Theme.expressiveDurations.expressiveFastSpatial
    resizeMotion: true
    resizing: contentLoader.item?.panelResizing ?? false
    surfacePadding: PopoutMetrics.editOverflow * 2
    inputMargin: editMode ? PopoutMetrics.editOverflow * 2 : 0
    minimumSurfaceWidth: editMode ? CcMetrics.sheetWidthFor(gridColumnCap) : 0

    property string expandedSection: ""
    property string pendingSection: ""
    property var triggerScreen: null
    property bool editMode: false
    readonly property int gridColumnCap: CcMetrics.columnCapFor((triggerScreen?.width ?? CcMetrics.sheetWidthDefault + Theme.spacingL * 2) - Theme.spacingL * 2)
    readonly property int gridColumns: Math.min(CcMetrics.gridColumns, gridColumnCap)
    readonly property real sheetContentWidth: CcMetrics.sheetWidthFor(gridColumns)
    readonly property real availableHeight: _maxPopupHeight()
    property bool powerMenuOpen: powerMenuModalLoader?.item?.shouldBeVisible ?? false
    property var colorPickerModal: null
    property var powerMenuModalLoader: null

    property string requestedWindow: ""

    function openSettings() {
        requestedWindow = "settings";
        close();
    }

    function openColorPicker() {
        if (!colorPickerModal)
            return;
        requestedWindow = "colorPicker";
        close();
    }

    function completeWindowClose() {
        if (!requestedWindow || !isClosing)
            return;
        instantClose();
    }

    onCloseAnimationFinished: finishClose.schedule()

    DeferredAction {
        id: finishClose
        onTriggered: root.completeWindowClose()
    }

    DeferredAction {
        id: openWindow
        onTriggered: {
            const requested = root.requestedWindow;
            root.requestedWindow = "";
            switch (requested) {
            case "settings":
                PopoutService.focusOrToggleSettings();
                break;
            case "colorPicker":
                root.colorPickerModal?.show();
                break;
            }
        }
    }

    onPopoutClosed: {
        editMode = false;
        collapseAll();
        if (requestedWindow)
            openWindow.schedule();
    }

    signal lockRequested

    function _maxPopupHeight() {
        const screenHeight = triggerScreen?.height ?? CcMetrics.fallbackScreenHeight;
        return screenHeight - CcMetrics.maxHeightInset;
    }

    function collapseAll() {
        expandedSection = "";
    }

    popupWidth: sheetContentWidth
    popupHeight: Math.min(_maxPopupHeight(), Math.max(CcMetrics.minHeight, contentLoader.item?.targetImplicitHeight ?? CcMetrics.minHeight))
    triggerWidth: CcMetrics.triggerWidth
    positioning: ""
    screen: triggerScreen
    shouldBeVisible: false
    contentHandlesKeys: true

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
            finishClose.cancel();
            openWindow.cancel();
            requestedWindow = "";
            expandedSection = pendingSection;
            pendingSection = "";
            Qt.callLater(() => {
                contentLoader.item?.forceActiveFocus();
                if (NetworkService.activeService)
                    NetworkService.activeService.autoRefreshEnabled = NetworkService.wifiEnabled;
            });
            return;
        }
        Qt.callLater(() => {
            if (NetworkService.activeService)
                NetworkService.activeService.autoRefreshEnabled = false;
            if (BluetoothService.adapter && BluetoothService.adapter.discovering)
                BluetoothService.adapter.discovering = false;
        });
    }

    content: Component {
        ControlCenterContent {
            host: root
        }
    }
}
