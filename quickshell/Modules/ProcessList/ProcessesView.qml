import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string searchText: ""
    property string expandedPid: ""
    property var contextMenu: null
    property string processFilter: "all" // "all", "user", "system"

    property int selectedIndex: -1
    property bool keyboardNavigationActive: false
    property int forceRefreshCount: 0
    property var killedPids: []

    readonly property bool pauseUpdates: (contextMenu?.visible ?? false) || expandedPid.length > 0
    readonly property bool shouldUpdate: !pauseUpdates || forceRefreshCount > 0
    property var cachedProcesses: []

    signal openContextMenuRequested(int index, real x, real y, bool fromKeyboard)

    onFilteredProcessesChanged: {
        if (!shouldUpdate)
            return;
        cachedProcesses = filteredProcesses;
        if (forceRefreshCount > 0)
            forceRefreshCount--;

        if (killedPids.length > 0 && DgopService.allProcesses) {
            var activePids = DgopService.allProcesses.map(p => p.pid);
            killedPids = killedPids.filter(pid => activePids.includes(pid));
        }
    }

    onShouldUpdateChanged: {
        if (shouldUpdate)
            cachedProcesses = filteredProcesses;
    }

    readonly property var filteredProcesses: {
        if (!DgopService.allProcesses || DgopService.allProcesses.length === 0)
            return [];

        let procs = DgopService.allProcesses.slice();

        if (root.killedPids.length > 0) {
            procs = procs.filter(p => !root.killedPids.includes(p.pid));
        }

        if (processFilter === "user") {
            procs = procs.filter(p => p.username === UserInfoService.username);
        } else if (processFilter === "system") {
            procs = procs.filter(p => p.username !== UserInfoService.username);
        }

        if (searchText.length > 0) {
            const search = searchText.toLowerCase();
            procs = procs.filter(p => {
                const cmd = (p.command || "").toLowerCase();
                const fullCmd = (p.fullCommand || "").toLowerCase();
                const pid = p.pid.toString();
                return cmd.includes(search) || fullCmd.includes(search) || pid.includes(search);
            });
        }

        const asc = DgopService.sortAscending;
        procs.sort((a, b) => {
            let valueA, valueB, result;
            switch (DgopService.currentSort) {
            case "cpu":
                valueA = a.cpu || 0;
                valueB = b.cpu || 0;
                result = valueB - valueA;
                break;
            case "memory":
                valueA = a.memoryKB || 0;
                valueB = b.memoryKB || 0;
                result = valueB - valueA;
                break;
            case "name":
                valueA = (a.command || "").toLowerCase();
                valueB = (b.command || "").toLowerCase();
                result = valueA.localeCompare(valueB);
                break;
            case "pid":
                valueA = a.pid || 0;
                valueB = b.pid || 0;
                result = valueA - valueB;
                break;
            default:
                return 0;
            }
            return asc ? -result : result;
        });

        return procs;
    }

    function selectNext() {
        if (cachedProcesses.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = Math.min(selectedIndex + 1, cachedProcesses.length - 1);
        ensureVisible();
    }

    function selectPrevious() {
        if (cachedProcesses.length === 0)
            return;
        keyboardNavigationActive = true;
        if (selectedIndex <= 0) {
            selectedIndex = -1;
            keyboardNavigationActive = false;
            return;
        }
        selectedIndex = selectedIndex - 1;
        ensureVisible();
    }

    function selectFirst() {
        if (cachedProcesses.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = 0;
        ensureVisible();
    }

    function selectLast() {
        if (cachedProcesses.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = cachedProcesses.length - 1;
        ensureVisible();
    }

    function toggleExpand() {
        if (selectedIndex < 0 || selectedIndex >= cachedProcesses.length)
            return;
        const process = cachedProcesses[selectedIndex];
        const pidStr = (process?.pid ?? -1).toString();
        expandedPid = (expandedPid === pidStr) ? "" : pidStr;
    }

    function openContextMenu() {
        if (selectedIndex < 0 || selectedIndex >= cachedProcesses.length)
            return;
        const delegate = processListView.itemAtIndex(selectedIndex);
        if (!delegate)
            return;
        const process = cachedProcesses[selectedIndex];
        if (!process || !contextMenu)
            return;
        contextMenu.processData = process;
        const itemPos = delegate.mapToItem(contextMenu.parent, delegate.width / 2, delegate.height / 2);
        contextMenu.parentFocusItem = root;
        contextMenu.show(itemPos.x, itemPos.y, true);
    }

    function reset() {
        selectedIndex = -1;
        keyboardNavigationActive = false;
        expandedPid = "";
    }

    function forceRefresh(count) {
        forceRefreshCount = count || 3;
    }

    function ensureVisible() {
        if (selectedIndex < 0)
            return;
        processListView.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Down:
            selectNext();
            event.accepted = true;
            return;
        case Qt.Key_Up:
            selectPrevious();
            event.accepted = true;
            return;
        case Qt.Key_J:
            if (event.modifiers & Qt.ControlModifier) {
                selectNext();
                event.accepted = true;
            }
            return;
        case Qt.Key_K:
            if (event.modifiers & Qt.ControlModifier) {
                selectPrevious();
                event.accepted = true;
            }
            return;
        case Qt.Key_Home:
            selectFirst();
            event.accepted = true;
            return;
        case Qt.Key_End:
            selectLast();
            event.accepted = true;
            return;
        case Qt.Key_Space:
            if (keyboardNavigationActive) {
                toggleExpand();
                event.accepted = true;
            }
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (keyboardNavigationActive) {
                toggleExpand();
                event.accepted = true;
            }
            return;
        case Qt.Key_Menu:
        case Qt.Key_F10:
            if (keyboardNavigationActive && selectedIndex >= 0) {
                openContextMenu();
                event.accepted = true;
            }
            return;
        }
    }

    Component.onCompleted: {
        DgopService.addRef(["processes", "cpu", "memory", "system"]);
        cachedProcesses = filteredProcesses;
    }

    Component.onDestruction: {
        DgopService.removeRef(["processes", "cpu", "memory", "system"]);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                spacing: 0

                SortableHeader {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 200
                    text: I18n.tr("Name")
                    sortKey: "name"
                    currentSort: DgopService.currentSort
                    sortAscending: DgopService.sortAscending
                    onClicked: DgopService.toggleSort("name")
                    alignment: Text.AlignLeft
                }

                SortableHeader {
                    Layout.preferredWidth: 100
                    text: "CPU"
                    sortKey: "cpu"
                    currentSort: DgopService.currentSort
                    sortAscending: DgopService.sortAscending
                    onClicked: DgopService.toggleSort("cpu")
                }

                SortableHeader {
                    Layout.preferredWidth: 100
                    text: I18n.tr("Memory")
                    sortKey: "memory"
                    currentSort: DgopService.currentSort
                    sortAscending: DgopService.sortAscending
                    onClicked: DgopService.toggleSort("memory")
                }

                SortableHeader {
                    Layout.preferredWidth: 80
                    text: "PID"
                    sortKey: "pid"
                    currentSort: DgopService.currentSort
                    sortAscending: DgopService.sortAscending
                    onClicked: DgopService.toggleSort("pid")
                }

                Item {
                    Layout.preferredWidth: 40
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.outlineLight
        }

        DankListView {
            id: processListView

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2

            add: root.searchText.length > 0 ? ListViewTransitions.add : null
            remove: root.searchText.length > 0 ? ListViewTransitions.remove : null
            displaced: root.searchText.length > 0 ? ListViewTransitions.displaced : null
            move: root.searchText.length > 0 ? ListViewTransitions.move : null

            model: ScriptModel {
                values: root.cachedProcesses
                objectProp: "pid"
            }

            delegate: ProcessItem {
                required property var modelData
                required property int index

                width: processListView.width
                process: modelData
                isExpanded: root.expandedPid === (modelData?.pid ?? -1).toString()
                isSelected: root.keyboardNavigationActive && root.selectedIndex === index
                contextMenu: root.contextMenu
                onToggleExpand: {
                    const pidStr = (modelData?.pid ?? -1).toString();
                    root.expandedPid = (root.expandedPid === pidStr) ? "" : pidStr;
                }
                onClicked: {
                    root.keyboardNavigationActive = true;
                    root.selectedIndex = index;
                }
                onContextMenuRequested: (mouseX, mouseY) => {
                    if (root.contextMenu) {
                        root.contextMenu.processData = modelData;
                        root.contextMenu.parentFocusItem = root;
                        const globalPos = mapToItem(root.contextMenu.parent, mouseX, mouseY);
                        root.contextMenu.show(globalPos.x, globalPos.y, false);
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 300
                height: 100
                radius: Theme.cornerRadius
                color: "transparent"
                visible: root.cachedProcesses.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM

                    DankIcon {
                        name: root.searchText.length > 0 ? "search_off" : "hourglass_empty"
                        size: 32
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: I18n.tr("No matching processes", "empty state in process list")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.searchText.length > 0
                    }
                }
            }
        }
    }

    component SortableHeader: Item {
        id: headerItem

        property string text: ""
        property string sortKey: ""
        property string currentSort: ""
        property bool sortAscending: false
        property int alignment: Text.AlignHCenter

        signal clicked

        readonly property bool isActive: sortKey === currentSort

        height: 36

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Theme.cornerRadius
            color: headerItem.isActive ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : (headerMouseArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06) : "transparent")

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingS
            anchors.rightMargin: Theme.spacingS
            spacing: 4

            Item {
                Layout.fillWidth: headerItem.alignment === Text.AlignLeft
                visible: headerItem.alignment !== Text.AlignLeft
            }

            StyledText {
                text: headerItem.text
                font.pixelSize: Theme.fontSizeSmall
                font.family: SettingsData.monoFontFamily
                font.weight: headerItem.isActive ? Font.Bold : Font.Medium
                color: headerItem.isActive ? Theme.primary : Theme.surfaceText
                opacity: headerItem.isActive ? 1 : 0.8
            }

            DankIcon {
                name: headerItem.sortAscending ? "arrow_upward" : "arrow_downward"
                size: Theme.fontSizeSmall
                color: Theme.primary
                visible: headerItem.isActive
            }

            Item {
                Layout.fillWidth: headerItem.alignment !== Text.AlignLeft
                visible: headerItem.alignment === Text.AlignLeft
            }
        }

        MouseArea {
            id: headerMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: headerItem.clicked()
        }
    }

    component ProcessItem: Rectangle {
        id: processItemRoot

        property var process: null
        property bool isExpanded: false
        property bool isSelected: false
        property var contextMenu: null

        signal toggleExpand
        signal clicked
        signal contextMenuRequested(real mouseX, real mouseY)

        property bool isAnimating: false
        property var particles: []

        readonly property int processPid: process?.pid ?? 0
        readonly property real processCpu: process?.cpu ?? 0
        readonly property int processMemKB: process?.memoryKB ?? 0
        readonly property string processCmd: process?.command ?? ""
        readonly property string processFullCmd: process?.fullCommand ?? processCmd

        height: isExpanded ? (44 + expandedRect.height + Theme.spacingXS) : 44
        radius: Theme.cornerRadius
        color: {
            if (isSelected)
                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15);
            return processMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06) : "transparent";
        }
        border.color: {
            if (isSelected)
                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3);
            return processMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent";
        }
        border.width: 1
        clip: !isAnimating

        Behavior on height {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
            }
        }

        MouseArea {
            id: processMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    processItemRoot.contextMenuRequested(mouse.x, mouse.y);
                    return;
                }
                processItemRoot.clicked();
                processItemRoot.toggleExpand();
            }
        }

        Column {
            anchors.fill: parent
            spacing: 0
            opacity: processItemRoot.isAnimating ? 0 : 1
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }
            }

            Item {
                width: parent.width
                height: 44

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 200
                        height: parent.height

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: DgopService.getProcessIcon(processItemRoot.processCmd)
                                size: Theme.iconSize - 4
                                color: {
                                    if (processItemRoot.processCpu > 80)
                                        return Theme.error;
                                    if (processItemRoot.processCpu > 50)
                                        return Theme.warning;
                                    return Theme.surfaceText;
                                }
                                opacity: 0.8
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: processItemRoot.processCmd
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, 280)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: 100
                        height: parent.height

                        Rectangle {
                            anchors.centerIn: parent
                            width: 70
                            height: 24
                            radius: Theme.cornerRadius
                            color: {
                                if (processItemRoot.processCpu > 80)
                                    return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15);
                                if (processItemRoot.processCpu > 50)
                                    return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12);
                                return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06);
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: DgopService.formatCpuUsage(processItemRoot.processCpu)
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                font.weight: Font.Bold
                                color: {
                                    if (processItemRoot.processCpu > 80)
                                        return Theme.error;
                                    if (processItemRoot.processCpu > 50)
                                        return Theme.warning;
                                    return Theme.surfaceText;
                                }
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: 100
                        height: parent.height

                        Rectangle {
                            anchors.centerIn: parent
                            width: 70
                            height: 24
                            radius: Theme.cornerRadius
                            color: {
                                if (processItemRoot.processMemKB > 2 * 1024 * 1024)
                                    return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15);
                                if (processItemRoot.processMemKB > 1024 * 1024)
                                    return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12);
                                return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06);
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: DgopService.formatMemoryUsage(processItemRoot.processMemKB)
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                font.weight: Font.Bold
                                color: {
                                    if (processItemRoot.processMemKB > 2 * 1024 * 1024)
                                        return Theme.error;
                                    if (processItemRoot.processMemKB > 1024 * 1024)
                                        return Theme.warning;
                                    return Theme.surfaceText;
                                }
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: 80
                        height: parent.height

                        StyledText {
                            anchors.centerIn: parent
                            text: processItemRoot.processPid > 0 ? processItemRoot.processPid.toString() : ""
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            color: Theme.surfaceVariantText
                        }
                    }

                    Item {
                        Layout.preferredWidth: 40
                        height: parent.height

                        DankIcon {
                            anchors.centerIn: parent
                            name: processItemRoot.isExpanded ? "expand_less" : "expand_more"
                            size: Theme.iconSize - 4
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }

            Rectangle {
                id: expandedRect
                width: parent.width - Theme.spacingM * 2
                height: processItemRoot.isExpanded ? (expandedContent.implicitHeight + Theme.spacingS * 2) : 0
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius - 2
                color: Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, 0.6)
                clip: true
                visible: processItemRoot.isExpanded

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Column {
                    id: expandedContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingXS

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            id: cmdLabel
                            text: I18n.tr("Full Command:", "process detail label")
                            font.pixelSize: Theme.fontSizeSmall - 2
                            font.weight: Font.Bold
                            color: Theme.surfaceVariantText
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            id: cmdText
                            text: processItemRoot.processFullCmd
                            font.pixelSize: Theme.fontSizeSmall - 2
                            font.family: SettingsData.monoFontFamily
                            color: Theme.surfaceText
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            elide: Text.ElideMiddle
                        }

                        Rectangle {
                            id: killBtn
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            radius: Theme.cornerRadius - 2
                            color: killMouseArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15) : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "delete"
                                size: 14
                                color: killMouseArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                            }

                            MouseArea {
                                id: killMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    processItemRoot.startScatterAnimation();
                                }
                            }
                        }

                        Rectangle {
                            id: copyBtn
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            radius: Theme.cornerRadius - 2
                            color: copyMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "content_copy"
                                size: 14
                                color: copyMouseArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                            }

                            MouseArea {
                                id: copyMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["dms", "cl", "copy", processItemRoot.processFullCmd]);
                                }
                            }
                        }
                    }

                    Row {
                        spacing: Theme.spacingL

                        Row {
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "PPID:"
                                font.pixelSize: Theme.fontSizeSmall - 2
                                font.weight: Font.Bold
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: (processItemRoot.process?.ppid ?? 0) > 0 ? processItemRoot.process.ppid.toString() : "--"
                                font.pixelSize: Theme.fontSizeSmall - 2
                                font.family: SettingsData.monoFontFamily
                                color: Theme.surfaceText
                            }
                        }

                        Row {
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "Mem:"
                                font.pixelSize: Theme.fontSizeSmall - 2
                                font.weight: Font.Bold
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: (processItemRoot.process?.memoryPercent ?? 0).toFixed(1) + "%"
                                font.pixelSize: Theme.fontSizeSmall - 2
                                font.family: SettingsData.monoFontFamily
                                color: Theme.surfaceText
                            }
                        }
                    }
                }
            }
        }

        function startScatterAnimation() {
            isAnimating = true;

            var tempParticles = [];
            var numParticles = 80;
            var w = processItemRoot.width;
            var h = processItemRoot.height;

            // Get delete button coordinates to spawn a dense burst
            var bx = w / 2;
            var by = h / 2;
            if (typeof killBtn !== "undefined" && killBtn !== null) {
                var btnCenter = killBtn.mapToItem(processItemRoot, killBtn.width / 2, killBtn.height / 2);
                bx = btnCenter.x;
                by = btnCenter.y;
            }

            var color1 = Theme.error;
            var color2 = Theme.primary;
            var color3 = Theme.surfaceText;

            for (var i = 0; i < numParticles; i++) {
                var px, py, vx, vy, size;
                var pColor = Math.random() < 0.5 ? color1 : (Math.random() < 0.8 ? color2 : color3);

                // First half of particles explode from the button
                if (i < 30) {
                    px = bx;
                    py = by;
                    var angle = Math.random() * Math.PI * 2;
                    var speed = Math.random() * 5 + 2;
                    vx = Math.cos(angle) * speed;
                    vy = Math.sin(angle) * speed - 2.5; // push slightly upwards
                    size = Math.random() * 4 + 2;
                } else {
                    // Second half dissolves the entire process row
                    px = Math.random() * w;
                    py = Math.random() * h;
                    vx = (Math.random() - 0.5) * 3;
                    vy = (Math.random() - 0.5) * 2 - 1.5; // slight upward drift
                    size = Math.random() * 3 + 1.5;
                }

                tempParticles.push({
                    x: px,
                    y: py,
                    vx: vx,
                    vy: vy,
                    size: size,
                    alpha: 1.0,
                    color: pColor
                });
            }

            particles = tempParticles;
            particleTimer.start();
        }

        Timer {
            id: particleTimer
            interval: 16
            repeat: true
            onTriggered: {
                var active = false;
                var tempParticles = processItemRoot.particles;
                for (var i = 0; i < tempParticles.length; i++) {
                    var p = tempParticles[i];
                    if (p.alpha > 0) {
                        p.x += p.vx;
                        p.y += p.vy;

                        p.vy += 0.15; // gravity
                        p.vx *= 0.95; // drag
                        p.vy *= 0.95;

                        p.alpha -= 0.035; // fade
                        if (p.alpha < 0) p.alpha = 0;

                        active = true;
                    }
                }

                if (active) {
                    processItemRoot.particles = tempParticles;
                    particleCanvas.requestPaint();
                } else {
                    particleTimer.stop();
                    processItemRoot.isAnimating = false;
                    root.killedPids = root.killedPids.concat([processItemRoot.processPid]);
                    Quickshell.execDetached(["kill", processItemRoot.processPid.toString()]);
                    root.expandedPid = "";
                }
            }
        }

        Canvas {
            id: particleCanvas
            anchors.fill: parent
            visible: processItemRoot.isAnimating
            renderStrategy: Canvas.Cooperative

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);

                var tempParticles = processItemRoot.particles;
                if (!tempParticles || tempParticles.length === 0)
                    return;

                for (var i = 0; i < tempParticles.length; i++) {
                    var p = tempParticles[i];
                    if (p.alpha <= 0) continue;

                    ctx.fillStyle = Qt.rgba(p.color.r, p.color.g, p.color.b, p.alpha);
                    ctx.beginPath();
                    ctx.rect(p.x, p.y, p.size, p.size);
                    ctx.fill();
                }
            }
        }
    }
}
