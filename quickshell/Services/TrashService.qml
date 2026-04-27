pragma Singleton
pragma ComponentBehavior: Bound

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

    property int count: 0
    readonly property bool isEmpty: count === 0

    property var availableFileManagers: ["default"]
    property string defaultFileManagerLabel: "default (xdg-open)"

    signal emptyTrashConfirmRequested(int itemCount)

    FolderListModel {
        id: homeTrashModel
        folder: "file://" + root.trashFilesDir
        showDirs: true
        showFiles: true
        showHidden: true
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        nameFilters: ["*"]
    }

    Connections {
        target: homeTrashModel
        function onCountChanged() {
            root.refreshCount();
        }
    }

    Process {
        id: detectProc
        running: false
        command: ["sh", "-c", "for fm in nautilus thunar dolphin nemo caja pcmanfm pcmanfm-qt krusader; do command -v $fm >/dev/null 2>&1 && echo $fm; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const detected = (text || "").split("\n").map(s => s.trim()).filter(s => s.length > 0);
                root.availableFileManagers = ["default"].concat(detected).concat(["custom"]);
            }
        }
    }

    Component.onCompleted: {
        detectProc.running = true;
        refreshCount();
    }

    function refreshCount() {
        Proc.runCommand("trash-count", ["dms", "trash", "count"], (output, exitCode) => {
            if (exitCode !== 0) {
                root.count = homeTrashModel.count;
                return;
            }
            const n = parseInt((output || "").trim(), 10);
            root.count = isNaN(n) ? homeTrashModel.count : n;
        });
    }

    function trashPath(path, callback) {
        if (!path) {
            if (callback)
                callback(false, "empty path");
            return;
        }
        Proc.runCommand(null, ["dms", "trash", "put", path], (output, exitCode) => {
            const ok = exitCode === 0;
            if (!ok)
                ToastService.showError(I18n.tr("Failed to move to trash"), path);
            refreshCount();
            if (callback)
                callback(ok, output);
        });
    }

    function openTrash() {
        const choice = SettingsData.dockTrashFileManager || "default";
        switch (choice) {
        case "default":
            Quickshell.execDetached(["xdg-open", "trash:///"]);
            return;
        case "custom":
            openCustom();
            return;
        }
        if (availableFileManagers.indexOf(choice) < 0) {
            ToastService.showInfo(I18n.tr("Cannot open trash: '%1' is not installed").arg(choice), I18n.tr("Pick a different file manager in Settings → Dock → Trash."));
            return;
        }
        Quickshell.execDetached([choice, "trash:///"]);
    }

    function openCustom() {
        const cmd = (SettingsData.dockTrashCustomCommand || "").trim();
        if (!cmd) {
            ToastService.showInfo(I18n.tr("Cannot open trash: no custom command set"), I18n.tr("Configure one in Settings → Dock → Trash."));
            return;
        }
        Proc.runCommand(null, ["sh", "-c", cmd], (output, exitCode) => {
            if (exitCode !== 0) {
                ToastService.showError(I18n.tr("Trash command failed (exit %1)").arg(exitCode), I18n.tr("Check your custom command in Settings → Dock → Trash."));
            }
        }, 0, Proc.noTimeout);
    }

    function requestEmptyTrash() {
        if (isEmpty)
            return;
        emptyTrashConfirmRequested(count);
    }

    function emptyTrash() {
        Proc.runCommand("trash-empty", ["dms", "trash", "empty"], (output, exitCode) => {
            if (exitCode !== 0)
                ToastService.showError(I18n.tr("Failed to empty trash"), output || "");
            refreshCount();
        });
    }
}
