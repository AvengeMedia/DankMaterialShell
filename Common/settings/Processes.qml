pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var settingsRoot: null

    function detectIcons() {
        systemDefaultDetectionProcess.running = true
    }

    function detectQtTools() {
        qtToolsDetectionProcess.running = true
    }

    function detectFprintd() {
        fprintdDetectionProcess.running = true
    }

    function checkPluginSettings() {
        pluginSettingsCheckProcess.running = true
    }

    function checkDefaultSettings() {
        defaultSettingsCheckProcess.running = true
    }

    property var systemDefaultDetectionProcess: Process {
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | sed \"s/'//g\" || echo ''"]
        running: false
        onExited: function(exitCode) {
            if (!settingsRoot) return;
            if (exitCode === 0 && stdout && stdout.length > 0) {
                settingsRoot.systemDefaultIconTheme = stdout.trim();
            } else {
                settingsRoot.systemDefaultIconTheme = "";
            }
            iconThemeDetectionProcess.running = true;
        }
    }

    property var iconThemeDetectionProcess: Process {

        command: ["sh", "-c", "find /usr/share/icons ~/.local/share/icons ~/.icons -maxdepth 1 -type d 2>/dev/null | sed 's|.*/||' | grep -v '^icons$' | sort -u"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (!settingsRoot) return
                var detectedThemes = ["System Default"]
                if (text && text.trim()) {
                    var themes = text.trim().split('\n')
                    for (var i = 0; i < themes.length; i++) {
                        var theme = themes[i].trim()
                        if (theme && theme !== "" && theme !== "default" && theme !== "hicolor" && theme !== "locolor") {
                            detectedThemes.push(theme)
                        }
                    }
                }
                settingsRoot.availableIconThemes = detectedThemes
            }
        }
    }

    property var qtToolsDetectionProcess: Process {
        command: ["sh", "-c", "echo -n 'qt5ct:'; command -v qt5ct >/dev/null && echo 'true' || echo 'false'; echo -n 'qt6ct:'; command -v qt6ct >/dev/null && echo 'true' || echo 'false'; echo -n 'gtk:'; (command -v gsettings >/dev/null || command -v dconf >/dev/null) && echo 'true' || echo 'false'"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (!settingsRoot) return;
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

    property var defaultSettingsCheckProcess: Process {
        command: ["sh", "-c", "CONFIG_DIR=\"" + (settingsRoot?._configDir || "") + "/DankMaterialShell\"; if [ -f \"$CONFIG_DIR/default-settings.json\" ] && [ ! -f \"$CONFIG_DIR/settings.json\" ]; then cp --no-preserve=mode \"$CONFIG_DIR/default-settings.json\" \"$CONFIG_DIR/settings.json\" && echo 'copied'; else echo 'not_found'; fi"]
        running: false
        onExited: function(exitCode) {
            if (!settingsRoot) return;
            if (exitCode === 0) {
                console.info("Copied default-settings.json to settings.json");
                if (settingsRoot.settingsFile) {
                    settingsRoot.settingsFile.reload();
                }
            } else {
                if (typeof ThemeApplier !== "undefined") {
                    ThemeApplier.applyStoredTheme(settingsRoot);
                }
            }
        }
    }

    property var fprintdDetectionProcess: Process {
        command: ["sh", "-c", "command -v fprintd-list >/dev/null 2>&1"]
        running: false
        onExited: function(exitCode) {
            if (!settingsRoot) return;
            settingsRoot.fprintdAvailable = (exitCode === 0);
        }
    }

    property var pluginSettingsCheckProcess: Process {
        command: ["test", "-f", settingsRoot?.pluginSettingsPath || ""]
        running: false

        onExited: function(exitCode) {
            if (!settingsRoot) return;
            settingsRoot.pluginSettingsFileExists = (exitCode === 0);
        }
    }
}
