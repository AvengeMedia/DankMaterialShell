pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import qs.Modules.Network

Item {
    id: root

    property var parentModal

    property bool qrOpen: false
    property bool qrMounted: false
    property bool qrLoading: false
    property string _qrSsid: ""
    property Item _returnFocus: null

    readonly property Item _openDialog: qrOpen ? qrDialog : null
    readonly property WifiQRCodeDialog qrDialog: qrLoader.item as WifiQRCodeDialog
    readonly property Item windowFocusItem: root.Window.window?.activeFocusItem ?? null

    onWindowFocusItemChanged: {
        if (_openDialog)
            focusTrapTimer.restart();
    }

    function openQRCode(ssid) {
        if (qrOpen || qrLoading)
            return;
        qrLoading = true;
        const reuse = qrLoader.item !== null;
        _returnFocus = root.Window.window?.activeFocusItem ?? null;
        _qrSsid = ssid;
        qrMounted = true;
        if (reuse)
            qrDialog.load(ssid);
    }

    function _closeQR() {
        if (!qrOpen)
            return;
        qrOpen = false;
        if (qrDialog)
            qrDialog.opened = false;
        _restoreFocus();
    }

    function _restoreFocus() {
        const focusItem = _returnFocus;
        _returnFocus = null;
        if (focusItem?.visible && focusItem.enabled)
            focusItem.forceActiveFocus(Qt.OtherFocusReason);
    }

    function _trapFocus() {
        if (!root.Window.window?.active)
            return;
        const dialog = _openDialog;
        if (!dialog || dialog.activeFocus)
            return;
        const first = dialog.nextItemInFocusChain(true);
        if (first && _isInside(first, dialog)) {
            first.forceActiveFocus(Qt.TabFocusReason);
            return;
        }
        dialog.forceActiveFocus();
    }

    function _isInside(item, ancestor) {
        for (let node = item; node; node = node.parent) {
            if (node === ancestor)
                return true;
        }
        return false;
    }

    Timer {
        id: focusTrapTimer
        interval: 0
        onTriggered: root._trapFocus()
    }

    Loader {
        id: qrLoader
        parent: root.parentModal?.modalFocusScope ?? root
        anchors.fill: parent
        z: 100
        active: root.qrMounted
        onLoaded: (item as WifiQRCodeDialog).load(root._qrSsid)

        sourceComponent: WifiQRCodeDialog {
            embedded: false
            opened: false
            onFailed: {
                root.qrLoading = false;
                root.qrMounted = false;
            }
            onReady: {
                root.qrLoading = false;
                root.qrOpen = true;
                opened = true;
                forceActiveFocus();
            }
            onRejected: root._closeQR()
            onActiveChanged: {
                if (!active && !root.qrOpen && !root.qrLoading)
                    root.qrMounted = false;
            }
        }
    }
}
