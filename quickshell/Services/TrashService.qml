pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string _homeDir: Quickshell.env("HOME") || ""
    readonly property string _xdgDataHome: Quickshell.env("XDG_DATA_HOME") || (_homeDir + "/.local/share")
    readonly property string trashFilesDir: _xdgDataHome + "/Trash/files"

    readonly property int count: trashModel.count
    readonly property bool isEmpty: count === 0

    property var availableFileManagers: []

    signal openBuiltinTrashRequested
    signal emptyTrashConfirmRequested(int itemCount)

    FolderListModel {
        id: trashModel
        folder: "file://" + root.trashFilesDir
        showDirs: true
        showFiles: true
        showHidden: true
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        nameFilters: ["*"]
    }

    Process {
        id: detectProc
        running: false
        command: ["sh", "-c", "for fm in nautilus thunar dolphin; do command -v $fm >/dev/null 2>&1 && echo $fm; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const detected = (text || "").split("\n").map(s => s.trim()).filter(s => s.length > 0);
                detected.push("builtin");
                root.availableFileManagers = detected;
            }
        }
    }

    Component.onCompleted: {
        detectProc.running = true;
    }

    function _resolveBackend() {
        const choice = SettingsData.dockTrashFileManager || "nautilus";
        if (choice === "builtin")
            return "builtin";
        if (availableFileManagers.indexOf(choice) >= 0)
            return choice;
        return "builtin";
    }

    function openTrash() {
        const backend = _resolveBackend();
        switch (backend) {
        case "nautilus":
            Quickshell.execDetached(["nautilus", "trash:///"]);
            break;
        case "thunar":
            Quickshell.execDetached(["thunar", "trash:///"]);
            break;
        case "dolphin":
            Quickshell.execDetached(["dolphin", "trash:///"]);
            break;
        case "builtin":
        default:
            openBuiltinTrashRequested();
            break;
        }
    }

    function requestEmptyTrash() {
        if (isEmpty)
            return;
        emptyTrashConfirmRequested(count);
    }

    function emptyTrash() {
        Quickshell.execDetached(["gio", "trash", "--empty"]);
    }
}
