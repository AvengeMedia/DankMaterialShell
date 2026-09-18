import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Notifications
import qs.Modules.Notifications as Notifications

Item {
    id: root

    property var notificationGroup
    property bool expanded: NotificationService.expandedGroups[notificationGroup?.key] || false
    property bool animateExpansion: true
    property bool isGroupSelected: false
    property int selectedNotificationIndex: -1
    property bool keyboardNavigationActive: false
    property var transientSurfaceTracker: null
    property bool firstInList: true
    property bool lastInList: true
    property bool nested: false
    readonly property color cardSurfaceColor: Theme.foregroundColor(nested ? Theme.chipSurface : Theme.cardSurface, Theme.isFloatingWindow(root))
    readonly property color cardChipColor: nested ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerFocus) : Theme.chipSurface
    readonly property real expandedTargetHeight: {
        let total = groupHeader.height;
        for (const child of expandedContent.children) {
            if (child.targetHeight === undefined)
                continue;
            total += Theme.groupedListGap + child.targetHeight;
        }
        return total;
    }
    readonly property real targetHeight: expanded ? expandedTargetHeight : collapsedCard.targetHeight
    readonly property bool isAnimating: heightAnimation.running

    width: parent ? parent.width : NotificationMetrics.popupWidth
    height: targetHeight
    clip: true

    function toggleGroup() {
        NotificationService.toggleGroupExpansion(notificationGroup?.key || "");
    }

    function invokeAction(action) {
        if (!action?.invoke)
            return;
        action.invoke();
        PopoutService.closeNotificationCenter();
    }

    function openContextMenu(item, x, y) {
        notificationCardContextMenu.popupAnchorItem = item;
        notificationCardContextMenu.showDropdownMenu();
    }

    Component.onDestruction: transientSurfaceTracker?.unregister(root)

    Connections {
        target: root.transientSurfaceTracker
        ignoreUnknownSignals: true
        function onCloseRequested() {
            notificationCardContextMenu.closeDropdownMenu();
        }
    }

    Behavior on height {
        enabled: root.animateExpansion && NotificationMetrics.animationsEnabled
        NumberAnimation {
            id: heightAnimation
            duration: root.expanded ? Theme.notificationExpandDuration : Theme.notificationCollapseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: NotificationMetrics.expandCurve
        }
    }

    Notifications.NotificationCard {
        id: collapsedCard
        width: parent.width
        surfaceColor: root.cardSurfaceColor
        chipColor: root.cardChipColor
        visible: !root.expanded
        notificationData: root.notificationGroup?.latestNotification ?? null
        groupCount: root.notificationGroup?.count || 0
        descriptionExpanded: NotificationService.expandedMessages[(notificationData?.notification?.id || "") + "_desc"] || false
        firstInGroup: root.firstInList
        lastInGroup: root.lastInList
        keyboardSelected: root.keyboardNavigationActive && root.isGroupSelected
        keyboardHints: keyboardSelected
        animateHeight: false
        onExpandRequested: NotificationService.toggleMessageExpansion((notificationData?.notification?.id || "") + "_desc")
        onGroupToggleRequested: root.toggleGroup()
        onDismissRequested: NotificationService.dismissGroup(root.notificationGroup?.key || "")
        onActionRequested: action => root.invokeAction(action)
        onBodyClicked: {
            if (groupCount > 1) {
                root.toggleGroup();
                return;
            }
            root.invokeAction(contextActions.defaultAction(notificationData));
        }
        onContextMenuRequested: (x, y) => root.openContextMenu(collapsedCard, x, y)
    }

    Column {
        id: expandedContent
        objectName: "expandedContent"
        property int swipingIndex: -1
        property real swipingOffset: 0
        width: parent.width
        visible: root.expanded
        spacing: Theme.groupedListGap

        Rectangle {
            id: groupHeader
            width: parent.width
            height: NotificationMetrics.cardPadding * 2 + NotificationMetrics.controlSize
            radius: Theme.groupedListOuterRadius
            color: "transparent"
            border.width: root.keyboardNavigationActive && root.isGroupSelected ? Theme.focusRingWidth : 0
            border.color: Theme.focusRingColor
            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: NotificationMetrics.cardPadding
                anchors.right: groupControls.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.notificationGroup?.appName || ""
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: Theme.primary
                elide: Text.ElideRight
            }
            Row {
                id: groupControls
                anchors.right: parent.right
                anchors.rightMargin: NotificationMetrics.cardPadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS
                DankButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Dismiss")
                    buttonHeight: NotificationMetrics.controlSize
                    horizontalPadding: NotificationMetrics.actionPadding
                    backgroundColor: "transparent"
                    textColor: Theme.primary
                    onClicked: NotificationService.dismissGroup(root.notificationGroup?.key || "")
                }
                DankButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.notificationGroup?.count || 0).toString()
                    iconName: "expand_less"
                    buttonHeight: NotificationMetrics.controlSize
                    horizontalPadding: Theme.spacingS
                    backgroundColor: root.cardChipColor
                    textColor: Theme.onSurfaceVariant
                    Accessible.name: I18n.tr("Collapse")
                    onClicked: root.toggleGroup()
                }
            }
        }

        Repeater {
            id: notificationRepeater
            objectName: "notificationRepeater"
            model: ScriptModel {
                values: root.expanded ? (root.notificationGroup?.notifications?.slice(0, NotificationMetrics.expandedLimit) || []) : []
            }

            Item {
                id: row
                required property var modelData
                required property int index
                property real swipeOffset: 0
                property bool dismissing: false
                property bool collapsing: false
                property var notificationToDismiss: null
                readonly property real targetHeight: collapsing ? 0 : message.targetHeight
                readonly property bool adjacentToSwipe: expandedContent.swipingIndex !== -1 && Math.abs(index - expandedContent.swipingIndex) === 1
                readonly property real adjacentSwipeInfluence: adjacentToSwipe ? expandedContent.swipingOffset * NotificationMetrics.adjacentSwipeInfluence : 0
                width: expandedContent.width
                height: message.height
                clip: true

                Notifications.NotificationCard {
                    id: message
                    surfaceColor: root.cardSurfaceColor
                    chipColor: root.cardChipColor
                    x: row.swipeOffset + row.adjacentSwipeInfluence
                    width: parent.width
                    notificationData: row.modelData
                    firstInGroup: row.index === 0
                    lastInGroup: row.index === notificationRepeater.count - 1
                    keyboardSelected: root.keyboardNavigationActive && root.selectedNotificationIndex === row.index
                    keyboardHints: keyboardSelected
                    descriptionExpanded: NotificationService.expandedMessages[(notificationData?.notification?.id || "") + "_desc"] || false
                    onExpandRequested: NotificationService.toggleMessageExpansion((notificationData?.notification?.id || "") + "_desc")
                    onDismissRequested: NotificationService.dismissNotification(row.modelData)
                    onActionRequested: action => root.invokeAction(action)
                    onBodyClicked: root.invokeAction(contextActions.defaultAction(notificationData))
                    onContextMenuRequested: (x, y) => root.openContextMenu(message, x, y)
                    Behavior on x {
                        enabled: !swipe.active && !row.dismissing && !row.adjacentToSwipe && NotificationMetrics.animationsEnabled
                        NumberAnimation {
                            duration: Theme.notificationExitDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: NotificationMetrics.dismissCurve
                        }
                    }
                }

                DragHandler {
                    id: swipe
                    target: null
                    yAxis.enabled: false
                    grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                    onTranslationChanged: {
                        if (row.dismissing)
                            return;
                        row.swipeOffset = translation.x;
                        expandedContent.swipingOffset = translation.x;
                    }
                    onActiveChanged: {
                        if (active) {
                            expandedContent.swipingIndex = row.index;
                            return;
                        }
                        expandedContent.swipingIndex = -1;
                        expandedContent.swipingOffset = 0;
                        if (row.dismissing)
                            return;
                        if (Math.abs(row.swipeOffset) <= row.width * NotificationMetrics.swipeThreshold) {
                            row.swipeOffset = 0;
                            return;
                        }
                        row.notificationToDismiss = row.modelData;
                        row.dismissing = true;
                        dismissAnimation.start();
                    }
                }
                SequentialAnimation {
                    id: dismissAnimation

                    NumberAnimation {
                        target: row
                        property: "swipeOffset"
                        to: row.swipeOffset > 0 ? row.width : -row.width
                        duration: NotificationMetrics.animationsEnabled ? Theme.notificationExitDuration : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: NotificationMetrics.dismissCurve
                    }
                    PropertyAction {
                        target: row
                        property: "collapsing"
                        value: true
                    }
                    NumberAnimation {
                        target: row
                        property: "height"
                        to: 0
                        duration: NotificationMetrics.animationsEnabled ? Theme.notificationExpandDuration : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: NotificationMetrics.expandCurve
                    }
                    ScriptAction {
                        script: NotificationService.dismissNotification(row.notificationToDismiss)
                    }
                }
            }
        }
    }

    NotificationActions {
        id: contextActions
        appName: root.notificationGroup?.appName || ""
        desktopEntry: root.notificationGroup?.latestNotification?.desktopEntry || ""
        onDismissRequested: NotificationService.dismissGroup(root.notificationGroup?.key || "")
        onAppMuted: NotificationService.dismissGroup(root.notificationGroup?.key || "")
    }

    DankDropdown {
        id: notificationCardContextMenu
        showTrigger: false
        popupWidth: NotificationMetrics.menuWidth
        transientSurfaceTracker: root.transientSurfaceTracker
        options: contextActions.items.map(item => item.label)
        onValueChanged: value => {
            const item = contextActions.items.find(item => item.label === value);
            if (item)
                contextActions.trigger(item.action);
        }
    }
}
