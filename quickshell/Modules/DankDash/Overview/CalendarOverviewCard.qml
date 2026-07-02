import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root
    readonly property var log: Log.scoped("CalendarOverviewCard")

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    implicitWidth: SettingsData.showWeekNumber ? 736 : 700

    property bool showEventDetails: false
    property date selectedDate: systemClock.date
    property var selectedDateEvents: []
    property bool hasEvents: selectedDateEvents && selectedDateEvents.length > 0
    property var detailEvent: null
    property bool showEditor: false
    property var editorEvent: null

    signal closeDash
    signal navFocusRequested

    function weekStartQt() {
        if (SettingsData.firstDayOfWeek >= 7 || SettingsData.firstDayOfWeek < 0) {
            return Qt.locale().firstDayOfWeek;
        }
        return SettingsData.firstDayOfWeek;
    }

    function weekStartJs() {
        return weekStartQt() % 7;
    }

    function startOfWeek(dateObj) {
        const d = new Date(dateObj);
        const jsDow = d.getDay();
        const diff = (jsDow - weekStartJs() + 7) % 7;
        d.setDate(d.getDate() - diff);
        return d;
    }

    function endOfWeek(dateObj) {
        const d = new Date(dateObj);
        const jsDow = d.getDay();
        const add = (weekStartJs() + 6 - jsDow + 7) % 7;
        d.setDate(d.getDate() + add);
        return d;
    }

    function getWeekNumber(dateObj) {
        // Set time to noon to avoid potential Daylight Saving Time related bugs
        const weekStartDay = startOfWeek(dateObj);
        weekStartDay.setHours(12, 0, 0, 0);

        let week1Start;

        if (weekStartJs() === 1) {
            // ISO 8601 Standard, week start on Monday
            // A week belongs to the year its Thursday falls in
            // So we have to get the yearTarget from weekStartDay instead of dateObj
            let yearTarget = weekStartDay;
            yearTarget.setDate(yearTarget.getDate() + 3); // Monday + 3 = Thursday

            // Week 1 is the week containing Jan 4th
            const jan4 = new Date(yearTarget.getFullYear(), 0, 4);
            week1Start = startOfWeek(jan4);
        } else {
            // Traditional / US Standard, week start on Sunday
            // A week belongs to the year its Sunday falls in
            let yearTarget = weekStartDay;
            yearTarget.setDate(yearTarget.getDate() + 6); // Monday + 6 = Sunday

            // Week 1 is the week containing Jan 1st
            const jan1 = new Date(yearTarget.getFullYear(), 0, 1);
            week1Start = startOfWeek(jan1);
        }

        week1Start.setHours(12, 0, 0, 0);

        const diffDays = Math.round((weekStartDay.getTime() - week1Start.getTime()) / 86400000); // Number of miliseconds in a day
        return Math.floor(diffDays / 7) + 1;
    }

    function updateSelectedDateEvents() {
        if (CalendarService && CalendarService.calendarAvailable) {
            const events = CalendarService.getEventsForDate(selectedDate);
            selectedDateEvents = events;
        } else {
            selectedDateEvents = [];
        }
    }

    function loadEventsForMonth() {
        if (!CalendarService || !CalendarService.calendarAvailable) {
            return;
        }

        const firstOfMonth = new Date(calendarGrid.displayDate.getFullYear(), calendarGrid.displayDate.getMonth(), 1);
        const lastOfMonth = new Date(calendarGrid.displayDate.getFullYear(), calendarGrid.displayDate.getMonth() + 1, 0);

        const startDate = startOfWeek(firstOfMonth);
        startDate.setDate(startDate.getDate() - 7);

        const endDate = endOfWeek(lastOfMonth);
        endDate.setDate(endDate.getDate() + 7);

        CalendarService.loadEvents(startDate, endDate);
    }

    function goToToday() {
        const now = systemClock.date;
        calendarGrid.selectedDate = now;
        calendarGrid.displayDate = now;
        root.selectedDate = now;
        loadEventsForMonth();
    }

    function moveSelection(days) {
        let d = new Date(calendarGrid.selectedDate);
        d.setDate(d.getDate() + days);
        calendarGrid.selectedDate = d;
        root.selectedDate = d;
        if (d.getMonth() !== calendarGrid.displayDate.getMonth() || d.getFullYear() !== calendarGrid.displayDate.getFullYear()) {
            calendarGrid.displayDate = d;
            loadEventsForMonth();
        }
    }

    function shiftMonth(delta) {
        let d = new Date(calendarGrid.displayDate);
        d.setMonth(d.getMonth() + delta);
        calendarGrid.displayDate = d;
        loadEventsForMonth();
    }

    function handleKeyEvent(event) {
        if (showEventDetails) {
            if (event.key === Qt.Key_Escape) {
                showEventDetails = false;
                return true;
            }
            return false;
        }
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_H:
            moveSelection(I18n.isRtl ? 1 : -1);
            return true;
        case Qt.Key_Right:
        case Qt.Key_L:
            moveSelection(I18n.isRtl ? -1 : 1);
            return true;
        case Qt.Key_Up:
        case Qt.Key_K:
            moveSelection(-7);
            return true;
        case Qt.Key_Down:
        case Qt.Key_J:
            moveSelection(7);
            return true;
        case Qt.Key_PageUp:
            shiftMonth(-1);
            return true;
        case Qt.Key_PageDown:
            shiftMonth(1);
            return true;
        case Qt.Key_T:
            goToToday();
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            root.selectedDate = calendarGrid.selectedDate;
            showEventDetails = true;
            return true;
        }
        return false;
    }

    onSelectedDateChanged: updateSelectedDateEvents()

    onShowEventDetailsChanged: {
        if (showEventDetails) {
            taskInput.forceActiveFocus();
        } else {
            navFocusRequested();
        }
    }

    Component.onCompleted: {
        loadEventsForMonth();
        updateSelectedDateEvents();
    }

    Connections {
        function onEventsByDateChanged() {
            updateSelectedDateEvents();
        }

        function onCalendarAvailableChanged() {
            if (CalendarService && CalendarService.calendarAvailable) {
                loadEventsForMonth();
            }
            updateSelectedDateEvents();
        }

        target: CalendarService
        enabled: CalendarService !== null
    }

    radius: Theme.cornerRadius
    color: Theme.nestedSurface
    border.color: Theme.outlineMedium
    border.width: 1

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        Rectangle {
            id: dankWarning
            width: parent.width
            visible: CalendarService && CalendarService.dankNeedsLaunch
            height: visible ? Math.max(28, warningRow.implicitHeight) + Theme.spacingS : 0
            radius: Theme.cornerRadius
            color: Theme.warningHover
            border.color: Theme.withAlpha(Theme.warning, 0.35)
            border.width: 1

            Row {
                id: warningRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                spacing: Theme.spacingS

                DankIcon {
                    name: "warning"
                    size: 16
                    color: Theme.warning
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    width: parent.width - 16 - Theme.spacingS - (launchButton.visible ? launchButton.width + Theme.spacingS : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    text: (CalendarService && CalendarService.dankBinaryExists) ? I18n.tr("DankCalendar isn't running") : I18n.tr("DankCalendar isn't installed")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.Wrap
                }

                DankButton {
                    id: launchButton
                    anchors.verticalCenter: parent.verticalCenter
                    visible: CalendarService && CalendarService.dankBinaryExists
                    text: I18n.tr("Launch")
                    buttonHeight: 26
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    onClicked: CalendarService.launchDankCalendar()
                }
            }
        }

        Item {
            width: parent.width
            height: 40
            visible: showEventDetails

            Rectangle {
                width: 32
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                radius: Theme.cornerRadius
                color: backButtonArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                DankIcon {
                    anchors.centerIn: parent
                    name: "arrow_back"
                    size: 14
                    color: Theme.primary
                }

                MouseArea {
                    id: backButtonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showEventDetails = false
                }
            }

            Rectangle {
                width: 32
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                radius: Theme.cornerRadius
                visible: CalendarService && CalendarService.canCreateEvents
                color: addEventArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                DankIcon {
                    anchors.centerIn: parent
                    name: "event"
                    size: 16
                    color: Theme.primary
                }

                MouseArea {
                    id: addEventArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.editorEvent = null;
                        root.showEditor = true;
                    }
                }
            }

            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 32 + Theme.spacingS * 2
                anchors.rightMargin: (CalendarService && CalendarService.canCreateEvents) ? 32 + Theme.spacingS * 2 : Theme.spacingS
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const dateStr = Qt.formatDate(selectedDate, "MMM d");
                    if (selectedDateEvents && selectedDateEvents.length > 0) {
                        const eventCount = selectedDateEvents.length === 1 ? I18n.tr("1 task", "task count next to a date") : I18n.tr("%1 tasks", "task count next to a date, %1 is the number of tasks").arg(selectedDateEvents.length);
                        return dateStr + " • " + eventCount;
                    }
                    return dateStr;
                }
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        Row {
            width: parent.width
            height: 28
            visible: !showEventDetails

            Rectangle {
                width: 28
                height: 28
                radius: Theme.cornerRadius
                color: prevMonthArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                DankIcon {
                    anchors.centerIn: parent
                    name: "chevron_left"
                    size: 14
                    color: Theme.primary
                }

                MouseArea {
                    id: prevMonthArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let newDate = new Date(calendarGrid.displayDate);
                        newDate.setMonth(newDate.getMonth() - 1);
                        calendarGrid.displayDate = newDate;
                        loadEventsForMonth();
                    }
                }
            }

            StyledText {
                width: parent.width - 84
                height: 28
                text: calendarGrid.displayDate.toLocaleDateString(I18n.locale(), "MMMM yyyy")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                width: 28
                height: 28
                radius: Theme.cornerRadius
                color: todayArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                DankIcon {
                    anchors.centerIn: parent
                    name: "today"
                    size: 14
                    color: Theme.primary
                }

                MouseArea {
                    id: todayArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goToToday()
                }
            }

            Rectangle {
                width: 28
                height: 28
                radius: Theme.cornerRadius
                color: nextMonthArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                DankIcon {
                    anchors.centerIn: parent
                    name: "chevron_right"
                    size: 14
                    color: Theme.primary
                }

                MouseArea {
                    id: nextMonthArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let newDate = new Date(calendarGrid.displayDate);
                        newDate.setMonth(newDate.getMonth() + 1);
                        calendarGrid.displayDate = newDate;
                        loadEventsForMonth();
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: parent.height - 28 - Theme.spacingS
            visible: !showEventDetails
            spacing: SettingsData.showWeekNumber ? Theme.spacingS : 0

            Column {
                id: weekNumberColumn
                visible: SettingsData.showWeekNumber
                width: SettingsData.showWeekNumber ? 28 : 0
                height: parent.height
                spacing: Theme.spacingS

                Item {
                    width: parent.width
                    height: 18
                }

                Grid {
                    width: parent.width
                    height: parent.height - 18 - Theme.spacingS
                    columns: 1
                    rows: 6

                    Repeater {
                        model: 6
                        Rectangle {
                            width: parent.width
                            height: parent.height / 6
                            color: "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: {
                                    const rowDate = new Date(calendarGrid.firstDay);
                                    rowDate.setDate(rowDate.getDate() + index * 7);
                                    return root.getWeekNumber(rowDate);
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextSecondary
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }

            Column {
                width: SettingsData.showWeekNumber ? (parent.width - weekNumberColumn.width - parent.spacing) : parent.width
                height: parent.height
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    height: 18

                    Repeater {
                        model: {
                            const days = [];
                            const qtFirst = weekStartQt();
                            for (let i = 0; i < 7; ++i) {
                                const qtDay = ((qtFirst - 1 + i) % 7) + 1;
                                days.push(I18n.locale().dayName(qtDay, Locale.ShortFormat));
                            }
                            return days;
                        }

                        Rectangle {
                            width: parent.width / 7
                            height: 18
                            color: "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextSecondary
                                font.weight: Font.Medium
                            }
                        }
                    }
                }

                Grid {
                    id: calendarGrid
                    width: parent.width
                    height: parent.height - 18 - Theme.spacingS
                    columns: 7
                    rows: 6

                    property date displayDate: systemClock.date
                    property date selectedDate: systemClock.date

                    readonly property date firstDay: {
                        const firstOfMonth = new Date(displayDate.getFullYear(), displayDate.getMonth(), 1);
                        return startOfWeek(firstOfMonth);
                    }

                    Repeater {
                        model: 42

                        Rectangle {
                            readonly property date dayDate: {
                                const date = new Date(parent.firstDay);
                                date.setDate(date.getDate() + index);
                                return date;
                            }
                            readonly property bool isCurrentMonth: dayDate.getMonth() === calendarGrid.displayDate.getMonth()
                            readonly property bool isToday: dayDate.toDateString() === new Date().toDateString()
                            readonly property bool isSelected: dayDate.toDateString() === calendarGrid.selectedDate.toDateString()

                            width: parent.width / 7
                            height: parent.height / 6
                            color: "transparent"

                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width - 4, parent.height - 4, 32)
                                height: width
                                color: isToday ? Theme.primaryHover : dayArea.containsMouse ? Theme.primaryHoverLight : Theme.withAlpha(Theme.primaryHoverLight, 0)
                                radius: Theme.cornerRadius
                                border.color: (isSelected && !isToday) ? Theme.primary : Theme.withAlpha(Theme.primary, 0)
                                border.width: (isSelected && !isToday) ? 1 : 0

                                StyledText {
                                    anchors.centerIn: parent
                                    text: dayDate.getDate()
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: isToday ? Theme.primary : isCurrentMonth ? Theme.surfaceText : Theme.surfaceVariantText
                                    font.weight: isToday ? Font.Medium : Font.Normal
                                }

                                Row {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: 3
                                    spacing: Theme.spacingXXS
                                    visible: CalendarService && CalendarService.calendarAvailable && CalendarService.hasEventsForDate(dayDate)

                                    Repeater {
                                        model: {
                                            const evs = CalendarService.getEventsForDate(dayDate);
                                            const seen = [];
                                            for (let i = 0; i < evs.length && seen.length < 3; i++) {
                                                const c = (evs[i].color && evs[i].color.length) ? evs[i].color : "primary";
                                                if (seen.indexOf(c) === -1)
                                                    seen.push(c);
                                            }
                                            return seen;
                                        }

                                        Rectangle {
                                            width: 5
                                            height: 5
                                            radius: 2.5
                                            color: modelData === "primary" ? (isToday ? Qt.lighter(Theme.primary, 1.3) : Theme.primary) : modelData
                                            opacity: isToday ? 0.95 : 0.8
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: dayArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    calendarGrid.selectedDate = dayDate;
                                    root.selectedDate = dayDate;
                                    root.showEventDetails = true;
                                }
                            }
                        }
                    }
                }
            }
        }

        Flickable {
            id: flickableArea
            width: parent.width - Theme.spacingS * 2
            height: parent.height - (showEventDetails ? 40 + 42 : 28 + 18) - Theme.spacingS
            anchors.horizontalCenter: parent.horizontalCenter
            visible: showEventDetails
            clip: true
            contentWidth: width
            contentHeight: listViewContainer.height
            interactive: listViewContainer.draggedItem === null

            Item {
                id: listViewContainer
                width: parent.width
                height: 100

                property var draggedItem: null
                property bool orderChanged: false

                function resetAndLayout() {
                    for (let i = 0; i < repeater.count; i++) {
                        let item = repeater.itemAt(i);
                        if (item) {
                            item.visualIndex = i;
                            item.isDragging = false;
                            item.isEditing = false;
                        }
                    }
                    updateLayout();
                }

                function updateLayout() {
                    let items = [];
                    for (let i = 0; i < repeater.count; i++) {
                        let item = repeater.itemAt(i);
                        if (item) {
                            items.push(item);
                        }
                    }
                    items.sort((a, b) => a.visualIndex - b.visualIndex);

                    let currentY = 0;
                    for (let i = 0; i < items.length; i++) {
                        let item = items[i];
                        if (item && !item.isDragging) {
                            item.y = currentY;
                        }
                        if (item) {
                            currentY += item.height + Theme.spacingXS;
                        }
                    }
                    listViewContainer.height = Math.max(0, currentY - Theme.spacingXS);
                }

                function checkAndReorder(dragged) {
                    let items = [];
                    for (let i = 0; i < repeater.count; i++) {
                        let item = repeater.itemAt(i);
                        if (item) {
                            items.push(item);
                        }
                    }
                    items.sort((a, b) => a.visualIndex - b.visualIndex);

                    let swapped = false;

                    // Helper to get target Y position without animation offsets
                    function getTargetY(index) {
                        let y = 0;
                        for (let i = 0; i < index; i++) {
                            y += items[i].height + Theme.spacingXS;
                        }
                        return y;
                    }

                    while (true) {
                        let draggedIdx = items.indexOf(dragged);
                        if (draggedIdx === -1)
                            break;

                        let didSwap = false;

                        // Check item above
                        if (draggedIdx > 0) {
                            let above = items[draggedIdx - 1];
                            let targetYAbove = getTargetY(draggedIdx - 1);
                            if (above && dragged.y < (targetYAbove + above.height / 2)) {
                                // Swap visualIndex
                                let temp = dragged.visualIndex;
                                dragged.visualIndex = above.visualIndex;
                                above.visualIndex = temp;

                                // Swap in local array
                                items[draggedIdx] = above;
                                items[draggedIdx - 1] = dragged;

                                listViewContainer.orderChanged = true;
                                swapped = true;
                                didSwap = true;
                            }
                        }

                        // Check item below
                        if (!didSwap && draggedIdx < items.length - 1) {
                            let below = items[draggedIdx + 1];
                            let targetYBelow = getTargetY(draggedIdx + 1);
                            if (below && (dragged.y + dragged.height) > (targetYBelow + below.height / 2)) {
                                // Swap visualIndex
                                let temp = dragged.visualIndex;
                                dragged.visualIndex = below.visualIndex;
                                below.visualIndex = temp;

                                // Swap in local array
                                items[draggedIdx] = below;
                                items[draggedIdx + 1] = dragged;

                                listViewContainer.orderChanged = true;
                                swapped = true;
                                didSwap = true;
                            }
                        }

                        if (!didSwap) {
                            break;
                        }
                    }

                    if (swapped) {
                        updateLayout();
                    }
                }

                function saveNewOrder() {
                    if (!orderChanged)
                        return;

                    let items = [];
                    for (let i = 0; i < repeater.count; i++) {
                        let item = repeater.itemAt(i);
                        if (item) {
                            items.push(item);
                        }
                    }
                    items.sort((a, b) => a.visualIndex - b.visualIndex);

                    let orderedIds = [];
                    for (let i = 0; i < items.length; i++) {
                        let tid = items[i].taskId;
                        if (tid && tid.startsWith("task_")) {
                            orderedIds.push(tid.replace("task_", ""));
                        }
                    }
                    if (orderedIds.length > 0) {
                        CalendarService.reorderTasksForDate(root.selectedDate, orderedIds);
                    }
                    orderChanged = false;
                }

                Repeater {
                    id: repeater
                    model: selectedDateEvents

                    onModelChanged: {
                        Qt.callLater(listViewContainer.resetAndLayout);
                    }

                    delegate: Rectangle {
                        id: taskItem
                        width: parent ? parent.width : 0
                        height: isEditing ? 34 : (eventContent.implicitHeight + Theme.spacingS)
                        radius: Theme.cornerRadius

                        property int modelIndex: index
                        property int visualIndex: index
                        property string taskId: (modelData && modelData.id) ? modelData.id : ""
                        property bool isDragging: false
                        property bool isEditing: false
                        property real dragMouseOffsetY: 0

                        onModelIndexChanged: {
                            visualIndex = modelIndex;
                        }

                        onYChanged: {
                            if (isDragging) {
                                listViewContainer.checkAndReorder(taskItem);
                            }
                        }

                        readonly property bool isTask: modelData && modelData.id && modelData.id.startsWith("task_")
                        readonly property color accentColor: {
                            if (isTask)
                                return modelData.completed ? Theme.withAlpha(Theme.primary, 0.4) : Theme.primary;
                            return (modelData && modelData.color && modelData.color.length) ? modelData.color : Theme.primary;
                        }
                        readonly property color surfaceColor: isDragging ? Theme.primaryPressed : (eventMouseArea.containsMouse ? Theme.primaryBackground : Theme.nestedSurface)

                        color: surfaceColor
                        border.color: isDragging ? Theme.primary : (eventMouseArea.containsMouse ? Theme.primaryPressed : Theme.outlineMedium)
                        border.width: (isDragging || eventMouseArea.containsMouse) ? 1 : Theme.layerOutlineWidth

                        scale: isDragging ? 1.02 : 1.0
                        z: isDragging ? 100 : visualIndex

                        Behavior on scale {
                            NumberAnimation {
                                duration: 100
                            }
                        }

                        Behavior on y {
                            id: yBehavior
                            enabled: !taskItem.isDragging
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }

                        Component.onCompleted: {
                            visualIndex = index;
                            listViewContainer.updateLayout();
                        }

                        onHeightChanged: {
                            listViewContainer.updateLayout();
                        }

                        onIsEditingChanged: {
                            if (isEditing) {
                                editInput.forceActiveFocus();
                                editInput.selectAll();
                            }
                        }

                        Item {
                            id: accentClip
                            width: 4
                            clip: true
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left

                            Rectangle {
                                width: taskItem.width
                                height: taskItem.height
                                radius: taskItem.radius
                                color: taskItem.accentColor
                                anchors.top: parent.top
                                anchors.left: parent.left
                            }
                        }

                        // Drag Handle
                        Rectangle {
                            id: dragHandle
                            width: 24
                            height: 24
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            radius: Theme.cornerRadius
                            color: "transparent"
                            visible: modelData && modelData.id && modelData.id.startsWith("task_") && !taskItem.isEditing

                            DankIcon {
                                anchors.centerIn: parent
                                name: "drag_indicator"
                                size: 14
                                color: dragMouseArea.containsMouse ? Theme.primary : Theme.surfaceTextAlpha
                            }

                            MouseArea {
                                id: dragMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.SizeAllCursor
                                preventStealing: true

                                drag.target: taskItem
                                drag.axis: Drag.YAxis
                                drag.minimumY: 0
                                drag.maximumY: listViewContainer.height - taskItem.height

                                onPressed: {
                                    taskItem.isDragging = true;
                                    listViewContainer.orderChanged = false;
                                    listViewContainer.draggedItem = taskItem;
                                }

                                onPositionChanged: {
                                    // Handled natively by MouseArea.drag
                                }

                                onReleased: {
                                    taskItem.isDragging = false;
                                    listViewContainer.draggedItem = null;
                                    if (listViewContainer.orderChanged) {
                                        listViewContainer.saveNewOrder();
                                    } else {
                                        listViewContainer.updateLayout();
                                    }
                                }

                                onCanceled: {
                                    taskItem.isDragging = false;
                                    listViewContainer.draggedItem = null;
                                    listViewContainer.resetAndLayout();
                                }
                            }
                        }

                        // Checkbox status icon
                        Rectangle {
                            id: checkboxContainer
                            width: 24
                            height: 24
                            anchors.left: parent.left
                            anchors.leftMargin: (modelData && modelData.id && modelData.id.startsWith("task_")) ? (taskItem.isEditing ? 8 : 32) : 8
                            anchors.verticalCenter: parent.verticalCenter
                            radius: Theme.cornerRadius
                            color: "transparent"
                            visible: modelData && modelData.id && modelData.id.startsWith("task_")

                            DankIcon {
                                anchors.centerIn: parent
                                name: (modelData && modelData.completed) ? "check_box" : "check_box_outline_blank"
                                size: 16
                                color: (modelData && modelData.completed) ? Theme.primary : Theme.onSurface_38
                            }
                        }

                        Column {
                            id: eventContent

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: (modelData && modelData.id && modelData.id.startsWith("task_")) ? 60 : (Theme.spacingS + 6)
                            anchors.rightMargin: (modelData && modelData.id && modelData.id.startsWith("task_")) ? 64 : Theme.spacingXS
                            spacing: Theme.spacingXXS
                            visible: !taskItem.isEditing

                            StyledText {
                                width: parent.width
                                text: modelData ? modelData.title : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: (modelData && modelData.id && modelData.id.startsWith("task_") && modelData.completed) ? Theme.surfaceTextSecondary : Theme.surfaceText
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignLeft
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            StyledText {
                                width: parent.width
                                text: {
                                    if (!modelData)
                                        return "";
                                    const cal = (modelData.calendar && modelData.calendar.length) ? " · " + modelData.calendar : "";
                                    if (modelData.allDay)
                                        return I18n.tr("All day", "calendar task with no specific time") + cal;
                                    if (modelData.start && modelData.end) {
                                        const timeFormat = SettingsData.use24HourClock ? "HH:mm" : "h:mm AP";
                                        const startTime = Qt.formatTime(modelData.start, timeFormat);
                                        if (modelData.start.toDateString() !== modelData.end.toDateString() || modelData.start.getTime() !== modelData.end.getTime())
                                            return startTime + " – " + Qt.formatTime(modelData.end, timeFormat) + cal;
                                        return startTime + cal;
                                    }
                                    return "";
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                font.weight: Font.Normal
                                horizontalAlignment: Text.AlignLeft
                                visible: text !== "" && modelData && modelData.id && !modelData.id.startsWith("task_")
                            }
                        }

                        // Inline Edit Input Box
                        Rectangle {
                            id: editInputContainer
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 36
                            anchors.rightMargin: 64
                            anchors.verticalCenter: parent.verticalCenter
                            height: 28
                            visible: taskItem.isEditing
                            color: "transparent"

                            TextInput {
                                id: editInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                selectByMouse: true
                                clip: true

                                text: modelData ? modelData.title : ""

                                onAccepted: {
                                    let txt = text.trim();
                                    if (txt !== "" && modelData && modelData.id) {
                                        CalendarService.editTask(modelData.id, txt);
                                    }
                                    taskItem.isEditing = false;
                                }

                                Keys.onEscapePressed: event => {
                                    taskItem.isEditing = false;
                                    event.accepted = true;
                                }
                            }
                        }

                        // Main body MouseArea (declared before the delete/edit buttons so they sit on top)
                        MouseArea {
                            id: eventMouseArea

                            anchors.fill: parent
                            anchors.leftMargin: (modelData && modelData.id && modelData.id.startsWith("task_")) ? 32 : 6
                            anchors.rightMargin: (modelData && modelData.id && modelData.id.startsWith("task_")) ? 64 : 0
                            hoverEnabled: true
                            cursorShape: modelData ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: modelData && !taskItem.isEditing
                            onClicked: {
                                if (modelData && modelData.id && modelData.id.startsWith("task_")) {
                                    CalendarService.toggleTask(modelData.id);
                                    return;
                                }
                                if (modelData)
                                    root.detailEvent = modelData;
                            }
                        }

                        // Delete / Cancel Button
                        Rectangle {
                            id: deleteButton
                            width: 24
                            height: 24
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            radius: Theme.cornerRadius
                            color: deleteMouseArea.containsMouse ? (taskItem.isEditing ? Theme.primaryHover : Qt.rgba(0.9, 0.2, 0.2, 0.15)) : Theme.withAlpha(Qt.rgba(0.9, 0.2, 0.2, 0.15), 0)
                            visible: modelData && modelData.id && modelData.id.startsWith("task_")

                            DankIcon {
                                anchors.centerIn: parent
                                name: taskItem.isEditing ? "close" : "delete"
                                size: 14
                                color: deleteMouseArea.containsMouse ? (taskItem.isEditing ? Theme.primary : Qt.rgba(0.9, 0.2, 0.2, 1.0)) : Theme.onSurface_38
                            }

                            MouseArea {
                                id: deleteMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (taskItem.isEditing) {
                                        taskItem.isEditing = false;
                                    } else if (modelData && modelData.id) {
                                        CalendarService.removeTask(modelData.id);
                                    }
                                }
                            }
                        }

                        // Edit / Save Button
                        Rectangle {
                            id: editButton
                            width: 24
                            height: 24
                            anchors.right: deleteButton.left
                            anchors.rightMargin: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            radius: Theme.cornerRadius
                            color: editMouseArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)
                            visible: modelData && modelData.id && modelData.id.startsWith("task_")

                            DankIcon {
                                anchors.centerIn: parent
                                name: taskItem.isEditing ? "check" : "edit"
                                size: 14
                                color: editMouseArea.containsMouse ? Theme.primary : Theme.onSurface_38
                            }

                            MouseArea {
                                id: editMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (taskItem.isEditing) {
                                        let txt = editInput.text.trim();
                                        if (txt !== "" && modelData && modelData.id) {
                                            CalendarService.editTask(modelData.id, txt);
                                        }
                                        taskItem.isEditing = false;
                                    } else {
                                        taskItem.isEditing = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width - Theme.spacingS * 2
            height: 34
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Theme.cornerRadius
            color: Theme.nestedSurface
            border.color: Theme.outlineMedium
            border.width: 1
            visible: showEventDetails

            TextInput {
                id: taskInput
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                selectByMouse: true
                clip: true

                Text {
                    text: I18n.tr("Add a task...", "placeholder in the new-task input field")
                    color: Theme.onSurface_38
                    visible: taskInput.text.length === 0
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }

                onAccepted: {
                    let txt = text.trim();
                    if (txt !== "") {
                        CalendarService.addTaskForDate(root.selectedDate, txt);
                        text = "";
                    }
                }

                Keys.onEscapePressed: event => {
                    root.showEventDetails = false;
                    event.accepted = true;
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        z: 1000
        active: root.detailEvent !== null

        sourceComponent: CalendarEventDetail {
            eventData: root.detailEvent
            canEdit: CalendarService && CalendarService.canCreateEvents && root.detailEvent && !root.detailEvent.readOnly && !(root.detailEvent.id && root.detailEvent.id.startsWith("task_"))
            onCloseRequested: root.detailEvent = null
            onEditRequested: {
                root.editorEvent = root.detailEvent;
                root.detailEvent = null;
                root.showEditor = true;
            }
            onDeleteRequested: {
                if (root.detailEvent && root.detailEvent.id)
                    CalendarService.deleteEvent(root.detailEvent.id, null);
                root.detailEvent = null;
            }
        }
    }

    Loader {
        anchors.fill: parent
        z: 1000
        active: root.showEditor

        sourceComponent: CalendarEventEditor {
            eventData: root.editorEvent
            initialDate: root.selectedDate
            onCloseRequested: {
                root.showEditor = false;
                root.editorEvent = null;
            }
            onSaved: {
                root.showEditor = false;
                root.editorEvent = null;
            }
        }
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Hours
    }
}
