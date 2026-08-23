pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.DankLauncherV2

FocusScope {
    id: root

    required property var islandController
    required property var launcherController
    property var transientSurfaceTracker: null
    property var effectiveScreen: null
    property real screenWidth: effectiveScreen?.width ?? 1920
    property real screenHeight: effectiveScreen?.height ?? 1080
    property real alignedX: 0
    property real alignedY: 0
    property real bottomInset: 18

    clip: true

    function focusSearch() {
        launcherContent.searchField.forceActiveFocus();
    }

    function initializeSession() {
        const targetQuery = islandController.launcherPendingQuery || (SettingsData.rememberLastQuery ? (SessionData.launcherLastQuery || "") : "");
        const targetMode = islandController.launcherPendingMode || SessionData.getLauncherRestoreMode();

        launcherContent.closeTransientUi?.();
        launcherController.reset();
        launcherController.explicitQuerySession = !!islandController.launcherPendingQuery;
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
        root.focusSearch();
        if (islandController.launcherPendingQuery)
            launcherContent.searchField.cursorPosition = targetQuery.length;
        else
            launcherContent.searchField.selectAll();
    }

    QtObject {
        id: hostContract

        readonly property bool spotlightOpen: root.islandController.launcherSessionActive
        readonly property bool isClosing: false
        readonly property bool contentVisible: true
        readonly property var effectiveScreen: root.effectiveScreen
        readonly property real screenWidth: root.screenWidth
        readonly property real screenHeight: root.screenHeight
        readonly property real alignedX: root.alignedX
        readonly property real alignedY: root.alignedY

        function hide() {
            root.islandController.requestCollapse();
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
        maxResultsHeight: Math.max(120, islandController.launcherExpandedTarget.height - Theme.spacingM - root.bottomInset - launcherContent.searchAreaHeight)
    }

    onActiveFocusChanged: root.islandController.launcherInputFocused = activeFocus

    Connections {
        target: root.islandController

        function onSessionStarted(activityId) {
            if (activityId === "launcher")
                Qt.callLater(root.initializeSession);
        }
    }

    Component.onCompleted: root.islandController.markVisualsReady("launcher")
    Component.onDestruction: root.islandController.launcherInputFocused = false
}
