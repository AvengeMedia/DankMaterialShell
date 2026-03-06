pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    FileBrowserModal {
        id: greeterWallpaperBrowserModal
        browserTitle: I18n.tr("Select greeter background image")
        browserIcon: "wallpaper"
        browserType: "wallpaper"
        showHiddenFiles: true
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif"]
        onFileSelected: path => {
            SettingsData.set("greeterWallpaperPath", path);
            close();
        }
    }

    property string greeterStatusText: ""
    property bool greeterStatusRunning: false
    property bool greeterSyncRunning: false
    property string greeterStatusStdout: ""
    property string greeterStatusStderr: ""
    property string greeterSyncStdout: ""
    property string greeterSyncStderr: ""
    property string greeterSudoProbeStderr: ""
    property string greeterTerminalFallbackStderr: ""
    property bool greeterTerminalFallbackFromPrecheck: false
    property var cachedFontFamilies: []
    property bool fontsEnumerated: false

    function runGreeterStatus() {
        greeterStatusText = "";
        greeterStatusStdout = "";
        greeterStatusStderr = "";
        greeterStatusRunning = true;
        greeterStatusProcess.running = true;
    }

    function runGreeterSync() {
        greeterSyncStdout = "";
        greeterSyncStderr = "";
        greeterSudoProbeStderr = "";
        greeterTerminalFallbackStderr = "";
        greeterTerminalFallbackFromPrecheck = false;
        greeterStatusText = I18n.tr("Checking whether sudo authentication is needed…");
        greeterSyncRunning = true;
        greeterSudoProbeProcess.running = true;
    }

    function launchGreeterSyncTerminalFallback(fromPrecheck, statusText) {
        greeterTerminalFallbackFromPrecheck = fromPrecheck;
        if (statusText && statusText !== "")
            greeterStatusText = statusText;
        greeterTerminalFallbackStderr = "";
        greeterTerminalFallbackProcess.running = true;
    }

    function enumerateFonts() {
        if (fontsEnumerated)
            return;
        var fonts = [];
        var availableFonts = Qt.fontFamilies();
        for (var i = 0; i < availableFonts.length; i++) {
            var fontName = availableFonts[i];
            if (fontName.startsWith("."))
                continue;
            fonts.push(fontName);
        }
        fonts.sort();
        fonts.unshift("Default");
        cachedFontFamilies = fonts;
        fontsEnumerated = true;
    }

    Component.onCompleted: Qt.callLater(enumerateFonts)

    Process {
        id: greeterStatusProcess
        command: ["dms", "greeter", "status"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.greeterStatusStdout = text || "";
            }
        }

        stderr: StdioCollector {
            onStreamFinished: root.greeterStatusStderr = text || ""
        }

        onExited: exitCode => {
            root.greeterStatusRunning = false;
            const out = (root.greeterStatusStdout || "").trim();
            const err = (root.greeterStatusStderr || "").trim();
            if (exitCode === 0) {
                root.greeterStatusText = out !== "" ? out : I18n.tr("No status output.");
                if (err !== "")
                    root.greeterStatusText = root.greeterStatusText + "\n\nstderr:\n" + err;
                return;
            }
            var failure = I18n.tr("Failed to run 'dms greeter status'. Ensure DMS is installed and dms is in PATH.", "greeter status error") + " (exit " + exitCode + ")";
            if (out !== "")
                failure = failure + "\n\n" + out;
            if (err !== "")
                failure = failure + "\n\nstderr:\n" + err;
            root.greeterStatusText = failure;
        }
    }

    Process {
        id: greeterSyncProcess
        command: ["dms", "greeter", "sync", "--yes"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.greeterSyncStdout = text || ""
        }

        stderr: StdioCollector {
            onStreamFinished: root.greeterSyncStderr = text || ""
        }

        onExited: exitCode => {
            root.greeterSyncRunning = false;
            const out = (root.greeterSyncStdout || "").trim();
            const err = (root.greeterSyncStderr || "").trim();
            if (exitCode === 0) {
                var success = I18n.tr("Sync completed successfully.");
                if (out !== "")
                    success = success + "\n\n" + out;
                if (err !== "")
                    success = success + "\n\nstderr:\n" + err;
                root.greeterStatusText = success;
            } else {
                var failure = I18n.tr("Sync failed in background mode. Trying terminal mode so you can authenticate interactively.") + " (exit " + exitCode + ")";
                if (out !== "")
                    failure = failure + "\n\n" + out;
                if (err !== "")
                    failure = failure + "\n\nstderr:\n" + err;
                root.greeterStatusText = failure;
                root.launchGreeterSyncTerminalFallback(false, "");
            }
        }
    }

    Process {
        id: greeterSudoProbeProcess
        command: ["sudo", "-n", "true"]
        running: false

        stderr: StdioCollector {
            onStreamFinished: root.greeterSudoProbeStderr = text || ""
        }

        onExited: exitCode => {
            const err = (root.greeterSudoProbeStderr || "").trim();
            if (exitCode === 0) {
                root.greeterStatusText = I18n.tr("Running greeter sync…");
                greeterSyncProcess.running = true;
                return;
            }

            var authNeeded = I18n.tr("Sync needs sudo authentication. Opening terminal so you can use password or fingerprint.");
            if (err !== "")
                authNeeded = authNeeded + "\n\n" + err;
            root.launchGreeterSyncTerminalFallback(true, authNeeded);
        }
    }

    Process {
        id: greeterTerminalFallbackProcess
        command: ["dms", "greeter", "sync", "--terminal", "--yes"]
        running: false

        stderr: StdioCollector {
            onStreamFinished: root.greeterTerminalFallbackStderr = text || ""
        }

        onExited: exitCode => {
            root.greeterSyncRunning = false;
            if (exitCode === 0) {
                var launched = root.greeterTerminalFallbackFromPrecheck ? I18n.tr("Terminal opened. Complete sync authentication there; it will close automatically when done.") : I18n.tr("Terminal fallback opened. Complete sync there; it will close automatically when done.");
                root.greeterStatusText = root.greeterStatusText ? root.greeterStatusText + "\n\n" + launched : launched;
                return;
            }
            var fallback = I18n.tr("Terminal fallback failed. Install one of the supported terminal emulators or run 'dms greeter sync' manually.") + " (exit " + exitCode + ")";
            const err = (root.greeterTerminalFallbackStderr || "").trim();
            if (err !== "")
                fallback = fallback + "\n\nstderr:\n" + err;
            root.greeterStatusText = root.greeterStatusText ? root.greeterStatusText + "\n\n" + fallback : fallback;
        }
    }

    readonly property var _lockDateFormatPresets: [
        {
            format: "",
            label: I18n.tr("System Default", "date format option")
        },
        {
            format: "ddd d",
            label: I18n.tr("Day Date", "date format option")
        },
        {
            format: "ddd MMM d",
            label: I18n.tr("Day Month Date", "date format option")
        },
        {
            format: "MMM d",
            label: I18n.tr("Month Date", "date format option")
        },
        {
            format: "M/d",
            label: I18n.tr("Numeric (M/D)", "date format option")
        },
        {
            format: "d/M",
            label: I18n.tr("Numeric (D/M)", "date format option")
        },
        {
            format: "ddd d MMM yyyy",
            label: I18n.tr("Full with Year", "date format option")
        },
        {
            format: "yyyy-MM-dd",
            label: I18n.tr("ISO Date", "date format option")
        },
        {
            format: "dddd, MMMM d",
            label: I18n.tr("Full Day & Month", "date format option")
        }
    ]
    readonly property var _wallpaperFillModes: ["Stretch", "Fit", "Fill", "Tile", "TileVertically", "TileHorizontally", "Pad"]

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "info"
                title: I18n.tr("Greeter Status")
                settingKey: "greeterStatus"

                StyledText {
                    text: I18n.tr("Check sync status on demand. Sync copies your theme, settings, PAM config, and wallpaper to the login screen in one step. Must run Sync to apply changes.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                Item {
                    width: 1
                    height: Theme.spacingS
                }

                Rectangle {
                    width: parent.width
                    height: Math.min(180, statusTextArea.implicitHeight + Theme.spacingM * 2)
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHighest

                    StyledText {
                        id: statusTextArea
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        text: root.greeterStatusRunning ? I18n.tr("Checking…", "greeter status loading") : (root.greeterStatusText || I18n.tr("Click Refresh to check status.", "greeter status placeholder"))
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: "monospace"
                        color: root.greeterStatusRunning ? Theme.surfaceVariantText : Theme.surfaceText
                        wrapMode: Text.Wrap
                        verticalAlignment: Text.AlignTop
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    topPadding: Theme.spacingM

                    DankButton {
                        text: I18n.tr("Refresh")
                        iconName: "refresh"
                        onClicked: root.runGreeterStatus()
                        enabled: !root.greeterStatusRunning
                    }

                    DankButton {
                        text: I18n.tr("Sync")
                        iconName: "sync"
                        onClicked: root.runGreeterSync()
                        enabled: !root.greeterSyncRunning
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "fingerprint"
                title: I18n.tr("Login Authentication")
                settingKey: "greeterAuth"

                StyledText {
                    text: I18n.tr("Enable fingerprint or security key for DMS Greeter. Run Sync to apply and configure PAM.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                SettingsToggleRow {
                    settingKey: "greeterEnableFprint"
                    tags: ["greeter", "fingerprint", "fprintd", "login", "auth"]
                    text: I18n.tr("Enable fingerprint at login")
                    description: {
                        if (!SettingsData.fprintdAvailable)
                            return I18n.tr("Not available — install fprintd and enroll fingerprints.");
                        return SettingsData.greeterEnableFprint ? I18n.tr("Run Sync to apply. Fingerprint-only login may not unlock GNOME Keyring.") : I18n.tr("Only off for DMS-managed PAM lines. If greetd includes system-auth/common-auth/password-auth with pam_fprintd, fingerprint still stays enabled.");
                    }
                    descriptionColor: SettingsData.fprintdAvailable ? Theme.surfaceVariantText : Theme.warning
                    checked: SettingsData.greeterEnableFprint
                    enabled: SettingsData.fprintdAvailable
                    onToggled: checked => SettingsData.set("greeterEnableFprint", checked)
                }

                SettingsToggleRow {
                    settingKey: "greeterEnableU2f"
                    tags: ["greeter", "u2f", "security", "key", "login", "auth"]
                    text: I18n.tr("Enable security key at login")
                    description: {
                        if (!SettingsData.u2fAvailable)
                            return I18n.tr("Not available — install pam_u2f and enroll keys.");
                        return SettingsData.greeterEnableU2f ? I18n.tr("Run Sync to apply.") : I18n.tr("Disabled.");
                    }
                    descriptionColor: SettingsData.u2fAvailable ? Theme.surfaceVariantText : Theme.warning
                    checked: SettingsData.greeterEnableU2f
                    enabled: SettingsData.u2fAvailable
                    onToggled: checked => SettingsData.set("greeterEnableU2f", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "palette"
                title: I18n.tr("Greeter Appearance")
                settingKey: "greeterAppearance"

                StyledText {
                    text: I18n.tr("Font")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    topPadding: Theme.spacingM
                }

                SettingsDropdownRow {
                    settingKey: "greeterFontFamily"
                    tags: ["greeter", "font", "typography"]
                    text: I18n.tr("Greeter font")
                    description: I18n.tr("Font used on the login screen")
                    options: root.fontsEnumerated ? root.cachedFontFamilies : ["Default"]
                    currentValue: (!SettingsData.greeterFontFamily || SettingsData.greeterFontFamily === "" || SettingsData.greeterFontFamily === Theme.defaultFontFamily) ? "Default" : (SettingsData.greeterFontFamily || "Default")
                    enableFuzzySearch: true
                    popupWidthOffset: 100
                    maxPopupHeight: 400
                    onValueChanged: value => {
                        if (value === "Default")
                            SettingsData.set("greeterFontFamily", "");
                        else
                            SettingsData.set("greeterFontFamily", value);
                    }
                }

                StyledText {
                    text: I18n.tr("Time format")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    topPadding: Theme.spacingM
                }

                SettingsToggleRow {
                    settingKey: "greeterUse24Hour"
                    tags: ["greeter", "time", "24hour"]
                    text: I18n.tr("24-hour clock")
                    description: I18n.tr("Greeter only — does not affect main clock")
                    checked: SettingsData.greeterUse24HourClock
                    onToggled: checked => SettingsData.set("greeterUse24HourClock", checked)
                }

                SettingsToggleRow {
                    settingKey: "greeterShowSeconds"
                    tags: ["greeter", "time", "seconds"]
                    text: I18n.tr("Show seconds")
                    checked: SettingsData.greeterShowSeconds
                    onToggled: checked => SettingsData.set("greeterShowSeconds", checked)
                }

                SettingsToggleRow {
                    settingKey: "greeterPadHours"
                    tags: ["greeter", "time", "12hour"]
                    text: I18n.tr("Pad hours (02:00 vs 2:00)")
                    visible: !SettingsData.greeterUse24HourClock
                    checked: SettingsData.greeterPadHours12Hour
                    onToggled: checked => SettingsData.set("greeterPadHours12Hour", checked)
                }

                StyledText {
                    text: I18n.tr("Date format on greeter")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    topPadding: Theme.spacingM
                }

                SettingsDropdownRow {
                    settingKey: "greeterLockDateFormat"
                    tags: ["greeter", "date", "format"]
                    text: I18n.tr("Date format")
                    description: I18n.tr("Greeter only — format for the date on the login screen")
                    options: root._lockDateFormatPresets.map(p => p.label)
                    currentValue: {
                        var current = (SettingsData.greeterLockDateFormat !== undefined && SettingsData.greeterLockDateFormat !== "") ? SettingsData.greeterLockDateFormat : SettingsData.lockDateFormat || "";
                        var match = root._lockDateFormatPresets.find(p => p.format === current);
                        return match ? match.label : (current ? I18n.tr("Custom: ") + current : root._lockDateFormatPresets[0].label);
                    }
                    onValueChanged: value => {
                        var preset = root._lockDateFormatPresets.find(p => p.label === value);
                        SettingsData.set("greeterLockDateFormat", preset ? preset.format : "");
                    }
                }

                StyledText {
                    text: I18n.tr("Background")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    topPadding: Theme.spacingM
                }

                StyledText {
                    text: I18n.tr("Use a custom image for the login screen, or leave empty to use your desktop wallpaper.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankTextField {
                        id: greeterWallpaperPathField
                        width: parent.width - browseGreeterWallpaperButton.width - Theme.spacingS
                        placeholderText: I18n.tr("Use desktop wallpaper")
                        text: SettingsData.greeterWallpaperPath
                        backgroundColor: Theme.surfaceContainerHighest
                        onTextChanged: {
                            if (text !== SettingsData.greeterWallpaperPath)
                                SettingsData.set("greeterWallpaperPath", text);
                        }
                    }

                    DankButton {
                        id: browseGreeterWallpaperButton
                        text: I18n.tr("Browse")
                        onClicked: greeterWallpaperBrowserModal.open()
                    }
                }

                SettingsDropdownRow {
                    settingKey: "greeterWallpaperFillMode"
                    tags: ["greeter", "wallpaper", "background", "fill"]
                    text: I18n.tr("Wallpaper fill mode")
                    description: I18n.tr("How the background image is scaled")
                    options: root._wallpaperFillModes.map(m => I18n.tr(m, "wallpaper fill mode"))
                    currentValue: {
                        var mode = (SettingsData.greeterWallpaperFillMode && SettingsData.greeterWallpaperFillMode !== "") ? SettingsData.greeterWallpaperFillMode : (SettingsData.wallpaperFillMode || "Fill");
                        var idx = root._wallpaperFillModes.indexOf(mode);
                        return idx >= 0 ? I18n.tr(root._wallpaperFillModes[idx], "wallpaper fill mode") : I18n.tr("Fill", "wallpaper fill mode");
                    }
                    onValueChanged: value => {
                        var idx = root._wallpaperFillModes.map(m => I18n.tr(m, "wallpaper fill mode")).indexOf(value);
                        if (idx >= 0)
                            SettingsData.set("greeterWallpaperFillMode", root._wallpaperFillModes[idx]);
                    }
                }

                StyledText {
                    text: I18n.tr("Layout and module positions on the greeter are synced from your shell (e.g. bar config). Run Sync to apply.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                    topPadding: Theme.spacingS
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "history"
                title: I18n.tr("Greeter Behavior")
                settingKey: "greeterBehavior"

                StyledText {
                    text: I18n.tr("Convenience options for the login screen. Sync to apply.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                SettingsToggleRow {
                    settingKey: "greeterRememberLastSession"
                    tags: ["greeter", "session", "remember", "login"]
                    text: I18n.tr("Remember last session")
                    description: I18n.tr("Pre-select the last used session on the greeter")
                    checked: SettingsData.greeterRememberLastSession
                    onToggled: checked => SettingsData.set("greeterRememberLastSession", checked)
                }

                SettingsToggleRow {
                    settingKey: "greeterRememberLastUser"
                    tags: ["greeter", "user", "remember", "login", "username"]
                    text: I18n.tr("Remember last user")
                    description: I18n.tr("Pre-fill the last successful username on the greeter")
                    checked: SettingsData.greeterRememberLastUser
                    onToggled: checked => SettingsData.set("greeterRememberLastUser", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "extension"
                title: I18n.tr("Dependencies & documentation")
                settingKey: "greeterDeps"

                StyledText {
                    text: I18n.tr("DMS greeter needs: greetd, dms-greeter. Fingerprint: fprintd, pam_fprintd. Security keys: pam_u2f. Add your user to the greeter group. Sync checks sudo first and opens a terminal when interactive authentication is required.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                StyledText {
                    text: I18n.tr("Installation and PAM setup: see the ") + "<a href=\"https://danklinux.com/docs/dankgreeter/installation\" style=\"text-decoration:none; color:" + Theme.primary + ";\">DankGreeter docs</a> " + I18n.tr("or run ") + "'dms greeter install'."
                    textFormat: Text.RichText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    linkColor: Theme.primary
                    width: parent.width
                    wrapMode: Text.Wrap
                    onLinkActivated: url => Qt.openUrlExternally(url)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                        acceptedButtons: Qt.NoButton
                        propagateComposedEvents: true
                    }
                }
            }
        }
    }
}
