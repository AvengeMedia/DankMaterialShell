pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Notifications.Center
import qs.Services

// Shared notification center body hosted in the island silhouette.
FocusScope {
    id: root

    required property var islandController
    property var effectiveScreen: null
    property var transientSurfaceTracker: null
    property real bottomInset: Theme.spacingM
    property bool _sessionOpen: false
    property bool _heightReportPending: false

    clip: true

    function focusList() {
        root.forceActiveFocus();
        keyboardController.rebuildFlatNavigation();
        return true;
    }

    function beginSession() {
        if (!hostContract.shouldBeVisible)
            return;
        root._sessionOpen = true;
        // Suppresses transient island cards for as long as the list owns them.
        NotificationService.onOverlayOpen();
        keyboardController.reset();
        keyboardController.listView = content.notificationList;
        content.notificationList.keyboardController = keyboardController;
        content.notificationHeader.keyboardController = keyboardController;
        keyboardController.rebuildFlatNavigation();
        root.forceActiveFocus();
        root.queueHeightReport();
    }

    function endSession() {
        if (!root._sessionOpen)
            return;
        root._sessionOpen = false;
        keyboardController.keyboardNavigationActive = false;
        NotificationService.expandedGroups = {};
        NotificationService.expandedMessages = {};
        NotificationService.onOverlayClose();
    }

    function queueHeightReport() {
        if (root._heightReportPending)
            return;
        root._heightReportPending = true;
        Qt.callLater(() => {
            root._heightReportPending = false;
            content.notificationList.syncSessionContentHeight();
            root.islandController.setNotificationCenterContentHeight(content.targetImplicitHeight + root.bottomInset);
        });
    }

    function prepareVisuals() {
        content.notificationList.syncSessionContentHeight();
        root.islandController.setNotificationCenterContentHeight(content.targetImplicitHeight + root.bottomInset);
        root.islandController.markNotificationCenterVisualsReady();
    }

    QtObject {
        id: hostContract

        readonly property bool shouldBeVisible: root.islandController.activeActivity === "notificationcenter" && root.islandController.expanded
        readonly property var screen: root.effectiveScreen
        readonly property var transientSurfaceTracker: root.transientSurfaceTracker
        readonly property real maxContentHeight: root.islandController.notificationCenterMaxHeight - root.bottomInset
        readonly property bool hostOwnsHeight: true
        readonly property bool headerTogglesClose: true
        readonly property bool animateCardExpansion: false
        readonly property bool lightweightNotifications: true

        function close() {
            root.islandController.requestCollapse();
        }

        function requestSettings() {
            root.islandController.requestCollapse();
            PopoutService.openSettingsWithTab("notifications", root, () => root.islandController.requestNotificationCenter(false));
        }
    }

    NotificationKeyboardController {
        id: keyboardController

        listView: null
        isOpen: hostContract.shouldBeVisible
        onClose: () => root.islandController.requestCollapse()
    }

    Keys.onPressed: event => content.handleKey(event)

    NotificationCenterContent {
        id: content

        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: root.bottomInset
        }
        width: root.islandController.notificationCenterExpandedTarget.width
        host: hostContract
        externalKeyboardController: keyboardController
        onTargetImplicitHeightChanged: root.queueHeightReport()
    }

    Connections {
        target: root.islandController

        function onNotificationCenterSessionSerialChanged() {
            Qt.callLater(root.beginSession);
        }

        function onExpandedChanged() {
            if (!root.islandController.expanded)
                root.endSession();
        }

        function onActiveActivityChanged() {
            if (root.islandController.activeActivity !== "notificationcenter")
                root.endSession();
        }
    }

    Component.onCompleted: Qt.callLater(root.prepareVisuals)
    Component.onDestruction: root.endSession()
}
