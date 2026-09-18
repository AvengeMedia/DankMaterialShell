import QtQuick
import qs.Common
import qs.Modules.Notifications
import qs.Services
import qs.Widgets

DankPopout {
    id: root

    layerNamespace: "dms:notification-center-popout"
    fullHeightSurface: true
    contentHandlesKeys: true
    onOpened: contentFocusTimer.restart()

    Timer {
        id: contentFocusTimer
        interval: 0
        onTriggered: {
            if (root.shouldBeVisible)
                root.contentLoader.item?.forceActiveFocus();
        }
    }

    property bool notificationHistoryVisible: false
    property var triggerScreen: null
    property real stablePopupHeight: NotificationMetrics.popupWidth
    property real _lastAlignedContentHeight: -1
    property bool _pendingSizedOpen: false
    property bool _heightUpdatePending: false

    function updateStablePopupHeight() {
        const item = contentLoader.item;
        if (item && !root.shouldBeVisible) {
            const notificationList = findChild(item, "notificationList");
            if (notificationList && typeof notificationList.forceLayout === "function") {
                notificationList.forceLayout();
            }
        }
        const target = item ? Theme.px(item.implicitHeight, dpr) : NotificationMetrics.popupWidth;
        if (Math.abs(target - _lastAlignedContentHeight) < 0.5)
            return;
        _lastAlignedContentHeight = target;
        stablePopupHeight = target;
    }

    function queueStablePopupHeightUpdate() {
        if (_heightUpdatePending)
            return;
        _heightUpdatePending = true;
        Qt.callLater(() => {
            _heightUpdatePending = false;
            updateStablePopupHeight();
        });
    }

    NotificationKeyboardController {
        id: keyboardController
        listView: null
        isOpen: root.shouldBeVisible
        onClose: () => {
            notificationHistoryVisible = false;
        }
    }

    popupWidth: NotificationMetrics.popupWidth + Theme.spacingL
    popupHeight: stablePopupHeight
    positioning: ""
    suspendShadowWhileResizing: false

    screen: triggerScreen

    function toggle() {
        notificationHistoryVisible = !notificationHistoryVisible;
    }

    function present() {
        openSized();
    }

    function openSized() {
        if (!notificationHistoryVisible)
            return;

        primeContent();
        if (contentLoader.item) {
            updateStablePopupHeight();
            _pendingSizedOpen = false;
            Qt.callLater(() => {
                if (!notificationHistoryVisible)
                    return;
                updateStablePopupHeight();
                open();
                clearPrimedContent();
            });
            return;
        }

        _pendingSizedOpen = true;
    }

    onBackgroundClicked: {
        notificationHistoryVisible = false;
    }

    onNotificationHistoryVisibleChanged: {
        if (notificationHistoryVisible) {
            openSized();
        } else {
            _pendingSizedOpen = false;
            clearPrimedContent();
            close();
        }
    }

    function setupKeyboardNavigation() {
        if (!contentLoader.item)
            return;
        contentLoader.item.externalKeyboardController = keyboardController;

        const notificationList = findChild(contentLoader.item, "notificationList");
        const notificationHeader = findChild(contentLoader.item, "notificationHeader");

        if (notificationList) {
            keyboardController.listView = notificationList;
            notificationList.keyboardController = keyboardController;
        }
        if (notificationHeader) {
            notificationHeader.keyboardController = keyboardController;
        }

        keyboardController.reset();
        keyboardController.rebuildFlatNavigation();
    }

    Connections {
        target: contentLoader
        function onLoaded() {
            root.updateStablePopupHeight();
            if (root._pendingSizedOpen && root.notificationHistoryVisible) {
                Qt.callLater(() => {
                    if (!root._pendingSizedOpen || !root.notificationHistoryVisible)
                        return;
                    root.updateStablePopupHeight();
                    root._pendingSizedOpen = false;
                    root.open();
                    root.clearPrimedContent();
                });
                return;
            }
            if (root.shouldBeVisible)
                Qt.callLater(root.setupKeyboardNavigation);
        }
    }

    readonly property real contentImplicitHeight: contentLoader.item?.implicitHeight ?? 0

    onContentImplicitHeightChanged: queueStablePopupHeightUpdate()

    onDprChanged: updateStablePopupHeight()

    onShouldBeVisibleChanged: {
        notificationHistoryVisible = shouldBeVisible;

        if (shouldBeVisible) {
            NotificationService.onOverlayOpen();
            updateStablePopupHeight();
            if (contentLoader.item)
                Qt.callLater(setupKeyboardNavigation);
        } else {
            NotificationService.onOverlayClose();
            keyboardController.keyboardNavigationActive = false;
            NotificationService.expandedGroups = {};
            NotificationService.expandedMessages = {};
        }
    }

    function findChild(parent, objectName) {
        if (parent.objectName === objectName) {
            return parent;
        }
        for (let i = 0; i < parent.children.length; i++) {
            const child = parent.children[i];
            const result = findChild(child, objectName);
            if (result) {
                return result;
            }
        }
        return null;
    }

    content: Component {
        Item {
            id: notificationContent

            property alias externalKeyboardController: body.externalKeyboardController

            implicitHeight: body.implicitHeight
            focus: true

            Component.onCompleted: {
                if (root.shouldBeVisible)
                    forceActiveFocus();
            }

            Keys.onPressed: event => body.handleKey(event)

            readonly property bool rootShouldBeVisible: root.shouldBeVisible

            onRootShouldBeVisibleChanged: {
                if (rootShouldBeVisible) {
                    Qt.callLater(() => notificationContent.forceActiveFocus());
                    return;
                }
                focus = false;
            }

            QtObject {
                id: popoutHost

                readonly property bool shouldBeVisible: root.shouldBeVisible
                readonly property var screen: root.screen
                readonly property var transientSurfaceTracker: root.transientSurfaceTracker
                readonly property real maxContentHeight: (root.screen?.height ?? 1080) * NotificationMetrics.screenHeightRatio

                function close() {
                    root.notificationHistoryVisible = false;
                }

                function requestSettings() {
                    root.notificationHistoryVisible = false;
                    PopoutService.openSettingsWithTab("notifications", root, () => root.open());
                }
            }

            NotificationCenterContent {
                id: body

                anchors.fill: parent
                host: popoutHost
            }
        }
    }
}
