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

    property var parentModal: null

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    ConfirmModal {
        id: greeterActionConfirm
    }

    property string greeterStatusText: ""
    property bool greeterStatusRunning: false
    readonly property bool greeterSyncRunning: GreeterService.syncing
    readonly property string greeterSyncStatus: GreeterService.syncStatus
    property bool greeterInstallActionRunning: false
    property string greeterStatusStdout: ""
    property string greeterStatusStderr: ""
    readonly property bool greeterBinaryExists: GreeterService.binaryExists
    property bool greeterEnabled: false
    property bool embeddedGreeterConfigured: false
    readonly property bool embeddedGreeterOnly: embeddedGreeterConfigured && !greeterBinaryExists
    readonly property string greeterAction: greeterBinaryExists && !greeterEnabled ? "activate" : ""
    readonly property bool greeterActionAvailable: greeterAction !== ""

    readonly property string greeterActionLabel: greeterAction === "activate" ? I18n.tr("Activate") : ""
    readonly property string greeterActionIcon: greeterAction === "activate" ? "login" : ""
    readonly property var greeterActionCommand: greeterAction === "activate" ? ["dms-greeter", "enable", "--terminal"] : []

    onGreeterSyncStatusChanged: greeterStatusText = greeterSyncStatus

    function checkGreeterInstallState() {
        greetdEnabledCheckProcess.running = true;
        GreeterService.refresh();
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
            "confirmText": I18n.tr("Activate", "verb, enable the greeter, also activate a wired network profile"),
            "cancelText": I18n.tr("Cancel"),
            "confirmColor": Theme.primary,
            "onConfirm": () => root.runGreeterInstallAction(),
            "onCancel": () => {}
        });
    }

    Component.onCompleted: {
        Qt.callLater(checkGreeterInstallState);
    }

    Process {
        id: greetdEnabledCheckProcess
        command: ["sh", "-c", "if [ \"$(uname -s)\" = FreeBSD ]; then service -e 2>/dev/null | grep -Eq \"/greetd$\" && echo enabled || echo disabled; else systemctl is-enabled greetd 2>/dev/null; fi"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.greeterEnabled = text.trim() === "enabled"
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

    Connections {
        target: GreeterService

        function onSyncFinished() {
            root.checkGreeterInstallState();
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

    SettingsPage {
        id: mainColumn

        SettingsCard {
            width: parent.width
            iconName: "info"
            title: I18n.tr("Status")
            settingKey: "greeterStatus"

            SettingsRow {
                body: StyledText {
                    text: I18n.tr("Sync applies your theme and settings to the login screen. Shared users should run dms-greeter sync --profile instead of a primary user sync.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignLeft
                }
            }

            SettingsRow {
                body: Rectangle {
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
            }

            SettingsRow {
                body: Flow {
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
                        text: I18n.tr("Sync", "verb, button that copies settings to the login greeter")
                        iconName: "sync"
                        horizontalPadding: Theme.spacingL
                        onClicked: GreeterService.sync()
                        enabled: root.greeterBinaryExists && !root.greeterSyncRunning && !root.greeterInstallActionRunning
                    }
                }
            }
        }

        SettingsCard {
            SettingsNavRow {
                settingKey: "greeterAuth"
                tags: ["greeter", "login", "authentication", "pam", "fingerprint", "security", "key"]
                title: I18n.tr("Authentication")
                iconName: "fingerprint"
                onClicked: root.parentModal?.navigateTo("greeter_auth")
            }
        }

        SettingsCard {
            title: I18n.tr("Appearance")
            settingKey: "greeterAppearance"
            tags: ["greeter", "login", "sync", "theme", "wallpaper"]

            SettingsRow {
                subtitle: I18n.tr("Uses your wallpaper, fonts and lock screen settings.", "login screen appearance")
            }

            SettingsNavRow {
                title: I18n.tr("Wallpaper & colors")
                iconName: "palette"
                onClicked: root.parentModal?.navigateTo("personalization")
            }

            SettingsNavRow {
                title: I18n.tr("Fonts & motion")
                iconName: "text_fields"
                onClicked: root.parentModal?.navigateTo("typography")
            }

            SettingsNavRow {
                title: I18n.tr("Lock screen")
                iconName: "lock"
                onClicked: root.parentModal?.navigateTo("lock_screen")
            }
        }

        SettingsCard {
            width: parent.width
            iconName: "history"
            title: I18n.tr("Behavior")
            settingKey: "greeterBehavior"

            SettingsToggleRow {
                settingKey: "greeterRememberLastSession"
                tags: ["greeter", "session", "remember", "login"]
                text: I18n.tr("Remember last session")
                checked: SettingsData.greeterRememberLastSession
                onToggled: checked => SettingsData.set("greeterRememberLastSession", checked)
            }

            SettingsToggleRow {
                settingKey: "greeterRememberLastUser"
                tags: ["greeter", "user", "remember", "login", "username"]
                text: I18n.tr("Remember last user")
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

            SettingsRow {
                body: StyledText {
                    text: I18n.tr("Requires greetd, dms-greeter, and your user in the greeter group (plus fprintd/pam_fprintd for fingerprint, pam_u2f for security keys).")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignLeft
                }
            }

            SettingsRow {
                body: StyledText {
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

        GreeterSyncFabBar {
            blocked: root.greeterInstallActionRunning
        }
    }
}
