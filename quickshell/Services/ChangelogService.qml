pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string currentVersion: "1.4"
    readonly property bool changelogEnabled: true

    readonly property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/DankMaterialShell"
    readonly property string changelogMarkerPath: configDir + "/.changelog-" + currentVersion

    property bool checkComplete: false
    property bool changelogDismissed: false

    readonly property bool shouldShowChangelog: {
        if (!checkComplete)
            return false;
        if (!changelogEnabled)
            return false;
        if (changelogDismissed)
            return false;
        if (typeof FirstLaunchService !== "undefined" && FirstLaunchService.isFirstLaunch)
            return false;
        return true;
    }

    signal changelogRequested
    signal changelogCompleted

    Component.onCompleted: {
        if (!changelogEnabled)
            return;
        if (FirstLaunchService.checkComplete)
            handleFirstLaunchResult();
    }

    function handleFirstLaunchResult() {
        if (FirstLaunchService.isFirstLaunch) {
            checkComplete = true;
            changelogDismissed = true;
            touchMarkerProcess.running = true;
        } else {
            changelogCheckProcess.running = true;
        }
    }

    Connections {
        target: FirstLaunchService

        function onCheckCompleteChanged() {
            if (FirstLaunchService.checkComplete && root.changelogEnabled && !root.checkComplete)
                root.handleFirstLaunchResult();
        }
    }

    function showChangelog() {
        changelogRequested();
    }

    function dismissChangelog() {
        changelogDismissed = true;
        touchMarkerProcess.running = true;
        changelogCompleted();
    }

    Process {
        id: changelogCheckProcess

        command: ["sh", "-c", "[ -f '" + changelogMarkerPath + "' ] && echo 'seen' || echo 'show'"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                const result = data.trim();
                root.checkComplete = true;

                switch (result) {
                case "seen":
                    root.changelogDismissed = true;
                    break;
                case "show":
                    root.changelogRequested();
                    break;
                }
            }
        }
    }

    Process {
        id: touchMarkerProcess

        command: ["sh", "-c", "mkdir -p '" + configDir + "' && touch '" + changelogMarkerPath + "'"]
        running: false

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("ChangelogService: Failed to create changelog marker");
            }
        }
    }
}
