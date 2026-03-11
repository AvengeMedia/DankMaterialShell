pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var settingsRoot: null

    function envFlag(name) {
        const value = (Quickshell.env(name) || "").trim().toLowerCase();
        if (value === "1" || value === "true" || value === "yes" || value === "on")
            return true;
        if (value === "0" || value === "false" || value === "no" || value === "off")
            return false;
        return null;
    }

    readonly property var forcedFprintAvailable: envFlag("DMS_FORCE_FPRINT_AVAILABLE")
    readonly property var forcedU2fAvailable: envFlag("DMS_FORCE_U2F_AVAILABLE")

    function detectQtTools() {
        qtToolsDetectionProcess.running = true;
    }

    function detectFprintd() {
        if (!settingsRoot)
            return;
        if (forcedFprintAvailable !== null) {
            settingsRoot.fprintdAvailable = forcedFprintAvailable;
            return;
        }
        fprintdDetectionProcess.running = true;
    }

    function detectU2f() {
        if (!settingsRoot)
            return;
        if (forcedU2fAvailable !== null) {
            settingsRoot.u2fAvailable = forcedU2fAvailable;
            return;
        }
        u2fDetectionProcess.running = true;
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
        command: ["sh", "-c", "command -v fprintd-list >/dev/null 2>&1 && fprintd-list \"${USER:-$(id -un)}\" >/dev/null 2>&1"]
        running: false
        onExited: function (exitCode) {
            if (!settingsRoot)
                return;
            settingsRoot.fprintdAvailable = (exitCode === 0);
        }
    }

    property var u2fDetectionProcess: Process {
        command: ["sh", "-c", "(test -f /usr/lib/security/pam_u2f.so || test -f /usr/lib64/security/pam_u2f.so) && (test -f /etc/pam.d/dankshell-u2f || test -f \"$HOME/.config/Yubico/u2f_keys\")"]
        running: false
        onExited: function (exitCode) {
            if (!settingsRoot)
                return;
            settingsRoot.u2fAvailable = (exitCode === 0);
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
