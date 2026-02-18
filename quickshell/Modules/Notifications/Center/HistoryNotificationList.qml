import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string selectedFilterKey: "all"
    property var keyboardController: null
    property bool keyboardActive: false
    property int selectedIndex: -1
    property bool showKeyboardHints: false

    function getStartOfDay(date) {
        const d = new Date(date);
        d.setHours(0, 0, 0, 0);
        return d;
    }

    function getFilterRange(key) {
        const now = new Date();
        const startOfToday = getStartOfDay(now);
        const startOfYesterday = new Date(startOfToday.getTime() - 86400000);

        switch (key) {
        case "all":
            return {
                start: null,
                end: null
            };
        case "1h":
            return {
                start: new Date(now.getTime() - 3600000),
                end: null
            };
        case "today":
            return {
                start: startOfToday,
                end: null
            };
        case "yesterday":
            return {
                start: startOfYesterday,
                end: startOfToday
            };
        case "older":
            return {
                start: null,
                end: getOlderCutoff()
            };
        case "7d":
            return {
                start: new Date(now.getTime() - 7 * 86400000),
                end: null
            };
        case "30d":
            return {
                start: new Date(now.getTime() - 30 * 86400000),
                end: null
            };
        default:
            return {
                start: null,
                end: null
            };
        }
    }

    function countForFilter(key) {
        const range = getFilterRange(key);
        if (!range.start && !range.end)
            return NotificationService.historyList.length;
        return NotificationService.historyList.filter(n => {
            const ts = n.timestamp;
            if (range.start && ts < range.start.getTime())
                return false;
            if (range.end && ts >= range.end.getTime())
                return false;
            return true;
        }).length;
    }

    readonly property var allFilters: [
        {
            label: I18n.tr("All", "notification history filter"),
            key: "all",
            maxDays: 0
        },
        {
            label: I18n.tr("Last hour", "notification history filter"),
            key: "1h",
            maxDays: 1
        },
        {
            label: I18n.tr("Today", "notification history filter"),
            key: "today",
            maxDays: 1
        },
        {
            label: I18n.tr("Yesterday", "notification history filter"),
            key: "yesterday",
            maxDays: 2
        },
        {
            label: I18n.tr("7 days", "notification history filter"),
            key: "7d",
            maxDays: 7
        },
        {
            label: I18n.tr("30 days", "notification history filter"),
            key: "30d",
            maxDays: 30
        },
        {
            label: I18n.tr("Older", "notification history filter for content older than other filters"),
            key: "older",
            maxDays: 0
        }
    ]

    function filterRelevantForRetention(filter) {
        const retention = SettingsData.notificationHistoryMaxAgeDays;
        if (filter.key === "older") {
            if (retention === 0)
                return true;
            return retention > 2 && retention < 7 || retention > 30;
        }
        if (retention === 0)
            return true;
        if (filter.maxDays === 0)
            return true;
        return filter.maxDays <= retention;
    }

    function getOlderCutoff() {
        const retention = SettingsData.notificationHistoryMaxAgeDays;
        const now = new Date();
        if (retention === 0 || retention > 30)
            return new Date(now.getTime() - 30 * 86400000);
        if (retention >= 7)
            return new Date(now.getTime() - 7 * 86400000);
        const startOfToday = getStartOfDay(now);
        return new Date(startOfToday.getTime() - 86400000);
    }

    readonly property var visibleFilters: {
        const result = [];
        const retention = SettingsData.notificationHistoryMaxAgeDays;
        for (let i = 0; i < allFilters.length; i++) {
            const f = allFilters[i];
            if (!filterRelevantForRetention(f))
                continue;
            const count = countForFilter(f.key);
            if (f.key === "all" || count > 0) {
                result.push({
                    label: f.label,
                    key: f.key,
                    count: count
                });
            }
        }
        return result;
    }

    onVisibleFiltersChanged: {
        let found = false;
        for (let i = 0; i < visibleFilters.length; i++) {
            if (visibleFilters[i].key === selectedFilterKey) {
                found = true;
                break;
            }
        }
        if (!found)
            selectedFilterKey = "all";
    }

    function getFilteredHistory() {
        const range = getFilterRange(selectedFilterKey);
        if (!range.start && !range.end)
            return NotificationService.historyList;
        return NotificationService.historyList.filter(n => {
            const ts = n.timestamp;
            if (range.start && ts < range.start.getTime())
                return false;
            if (range.end && ts >= range.end.getTime())
                return false;
            return true;
        });
    }

    function getChipIndex() {
        for (let i = 0; i < visibleFilters.length; i++) {
            if (visibleFilters[i].key === selectedFilterKey)
                return i;
        }
        return 0;
    }

    function enableAutoScroll() {
    }

    function removeWithScrollPreserve(itemId) {
        historyListView.savedY = historyListView.contentY;
        NotificationService.removeFromHistory(itemId);
        Qt.callLater(() => {
            historyListView.forceLayout();
        });
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spacingS

        DankFilterChips {
            id: filterChips
            width: parent.width
            currentIndex: root.getChipIndex()
            showCounts: true
            model: root.visibleFilters
            onSelectionChanged: index => {
                if (index >= 0 && index < root.visibleFilters.length) {
                    root.selectedFilterKey = root.visibleFilters[index].key;
                }
            }
        }

        DankListView {
            id: historyListView
            width: parent.width
            height: parent.height - filterChips.height - Theme.spacingS
            clip: true
            spacing: Theme.spacingS

            model: ScriptModel {
                id: historyModel
                values: root.getFilteredHistory()
                objectProp: "id"
            }

            NotificationEmptyState {
                visible: historyListView.count === 0
                y: Theme.spacingL
                anchors.horizontalCenter: parent.horizontalCenter
            }

            delegate: Item {
                id: delegateRoot
                required property var modelData
                required property int index

                property real swipeOffset: 0
                property bool isDismissing: false
                readonly property real dismissThreshold: width * 0.35
                property bool __delegateInitialized: false

                Component.onCompleted: {
                    Qt.callLater(() => {
                        if (delegateRoot)
                            delegateRoot.__delegateInitialized = true;
                    });
                }

                width: ListView.view.width
                height: historyCard.height
                clip: true

                HistoryNotificationCard {
                    id: historyCard
                    width: parent.width
                    x: delegateRoot.swipeOffset
                    historyItem: modelData
                    isSelected: root.keyboardActive && root.selectedIndex === index
                    keyboardNavigationActive: root.keyboardActive
                    opacity: 1 - Math.abs(delegateRoot.swipeOffset) / (delegateRoot.width * 0.5)

                    Behavior on x {
                        enabled: !swipeDragHandler.active && delegateRoot.__delegateInitialized
                        NumberAnimation {
                            duration: Theme.notificationExitDuration
                            easing.type: Theme.standardEasing
                        }
                    }

                    Behavior on opacity {
                        enabled: delegateRoot.__delegateInitialized
                        NumberAnimation {
                            duration: delegateRoot.__delegateInitialized ? Theme.notificationExitDuration : 0
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
                            root.removeWithScrollPreserve(delegateRoot.modelData?.id || "");
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
            }
        }
    }

    function selectNext() {
        if (historyModel.values.length === 0)
            return;
        keyboardActive = true;
        selectedIndex = Math.min(selectedIndex + 1, historyModel.values.length - 1);
        historyListView.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function selectPrevious() {
        if (historyModel.values.length === 0)
            return;
        if (selectedIndex <= 0) {
            keyboardActive = false;
            selectedIndex = -1;
            return;
        }
        selectedIndex = Math.max(selectedIndex - 1, 0);
        historyListView.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function clearSelected() {
        if (selectedIndex < 0 || selectedIndex >= historyModel.values.length)
            return;
        const item = historyModel.values[selectedIndex];
        NotificationService.removeFromHistory(item.id);
        if (historyModel.values.length === 0) {
            keyboardActive = false;
            selectedIndex = -1;
        } else {
            selectedIndex = Math.min(selectedIndex, historyModel.values.length - 1);
        }
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Down || event.key === 16777237) {
            if (!keyboardActive) {
                keyboardActive = true;
                selectedIndex = 0;
            } else {
                selectNext();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || event.key === 16777235) {
            if (keyboardActive) {
                selectPrevious();
            }
            event.accepted = true;
        } else if (keyboardActive && (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)) {
            clearSelected();
            event.accepted = true;
        } else if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && (event.modifiers & Qt.ShiftModifier)) {
            NotificationService.clearHistory();
            keyboardActive = false;
            selectedIndex = -1;
            event.accepted = true;
        } else if (event.key === Qt.Key_F10) {
            showKeyboardHints = !showKeyboardHints;
            event.accepted = true;
        }
    }
}
