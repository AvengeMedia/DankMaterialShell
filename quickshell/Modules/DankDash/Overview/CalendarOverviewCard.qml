import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root
    readonly property var log: Log.scoped("CalendarOverviewCard")

    implicitWidth: SettingsData.showWeekNumber ? 736 : 700

    property bool showEventDetails: false
    property date selectedDate: systemClock.date
    property var selectedDateEvents: []
    property bool hasEvents: selectedDateEvents && selectedDateEvents.length > 0

    signal closeDash

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
        if (CalendarService && CalendarService.khalAvailable) {
            const events = CalendarService.getEventsForDate(selectedDate);
            selectedDateEvents = events;
        } else {
            selectedDateEvents = [];
        }
    }

    function loadEventsForMonth() {
        if (!CalendarService || !CalendarService.khalAvailable) {
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

    onSelectedDateChanged: updateSelectedDateEvents()

    onShowEventDetailsChanged: {
        if (showEventDetails) {
            taskInput.forceActiveFocus();
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

        function onKhalAvailableChanged() {
            if (CalendarService && CalendarService.khalAvailable) {
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
                color: backButtonArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

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

            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 32 + Theme.spacingS * 2
                anchors.rightMargin: Theme.spacingS
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const dateStr = Qt.formatDate(selectedDate, "MMM d");
                    if (selectedDateEvents && selectedDateEvents.length > 0) {
                        const eventCount = selectedDateEvents.length === 1 ? I18n.tr("1 task") : selectedDateEvents.length + " " + I18n.tr("tasks");
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
                color: prevMonthArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

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
                width: parent.width - 56
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
                color: nextMonthArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

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
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
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
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
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
                                color: isToday ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : dayArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                                radius: Theme.cornerRadius

                                StyledText {
                                    anchors.centerIn: parent
                                    text: dayDate.getDate()
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: isToday ? Theme.primary : isCurrentMonth ? Theme.surfaceText : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                                    font.weight: isToday ? Font.Medium : Font.Normal
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: 4
                                    width: 12
                                    height: 2
                                    radius: Theme.cornerRadius
                                    visible: CalendarService && CalendarService.khalAvailable && CalendarService.hasEventsForDate(dayDate)
                                    color: isToday ? Qt.lighter(Theme.primary, 1.3) : Theme.primary
                                    opacity: isToday ? 0.9 : 0.7

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.standardEasing
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
                        if (draggedIdx === -1) break;
                        
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
                    if (!orderChanged) return;
                    
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
                        property string taskId: modelData ? modelData.id : ""
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
                        
                        color: isDragging ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : (eventMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06) : Theme.nestedSurface)
                        border.color: isDragging ? Theme.primary : (eventMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Theme.outlineMedium)
                        border.width: (isDragging || eventMouseArea.containsMouse) ? 1 : Theme.layerOutlineWidth
                        
                        scale: isDragging ? 1.02 : 1.0
                        z: isDragging ? 100 : visualIndex
                        
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        
                        Behavior on y {
                            id: yBehavior
                            enabled: !taskItem.isDragging && listViewContainer.draggedItem === null
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

                        Rectangle {
                            width: 3
                            height: parent.height - 6
                            anchors.left: parent.left
                            anchors.leftMargin: 3
                            anchors.verticalCenter: parent.verticalCenter
                            radius: Theme.cornerRadius
                            color: modelData.id.startsWith("task_") ? (modelData.title.startsWith("✓") ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Theme.primary) : Theme.primary
                            opacity: 0.8
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
                            visible: modelData.id.startsWith("task_") && !taskItem.isEditing

                            DankIcon {
                                anchors.centerIn: parent
                                name: "drag_indicator"
                                size: 14
                                color: dragMouseArea.containsMouse ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
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

                        Column {
                            id: eventContent

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: modelData.id.startsWith("task_") ? 36 : (Theme.spacingS + 6)
                            anchors.rightMargin: modelData.id.startsWith("task_") ? 64 : Theme.spacingXS
                            spacing: 2
                            visible: !taskItem.isEditing

                            StyledText {
                                width: parent.width
                                text: modelData.title
                                font.pixelSize: Theme.fontSizeSmall
                                color: modelData.id.startsWith("task_") && modelData.title.startsWith("✓") ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5) : Theme.surfaceText
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            StyledText {
                                width: parent.width
                                text: {
                                    if (!modelData || modelData.allDay) {
                                        return I18n.tr("All day");
                                    } else if (modelData.start && modelData.end) {
                                        const timeFormat = SettingsData.use24HourClock ? "HH:mm" : "h:mm AP";
                                        const startTime = Qt.formatTime(modelData.start, timeFormat);
                                        if (modelData.start.toDateString() !== modelData.end.toDateString() || modelData.start.getTime() !== modelData.end.getTime()) {
                                            return startTime + " – " + Qt.formatTime(modelData.end, timeFormat);
                                        }
                                        return startTime;
                                    }
                                    return "";
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                font.weight: Font.Normal
                                visible: text !== "" && !modelData.id.startsWith("task_")
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
                                
                                text: {
                                    if (!modelData) return "";
                                    let title = modelData.title;
                                    if (title.startsWith("✓ ") || title.startsWith("☐ ")) {
                                        return title.substring(2);
                                    }
                                    return title;
                                }
                                
                                onAccepted: {
                                    let txt = text.trim();
                                    if (txt !== "") {
                                        CalendarService.editTask(modelData.id, txt);
                                    }
                                    taskItem.isEditing = false;
                                }
                                
                                Keys.onEscapePressed: {
                                    taskItem.isEditing = false;
                                }
                            }
                        }

                        // Main body MouseArea (declared before the delete/edit buttons so they sit on top)
                        MouseArea {
                            id: eventMouseArea

                            anchors.fill: parent
                            anchors.leftMargin: modelData.id.startsWith("task_") ? 36 : 6
                            anchors.rightMargin: modelData.id.startsWith("task_") ? 64 : 0
                            hoverEnabled: true
                            cursorShape: (modelData.url || modelData.id.startsWith("task_")) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: (modelData.url !== "" || modelData.id.startsWith("task_")) && !taskItem.isEditing
                            onClicked: {
                                if (modelData.id.startsWith("task_")) {
                                    CalendarService.toggleTask(modelData.id);
                                } else if (modelData.url && modelData.url !== "") {
                                    if (Qt.openUrlExternally(modelData.url) === false) {
                                        log.warn("Failed to open URL: " + modelData.url);
                                    } else {
                                        root.closeDash();
                                    }
                                }
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
                            color: deleteMouseArea.containsMouse ? (taskItem.isEditing ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(0.9, 0.2, 0.2, 0.15)) : "transparent"
                            visible: modelData.id.startsWith("task_")

                            DankIcon {
                                anchors.centerIn: parent
                                name: taskItem.isEditing ? "close" : "delete"
                                size: 14
                                color: deleteMouseArea.containsMouse ? (taskItem.isEditing ? Theme.primary : Qt.rgba(0.9, 0.2, 0.2, 1.0)) : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                            }

                            MouseArea {
                                id: deleteMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (taskItem.isEditing) {
                                        taskItem.isEditing = false;
                                    } else {
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
                            color: editMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                            visible: modelData.id.startsWith("task_")

                            DankIcon {
                                anchors.centerIn: parent
                                name: taskItem.isEditing ? "check" : "edit"
                                size: 14
                                color: editMouseArea.containsMouse ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                            }

                            MouseArea {
                                id: editMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (taskItem.isEditing) {
                                        let txt = editInput.text.trim();
                                        if (txt !== "") {
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

                // Hint placeholder text
                Text {
                    text: I18n.tr("Add a task...")
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                    visible: !taskInput.text && !taskInput.activeFocus
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
            }
        }
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Hours
    }
}
