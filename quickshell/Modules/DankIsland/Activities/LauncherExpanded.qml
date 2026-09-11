pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.DankLauncherV2

FocusScope {
    id: root

    required property var controller
    required property var launcherController
    property var transientSurfaceTracker: null
    property var effectiveScreen: null
    property real screenWidth: effectiveScreen?.width ?? 1920
    property real screenHeight: effectiveScreen?.height ?? 1080
    property real alignedX: 0
    property real alignedY: 0
    property real bottomInset: 18

    clip: true

    function focusFace() {
        launcherContent.searchField.forceActiveFocus();
        return true;
    }

    function initializeSession() {
        const targetQuery = root.controller.launcherPendingQuery || (SettingsData.rememberLastQuery ? (SessionData.launcherLastQuery || "") : "");
        const targetMode = root.controller.launcherPendingMode || SessionData.getLauncherRestoreMode();

        launcherContent.closeTransientUi?.();
        launcherController.reset();
        launcherController.explicitQuerySession = !!root.controller.launcherPendingQuery;
        launcherController.searchMode = targetMode;
        launcherController.historyIndex = -1;

        launcherContent.suspendSearchUpdates = true;
        launcherContent.searchField.text = targetQuery;
        launcherContent.suspendSearchUpdates = false;
        if (targetQuery.length > 0)
            launcherController.setSearchQuery(targetQuery);
        else
            launcherController.performSearch();

        launcherContent.resetScroll();
        root.focusFace();
        if (!root.controller.launcherPendingQuery) {
            launcherContent.searchField.selectAll();
            return;
        }
        launcherContent.searchField.cursorPosition = targetQuery.length;
    }

    QtObject {
        id: hostContract

        readonly property bool spotlightOpen: root.controller.launcherSessionActive
        readonly property bool isClosing: false
        readonly property bool contentVisible: true
        readonly property var effectiveScreen: root.effectiveScreen
        readonly property real screenWidth: root.screenWidth
        readonly property real screenHeight: root.screenHeight
        readonly property real alignedX: root.alignedX
        readonly property real alignedY: root.alignedY

        function hide() {
            root.controller.requestCollapse();
        }
    }

    SpotlightLauncherContent {
        id: launcherContent

        anchors.fill: parent
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        anchors.bottomMargin: root.bottomInset
        parentModal: hostContract
        controllerOverride: root.launcherController
        transientSurfaceTracker: root.transientSurfaceTracker
        showResultsWithoutQuery: true
        maxResultsHeight: Math.max(120, root.controller.launcherExpandedTarget.height - Theme.spacingM - root.bottomInset - launcherContent.searchAreaHeight - launcherContent.actionPanelHeight)
    }

    onActiveFocusChanged: root.controller.launcherInputFocused = activeFocus

    Connections {
        target: root.controller

        function onSessionStarted(activityId) {
            if (activityId === "launcher")
                Qt.callLater(root.initializeSession);
        }
    }

    Component.onCompleted: root.controller.markVisualsReady("launcher")
    Component.onDestruction: root.controller.launcherInputFocused = false
}
