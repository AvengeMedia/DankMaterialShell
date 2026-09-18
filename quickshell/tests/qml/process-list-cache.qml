import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.ProcessList
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    TestCase {
        id: input
        when: false
        name: "process-list-cache"
    }

    PanelWindow {
        color: "transparent"
        implicitWidth: 600
        implicitHeight: 500
        anchors {
            top: true
            left: true
        }

        ProcessesView {
            id: view
            anchors.fill: parent
            active: false
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    function check(value, message) {
        if (!value)
            throw new Error(message);
    }

    function process(pid, command) {
        return {
            pid: pid,
            command: command,
            fullCommand: command,
            username: UserInfoService.username,
            cpu: 1,
            memoryKB: 1024
        };
    }

    function find(item, predicate) {
        if (predicate(item))
            return item;
        for (const child of item.children ?? []) {
            const found = find(child, predicate);
            if (found)
                return found;
        }
        return null;
    }

    readonly property var emptyLabel: find(view, c => c.text === "No matching processes" || c.text === "Loading...")

    Timer {
        interval: 500
        running: true
        onTriggered: {
            try {
                root.check(root.emptyLabel && root.emptyLabel.text === "Loading..." && root.emptyLabel.visible, "first open with no data says loading");

                DgopService.allProcesses = [root.process(1, "init"), root.process(2, "shell")];
                view.active = true;
                input.wait(20);
                root.check(view.cachedProcesses.length === 2 && !root.emptyLabel.visible, "rows appear once data and activity meet");

                view.active = false;
                input.wait(20);
                root.check(view.cachedProcesses.length === 2 && !root.emptyLabel.visible, "closing keeps the last rows for the close animation");

                DgopService.allProcesses = [];
                input.wait(20);
                root.check(view.cachedProcesses.length === 2 && !root.emptyLabel.visible, "releasing the data source keeps the last rows");

                view.active = true;
                input.wait(20);
                root.check(view.cachedProcesses.length === 2 && !root.emptyLabel.visible, "reopening before the first sample keeps the last rows");

                DgopService.allProcesses = [root.process(3, "editor")];
                input.wait(20);
                root.check(view.cachedProcesses.length === 1 && view.cachedProcesses[0].pid === 3, "first sample after reopen replaces the rows");

                view.searchText = "nomatch";
                input.wait(20);
                root.check(view.cachedProcesses.length === 0 && root.emptyLabel.visible && root.emptyLabel.text === "No matching processes", "a search with no hits shows the empty state");

                console.log("FIXTURE_PASS process list keeps rows across close, release and reopen; empty state only for real misses");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
