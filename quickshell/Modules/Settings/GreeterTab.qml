pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property bool greeterFprintToggleAvailable: SettingsData.greeterFingerprintCanEnable || SettingsData.greeterEnableFprint
    readonly property bool greeterU2fToggleAvailable: SettingsData.greeterU2fCanEnable || SettingsData.greeterEnableU2f

    function greeterFingerprintDescription() {
        if (SettingsData.greeterPamExternallyManaged)
            return I18n.tr("Managed by the primary PAM source", "factor managed by PAM source status");
        if (SettingsData.greeterFingerprintSource === "pam")
            return I18n.tr("PAM already provides fingerprint auth. Enable this to show it at login.", "greeter fingerprint login setting");

        switch (SettingsData.greeterFingerprintReason) {
        case "ready":
            return I18n.tr("Applies on the next greeter sync", "greeter auth setting description");
        case "missing_enrollment":
            return I18n.tr("Fingerprint reader detected, but no prints are enrolled yet. You can enable this now and run Sync later.", "greeter fingerprint login setting");
        case "missing_reader":
            return I18n.tr("No fingerprint reader detected", "fingerprint setting status");
        case "missing_pam_support":
            return I18n.tr("Not available — install fprintd and pam_fprintd, or configure greetd PAM.", "greeter fingerprint login setting");
        default:
            return I18n.tr("Fingerprint availability could not be confirmed", "fingerprint setting status");
        }
    }

    function greeterU2fDescription() {
        if (SettingsData.greeterPamExternallyManaged)
            return I18n.tr("Managed by the primary PAM source", "factor managed by PAM source status");
        if (SettingsData.greeterU2fSource === "pam")
            return I18n.tr("PAM already provides security-key auth. Enable this to show it at login.", "greeter security key login setting");

        switch (SettingsData.greeterU2fReason) {
        case "ready":
            return I18n.tr("Applies on the next greeter sync", "greeter auth setting description");
        case "missing_key_registration":
            return I18n.tr("Security-key support was detected, but no registered key was found yet. You can enable this now and register one later.", "security key setting status");
        case "missing_pam_support":
            return I18n.tr("Not available — install or configure pam_u2f, or configure greetd PAM.", "greeter security key login setting");
        default:
            return I18n.tr("Security-key availability could not be confirmed", "security key setting status");
        }
    }

    function refreshAuthDetection() {
        SettingsData.refreshAuthAvailability();
    }

    onVisibleChanged: {
        if (visible)
            refreshAuthDetection();
    }

    ConfirmModal {
        id: greeterActionConfirm
    }

    property string greeterStatusText: ""
    property bool greeterStatusRunning: false
    property bool greeterSyncRunning: false
    property bool greeterInstallActionRunning: false
    property string greeterStatusStdout: ""
    property string greeterStatusStderr: ""
    property string greeterSyncStdout: ""
    property string greeterSyncStderr: ""
    property string greeterSudoProbeStderr: ""
    property string greeterTerminalFallbackStderr: ""
    property bool greeterTerminalFallbackFromPrecheck: false
    property bool greeterBinaryExists: false
    property bool greeterEnabled: false
    property bool embeddedGreeterConfigured: false
    readonly property bool embeddedGreeterOnly: embeddedGreeterConfigured && !greeterBinaryExists
    readonly property string greeterAction: greeterBinaryExists && !greeterEnabled ? "activate" : ""
    readonly property bool greeterActionAvailable: greeterAction !== ""

    readonly property string greeterActionLabel: greeterAction === "activate" ? I18n.tr("Activate") : ""
    readonly property string greeterActionIcon: greeterAction === "activate" ? "login" : ""
    readonly property var greeterActionCommand: greeterAction === "activate" ? ["dms-greeter", "enable", "--terminal"] : []

    function checkGreeterInstallState() {
        greetdEnabledCheckProcess.running = true;
        greeterBinaryCheckProcess.running = true;
        embeddedGreeterCheckProcess.running = true;
    }

    function runGreeterStatus() {
        greeterStatusText = "";
        greeterStatusStdout = "";
        greeterStatusStderr = "";
        greeterStatusRunning = true;
        greeterStatusProcess.running = true;
    }

    function runGreeterInstallAction() {
        greeterStatusText = I18n.tr("Opening terminal: ") + root.greeterActionLabel + "...";
        greeterInstallActionRunning = true;
        greeterInstallActionProcess.running = true;
    }

    function promptGreeterActionConfirm() {
        if (!root.greeterActionAvailable)
            return;

        greeterActionConfirm.showWithOptions({
            "title": I18n.tr("Activate Greeter", "greeter action confirmation"),
            "message": I18n.tr("Activate the DMS greeter? A terminal will open for sudo authentication. Run Sync after activation to apply your settings."),
            "confirmText": I18n.tr("Activate"),
            "cancelText": I18n.tr("Cancel"),
            "confirmColor": Theme.primary,
            "onConfirm": () => root.runGreeterInstallAction(),
            "onCancel": () => {}
        });
    }

    function runGreeterSync() {
        if (!greeterBinaryExists)
            return;
        greeterSyncStdout = "";
        greeterSyncStderr = "";
        greeterSudoProbeStderr = "";
        greeterTerminalFallbackStderr = "";
        greeterTerminalFallbackFromPrecheck = false;
        greeterStatusText = I18n.tr("Checking whether sudo authentication is needed...");
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

    Component.onCompleted: {
        refreshAuthDetection();
        Qt.callLater(checkGreeterInstallState);
    }

    Process {
        id: greetdEnabledCheckProcess
        command: ["systemctl", "is-enabled", "greetd"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.greeterEnabled = text.trim() === "enabled"
        }
    }

    Process {
        id: greeterBinaryCheckProcess
        command: ["sh", "-c", "command -v dms-greeter >/dev/null 2>&1"]
        running: false

        onExited: exitCode => {
            root.greeterBinaryExists = (exitCode === 0);
        }
    }

    Process {
        id: embeddedGreeterCheckProcess
        // archinstall's DMS profile points greetd at this launcher inside the packaged DMS tree
        command: ["sh", "-c", "grep -q 'Modules/Greetd/assets/dms-greeter' /etc/greetd/config.toml 2>/dev/null"]
        running: false

        onExited: exitCode => {
            root.embeddedGreeterConfigured = (exitCode === 0);
        }
    }

    Process {
        id: greeterStatusProcess
        command: ["dms-greeter", "status"]
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
            var failure = I18n.tr("Failed to run 'dms-greeter status'. Ensure the dms-greeter package is installed.", "greeter status error") + " (exit " + exitCode + ")";
            if (out !== "")
                failure = failure + "\n\n" + out;
            if (err !== "")
                failure = failure + "\n\nstderr:\n" + err;
            root.greeterStatusText = failure;
        }
    }

    Process {
        id: greeterSyncProcess
        command: ["dms-greeter", "sync", "--yes"]
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
            root.checkGreeterInstallState();
            if (exitCode !== 0) {
                var failure = I18n.tr("Sync failed in background mode. Trying terminal mode so you can authenticate interactively.") + " (exit " + exitCode + ")";
                if (out !== "")
                    failure = failure + "\n\n" + out;
                if (err !== "")
                    failure = failure + "\n\nstderr:\n" + err;
                root.greeterStatusText = failure;
                root.launchGreeterSyncTerminalFallback(false, "");
                return;
            }
            var success = I18n.tr("Sync completed successfully.");
            if (out !== "")
                success = success + "\n\n" + out;
            if (err !== "")
                success = success + "\n\nstderr:\n" + err;
            root.greeterStatusText = success;
            SettingsData.clearGreeterSyncPending();
            ToastService.showInfo(I18n.tr("Greeter sync complete"));
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
                root.greeterStatusText = I18n.tr("Running greeter sync...");
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
        command: ["dms-greeter", "sync", "--terminal", "--yes"]
        running: false

        stderr: StdioCollector {
            onStreamFinished: root.greeterTerminalFallbackStderr = text || ""
        }

        onExited: exitCode => {
            root.greeterSyncRunning = false;
            if (exitCode === 0) {
                var launched = root.greeterTerminalFallbackFromPrecheck ? I18n.tr("Terminal opened. Complete authentication there; it will close automatically when done.") : I18n.tr("Terminal fallback opened. Complete authentication there; it will close automatically when done.");
                root.greeterStatusText = root.greeterStatusText ? root.greeterStatusText + "\n\n" + launched : launched;
                SettingsData.clearGreeterSyncPending();
                return;
            }
            var fallback = I18n.tr("Terminal fallback failed. Install one of the supported terminal emulators or run 'dms-greeter sync' manually.") + " (exit " + exitCode + ")";
            const err = (root.greeterTerminalFallbackStderr || "").trim();
            if (err !== "")
                fallback = fallback + "\n\nstderr:\n" + err;
            root.greeterStatusText = root.greeterStatusText ? root.greeterStatusText + "\n\n" + fallback : fallback;
        }
    }

    Process {
        id: greeterInstallActionProcess
        command: root.greeterActionCommand
        running: false

        onExited: exitCode => {
            root.greeterInstallActionRunning = false;
            root.checkGreeterInstallState();
            if (exitCode !== 0) {
                root.greeterStatusText = I18n.tr("Action failed or terminal was closed.") + " (exit " + exitCode + ")";
                return;
            }
            root.greeterStatusText = I18n.tr("Greeter activated. greetd is now enabled.");
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

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL + (syncPendingPill.shown ? syncPendingPill.height + Theme.spacingL : 0)
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
                title: I18n.tr("Status")
                settingKey: "greeterStatus"

                StyledText {
                    text: I18n.tr("Sync applies your theme and settings to the login screen. Shared users should run dms-greeter sync --profile instead of a primary user sync.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignLeft
                }

                Item {
                    width: 1
                    height: Theme.spacingS
                }

                Rectangle {
                    width: parent.width
                    height: Math.min(180, statusTextArea.implicitHeight + Theme.spacingM * 2)
                    radius: Theme.cornerRadius
                    color: Theme.floatingWindowFieldColor
                    border.color: Theme.outlineMedium
                    border.width: Theme.layerOutlineWidth

                    StyledText {
                        id: statusTextArea
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        text: {
                            if (root.greeterStatusRunning)
                                return I18n.tr("Checking...", "greeter status loading");
                            if (root.greeterStatusText !== "")
                                return root.greeterStatusText;
                            if (root.embeddedGreeterOnly)
                                return I18n.tr("The greeter bundled with DMS is active (archinstall setup). It keeps working as is, but syncing theme and settings needs the standalone greeter. Install greetd-dms-greeter-bin from the AUR, then run Sync to migrate the login screen.", "embedded greeter status");
                            if (!root.greeterBinaryExists && root.greeterEnabled)
                                return I18n.tr("dms-greeter is not installed. Install the dms-greeter package to manage the greeter.", "greeter status placeholder");
                            return I18n.tr("Click Refresh to check status.", "greeter status placeholder");
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: "monospace"
                        color: root.greeterStatusRunning ? Theme.surfaceVariantText : Theme.surfaceText
                        wrapMode: Text.Wrap
                        verticalAlignment: Text.AlignTop
                    }
                }

                Item {
                    width: 1
                    height: Theme.spacingM
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankButton {
                        visible: root.greeterActionAvailable
                        text: root.greeterActionLabel
                        iconName: root.greeterActionIcon
                        horizontalPadding: Theme.spacingL
                        onClicked: root.promptGreeterActionConfirm()
                        enabled: !root.greeterInstallActionRunning && !root.greeterSyncRunning
                    }

                    DankButton {
                        text: I18n.tr("Refresh")
                        iconName: "refresh"
                        horizontalPadding: Theme.spacingL
                        onClicked: root.runGreeterStatus()
                        enabled: !root.greeterStatusRunning
                    }

                    DankButton {
                        text: I18n.tr("Sync")
                        iconName: "sync"
                        horizontalPadding: Theme.spacingL
                        onClicked: root.runGreeterSync()
                        enabled: root.greeterBinaryExists && !root.greeterSyncRunning && !root.greeterInstallActionRunning
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "fingerprint"
                title: I18n.tr("Authentication")
                settingKey: "greeterAuth"

                StyledText {
                    text: I18n.tr("Enable fingerprint or security key for DMS Greeter")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignLeft
                }

                SettingsToggleRow {
                    settingKey: "greeterPamExternallyManaged"
                    tags: ["greeter", "pam", "managed", "external", "greetd", "auth"]
                    text: I18n.tr("Use system PAM authentication", "system PAM policy toggle")
                    description: I18n.tr("DMS removes its managed block from /etc/pam.d/greetd and stops write services", "greeter system PAM toggle description")
                    checked: SettingsData.greeterPamExternallyManaged
                    onToggled: checked => SettingsData.set("greeterPamExternallyManaged", checked)
                }

                SettingsToggleRow {
                    settingKey: "greeterEnableFprint"
                    tags: ["greeter", "fingerprint", "fprintd", "login", "auth"]
                    text: I18n.tr("Enable fingerprint at login")
                    description: root.greeterFingerprintDescription()
                    descriptionColor: (SettingsData.greeterFingerprintReason === "ready" || SettingsData.greeterFingerprintReason === "configured_externally") ? Theme.surfaceVariantText : Theme.warning
                    checked: SettingsData.greeterEnableFprint
                    enabled: root.greeterFprintToggleAvailable && !SettingsData.greeterPamExternallyManaged
                    onToggled: checked => SettingsData.set("greeterEnableFprint", checked)
                }

                SettingsToggleRow {
                    settingKey: "greeterEnableU2f"
                    tags: ["greeter", "u2f", "security", "key", "login", "auth"]
                    text: I18n.tr("Enable security key at login")
                    description: root.greeterU2fDescription()
                    descriptionColor: (SettingsData.greeterU2fReason === "ready" || SettingsData.greeterU2fReason === "configured_externally") ? Theme.surfaceVariantText : Theme.warning
                    checked: SettingsData.greeterEnableU2f
                    enabled: root.greeterU2fToggleAvailable && !SettingsData.greeterPamExternallyManaged
                    onToggled: checked => SettingsData.set("greeterEnableU2f", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "palette"
                title: I18n.tr("Appearance")
                settingKey: "greeterAppearance"

                StyledText {
                    text: I18n.tr("Font")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    topPadding: Theme.spacingM
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                }

                SettingsFontDropdownRow {
                    settingKey: "greeterFontFamily"
                    tags: ["greeter", "font", "typography"]
                    text: I18n.tr("Greeter font")
                    description: I18n.tr("Font used on the login screen")
                    currentFont: SettingsData.greeterFontFamily || ""
                    onFontSelected: family => SettingsData.set("greeterFontFamily", family)
                }

                SettingsToggleRow {
                    settingKey: "greeterShowWeather"
                    tags: ["greeter", "weather", "temperature", "login"]
                    text: I18n.tr("Weather", "Enable weather display on the login screen")
                    description: I18n.tr("Show weather on the login screen")
                    checked: SettingsData.greeterShowWeather
                    onToggled: checked => SettingsData.set("greeterShowWeather", checked)
                }

                StyledText {
                    text: I18n.tr("Date format on greeter")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    topPadding: Theme.spacingM
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                }

                SettingsDropdownRow {
                    settingKey: "greeterLockDateFormat"
                    tags: ["greeter", "date", "format"]
                    text: I18n.tr("Date Format")
                    description: I18n.tr("Format the date on the login screen")
                    options: root._lockDateFormatPresets.map(p => p.label)
                    currentValue: {
                        var current = SettingsData.greeterLockDateFormat || SettingsData.lockDateFormat || "";
                        var match = root._lockDateFormatPresets.find(p => p.format === current);
                        if (match)
                            return match.label;
                        if (current)
                            return I18n.tr("Custom") + ": " + current;
                        return root._lockDateFormatPresets[0].label;
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
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                }

                StyledText {
                    text: I18n.tr("Use a custom image for the login screen, or leave empty to use desktop wallpaper")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignLeft
                }

                SettingsWallpaperPicker {
                    width: parent.width
                    path: SettingsData.greeterWallpaperPath
                    fillMode: SettingsData.greeterWallpaperFillMode
                    fallbackFillMode: SettingsData.wallpaperFillMode || "Fill"
                    browserTitle: I18n.tr("Select greeter background image")
                    fillModeSettingKey: "greeterWallpaperFillMode"
                    fillModeTags: ["greeter", "wallpaper", "background", "fill"]
                    onPathSelected: path => SettingsData.set("greeterWallpaperPath", path)
                    onFillModeSelected: mode => SettingsData.set("greeterWallpaperFillMode", mode)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "history"
                title: I18n.tr("Behavior")
                settingKey: "greeterBehavior"

                StyledText {
                    text: I18n.tr("Convenience options for the login screen")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignLeft
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

                SettingsToggleRow {
                    settingKey: "greeterAutoLogin"
                    tags: ["greeter", "autologin", "login", "startup", "password"]
                    text: I18n.tr("Auto-login on startup")
                    description: SettingsData.greeterRememberLastUser && SettingsData.greeterRememberLastSession ? I18n.tr("Skip the greeter password after boot until you sign out. Lock screen unlock is unchanged. Takes effect on the next reboot after sync.") : I18n.tr("Requires remembering the last user and session. Enable those options first.")
                    checked: SettingsData.greeterAutoLogin
                    enabled: SettingsData.greeterRememberLastUser && SettingsData.greeterRememberLastSession
                    onToggled: checked => SettingsData.set("greeterAutoLogin", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "extension"
                title: I18n.tr("Dependencies & documentation")
                settingKey: "greeterDeps"

                StyledText {
                    text: I18n.tr("Requires greetd, dms-greeter, and your user in the greeter group (plus fprintd/pam_fprintd for fingerprint, pam_u2f for security keys).")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignLeft
                }

                StyledText {
                    text: I18n.tr("Installation and PAM setup are documented in the ") + "<a href=\"https://danklinux.com/docs/dankgreeter/installation\" style=\"text-decoration:none; color:" + Theme.primary + ";\">DankGreeter docs.</a> "
                    textFormat: Text.RichText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    linkColor: Theme.primary
                    width: parent.width
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignLeft
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

    Rectangle {
        id: syncPendingPill

        readonly property bool shown: SessionData.greeterSyncPending && root.greeterBinaryExists

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: shown ? Theme.spacingL : Theme.spacingXS
        width: pillRow.implicitWidth + Theme.spacingL * 2
        height: 44
        radius: height / 2
        color: Theme.primary
        opacity: shown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            cursorShape: !root.greeterSyncRunning && !root.greeterInstallActionRunning ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton && !root.greeterSyncRunning && !root.greeterInstallActionRunning)
                    root.runGreeterSync();
            }
        }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankIcon {
                id: syncPillIcon
                name: "sync"
                size: Theme.iconSize - 4
                color: Theme.primaryText
                anchors.verticalCenter: parent.verticalCenter

                RotationAnimation on rotation {
                    running: root.greeterSyncRunning && syncPendingPill.shown
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    onRunningChanged: {
                        if (!running)
                            syncPillIcon.rotation = 0;
                    }
                }
            }

            StyledText {
                text: root.greeterSyncRunning ? I18n.tr("Syncing...") : I18n.tr("Sync to apply")
                color: Theme.primaryText
                font.pixelSize: Theme.fontSizeMedium
                anchors.verticalCenter: parent.verticalCenter
            }

            DankActionButton {
                iconName: "close"
                iconSize: Theme.iconSize - 6
                iconColor: Theme.primaryText
                buttonSize: 28
                anchors.verticalCenter: parent.verticalCenter
                onClicked: SettingsData.revertGreeterSyncPending()
            }
        }
    }
}
