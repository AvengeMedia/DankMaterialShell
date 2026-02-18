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
    property real stableContentHeight: 0
    property bool cardAnimateExpansion: true
    property bool listInitialized: false
    property int swipingCardIndex: -1
    property real swipingCardOffset: 0
    property real __pendingStableHeight: 0
    property real __heightUpdateThreshold: 20

    Component.onCompleted: {
        Qt.callLater(() => {
            if (listView) {
                listView.listInitialized = true;
                listView.stableContentHeight = listView.contentHeight;
            }
        });
    }

    Timer {
        id: heightUpdateDebounce
        interval: Theme.mediumDuration + 20
        repeat: false
        onTriggered: {
            if (!listView.isAnimatingExpansion && Math.abs(listView.__pendingStableHeight - listView.stableContentHeight) > listView.__heightUpdateThreshold) {
                listView.stableContentHeight = listView.__pendingStableHeight;
            }
        }
    }

    onContentHeightChanged: {
        if (!isAnimatingExpansion) {
            __pendingStableHeight = contentHeight;
            if (Math.abs(contentHeight - stableContentHeight) > __heightUpdateThreshold) {
                heightUpdateDebounce.restart();
            } else {
                stableContentHeight = contentHeight;
            }
        }
    }

    onIsAnimatingExpansionChanged: {
        if (isAnimatingExpansion) {
            heightUpdateDebounce.stop();
            let delta = 0;
            for (let i = 0; i < count; i++) {
                const item = itemAtIndex(i);
                if (item && item.children[0] && item.children[0].isAnimating)
                    delta += item.children[0].targetHeight - item.height;
            }
            const targetHeight = contentHeight + delta;
            // During expansion, always update immediately without threshold check
            stableContentHeight = targetHeight;
        } else {
            __pendingStableHeight = contentHeight;
            heightUpdateDebounce.restart();
        }
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

        readonly property bool isAdjacentToSwipe: listView.count >= 2 && listView.swipingCardIndex !== -1 &&
            (index === listView.swipingCardIndex - 1 || index === listView.swipingCardIndex + 1)
        readonly property real adjacentSwipeInfluence: isAdjacentToSwipe ? listView.swipingCardOffset * 0.10 : 0
        readonly property real adjacentScaleInfluence: isAdjacentToSwipe ? 1.0 - Math.abs(listView.swipingCardOffset) / width * 0.02 : 1.0
        readonly property real swipeFadeStartOffset: width * 0.75
        readonly property real swipeFadeDistance: Math.max(1, width - swipeFadeStartOffset)

        Component.onCompleted: {
            Qt.callLater(() => {
                if (delegateRoot)
                    delegateRoot.__delegateInitialized = true;
            });
        }

        width: ListView.view.width
        height: notificationCard.height
        clip: notificationCard.isAnimating

        NotificationCard {
            id: notificationCard
            width: parent.width
            x: delegateRoot.swipeOffset + delegateRoot.adjacentSwipeInfluence
            listLevelAdjacentScaleInfluence: delegateRoot.adjacentScaleInfluence
            listLevelScaleAnimationsEnabled: listView.swipingCardIndex === -1 || !delegateRoot.isAdjacentToSwipe
            notificationGroup: modelData
            keyboardNavigationActive: listView.keyboardActive
            animateExpansion: listView.cardAnimateExpansion && listView.listInitialized
            opacity: {
                const swipeAmount = Math.abs(delegateRoot.swipeOffset);
                if (swipeAmount <= delegateRoot.swipeFadeStartOffset)
                    return 1;
                const fadeProgress = (swipeAmount - delegateRoot.swipeFadeStartOffset) / delegateRoot.swipeFadeDistance;
                return Math.max(0, 1 - fadeProgress);
            }
            onIsAnimatingChanged: {
                if (isAnimating) {
                    listView.isAnimatingExpansion = true;
                } else {
                    Qt.callLater(() => {
                        if (!notificationCard || !listView)
                            return;
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
                enabled: !swipeDragHandler.active && !delegateRoot.isDismissing && (listView.swipingCardIndex === -1 || !delegateRoot.isAdjacentToSwipe) && listView.listInitialized
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
                if (active) {
                    listView.swipingCardIndex = index;
                    return;
                }
                listView.swipingCardIndex = -1;
                listView.swipingCardOffset = 0;
                if (delegateRoot.isDismissing)
                    return;
                if (Math.abs(delegateRoot.swipeOffset) > delegateRoot.dismissThreshold) {
                    delegateRoot.isDismissing = true;
                    swipeDismissAnim.to = delegateRoot.swipeOffset > 0 ? delegateRoot.width : -delegateRoot.width;
                    swipeDismissAnim.start();
                } else {
                    delegateRoot.swipeOffset = 0;
                }
            }

            onTranslationChanged: {
                if (delegateRoot.isDismissing)
                    return;
                delegateRoot.swipeOffset = translation.x;
                listView.swipingCardOffset = translation.x;
            }
        }

        NumberAnimation {
            id: swipeDismissAnim
            target: delegateRoot
            property: "swipeOffset"
            to: 0
            duration: Theme.notificationExitDuration
            easing.type: Easing.OutCubic
            onStopped: NotificationService.dismissGroup(delegateRoot.modelData?.key || "")
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
