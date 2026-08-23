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
    property bool trackStableContentHeight: true
    property bool trackSessionContentHeight: false
    property bool lightweightCards: false
    property bool listInitialized: false
    property int swipingCardIndex: -1
    property real swipingCardOffset: 0
    property bool _stableHeightUpdatePending: false
    property bool _sessionHeightUpdatePending: false
    property real sessionContentHeight: 0
    property var transientSurfaceTracker: null
    readonly property real shadowBlurPx: Theme.elevationEnabled ? ((Theme.elevationLevel1 && Theme.elevationLevel1.blurPx !== undefined) ? Theme.elevationLevel1.blurPx : 4) : 0
    readonly property real shadowHorizontalGutter: Theme.snap(Math.max(Theme.spacingS, Math.min(32, shadowBlurPx * 1.5 + 6)), 1)
    readonly property real shadowVerticalGutter: Theme.snap(Math.max(Theme.spacingXS, 6), 1)
    readonly property real delegateShadowGutter: Theme.snap(Math.max(Theme.spacingXS, 4), 1)
    readonly property real estimatedCollapsedCardHeight: {
        const compact = SettingsData.notificationCompactMode;
        const padding = compact ? Theme.notificationCardPaddingCompact : Theme.notificationCardPadding;
        const icon = compact ? Theme.notificationIconSizeCompact : Theme.notificationIconSizeNormal;
        const body = Theme.fontSizeSmall * 1.2 + Theme.fontSizeMedium * 1.2 + Theme.fontSizeSmall * 1.2 * (compact ? 1 : 2);
        const actionHeight = compact ? 20 : 24;
        const contentSpacing = compact ? Theme.spacingXS : Theme.spacingS;
        return padding * 2 + Math.max(icon, body) + actionHeight + contentSpacing + delegateShadowGutter;
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            if (listView) {
                listView.listInitialized = true;
                if (listView.trackStableContentHeight)
                    listView.syncStableContentHeight(false);
                listView.syncSessionContentHeight();
            }
        });
    }

    function estimateContentHeight(groupCount) {
        if (groupCount <= 0)
            return 0;
        return topMargin + bottomMargin + groupCount * estimatedCollapsedCardHeight + Math.max(0, groupCount - 1) * spacing;
    }

    function estimateExpandedCardHeight(group) {
        const compact = SettingsData.notificationCompactMode;
        const padding = compact ? Theme.notificationCardPaddingCompact : Theme.notificationCardPadding;
        const header = compact ? 32 : 40;
        const count = Math.min(10, Math.max(1, group?.count || group?.notifications?.length || 1));
        const icon = compact ? Theme.notificationExpandedIconSizeCompact : Theme.notificationExpandedIconSizeNormal;
        const itemPadding = compact ? Theme.spacingS : Theme.spacingM;
        const contentSpacing = compact ? Theme.spacingXS : Theme.spacingS;
        const actionHeight = compact ? 20 : 24;
        const textBlock = Theme.fontSizeSmall * 1.2 + Theme.fontSizeMedium * 1.2 + Theme.fontSizeSmall * 1.2 * 2;
        const row = itemPadding * 2 + Math.max(icon, textBlock) + actionHeight + contentSpacing * 2;
        const innerSpacing = compact ? Theme.spacingS : Theme.spacingL;
        const headerSpacing = compact ? Theme.spacingXS : Theme.spacingS;
        return padding * 2 + header + headerSpacing + count * row + Math.max(0, count - 1) * innerSpacing + delegateShadowGutter;
    }

    function estimatedHeightForGroup(group) {
        if (!group)
            return estimatedCollapsedCardHeight;
        if (NotificationService.expandedGroups[group.key])
            return estimateExpandedCardHeight(group);
        return estimatedCollapsedCardHeight;
    }

    function computeSessionContentHeight() {
        const groups = NotificationService.groupedNotifications;
        const count = groups ? groups.length : 0;
        if (count <= 0)
            return 0;

        let total = topMargin + bottomMargin + Math.max(0, count - 1) * spacing;
        for (let i = 0; i < count; i++) {
            const item = itemAtIndex(i);
            if (item && item.nonAnimHeight !== undefined && item.nonAnimHeight > 0)
                total += item.nonAnimHeight;
            else
                total += estimatedHeightForGroup(groups[i]);
        }
        return Math.max(0, total);
    }

    function syncSessionContentHeight() {
        if (!trackSessionContentHeight)
            return;
        const next = computeSessionContentHeight();
        if (Math.abs(next - sessionContentHeight) <= 0.5)
            return;
        sessionContentHeight = next;
    }

    function queueSessionContentHeightUpdate() {
        if (!trackSessionContentHeight || _sessionHeightUpdatePending)
            return;
        _sessionHeightUpdatePending = true;
        Qt.callLater(() => {
            _sessionHeightUpdatePending = false;
            syncSessionContentHeight();
        });
    }

    function targetContentHeight() {
        if (count <= 0)
            return contentHeight;

        let total = topMargin + bottomMargin + Math.max(0, count - 1) * spacing;
        for (let i = 0; i < count; i++) {
            const item = itemAtIndex(i);
            if (!item || item.nonAnimHeight === undefined)
                return contentHeight;
            total += item.nonAnimHeight;
        }
        return Math.max(0, total);
    }

    function syncStableContentHeight(useTarget) {
        if (!trackStableContentHeight)
            return;
        const nextHeight = useTarget ? targetContentHeight() : contentHeight;
        if (Math.abs(nextHeight - stableContentHeight) <= 0.5)
            return;
        stableContentHeight = nextHeight;
    }

    function queueStableContentHeightUpdate(useTarget) {
        if (!trackStableContentHeight || _stableHeightUpdatePending)
            return;
        _stableHeightUpdatePending = true;
        Qt.callLater(() => {
            _stableHeightUpdatePending = false;
            syncStableContentHeight(useTarget || isAnimatingExpansion);
        });
    }

    onContentHeightChanged: {
        if (trackStableContentHeight && !isAnimatingExpansion)
            queueStableContentHeightUpdate(false);
    }

    onIsAnimatingExpansionChanged: {
        if (!trackStableContentHeight)
            return;
        if (isAnimatingExpansion) {
            syncStableContentHeight(true);
        } else {
            queueStableContentHeightUpdate(false);
        }
    }

    clip: true
    model: NotificationService.groupedNotifications
    spacing: Theme.spacingL
    topMargin: shadowVerticalGutter
    bottomMargin: shadowVerticalGutter

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

    onCountChanged: listView.queueSessionContentHeightUpdate()

    onModelChanged: {
        listView.queueSessionContentHeightUpdate();
        if (!keyboardController || !keyboardController.keyboardNavigationActive)
            return;
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

        readonly property bool isAdjacentToSwipe: listView.count >= 2 && listView.swipingCardIndex !== -1 && (index === listView.swipingCardIndex - 1 || index === listView.swipingCardIndex + 1)
        readonly property real adjacentSwipeInfluence: isAdjacentToSwipe ? listView.swipingCardOffset * 0.10 : 0
        readonly property real adjacentScaleInfluence: isAdjacentToSwipe ? 1.0 - Math.abs(listView.swipingCardOffset) / width * 0.02 : 1.0
        readonly property real swipeFadeStartOffset: width * 0.75
        readonly property real swipeFadeDistance: Math.max(1, width - swipeFadeStartOffset)
        readonly property real nonAnimHeight: notificationCard.targetHeight + listView.delegateShadowGutter

        Component.onCompleted: {
            Qt.callLater(() => {
                if (delegateRoot) {
                    delegateRoot.__delegateInitialized = true;
                    if (listView.trackStableContentHeight)
                        listView.queueStableContentHeightUpdate(listView.isAnimatingExpansion);
                    listView.queueSessionContentHeightUpdate();
                }
            });
        }

        width: ListView.view.width
        height: notificationCard.height + listView.delegateShadowGutter
        clip: false

        NotificationCard {
            id: notificationCard
            width: Math.max(0, parent.width - (listView.shadowHorizontalGutter * 2))
            y: listView.delegateShadowGutter / 2
            x: listView.shadowHorizontalGutter + delegateRoot.swipeOffset + delegateRoot.adjacentSwipeInfluence
            listLevelAdjacentScaleInfluence: delegateRoot.adjacentScaleInfluence
            listLevelScaleAnimationsEnabled: listView.swipingCardIndex === -1 || !delegateRoot.isAdjacentToSwipe
            notificationGroup: modelData
            keyboardNavigationActive: listView.keyboardActive
            animateExpansion: listView.cardAnimateExpansion && listView.listInitialized
            lightweight: listView.lightweightCards
            transientSurfaceTracker: listView.transientSurfaceTracker
            opacity: {
                const swipeAmount = Math.abs(delegateRoot.swipeOffset);
                if (swipeAmount <= delegateRoot.swipeFadeStartOffset)
                    return 1;
                const fadeProgress = (swipeAmount - delegateRoot.swipeFadeStartOffset) / delegateRoot.swipeFadeDistance;
                return Math.max(0, 1 - fadeProgress);
            }
            onIsAnimatingChanged: {
                if (!listView.trackStableContentHeight)
                    return;
                if (isAnimating) {
                    listView.isAnimatingExpansion = true;
                    listView.syncStableContentHeight(true);
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

            onTargetHeightChanged: {
                listView.queueSessionContentHeightUpdate();
                if (!listView.trackStableContentHeight)
                    return;
                if (isAnimating || listView.isAnimatingExpansion)
                    listView.syncStableContentHeight(true);
                else
                    listView.queueStableContentHeightUpdate(false);
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
            listView.queueSessionContentHeightUpdate();
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
            listView.queueSessionContentHeightUpdate();
            if (!keyboardController || !keyboardController.keyboardNavigationActive)
                return;
            expansionEnsureVisibleTimer.restart();
        }

        function onExpandedMessagesChanged() {
            listView.queueSessionContentHeightUpdate();
            if (!keyboardController || !keyboardController.keyboardNavigationActive)
                return;
            expansionEnsureVisibleTimer.restart();
        }
    }
}
