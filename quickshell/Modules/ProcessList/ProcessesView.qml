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
    }

    onShouldUpdateChanged: {
        if (shouldUpdate)
            cachedProcesses = filteredProcesses;
    }

    readonly property var filteredProcesses: {
        if (!DgopService.allProcesses || DgopService.allProcesses.length === 0)
            return [];

        let procs = DgopService.allProcesses.slice();

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
}
