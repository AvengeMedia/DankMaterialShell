import QtQuick
import qs.Common
import qs.Services

Item {
    id: root
    readonly property var log: Log.scoped("DankLauncherV2Modal")

    readonly property bool spotlightOpen: impl.item ? impl.item.spotlightOpen : false
    readonly property bool isClosing: impl.item ? impl.item.isClosing : false
    readonly property bool keyboardActive: impl.item ? impl.item.keyboardActive : false
    readonly property bool contentVisible: impl.item ? impl.item.contentVisible : false
    readonly property var spotlightContent: impl.item ? impl.item.spotlightContent : null
    readonly property bool openedFromOverview: impl.item ? impl.item.openedFromOverview : false
    readonly property var effectiveScreen: impl.item ? impl.item.effectiveScreen : null
    readonly property real screenWidth: impl.item ? impl.item.screenWidth : 1920
    readonly property real screenHeight: impl.item ? impl.item.screenHeight : 1080
    readonly property real dpr: impl.item ? impl.item.dpr : 1
    readonly property int modalWidth: impl.item ? impl.item.modalWidth : 620
    readonly property int modalHeight: impl.item ? impl.item.modalHeight : 600
    readonly property real modalX: impl.item ? impl.item.modalX : 0
    readonly property real modalY: impl.item ? impl.item.modalY : 0
    readonly property bool frameOwnsConnectedChrome: impl.item ? (impl.item.frameOwnsConnectedChrome ?? false) : false
    readonly property string resolvedConnectedBarSide: impl.item ? (impl.item.resolvedConnectedBarSide ?? "") : ""
    readonly property bool launcherArcExtenderActive: impl.item ? (impl.item.launcherArcExtenderActive ?? false) : false

    signal dialogClosed

    function show() {
        if (impl.item)
            impl.item.show();
    }

    function showWithQuery(query) {
        if (impl.item)
            impl.item.showWithQuery(query);
    }

    function showWithMode(mode) {
        if (impl.item)
            impl.item.showWithMode(mode);
    }

    function hide() {
        if (impl.item)
            impl.item.hide();
    }

    function toggle() {
        if (impl.item)
            impl.item.toggle();
    }

    function toggleWithQuery(query) {
        if (impl.item)
            impl.item.toggleWithQuery(query);
    }

    function toggleWithMode(mode) {
        if (impl.item)
            impl.item.toggleWithMode(mode);
    }

    readonly property var _desiredBackend: SettingsData.connectedFrameModeActive ? connectedComp : standaloneComp
    property var _resolvedBackend: null

    Component.onCompleted: _resolvedBackend = _desiredBackend

    Connections {
        target: SettingsData
        function onConnectedFrameModeActiveChanged() {
            root._maybeResolveBackend();
        }
    }

    // Defer Loader source-component swap until impl is fully closed; avoids
    // tearing down the launcher mid-animation when frame mode is toggled.
    function _maybeResolveBackend() {
        if (_resolvedBackend === _desiredBackend)
            return;
        if (impl.item && (impl.item.spotlightOpen || impl.item.isClosing))
            return;
        _resolvedBackend = _desiredBackend;
    }

    Loader {
        id: impl
        sourceComponent: root._resolvedBackend
        onItemChanged: if (item)
            root._wireBackend(item)
    }

    Component {
        id: standaloneComp
        DankLauncherV2ModalStandalone {}
    }

    Component {
        id: connectedComp
        DankLauncherV2ModalConnected {}
    }

    function _wireBackend(it) {
        if (!it)
            return;
        it.modalHandle = root;
    }

    Connections {
        target: impl.item
        ignoreUnknownSignals: true

        function onDialogClosed() {
            root.dialogClosed();
            root._maybeResolveBackend();
        }
    }
}
