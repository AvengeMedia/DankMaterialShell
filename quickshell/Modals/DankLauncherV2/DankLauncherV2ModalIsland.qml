pragma ComponentBehavior: Bound

import QtQuick
import qs.Services

Item {
    id: root

    property var modalHandle: root
    property bool triggerUsesOverlayLayer: false
    property bool usingFallback: false
    property bool _islandWasOpen: false

    readonly property var log: Log.scoped("DankLauncherV2ModalIsland")
    readonly property var router: PopoutService.dankIslandRouter
    readonly property bool spotlightOpen: usingFallback ? fallback.spotlightOpen : (router?.launcherOpen ?? false)
    readonly property bool isClosing: usingFallback ? fallback.isClosing : false
    readonly property bool keyboardActive: usingFallback ? fallback.keyboardActive : spotlightOpen
    readonly property bool contentVisible: usingFallback ? fallback.contentVisible : spotlightOpen
    readonly property var spotlightContent: usingFallback ? fallback.spotlightContent : null
    readonly property bool openedFromOverview: usingFallback ? fallback.openedFromOverview : false
    readonly property var effectiveScreen: usingFallback ? fallback.effectiveScreen : null
    readonly property real screenWidth: usingFallback ? fallback.screenWidth : 1920
    readonly property real screenHeight: usingFallback ? fallback.screenHeight : 1080
    readonly property real dpr: usingFallback ? fallback.dpr : 1
    readonly property int modalWidth: usingFallback ? fallback.modalWidth : 680
    readonly property int modalHeight: usingFallback ? fallback.modalHeight : 560
    readonly property real modalX: usingFallback ? fallback.modalX : 0
    readonly property real modalY: usingFallback ? fallback.modalY : 0
    readonly property bool frameOwnsConnectedChrome: false
    readonly property string resolvedConnectedBarSide: ""
    readonly property bool launcherArcExtenderActive: false

    signal dialogClosed

    function _openIsland(query, mode) {
        const accepted = router?.openLauncher?.(query || "", mode || "") ?? false;
        if (accepted) {
            usingFallback = false;
            return true;
        }
        log.warn("No DankIsland is routed to the focused screen; falling back to Spotlight");
        usingFallback = true;
        return false;
    }

    function show() {
        if (!root._openIsland("", ""))
            fallback.show();
    }

    function showWithQuery(query) {
        if (!root._openIsland(query, ""))
            fallback.showWithQuery(query);
    }

    function showWithMode(mode) {
        if (!root._openIsland("", mode))
            fallback.showWithMode(mode);
    }

    function hide() {
        if (usingFallback) {
            fallback.hide();
            return;
        }
        router?.closeLauncher?.();
    }

    function toggle() {
        if (usingFallback && fallback.spotlightOpen) {
            fallback.toggle();
            return;
        }
        const accepted = router?.toggleLauncher?.("", "") ?? false;
        if (!accepted) {
            usingFallback = true;
            fallback.toggle();
        }
    }

    function toggleWithQuery(query) {
        if (spotlightOpen) {
            hide();
            return;
        }
        showWithQuery(query);
    }

    function toggleWithMode(mode) {
        if (spotlightOpen) {
            hide();
            return;
        }
        showWithMode(mode);
    }

    onSpotlightOpenChanged: {
        if (usingFallback)
            return;
        if (spotlightOpen) {
            _islandWasOpen = true;
            return;
        }
        if (!_islandWasOpen)
            return;
        _islandWasOpen = false;
        dialogClosed();
    }

    DankLauncherV2ModalSpotlight {
        id: fallback

        modalHandle: root.modalHandle
        triggerUsesOverlayLayer: root.triggerUsesOverlayLayer
    }

    Connections {
        target: fallback

        function onDialogClosed() {
            root.usingFallback = false;
            root.dialogClosed();
        }
    }
}
