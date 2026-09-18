import QtQuick
import "." as Center
import Quickshell
import qs.Modules.Notifications
import qs.DankCommon.Common as DC
import qs.Common
import qs.Services
import qs.Widgets

DankListView {
    id: listView

    property var keyboardController: null
    property bool keyboardActive: false
    property bool focusAllowed: true
    property bool autoScrollDisabled: false
    property bool isAnimatingExpansion: false
    property alias listContentHeight: listView.contentHeight
    property real stableContentHeight: 0
    property bool cardAnimateExpansion: true
    property bool trackStableContentHeight: true
    property bool trackSessionContentHeight: false
    property bool listInitialized: false
    property int swipingCardIndex: -1
    property real swipingCardOffset: 0
    property real sessionContentHeight: 0
    property var transientSurfaceTracker: null
    property bool nested: false
    readonly property real estimatedCollapsedCardHeight: NotificationMetrics.estimatedCardHeight

    Timer {
        interval: 0
        running: true
        onTriggered: {
            listView.listInitialized = true;
            listView.syncStableContentHeight(false);
            listView.syncSessionContentHeight();
        }
    }

    Timer {
        id: sessionHeightTimer
        interval: 0
        onTriggered: listView.syncSessionContentHeight()
    }

    Timer {
        id: stableHeightTimer
        property bool useTarget: false
        interval: 0
        onTriggered: listView.syncStableContentHeight(useTarget || listView.isAnimatingExpansion)
    }

    Timer {
        id: ensureVisibleTimer
        interval: 0
        onTriggered: {
            if (listView.keyboardController?.keyboardNavigationActive && !listView.autoScrollDisabled)
                listView.keyboardController.ensureVisible();
        }
    }

    Timer {
        id: expansionStateTimer
        interval: 0
        onTriggered: {
            for (let i = 0; i < listView.count; i++) {
                if (!listView.itemAtIndex(i)?.isCardAnimating)
                    continue;
                listView.isAnimatingExpansion = true;
                return;
            }
            listView.isAnimatingExpansion = false;
        }
    }

    function estimateContentHeight(groupCount) {
        if (groupCount <= 0)
            return 0;
        return topMargin + bottomMargin + groupCount * estimatedCollapsedCardHeight + Math.max(0, groupCount - 1) * spacing;
    }

    function estimateExpandedCardHeight(group) {
        const count = Math.min(NotificationMetrics.expandedLimit, Math.max(1, group?.count || 1));
        return Theme.iconButtonSize + count * (estimatedCollapsedCardHeight + Theme.groupedListGap);
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
        if (!trackSessionContentHeight || sessionHeightTimer.running)
            return;
        sessionHeightTimer.start();
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
        if (!trackStableContentHeight || stableHeightTimer.running)
            return;
        stableHeightTimer.useTarget = useTarget;
        stableHeightTimer.start();
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
    model: ScriptModel {
        values: NotificationService.groupedNotifications.map(group => group.key)
    }
    add: NotificationMetrics.animationsEnabled ? DC.ListViewTransitions.add : null
    remove: NotificationMetrics.animationsEnabled ? DC.ListViewTransitions.fadeRemove : null
    displaced: NotificationMetrics.animationsEnabled ? DC.ListViewTransitions.displaced : null
    move: NotificationMetrics.animationsEnabled ? DC.ListViewTransitions.move : null
    spacing: Theme.groupedListGap

    onIsUserScrollingChanged: {
        if (isUserScrolling && keyboardController && keyboardController.keyboardNavigationActive) {
            autoScrollDisabled = true;
        }
    }

    function enableAutoScroll() {
        autoScrollDisabled = false;
    }

    Timer {
        id: expansionEnsureVisibleTimer
        interval: Math.max(Theme.notificationExpandDuration, Theme.notificationInlineExpandDuration)
        repeat: false
        onTriggered: {
            if (keyboardController && keyboardController.keyboardNavigationActive && !autoScrollDisabled) {
                keyboardController.ensureVisible();
            }
        }
    }

    NotificationEmptyState {
        parent: listView
        visible: listView.count === 0
    }

    onCountChanged: listView.queueSessionContentHeightUpdate()

    onModelChanged: {
        listView.queueSessionContentHeightUpdate();
        if (!keyboardController || !keyboardController.keyboardNavigationActive)
            return;
        keyboardController.rebuildFlatNavigation();
        ensureVisibleTimer.restart();
    }

    delegate: Item {
        id: delegateRoot
        required property string modelData
        required property int index

        readonly property var notificationGroup: NotificationService.groupedNotifications.find(group => group.key === modelData)
        readonly property bool isExpanded: NotificationService.expandedGroups[modelData] || false
        property real swipeOffset: 0
        property bool isDismissing: false
        readonly property real dismissThreshold: width * NotificationMetrics.swipeThreshold

        readonly property bool isAdjacentToSwipe: listView.count >= 2 && listView.swipingCardIndex !== -1 && (index === listView.swipingCardIndex - 1 || index === listView.swipingCardIndex + 1)
        readonly property real adjacentSwipeInfluence: isAdjacentToSwipe ? listView.swipingCardOffset * NotificationMetrics.adjacentSwipeInfluence : 0
        readonly property real swipeFadeStartOffset: width * NotificationMetrics.swipeFadeStart
        readonly property real swipeFadeDistance: Math.max(1, width - swipeFadeStartOffset)
        readonly property real nonAnimHeight: notificationCard.targetHeight

        readonly property bool isCardAnimating: notificationCard.isAnimating

        Timer {
            interval: 0
            running: true
            onTriggered: {
                listView.queueStableContentHeightUpdate(listView.isAnimatingExpansion);
                listView.queueSessionContentHeightUpdate();
            }
        }

        width: ListView.view.width
        height: notificationCard.height
        clip: true

        Center.NotificationCard {
            id: notificationCard
            width: parent.width
            x: delegateRoot.swipeOffset + delegateRoot.adjacentSwipeInfluence
            notificationGroup: delegateRoot.notificationGroup
            nested: listView.nested
            firstInList: index === 0
            lastInList: index === listView.count - 1
            keyboardNavigationActive: listView.keyboardActive && listView.focusAllowed
            animateExpansion: listView.cardAnimateExpansion && listView.listInitialized
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
                if (!isAnimating) {
                    expansionStateTimer.restart();
                    return;
                }
                listView.isAnimatingExpansion = true;
                listView.syncStableContentHeight(true);
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
                if (!keyboardController || !keyboardController.keyboardNavigationActive || !listView.keyboardActive || !listView.focusAllowed)
                    return false;
                keyboardController.selectionVersion;
                const selection = keyboardController.getCurrentSelection();
                return selection.type === "group" && selection.groupIndex === index;
            }

            selectedNotificationIndex: {
                if (!keyboardController || !keyboardController.keyboardNavigationActive || !listView.keyboardActive || !listView.focusAllowed)
                    return -1;
                keyboardController.selectionVersion;
                const selection = keyboardController.getCurrentSelection();
                return (selection.type === "notification" && selection.groupIndex === index) ? selection.notificationIndex : -1;
            }

            Behavior on x {
                enabled: NotificationMetrics.animationsEnabled && !swipeDragHandler.active && !delegateRoot.isDismissing && (listView.swipingCardIndex === -1 || !delegateRoot.isAdjacentToSwipe) && listView.listInitialized
                NumberAnimation {
                    duration: Theme.notificationExitDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: NotificationMetrics.heightCurve
                }
            }

            Behavior on opacity {
                enabled: NotificationMetrics.animationsEnabled && listView.listInitialized
                NumberAnimation {
                    duration: listView.listInitialized ? Theme.notificationExitDuration : 0
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
            duration: NotificationMetrics.animationsEnabled ? Theme.notificationExitDuration : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: NotificationMetrics.dismissCurve
            onFinished: NotificationService.dismissGroup(delegateRoot.modelData)
        }
    }

    readonly property var serviceGroupedNotifications: NotificationService.groupedNotifications
    readonly property var serviceExpandedGroups: NotificationService.expandedGroups
    readonly property var serviceExpandedMessages: NotificationService.expandedMessages

    onServiceGroupedNotificationsChanged: {
        queueSessionContentHeightUpdate();
        if (!keyboardController) {
            return;
        }

        if (keyboardController.isTogglingGroup) {
            keyboardController.rebuildFlatNavigation();
            return;
        }

        keyboardController.rebuildFlatNavigation();

        if (keyboardController.keyboardNavigationActive) {
            ensureVisibleTimer.restart();
        }
    }

    onServiceExpandedGroupsChanged: {
        queueSessionContentHeightUpdate();
        keyboardController?.rebuildFlatNavigation();
        if (!keyboardController || !keyboardController.keyboardNavigationActive)
            return;
        expansionEnsureVisibleTimer.restart();
    }

    onServiceExpandedMessagesChanged: {
        queueSessionContentHeightUpdate();
        if (!keyboardController || !keyboardController.keyboardNavigationActive)
            return;
        expansionEnsureVisibleTimer.restart();
    }
}
