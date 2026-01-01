pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var settingsRoot: null

    function detectQtTools() {
        qtToolsDetectionProcess.running = true;
    }

    function detectFprintd() {
        fprintdDetectionProcess.running = true;
    }

    function checkPluginSettings() {
        pluginSettingsCheckProcess.running = true;
    }

    property var qtToolsDetectionProcess: Process {
        command: ["sh", "-c", "echo -n 'qt5ct:'; command -v qt5ct >/dev/null && echo 'true' || echo 'false'; echo -n 'qt6ct:'; command -v qt6ct >/dev/null && echo 'true' || echo 'false'; echo -n 'gtk:'; (command -v gsettings >/dev/null || command -v dconf >/dev/null) && echo 'true' || echo 'false'"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (!settingsRoot)
                    return;
                if (text && text.trim()) {
                    var lines = text.trim().split('\n');
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i];
                        if (line.startsWith('qt5ct:')) {
                            settingsRoot.qt5ctAvailable = line.split(':')[1] === 'true';
                        } else if (line.startsWith('qt6ct:')) {
                            settingsRoot.qt6ctAvailable = line.split(':')[1] === 'true';
                        } else if (line.startsWith('gtk:')) {
                            settingsRoot.gtkAvailable = line.split(':')[1] === 'true';
                        }
                    }
                }
            }
        }
    }

    property var fprintdDetectionProcess: Process {
        command: ["sh", "-c", "command -v fprintd-list >/dev/null 2>&1"]
        running: false
        onExited: function (exitCode) {
            if (!settingsRoot)
                return;
            settingsRoot.fprintdAvailable = (exitCode === 0);
        }
    }

    property var pluginSettingsCheckProcess: Process {
        command: ["test", "-f", settingsRoot?.pluginSettingsPath || ""]
        running: false

        onExited: function (exitCode) {
            if (!settingsRoot)
                return;
            settingsRoot.pluginSettingsFileExists = (exitCode === 0);
        }
    }
}
