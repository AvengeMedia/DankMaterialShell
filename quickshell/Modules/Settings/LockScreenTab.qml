import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    readonly property bool lockFprintToggleAvailable: SettingsData.lockFingerprintCanEnable || SettingsData.enableFprint
    readonly property bool lockU2fToggleAvailable: SettingsData.lockU2fCanEnable || SettingsData.enableU2f
    readonly property bool primaryPamHasFprint: SettingsData.lockPamPath !== "" && SettingsData.lockPamInlineFprint
    readonly property bool primaryPamHasU2f: SettingsData.lockPamPath !== "" && SettingsData.lockPamInlineU2f
    readonly property bool lockFprintControlledByPrimary: SettingsData.lockPamExternallyManaged || primaryPamHasFprint
    readonly property bool lockU2fControlledByPrimary: SettingsData.lockPamExternallyManaged || primaryPamHasU2f

    property var authServices: []
    property bool authValidateRunning: false
    property bool authValidateOk: false
    property bool authValidateWarn: false
    property string authValidateMessage: ""
    property string authPendingApplyPath: ""
    property bool authShowCustom: false
    property bool u2fValidateRunning: false
    property bool u2fValidateOk: false
    property bool u2fValidateWarn: false
    property string u2fValidateMessage: ""
    property string u2fPendingApplyPath: ""
    property bool u2fShowCustom: false

    readonly property string authAutoLabel: I18n.tr("Auto", "automatic PAM authentication source option")
    readonly property string authCustomLabel: I18n.tr("Custom...", "custom PAM authentication source option")

    function authServiceLabel(service) {
        const label = service.name.split("-").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join("-");
        return service.dir === "/etc/pam.d" ? label : label + " (" + service.dir + ")";
    }

    readonly property var authOptions: [authAutoLabel, ...authServices.map(s => authServiceLabel(s)), authCustomLabel]

    readonly property string authCurrentValue: {
        if (SettingsData.lockPamPath === "")
            return authAutoLabel;
        const svc = authServices.find(s => s.path === SettingsData.lockPamPath);
        return svc ? authServiceLabel(svc) : authCustomLabel;
    }

    readonly property string u2fAuthCurrentValue: SettingsData.lockU2fPamPath === "" ? authAutoLabel : authCustomLabel

    function refreshAuthServices() {
        authListServicesProcess.running = true;
    }

    function applyAutoAuthSource() {
        SettingsData.set("lockPamPath", "");
        SettingsData.set("lockPamInlineFprint", false);
        SettingsData.set("lockPamInlineU2f", false);
        root.authValidateOk = false;
        root.authValidateWarn = false;
        root.authValidateMessage = "";
    }

    function validateAndApplyAuthSource(path) {
        if (!path)
            return;
        root.authPendingApplyPath = path;
        root.authValidateMessage = "";
        root.authValidateOk = false;
        root.authValidateWarn = false;
        root.authValidateRunning = true;
        authValidateProcess.command = ["dms", "auth", "validate", "--path", path, "--json"];
        authValidateProcess.running = true;
    }

    function applyAutoU2fSource() {
        SettingsData.set("lockU2fPamPath", "");
        root.u2fValidateOk = false;
        root.u2fValidateWarn = false;
        root.u2fValidateMessage = "";
    }

    function validateAndApplyU2fSource(path) {
        if (!path)
            return;
        root.u2fPendingApplyPath = path;
        root.u2fValidateMessage = "";
        root.u2fValidateOk = false;
        root.u2fValidateWarn = false;
        root.u2fValidateRunning = true;
        u2fValidateProcess.command = ["dms", "auth", "validate", "--purpose", "u2f", "--path", path, "--json"];
        u2fValidateProcess.running = true;
    }

    function lockFingerprintDescription() {
        switch (SettingsData.lockFingerprintReason) {
        case "ready":
            return I18n.tr("Use fingerprint authentication for the lock screen", "lock screen fingerprint setting");
        case "missing_enrollment":
            return I18n.tr("Fingerprint reader detected, but no prints are enrolled yet. You can enable this now and enroll later.", "lock screen fingerprint setting");
        case "missing_reader":
            return I18n.tr("No fingerprint reader detected", "fingerprint setting status");
        case "missing_pam_support":
            return I18n.tr("Not available - install fprintd and pam_fprintd", "lock screen fingerprint setting");
        default:
            return I18n.tr("Fingerprint availability could not be confirmed", "fingerprint setting status");
        }
    }

    function lockU2fDescription() {
        switch (SettingsData.lockU2fReason) {
        case "ready":
            return I18n.tr("Use a security key for lock screen authentication", "lock screen U2F security key setting");
        case "missing_key_registration":
            return I18n.tr("Security-key support was detected, but no registered key was found yet. You can enable this now and register one later.", "security key setting status");
        case "missing_pam_support":
            return I18n.tr("Not available - install or configure pam_u2f", "lock screen security key setting");
        default:
            return I18n.tr("Security-key availability could not be confirmed", "security key setting status");
        }
    }

    function refreshAuthDetection() {
        SettingsData.refreshAuthAvailability();
    }

    Component.onCompleted: {
        refreshAuthDetection();
        refreshAuthServices();
    }
    onVisibleChanged: {
        if (visible) {
            refreshAuthDetection();
            refreshAuthServices();
        }
    }

    FileBrowserModal {
        id: videoBrowserModal
        browserTitle: I18n.tr("Select Video or Folder")
        browserIcon: "movie"
        browserType: "video"
        showHiddenFiles: false
        fileExtensions: ["*.mp4", "*.mkv", "*.webm", "*.mov", "*.avi", "*.m4v"]
        onFileSelected: path => SettingsData.set("lockScreenVideoPath", path)
    }

    Process {
        id: authListServicesProcess
        command: ["dms", "auth", "list-services", "--json"]
        running: false

        property string collected: ""

        stdout: StdioCollector {
            onStreamFinished: authListServicesProcess.collected = text || ""
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.authServices = [];
                return;
            }
            try {
                const data = JSON.parse(authListServicesProcess.collected);
                root.authServices = (data && Array.isArray(data.services)) ? data.services.filter(s => s.hasAuth) : [];
            } catch (e) {
                root.authServices = [];
            }
        }
    }

    Process {
        id: authValidateProcess
        running: false

        property string collected: ""

        stdout: StdioCollector {
            onStreamFinished: authValidateProcess.collected = text || ""
        }

        onExited: exitCode => {
            root.authValidateRunning = false;
            root.authValidateOk = false;
            root.authValidateWarn = false;

            let data = null;
            try {
                data = JSON.parse(authValidateProcess.collected);
            } catch (e) {}

            if (!data) {
                root.authValidateMessage = I18n.tr("Config validation failed");
                return;
            }
            if (!data.valid) {
                const errs = Array.isArray(data.errors) ? data.errors : [];
                root.authValidateMessage = [I18n.tr("Config validation failed"), ...errs].join("\n");
                return;
            }

            SettingsData.set("lockPamPath", root.authPendingApplyPath);
            SettingsData.set("lockPamInlineFprint", data.inlineFingerprint === true);
            SettingsData.set("lockPamInlineU2f", data.inlineU2f === true);
            const warns = Array.isArray(data.warnings) ? data.warnings : [];
            root.authValidateOk = true;
            root.authValidateWarn = warns.length > 0;
            root.authValidateMessage = [I18n.tr("Authentication changes applied"), ...warns].join("\n");
        }
    }

    Process {
        id: u2fValidateProcess
        running: false

        property string collected: ""

        stdout: StdioCollector {
            onStreamFinished: u2fValidateProcess.collected = text || ""
        }

        onExited: exitCode => {
            root.u2fValidateRunning = false;
            root.u2fValidateOk = false;
            root.u2fValidateWarn = false;

            let data = null;
            try {
                data = JSON.parse(u2fValidateProcess.collected);
            } catch (e) {}

            if (!data) {
                root.u2fValidateMessage = I18n.tr("Config validation failed");
                return;
            }
            if (!data.valid) {
                const errs = Array.isArray(data.errors) ? data.errors : [];
                root.u2fValidateMessage = [I18n.tr("Config validation failed"), ...errs].join("\n");
                return;
            }

            SettingsData.set("lockU2fPamPath", root.u2fPendingApplyPath);
            const warns = Array.isArray(data.warnings) ? data.warnings : [];
            root.u2fValidateOk = true;
            root.u2fValidateWarn = warns.length > 0;
            root.u2fValidateMessage = [I18n.tr("Authentication changes applied"), ...warns].join("\n");
            root.refreshAuthDetection();
        }
    }

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
                iconName: "lock"
                title: I18n.tr("Layout")
                settingKey: "lockLayout"

                SettingsToggleRow {
                    settingKey: "lockScreenShowPowerActions"
                    tags: ["lock", "screen", "power", "actions", "shutdown", "reboot"]
                    text: I18n.tr("Show Power Actions", "Enable power action icon on the lock screen window")
                    checked: SettingsData.lockScreenShowPowerActions
                    onToggled: checked => SettingsData.set("lockScreenShowPowerActions", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockScreenShowSystemIcons"
                    tags: ["lock", "screen", "system", "icons", "status"]
                    text: I18n.tr("Show System Icons", "Enable system status icons on the lock screen window")
                    checked: SettingsData.lockScreenShowSystemIcons
                    onToggled: checked => SettingsData.set("lockScreenShowSystemIcons", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockScreenShowTime"
                    tags: ["lock", "screen", "time", "clock", "display"]
                    text: I18n.tr("Show System Time", "Enable system time display on the lock screen window")
                    checked: SettingsData.lockScreenShowTime
                    onToggled: checked => SettingsData.set("lockScreenShowTime", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockScreenShowDate"
                    tags: ["lock", "screen", "date", "calendar", "display"]
                    text: I18n.tr("Show System Date", "Enable system date display on the lock screen window")
                    checked: SettingsData.lockScreenShowDate
                    onToggled: checked => SettingsData.set("lockScreenShowDate", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockScreenShowProfileImage"
                    tags: ["lock", "screen", "profile", "image", "avatar", "picture"]
                    text: I18n.tr("Show Profile Image", "Enable profile image display on the lock screen window")
                    checked: SettingsData.lockScreenShowProfileImage
                    onToggled: checked => SettingsData.set("lockScreenShowProfileImage", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockScreenShowPasswordField"
                    tags: ["lock", "screen", "password", "field", "input", "visible"]
                    text: I18n.tr("Show Password Field", "Enable password field display on the lock screen window")
                    description: I18n.tr("If the field is hidden, it will appear as soon as a key is pressed.")
                    checked: SettingsData.lockScreenShowPasswordField
                    onToggled: checked => SettingsData.set("lockScreenShowPasswordField", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockScreenShowMediaPlayer"
                    tags: ["lock", "screen", "media", "player", "music", "mpris"]
                    text: I18n.tr("Show Media Player", "Enable media player controls on the lock screen window")
                    checked: SettingsData.lockScreenShowMediaPlayer
                    onToggled: checked => SettingsData.set("lockScreenShowMediaPlayer", checked)
                }

                SettingsDropdownRow {
                    settingKey: "lockScreenNotificationMode"
                    tags: ["lock", "screen", "notification", "notifications", "privacy"]
                    text: I18n.tr("Notification Display", "lock screen notification privacy setting")
                    description: I18n.tr("Control what notification information is shown on the lock screen", "lock screen notification privacy setting")
                    options: [I18n.tr("Disabled", "lock screen notification mode option"), I18n.tr("Count Only", "lock screen notification mode option"), I18n.tr("App Names", "lock screen notification mode option"), I18n.tr("Full Content", "lock screen notification mode option")]
                    currentValue: options[SettingsData.lockScreenNotificationMode] || options[0]
                    onValueChanged: value => {
                        const idx = options.indexOf(value);
                        if (idx >= 0) {
                            SettingsData.set("lockScreenNotificationMode", idx);
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "palette"
                title: I18n.tr("Appearance")
                settingKey: "lockAppearance"

                StyledText {
                    text: I18n.tr("Customize the font and background of the lock screen, or leave empty to use your theme font and desktop wallpaper. Changes apply instantly.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                SettingsFontDropdownRow {
                    settingKey: "lockScreenFontFamily"
                    tags: ["lock", "screen", "font", "typography"]
                    text: I18n.tr("Lock screen font")
                    description: I18n.tr("Font used for the clock and date on the lock screen")
                    currentFont: SettingsData.lockScreenFontFamily || ""
                    onFontSelected: family => SettingsData.set("lockScreenFontFamily", family)
                }

                StyledText {
                    text: I18n.tr("Background")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    topPadding: Theme.spacingM
                }

                StyledText {
                    text: I18n.tr("Use a custom image for the lock screen, or leave empty to use your desktop wallpaper.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                SettingsWallpaperPicker {
                    width: parent.width
                    path: SettingsData.lockScreenWallpaperPath
                    fillMode: SettingsData.lockScreenWallpaperFillMode
                    browserTitle: I18n.tr("Select lock screen background image")
                    fillModeSettingKey: "lockScreenWallpaperFillMode"
                    fillModeTags: ["lock", "screen", "wallpaper", "background", "fill"]
                    onPathSelected: path => SettingsData.set("lockScreenWallpaperPath", path)
                    onFillModeSelected: mode => SettingsData.set("lockScreenWallpaperFillMode", mode)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "key"
                title: I18n.tr("Authentication")
                settingKey: "lockAuthSource"

                StyledText {
                    text: I18n.tr("Authentication changes apply automatically")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                SettingsDropdownRow {
                    settingKey: "lockPamPath"
                    tags: ["lock", "screen", "pam", "authentication", "source", "service"]
                    text: I18n.tr("Authentication Source", "lock screen PAM source setting")
                    description: SettingsData.lockPamPath !== "" ? SettingsData.lockPamPath : I18n.tr("Which PAM service the lock screen uses to authenticate", "lock screen PAM source setting")
                    options: root.authOptions
                    currentValue: root.authCurrentValue
                    onValueChanged: value => {
                        if (value === root.authAutoLabel) {
                            root.authShowCustom = false;
                            root.applyAutoAuthSource();
                            return;
                        }
                        if (value === root.authCustomLabel) {
                            root.authShowCustom = true;
                            return;
                        }
                        root.authShowCustom = false;
                        const svc = root.authServices.find(s => root.authServiceLabel(s) === value);
                        if (svc)
                            root.validateAndApplyAuthSource(svc.path);
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.authShowCustom || root.authCurrentValue === root.authCustomLabel

                    DankTextField {
                        id: customPamField
                        width: parent.width - validatePamButton.width - Theme.spacingS
                        placeholderText: "/etc/pam.d/my-service"
                        text: SettingsData.lockPamPath
                        backgroundColor: Theme.surfaceContainerHighest
                    }

                    DankButton {
                        id: validatePamButton
                        text: I18n.tr("Apply Changes", "validate and apply custom PAM authentication source")
                        enabled: !root.authValidateRunning && customPamField.text.trim() !== ""
                        onClicked: root.validateAndApplyAuthSource(customPamField.text.trim())
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Math.min(160, authStatusText.implicitHeight + Theme.spacingM * 2)
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHighest
                    visible: root.authValidateMessage !== ""

                    StyledText {
                        id: authStatusText
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        text: root.authValidateMessage
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: "monospace"
                        color: !root.authValidateOk ? Theme.error : (root.authValidateWarn ? Theme.warning : Theme.surfaceVariantText)
                        wrapMode: Text.Wrap
                        verticalAlignment: Text.AlignTop
                    }
                }

                SettingsToggleRow {
                    settingKey: "lockPamExternallyManaged"
                    tags: ["lock", "screen", "pam", "managed", "external", "authentication", "policy"]
                    text: I18n.tr("Use system PAM authentication", "system PAM policy toggle")
                    checked: SettingsData.lockPamExternallyManaged
                    onToggled: checked => SettingsData.set("lockPamExternallyManaged", checked)
                }

                SettingsToggleRow {
                    settingKey: "enableFprint"
                    tags: ["lock", "screen", "fingerprint", "authentication", "biometric", "fprint"]
                    text: I18n.tr("Enable fingerprint authentication")
                    description: root.lockFprintControlledByPrimary ? I18n.tr("Managed by the primary PAM source", "factor managed by PAM source status") : root.lockFingerprintDescription()
                    descriptionColor: root.lockFprintControlledByPrimary || SettingsData.lockFingerprintReason === "ready" ? Theme.surfaceVariantText : Theme.warning
                    checked: SettingsData.enableFprint || root.primaryPamHasFprint
                    enabled: root.lockFprintToggleAvailable && !root.lockFprintControlledByPrimary
                    onToggled: checked => SettingsData.set("enableFprint", checked)
                }

                SettingsToggleRow {
                    settingKey: "enableU2f"
                    tags: ["lock", "screen", "u2f", "yubikey", "security", "key", "fido", "authentication", "hardware"]
                    text: I18n.tr("Enable security key authentication", "Enable FIDO2/U2F hardware security key for lock screen")
                    description: root.lockU2fControlledByPrimary ? I18n.tr("Managed by the primary PAM source", "factor managed by PAM source status") : root.lockU2fDescription()
                    descriptionColor: root.lockU2fControlledByPrimary || SettingsData.lockU2fReason === "ready" ? Theme.surfaceVariantText : Theme.warning
                    checked: SettingsData.enableU2f || root.primaryPamHasU2f
                    enabled: root.lockU2fToggleAvailable && !root.lockU2fControlledByPrimary
                    onToggled: checked => SettingsData.set("enableU2f", checked)
                }

                SettingsDropdownRow {
                    settingKey: "u2fMode"
                    tags: ["lock", "screen", "u2f", "yubikey", "security", "key", "mode", "factor", "second"]
                    text: I18n.tr("Security key mode", "lock screen U2F security key mode setting")
                    description: I18n.tr("'Alternative' lets the key unlock on its own. 'Second factor' requires password or fingerprint first, then the key.", "lock screen U2F security key mode setting")
                    visible: SettingsData.enableU2f && !root.lockU2fControlledByPrimary
                    options: [I18n.tr("Alternative (OR)", "U2F mode option: key works as standalone unlock method"), I18n.tr("Second Factor (AND)", "U2F mode option: key required after password or fingerprint")]
                    currentValue: SettingsData.u2fMode === "and" ? I18n.tr("Second Factor (AND)", "U2F mode option: key required after password or fingerprint") : I18n.tr("Alternative (OR)", "U2F mode option: key works as standalone unlock method")
                    onValueChanged: value => {
                        if (value === I18n.tr("Second Factor (AND)", "U2F mode option: key required after password or fingerprint"))
                            SettingsData.set("u2fMode", "and");
                        else
                            SettingsData.set("u2fMode", "or");
                    }
                }

                SettingsDropdownRow {
                    settingKey: "lockU2fPamPath"
                    tags: ["lock", "screen", "pam", "u2f", "security", "key", "source", "service"]
                    text: I18n.tr("Security Key PAM Source", "lock screen dedicated U2F PAM source setting")
                    description: SettingsData.lockU2fPamPath !== "" ? SettingsData.lockU2fPamPath : I18n.tr("Auto uses an installed or bundled key-only service.", "lock screen dedicated U2F PAM source setting")
                    visible: !root.lockU2fControlledByPrimary
                    options: [root.authAutoLabel, root.authCustomLabel]
                    currentValue: root.u2fAuthCurrentValue
                    onValueChanged: value => {
                        if (value === root.authAutoLabel) {
                            root.u2fShowCustom = false;
                            root.applyAutoU2fSource();
                            return;
                        }
                        root.u2fShowCustom = true;
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: !root.lockU2fControlledByPrimary && (root.u2fShowCustom || root.u2fAuthCurrentValue === root.authCustomLabel)

                    DankTextField {
                        id: customU2fPamField
                        width: parent.width - validateU2fPamButton.width - Theme.spacingS
                        placeholderText: "/etc/pam.d/dankshell-u2f"
                        text: SettingsData.lockU2fPamPath
                        backgroundColor: Theme.surfaceContainerHighest
                    }

                    DankButton {
                        id: validateU2fPamButton
                        text: I18n.tr("Apply Changes", "validate and apply custom U2F PAM authentication source")
                        enabled: !root.u2fValidateRunning && customU2fPamField.text.trim() !== ""
                        onClicked: root.validateAndApplyU2fSource(customU2fPamField.text.trim())
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Math.min(160, u2fStatusText.implicitHeight + Theme.spacingM * 2)
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHighest
                    visible: !root.lockU2fControlledByPrimary && root.u2fValidateMessage !== ""

                    StyledText {
                        id: u2fStatusText
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        text: root.u2fValidateMessage
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: "monospace"
                        color: !root.u2fValidateOk ? Theme.error : (root.u2fValidateWarn ? Theme.warning : Theme.surfaceVariantText)
                        wrapMode: Text.Wrap
                        verticalAlignment: Text.AlignTop
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "lock"
                title: I18n.tr("Behavior")
                settingKey: "lockBehavior"

                StyledText {
                    text: I18n.tr("loginctl not available - lock integration requires DMS socket connection")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.warning
                    visible: !SessionService.loginctlAvailable
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                SettingsToggleRow {
                    settingKey: "loginctlLockIntegration"
                    tags: ["lock", "screen", "loginctl", "dbus", "integration", "external"]
                    text: I18n.tr("Enable loginctl lock integration")
                    description: I18n.tr("Bind lock screen to dbus signals from loginctl. Disable if using an external lock screen")
                    checked: SessionService.loginctlAvailable && SettingsData.loginctlLockIntegration
                    enabled: SessionService.loginctlAvailable
                    onToggled: checked => {
                        if (!SessionService.loginctlAvailable)
                            return;
                        SettingsData.set("loginctlLockIntegration", checked);
                    }
                }

                SettingsToggleRow {
                    settingKey: "lockBeforeSuspend"
                    tags: ["lock", "screen", "suspend", "sleep", "automatic"]
                    text: I18n.tr("Lock before suspend")
                    description: I18n.tr("Automatically lock the screen when the system prepares to suspend")
                    checked: SettingsData.lockBeforeSuspend
                    visible: SessionService.loginctlAvailable && SettingsData.loginctlLockIntegration
                    onToggled: checked => SettingsData.set("lockBeforeSuspend", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockScreenPowerOffMonitorsOnLock"
                    tags: ["lock", "screen", "monitor", "display", "dpms", "power"]
                    text: I18n.tr("Power off monitors on lock")
                    description: I18n.tr("Turn off all displays immediately when the lock screen activates")
                    checked: SettingsData.lockScreenPowerOffMonitorsOnLock
                    onToggled: checked => SettingsData.set("lockScreenPowerOffMonitorsOnLock", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockAtStartup"
                    tags: ["lock", "screen", "startup", "start", "boot", "login", "automatic"]
                    text: I18n.tr("Lock at startup")
                    description: I18n.tr("Automatically lock the screen when DMS starts")
                    checked: SettingsData.lockAtStartup
                    onToggled: checked => SettingsData.set("lockAtStartup", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "movie"
                title: I18n.tr("Video Screensaver")
                settingKey: "videoScreensaver"

                StyledText {
                    visible: !MultimediaService.available
                    text: I18n.tr("QtMultimedia is not available - video screensaver requires qt multimedia services")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.warning
                    width: parent.width
                    wrapMode: Text.WordWrap
                }

                SettingsToggleRow {
                    settingKey: "lockScreenVideoEnabled"
                    tags: ["lock", "screen", "video", "screensaver", "animation", "movie"]
                    text: I18n.tr("Enable Video Screensaver")
                    description: I18n.tr("Play a video when the screen locks.")
                    enabled: MultimediaService.available
                    checked: SettingsData.lockScreenVideoEnabled
                    onToggled: checked => SettingsData.set("lockScreenVideoEnabled", checked)
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS
                    visible: SettingsData.lockScreenVideoEnabled && MultimediaService.available

                    StyledText {
                        text: I18n.tr("Video Path")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        text: I18n.tr("Path to a video file or folder containing videos")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.outlineVariant
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankTextField {
                            id: videoPathField
                            width: parent.width - browseVideoButton.width - Theme.spacingS
                            placeholderText: I18n.tr("/path/to/videos")
                            text: SettingsData.lockScreenVideoPath
                            backgroundColor: Theme.surfaceContainerHighest
                            onTextChanged: {
                                if (text !== SettingsData.lockScreenVideoPath) {
                                    SettingsData.set("lockScreenVideoPath", text);
                                }
                            }
                        }

                        DankButton {
                            id: browseVideoButton
                            text: I18n.tr("Browse")
                            onClicked: videoBrowserModal.open()
                        }
                    }
                }

                SettingsToggleRow {
                    settingKey: "lockScreenVideoCycling"
                    tags: ["lock", "screen", "video", "screensaver", "cycling", "random", "shuffle"]
                    text: I18n.tr("Automatic Cycling")
                    description: I18n.tr("Pick a different random video each time from the same folder")
                    visible: SettingsData.lockScreenVideoEnabled && MultimediaService.available
                    enabled: MultimediaService.available
                    checked: SettingsData.lockScreenVideoCycling
                    onToggled: checked => SettingsData.set("lockScreenVideoCycling", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "monitor"
                title: I18n.tr("Display Assignment")
                settingKey: "lockDisplay"

                StyledText {
                    text: I18n.tr("Choose which monitors show the lock screen interface. Other monitors will display a solid color for OLED burn-in protection.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                SettingsDisplayPicker {
                    width: parent.width
                    displayPreferences: SettingsData.screenPreferences?.lockScreen || ["all"]
                    onPreferencesChanged: prefs => {
                        var p = SettingsData.screenPreferences || {};
                        var updated = Object.assign({}, p);
                        updated["lockScreen"] = prefs;
                        SettingsData.set("screenPreferences", updated);
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: {
                        var prefs = SettingsData.screenPreferences?.lockScreen;
                        return Array.isArray(prefs) && !prefs.includes("all") && prefs.length > 0;
                    }

                    Column {
                        width: parent.width - inactiveColorPreview.width - Theme.spacingM
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: I18n.tr("Inactive Monitor Color")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: I18n.tr("Color displayed on monitors without the lock screen")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            wrapMode: Text.Wrap
                        }
                    }

                    Rectangle {
                        id: inactiveColorPreview
                        width: 48
                        height: 48
                        radius: Theme.cornerRadius
                        color: SettingsData.lockScreenInactiveColor
                        border.color: Theme.outline
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!PopoutService.colorPickerModal)
                                    return;
                                PopoutService.colorPickerModal.selectedColor = SettingsData.lockScreenInactiveColor;
                                PopoutService.colorPickerModal.pickerTitle = I18n.tr("Inactive Monitor Color");
                                PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                                    SettingsData.set("lockScreenInactiveColor", selectedColor);
                                };
                                PopoutService.colorPickerModal.show();
                            }
                        }
                    }
                }
            }
        }
    }
}
