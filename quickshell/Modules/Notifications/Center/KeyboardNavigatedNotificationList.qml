import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankListView {
    id: listView

    property var keyboardController: null
    property bool keyboardActive: false
    property bool autoScrollDisabled: false
    property bool isAnimatingExpansion: false
    property alias listContentHeight: listView.contentHeight
    property bool cardAnimateExpansion: true
    property bool listInitialized: false

    Component.onCompleted: {
        Qt.callLater(() => {
            listInitialized = true;
        });
    }

    clip: true
    model: NotificationService.groupedNotifications
    spacing: Theme.spacingL

    onIsUserScrollingChanged: {
        if (isUserScrolling && keyboardController && keyboardController.keyboardNavigationActive) {
            autoScrollDisabled = true;
        }
    }

    function enableAutoScroll() {
        autoScrollDisabled = false;
    }

    Timer {
        id: positionPreservationTimer
        interval: 200
        running: keyboardController && keyboardController.keyboardNavigationActive && !autoScrollDisabled && !isAnimatingExpansion
        repeat: true
        onTriggered: {
            if (keyboardController && keyboardController.keyboardNavigationActive && !autoScrollDisabled && !isAnimatingExpansion) {
                keyboardController.ensureVisible();
            }
        }
    }

    Timer {
        id: expansionEnsureVisibleTimer
        interval: Theme.mediumDuration + 50
        repeat: false
        onTriggered: {
            if (keyboardController && keyboardController.keyboardNavigationActive && !autoScrollDisabled) {
                keyboardController.ensureVisible();
            }
        }
    }

    NotificationEmptyState {
        visible: listView.count === 0
        y: 20
        anchors.horizontalCenter: parent.horizontalCenter
    }

    onModelChanged: {
        if (!keyboardController || !keyboardController.keyboardNavigationActive) {
            return;
        }
        keyboardController.rebuildFlatNavigation();
        Qt.callLater(() => {
            if (keyboardController && keyboardController.keyboardNavigationActive && !autoScrollDisabled) {
                keyboardController.ensureVisible();
            }
        });
    }

    delegate: Item {
        id: delegateRoot
        required property var modelData
        required property int index

        readonly property bool isExpanded: (NotificationService.expandedGroups[modelData && modelData.key] || false)
        property real swipeOffset: 0
        property bool isDismissing: false
        readonly property real dismissThreshold: width * 0.35
        property bool __delegateInitialized: false

        Component.onCompleted: {
            Qt.callLater(() => {
                __delegateInitialized = true;
            });
        }

        width: ListView.view.width
        height: isDismissing ? 0 : notificationCard.targetHeight
        clip: isDismissing || notificationCard.isAnimating

        NotificationCard {
            id: notificationCard
            width: parent.width
            x: delegateRoot.swipeOffset
            notificationGroup: modelData
            keyboardNavigationActive: listView.keyboardActive
            animateExpansion: listView.cardAnimateExpansion && listView.listInitialized
            opacity: 1 - Math.abs(delegateRoot.swipeOffset) / (delegateRoot.width * 0.5)
            onIsAnimatingChanged: {
                if (isAnimating) {
                    listView.isAnimatingExpansion = true;
                } else {
                    Qt.callLater(() => {
                        let anyAnimating = false;
                        for (let i = 0; i < listView.count; i++) {
                            const item = listView.itemAtIndex(i);
                            if (item && item.children[0] && item.children[0].isAnimating) {
                                anyAnimating = true;
                                break;
                            }
                        }
                        listView.isAnimatingExpansion = anyAnimating;
                    });
                }
            }

            isGroupSelected: {
                if (!keyboardController || !keyboardController.keyboardNavigationActive || !listView.keyboardActive)
                    return false;
                keyboardController.selectionVersion;
                const selection = keyboardController.getCurrentSelection();
                return selection.type === "group" && selection.groupIndex === index;
            }

            selectedNotificationIndex: {
                if (!keyboardController || !keyboardController.keyboardNavigationActive || !listView.keyboardActive)
                    return -1;
                keyboardController.selectionVersion;
                const selection = keyboardController.getCurrentSelection();
                return (selection.type === "notification" && selection.groupIndex === index) ? selection.notificationIndex : -1;
            }

            Behavior on x {
                enabled: !swipeDragHandler.active && listView.listInitialized
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on opacity {
                enabled: listView.listInitialized
                NumberAnimation {
                    duration: listView.listInitialized ? Theme.shortDuration : 0
                }
            }
        }

        DragHandler {
            id: swipeDragHandler
            target: null
            yAxis.enabled: false
            xAxis.enabled: true

            onActiveChanged: {
                if (active || delegateRoot.isDismissing)
                    return;
                if (Math.abs(delegateRoot.swipeOffset) > delegateRoot.dismissThreshold) {
                    delegateRoot.isDismissing = true;
                    delegateRoot.swipeOffset = delegateRoot.swipeOffset > 0 ? delegateRoot.width : -delegateRoot.width;
                    dismissTimer.start();
                } else {
                    delegateRoot.swipeOffset = 0;
                }
            }

            onTranslationChanged: {
                if (delegateRoot.isDismissing)
                    return;
                delegateRoot.swipeOffset = translation.x;
            }
        }

        Timer {
            id: dismissTimer
            interval: Theme.shortDuration
            onTriggered: NotificationService.dismissGroup(delegateRoot.modelData?.key || "")
        }
    }

    Connections {
        target: NotificationService

        function onGroupedNotificationsChanged() {
            if (!keyboardController) {
                return;
            }

            if (keyboardController.isTogglingGroup) {
                keyboardController.rebuildFlatNavigation();
                return;
            }

            keyboardController.rebuildFlatNavigation();

            if (keyboardController.keyboardNavigationActive) {
                Qt.callLater(() => {
                    if (!autoScrollDisabled) {
                        keyboardController.ensureVisible();
                    }
                });
            }
        }

        function onExpandedGroupsChanged() {
            if (!keyboardController || !keyboardController.keyboardNavigationActive)
                return;
            expansionEnsureVisibleTimer.restart();
        }

        function onExpandedMessagesChanged() {
            if (!keyboardController || !keyboardController.keyboardNavigationActive)
                return;
            expansionEnsureVisibleTimer.restart();
        }
    }
}
