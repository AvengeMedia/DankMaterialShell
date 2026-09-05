pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Notifications.Center
import qs.Services

FocusScope {
    id: root

    required property var controller
    property var effectiveScreen: null
    property var transientSurfaceTracker: null
    property real bottomInset: Theme.spacingM
    property bool _sessionOpen: false
    property bool _heightReportPending: false

    clip: true

    function focusFace() {
        root.forceActiveFocus();
        keyboardController.rebuildFlatNavigation();
        return true;
    }

    function beginSession() {
        if (!hostContract.shouldBeVisible)
            return;
        root._sessionOpen = true;
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
            root.controller.setDestinationContentHeight("notificationcenter", content.targetImplicitHeight + root.bottomInset);
        });
    }

    function prepareVisuals() {
        content.notificationList.syncSessionContentHeight();
        root.controller.setDestinationContentHeight("notificationcenter", content.targetImplicitHeight + root.bottomInset);
        root.controller.markVisualsReady("notificationcenter");
    }

    QtObject {
        id: hostContract

        readonly property bool shouldBeVisible: root.controller.activeActivity === "notificationcenter" && root.controller.expanded
        readonly property var screen: root.effectiveScreen
        readonly property var transientSurfaceTracker: root.transientSurfaceTracker
        readonly property real maxContentHeight: root.controller.notificationCenterMaxHeight - root.bottomInset
        readonly property bool hostOwnsHeight: true
        readonly property bool headerTogglesClose: true
        readonly property bool animateCardExpansion: false
        readonly property bool lightweightNotifications: true

        function close() {
            root.controller.requestCollapse();
        }

        function requestSettings() {
            root.controller.requestCollapse();
            PopoutService.openSettingsWithTab("notifications", root, () => root.controller.requestNotificationCenter(false));
        }
    }

    NotificationKeyboardController {
        id: keyboardController

        listView: null
        isOpen: hostContract.shouldBeVisible
        onClose: () => root.controller.requestCollapse()
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
        width: root.controller.notificationCenterExpandedTarget.width
        host: hostContract
        externalKeyboardController: keyboardController
        onTargetImplicitHeightChanged: root.queueHeightReport()
    }

    Connections {
        target: root.controller

        function onSessionStarted(activityId) {
            if (activityId === "notificationcenter")
                Qt.callLater(root.beginSession);
        }

        function onExpandedChanged() {
            if (!root.controller.expanded)
                root.endSession();
        }

        function onActiveActivityChanged() {
            if (root.controller.activeActivity !== "notificationcenter")
                root.endSession();
        }
    }

    Component.onCompleted: Qt.callLater(root.prepareVisuals)
    Component.onDestruction: root.endSession()
}
