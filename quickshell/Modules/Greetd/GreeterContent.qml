import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Lock

Item {
    id: root

    function encodeFileUrl(path) {
        if (!path)
            return "";
        return "file://" + path.split('/').map(s => encodeURIComponent(s)).join('/');
    }

    readonly property string xdgDataDirs: Quickshell.env("XDG_DATA_DIRS")
    property string screenName: ""
    property string hyprlandCurrentLayout: ""
    property string hyprlandKeyboard: ""
    property int hyprlandLayoutCount: 0
    property bool isPrimaryScreen: !Quickshell.screens?.length || screenName === Quickshell.screens[0]?.name

    signal launchRequested

    property bool weatherInitialized: false
    property bool awaitingExternalAuth: false
    property bool pendingPasswordResponse: false
    property bool passwordSubmitRequested: false
    property bool cancelingExternalAuthForPassword: false
    property int defaultAuthTimeoutMs: 10000
    property int externalAuthTimeoutMs: 30000
    property int memoryFlushDelayMs: 120
    property string pendingLaunchCommand: ""
    property var pendingLaunchEnv: []
    property int passwordFailureCount: 0
    property int passwordAttemptLimitHint: 0
    property string authFeedbackMessage: ""
    property string greetdPamText: ""
    property string systemAuthPamText: ""
    property string commonAuthPamText: ""
    property string passwordAuthPamText: ""
    property string systemLoginPamText: ""
    property string systemLocalLoginPamText: ""
    property string commonAuthPcPamText: ""
    property string loginPamText: ""
    property string faillockConfigText: ""
    property bool greeterWallpaperOverrideExists: false
    property string externalAuthAutoStartedForUser: ""
    property int passwordSessionTransitionRetryCount: 0
    property int maxPasswordSessionTransitionRetries: 2
    property bool fprintdProbeComplete: false
    property bool fprintdHasDevice: false
    // Falls back to PAM-only detection until the fprintd D-Bus probe completes.
    readonly property bool greeterPamHasFprint: greeterPamStackHasModule("pam_fprintd") && (!fprintdProbeComplete || fprintdHasDevice)
    readonly property bool greeterPamHasU2f: greeterPamStackHasModule("pam_u2f")
    readonly property bool greeterExternalAuthAvailable: (greeterPamHasFprint && GreetdSettings.greeterEnableFprint) || (greeterPamHasU2f && GreetdSettings.greeterEnableU2f)
    readonly property bool greeterPamHasExternalAuth: greeterPamHasFprint || greeterPamHasU2f

    function initWeatherService() {
        if (weatherInitialized)
            return;
        if (!GreetdSettings.settingsLoaded)
            return;
        if (!GreetdSettings.weatherEnabled)
            return;
        weatherInitialized = true;
        WeatherService.addRef();
        WeatherService.forceRefresh();
    }

    function stripPamComment(line) {
        if (!line)
            return "";
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith("#"))
            return "";
        const hashIdx = trimmed.indexOf("#");
        if (hashIdx >= 0)
            return trimmed.substring(0, hashIdx).trim();
        return trimmed;
    }

    function pamModuleEnabled(pamText, moduleName) {
        if (!pamText || !moduleName)
            return false;
        const lines = pamText.split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
            const line = stripPamComment(lines[i]);
            if (!line)
                continue;
            if (line.includes(moduleName))
                return true;
        }
        return false;
    }

    function pamTextIncludesFile(pamText, filename) {
        if (!pamText || !filename)
            return false;
        const lines = pamText.split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
            const line = stripPamComment(lines[i]);
            if (!line)
                continue;
            if (line.includes(filename) && (line.includes("include") || line.includes("substack") || line.startsWith("@include")))
                return true;
        }
        return false;
    }

    function greeterPamStackHasModule(moduleName) {
        if (pamModuleEnabled(greetdPamText, moduleName))
            return true;
        const includedPamStacks = [["system-auth", systemAuthPamText], ["common-auth", commonAuthPamText], ["password-auth", passwordAuthPamText], ["system-login", systemLoginPamText], ["system-local-login", systemLocalLoginPamText], ["common-auth-pc", commonAuthPcPamText], ["login", loginPamText]];
        for (let i = 0; i < includedPamStacks.length; i++) {
            const stack = includedPamStacks[i];
            if (pamTextIncludesFile(greetdPamText, stack[0]) && pamModuleEnabled(stack[1], moduleName))
                return true;
        }
        return false;
    }

    function usesPamLockoutPolicy(pamText) {
        if (!pamText)
            return false;
        const lines = pamText.split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
            const line = stripPamComment(lines[i]);
            if (!line)
                continue;
            if (line.includes("pam_faillock.so") || line.includes("pam_tally2.so") || line.includes("pam_tally.so"))
                return true;
        }
        return false;
    }

    function parsePamLineDenyValue(pamText) {
        if (!pamText)
            return -1;
        const lines = pamText.split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
            const line = stripPamComment(lines[i]);
            if (!line)
                continue;
            if (!line.includes("pam_faillock.so") && !line.includes("pam_tally2.so") && !line.includes("pam_tally.so"))
                continue;
            const denyMatch = line.match(/\bdeny\s*=\s*(\d+)\b/i);
            if (!denyMatch)
                continue;
            const parsed = parseInt(denyMatch[1], 10);
            if (!isNaN(parsed))
                return parsed;
        }
        return -1;
    }

    function parseFaillockDenyValue(configText) {
        if (!configText)
            return -1;
        const lines = configText.split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
            const line = stripPamComment(lines[i]);
            if (!line)
                continue;
            const denyMatch = line.match(/^deny\s*=\s*(\d+)\s*$/i);
            if (!denyMatch)
                continue;
            const parsed = parseInt(denyMatch[1], 10);
            if (!isNaN(parsed))
                return parsed;
        }
        return -1;
    }

    function refreshPasswordAttemptPolicyHint() {
        const pamSources = [greetdPamText, systemAuthPamText, commonAuthPamText, passwordAuthPamText, systemLoginPamText, systemLocalLoginPamText, commonAuthPcPamText, loginPamText];
        let lockoutConfigured = false;
        let denyFromPam = -1;
        for (let i = 0; i < pamSources.length; i++) {
            const source = pamSources[i];
            if (!source)
                continue;
            if (usesPamLockoutPolicy(source))
                lockoutConfigured = true;
            const denyValue = parsePamLineDenyValue(source);
            if (denyValue >= 0 && (denyFromPam < 0 || denyValue < denyFromPam))
                denyFromPam = denyValue;
        }

        if (!lockoutConfigured) {
            passwordAttemptLimitHint = 0;
            return;
        }

        const denyFromConfig = parseFaillockDenyValue(faillockConfigText);
        if (denyFromConfig >= 0) {
            passwordAttemptLimitHint = denyFromConfig;
            return;
        }

        if (denyFromPam >= 0) {
            passwordAttemptLimitHint = denyFromPam;
            return;
        }

        // pam_faillock default deny value when no explicit config is set.
        passwordAttemptLimitHint = 3;
    }

    function isLikelyLockoutMessage(message) {
        const lower = (message || "").toLowerCase();
        return lower.includes("account is locked") || lower.includes("too many") || lower.includes("maximum number of") || lower.includes("auth_err");
    }

    function currentAuthMessage() {
        if (GreeterState.pamState === "error")
            return I18n.tr("Authentication error - try again");
        if (GreeterState.pamState === "max")
            return I18n.tr("Too many failed attempts - account may be locked");
        if (GreeterState.pamState === "fail") {
            if (passwordAttemptLimitHint > 0) {
                const attempt = Math.max(1, Math.min(passwordFailureCount, passwordAttemptLimitHint));
                const remaining = Math.max(passwordAttemptLimitHint - attempt, 0);
                if (remaining > 0) {
                    return I18n.tr("Incorrect password - attempt %1 of %2 (lockout may follow)").arg(attempt).arg(passwordAttemptLimitHint);
                }
                return I18n.tr("Incorrect password - next failures may trigger account lockout");
            }
            return I18n.tr("Incorrect password");
        }
        return "";
    }

    function clearAuthFeedback() {
        GreeterState.pamState = "";
        authFeedbackMessage = "";
    }

    function resetPasswordSessionTransition(clearSubmitRequest) {
        cancelingExternalAuthForPassword = false;
        passwordSessionTransitionRetryCount = 0;
        if (clearSubmitRequest)
            passwordSubmitRequested = false;
    }

    Connections {
        target: GreetdSettings
        function onSettingsLoadedChanged() {
            if (GreetdSettings.settingsLoaded) {
                initWeatherService();
                if (isPrimaryScreen) {
                    applyLastSuccessfulUser();
                    finalizeSessionSelection();
                }
            }
        }

        function onRememberLastUserChanged() {
            if (!isPrimaryScreen)
                return;
            if (!GreetdSettings.rememberLastUser && GreetdMemory.lastSuccessfulUser) {
                GreetdMemory.setLastSuccessfulUser("");
            }
            applyLastSuccessfulUser();
        }

        function onRememberLastSessionChanged() {
            if (!isPrimaryScreen)
                return;
            if (!GreetdSettings.rememberLastSession && GreetdMemory.lastSessionId) {
                GreetdMemory.setLastSessionId("");
            }
            finalizeSessionSelection();
        }
    }

    FileView {
        id: greetdPamWatcher
        path: "/etc/pam.d/greetd"
        printErrors: false
        onLoaded: {
            root.greetdPamText = text();
            root.refreshPasswordAttemptPolicyHint();
            root.maybeAutoStartExternalAuth();
        }
        onLoadFailed: {
            root.greetdPamText = "";
            root.refreshPasswordAttemptPolicyHint();
        }
    }

    FileView {
        id: systemAuthPamWatcher
        path: "/etc/pam.d/system-auth"
        printErrors: false
        onLoaded: {
            root.systemAuthPamText = text();
            root.refreshPasswordAttemptPolicyHint();
            root.maybeAutoStartExternalAuth();
        }
        onLoadFailed: {
            root.systemAuthPamText = "";
            root.refreshPasswordAttemptPolicyHint();
        }
    }

    FileView {
        id: commonAuthPamWatcher
        path: "/etc/pam.d/common-auth"
        printErrors: false
        onLoaded: {
            root.commonAuthPamText = text();
            root.refreshPasswordAttemptPolicyHint();
            root.maybeAutoStartExternalAuth();
        }
        onLoadFailed: {
            root.commonAuthPamText = "";
            root.refreshPasswordAttemptPolicyHint();
        }
    }

    FileView {
        id: passwordAuthPamWatcher
        path: "/etc/pam.d/password-auth"
        printErrors: false
        onLoaded: {
            root.passwordAuthPamText = text();
            root.refreshPasswordAttemptPolicyHint();
            root.maybeAutoStartExternalAuth();
        }
        onLoadFailed: {
            root.passwordAuthPamText = "";
            root.refreshPasswordAttemptPolicyHint();
        }
    }

    FileView {
        id: systemLoginPamWatcher
        path: "/etc/pam.d/system-login"
        printErrors: false
        onLoaded: {
            root.systemLoginPamText = text();
            root.refreshPasswordAttemptPolicyHint();
            root.maybeAutoStartExternalAuth();
        }
        onLoadFailed: {
            root.systemLoginPamText = "";
            root.refreshPasswordAttemptPolicyHint();
        }
    }

    FileView {
        id: systemLocalLoginPamWatcher
        path: "/etc/pam.d/system-local-login"
        printErrors: false
        onLoaded: {
            root.systemLocalLoginPamText = text();
            root.refreshPasswordAttemptPolicyHint();
            root.maybeAutoStartExternalAuth();
        }
        onLoadFailed: {
            root.systemLocalLoginPamText = "";
            root.refreshPasswordAttemptPolicyHint();
        }
    }

    FileView {
        id: commonAuthPcPamWatcher
        path: "/etc/pam.d/common-auth-pc"
        printErrors: false
        onLoaded: {
            root.commonAuthPcPamText = text();
            root.refreshPasswordAttemptPolicyHint();
            root.maybeAutoStartExternalAuth();
        }
        onLoadFailed: {
            root.commonAuthPcPamText = "";
            root.refreshPasswordAttemptPolicyHint();
        }
    }

    FileView {
        id: loginPamWatcher
        path: "/etc/pam.d/login"
        printErrors: false
        onLoaded: {
            root.loginPamText = text();
            root.refreshPasswordAttemptPolicyHint();
            root.maybeAutoStartExternalAuth();
        }
        onLoadFailed: {
            root.loginPamText = "";
            root.refreshPasswordAttemptPolicyHint();
        }
    }

    FileView {
        id: faillockConfigWatcher
        path: "/etc/security/faillock.conf"
        printErrors: false
        onLoaded: {
            root.faillockConfigText = text();
            root.refreshPasswordAttemptPolicyHint();
        }
        onLoadFailed: {
            root.faillockConfigText = "";
            root.refreshPasswordAttemptPolicyHint();
        }
    }

    Component.onCompleted: {
        initWeatherService();
        refreshPasswordAttemptPolicyHint();

        if (isPrimaryScreen)
            applyLastSuccessfulUser();

        if (CompositorService.isHyprland)
            updateHyprlandLayout();

        fprintdDeviceProbe.running = true;
    }

    function applyLastSuccessfulUser() {
        if (!GreetdSettings.settingsLoaded || !GreetdSettings.rememberLastUser)
            return;
        const lastUser = GreetdMemory.lastSuccessfulUser;
        if (lastUser && !GreeterState.showPasswordInput && !GreeterState.username) {
            GreeterState.username = lastUser;
            GreeterState.usernameInput = lastUser;
            GreeterState.showPasswordInput = true;
            PortalService.getGreeterUserProfileImage(lastUser);
            maybeAutoStartExternalAuth();
        }
    }

    function submitUsername(rawValue) {
        const user = (rawValue || "").trim();
        if (!user)
            return;
        if (GreeterState.username !== user) {
            passwordFailureCount = 0;
            clearAuthFeedback();
            externalAuthAutoStartedForUser = "";
        }
        GreeterState.username = user;
        GreeterState.showPasswordInput = true;
        PortalService.getGreeterUserProfileImage(user);
        GreeterState.passwordBuffer = "";
        pendingPasswordResponse = false;
        resetPasswordSessionTransition(true);
        maybeAutoStartExternalAuth();
    }

    function submitBufferedPassword() {
        pendingPasswordResponse = false;
        resetPasswordSessionTransition(true);
        awaitingExternalAuth = false;
        authTimeout.interval = defaultAuthTimeoutMs;
        authTimeout.restart();
        // Some PAM stacks expect an explicit empty response to advance U2F/fprint or fail normally.
        Greetd.respond(GreeterState.passwordBuffer || "");
        GreeterState.passwordBuffer = "";
        inputField.text = "";
        return true;
    }

    function requestPasswordSessionTransition() {
        const hasPasswordBuffer = GreeterState.passwordBuffer && GreeterState.passwordBuffer.length > 0;
        if (!passwordSubmitRequested && !hasPasswordBuffer)
            return;
        if (cancelingExternalAuthForPassword)
            return;
        if (passwordSessionTransitionRetryCount >= maxPasswordSessionTransitionRetries) {
            pendingPasswordResponse = false;
            awaitingExternalAuth = false;
            authTimeout.interval = defaultAuthTimeoutMs;
            authTimeout.stop();
            resetPasswordSessionTransition(true);
            GreeterState.pamState = "error";
            authFeedbackMessage = currentAuthMessage();
            placeholderDelay.restart();
            Greetd.cancelSession();
            return;
        }
        cancelingExternalAuthForPassword = true;
        passwordSessionTransitionRetryCount = passwordSessionTransitionRetryCount + 1;
        awaitingExternalAuth = false;
        pendingPasswordResponse = false;
        authTimeout.interval = defaultAuthTimeoutMs;
        authTimeout.stop();
        Greetd.cancelSession();
    }

    function startAuthSession(submitPassword) {
        submitPassword = submitPassword === true;
        if (!GreeterState.showPasswordInput || !GreeterState.username)
            return;
        if (GreeterState.unlocking)
            return;
        const hasPasswordBuffer = GreeterState.passwordBuffer && GreeterState.passwordBuffer.length > 0;
        if (Greetd.state !== GreetdState.Inactive) {
            if (pendingPasswordResponse && submitPassword)
                submitBufferedPassword();
            else if (submitPassword)
                passwordSubmitRequested = true;
            return;
        }
        if (cancelingExternalAuthForPassword) {
            if (submitPassword)
                passwordSubmitRequested = true;
            return;
        }
        if (!submitPassword && !hasPasswordBuffer && !root.greeterExternalAuthAvailable)
            return;
        pendingPasswordResponse = false;
        passwordSubmitRequested = submitPassword;
        awaitingExternalAuth = !submitPassword && !hasPasswordBuffer && root.greeterExternalAuthAvailable;
        // Use greeterExternalAuthAvailable so systems with pam_fprintd but no hardware don't incur the 30 s wait.
        const waitingOnPamExternalBeforePassword = submitPassword && root.greeterExternalAuthAvailable;
        authTimeout.interval = (awaitingExternalAuth || waitingOnPamExternalBeforePassword) ? externalAuthTimeoutMs : defaultAuthTimeoutMs;
        authTimeout.restart();
        Greetd.createSession(GreeterState.username);
    }

    function maybeAutoStartExternalAuth() {
        if (!GreeterState.showPasswordInput || !GreeterState.username)
            return;
        if (!root.greeterExternalAuthAvailable)
            return;
        if (GreeterState.unlocking || Greetd.state !== GreetdState.Inactive)
            return;
        if (passwordSubmitRequested || cancelingExternalAuthForPassword)
            return;
        if (GreeterState.passwordBuffer && GreeterState.passwordBuffer.length > 0)
            return;
        if (externalAuthAutoStartedForUser === GreeterState.username)
            return;

        externalAuthAutoStartedForUser = GreeterState.username;
        startAuthSession(false);
    }

    function isExternalAuthPrompt(message, responseRequired) {
        // Non-response PAM messages commonly represent waiting states (fprint/U2F/token touch).
        return !responseRequired;
    }

    Component.onDestruction: {
        if (weatherInitialized)
            WeatherService.removeRef();
    }

    function updateHyprlandLayout() {
        if (CompositorService.isHyprland) {
            hyprlandLayoutProcess.running = true;
        }
    }

    Process {
        id: hyprlandLayoutProcess
        running: false
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const mainKeyboard = data.keyboards.find(kb => kb.main === true);
                    if (!mainKeyboard) {
                        hyprlandCurrentLayout = "";
                        hyprlandLayoutCount = 0;
                        return;
                    }
                    hyprlandKeyboard = mainKeyboard.name;
                    if (mainKeyboard.active_keymap) {
                        const parts = mainKeyboard.active_keymap.split(" ");
                        hyprlandCurrentLayout = parts[0].substring(0, 2).toUpperCase();
                    } else {
                        hyprlandCurrentLayout = "";
                    }
                    hyprlandLayoutCount = mainKeyboard.layout ? mainKeyboard.layout.split(",").length : 0;
                } catch (e) {
                    hyprlandCurrentLayout = "";
                    hyprlandLayoutCount = 0;
                }
            }
        }
    }

    // Probe fprintd D-Bus for physically enrolled scanners to eliminate PAM stack false-positives.
    Process {
        id: fprintdDeviceProbe
        running: false
        // sh wrapper: emits PROBE_UNAVAILABLE if gdbus is absent or fprintd unreachable,
        // keeping the PAM-only fallback active in those cases.
        command: ["sh", "-c", "command -v gdbus >/dev/null 2>&1 || { echo PROBE_UNAVAILABLE; exit 0; }; " + "gdbus call --system " + "--dest net.reactivated.Fprint " + "--object-path /net/reactivated/Fprint/Manager " + "--method net.reactivated.Fprint.Manager.GetDevices 2>/dev/null " + "|| echo PROBE_UNAVAILABLE"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("PROBE_UNAVAILABLE"))
                    return; // PAM-only fallback stays active
                root.fprintdHasDevice = text.includes("objectpath");
                root.fprintdProbeComplete = true;
                root.maybeAutoStartExternalAuth();
            }
        }
        onExited: function (exitCode, exitStatus) {
            if (!root.fprintdProbeComplete)
                root.maybeAutoStartExternalAuth(); // PAM-only fallback stays active
        }
    }

    Connections {
        target: CompositorService.isHyprland ? Hyprland : null
        enabled: CompositorService.isHyprland

        function onRawEvent(event) {
            if (event.name === "activelayout")
                updateHyprlandLayout();
        }
    }

    Connections {
        target: GreetdMemory
        enabled: isPrimaryScreen
        function onLastSuccessfulUserChanged() {
            applyLastSuccessfulUser();
        }
        function onMemoryReadyChanged() {
            finalizeSessionSelection();
        }
    }

    Connections {
        target: GreeterState
        function onUsernameChanged() {
            if (GreeterState.username) {
                PortalService.getGreeterUserProfileImage(GreeterState.username);
            }
        }
    }

    FileView {
        id: greeterWallpaperOverrideFile
        path: GreetdSettings.greeterWallpaperOverridePath
        printErrors: false
        watchChanges: true
        onLoaded: root.greeterWallpaperOverrideExists = true
        onLoadFailed: root.greeterWallpaperOverrideExists = false
    }

    Connections {
        target: GreetdSettings
        function onGreeterWallpaperOverridePathChanged() {
            if (!GreetdSettings.greeterWallpaperOverridePath) {
                root.greeterWallpaperOverrideExists = false;
                return;
            }
            greeterWallpaperOverrideFile.reload();
        }
        function onGreeterWallpaperPathChanged() {
            if (!GreetdSettings.greeterWallpaperPath) {
                root.greeterWallpaperOverrideExists = false;
                return;
            }
            greeterWallpaperOverrideFile.reload();
        }
    }

    DankBackdrop {
        anchors.fill: parent
        screenName: root.screenName
        visible: {
            if (GreetdSettings.greeterWallpaperPath !== "" && root.greeterWallpaperOverrideExists)
                return false;
            var _ = SessionData.perMonitorWallpaper;
            var __ = SessionData.monitorWallpapers;
            var currentWallpaper = SessionData.getMonitorWallpaper(screenName);
            return !currentWallpaper || currentWallpaper === "" || (currentWallpaper && currentWallpaper.startsWith("#"));
        }
    }

    Image {
        id: wallpaperBackground

        anchors.fill: parent
        source: {
            if (GreetdSettings.greeterWallpaperPath !== "" && root.greeterWallpaperOverrideExists)
                return encodeFileUrl(GreetdSettings.greeterWallpaperOverridePath);
            var _ = SessionData.perMonitorWallpaper;
            var __ = SessionData.monitorWallpapers;
            var currentWallpaper = SessionData.getMonitorWallpaper(screenName);
            return (currentWallpaper && !currentWallpaper.startsWith("#")) ? encodeFileUrl(currentWallpaper) : "";
        }
        fillMode: Theme.getFillMode(GreetdSettings.getEffectiveWallpaperFillMode())
        smooth: true
        asynchronous: false
        cache: true
        visible: source !== ""
        layer.enabled: true

        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 0.8
            blurMax: 32
            blurMultiplier: 1
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Item {
            id: clockContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: 60
            width: parent.width
            height: clockText.implicitHeight

            Row {
                id: clockText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                spacing: 0

                property string fullTimeStr: {
                    const format = GreetdSettings.getEffectiveTimeFormat();
                    return systemClock.date.toLocaleTimeString(I18n.locale(), format);
                }
                property var timeParts: fullTimeStr.split(':')
                property string hours: timeParts[0] || ""
                property string minutes: timeParts[1] || ""
                property string secondsWithAmPm: timeParts.length > 2 ? timeParts[2] : ""
                property string seconds: secondsWithAmPm.replace(/\s*(AM|PM|am|pm)$/i, '')
                property string ampm: {
                    const match = fullTimeStr.match(/\s*(AM|PM|am|pm)$/i);
                    return match ? match[0].trim() : "";
                }
                property bool hasSeconds: timeParts.length > 2

                StyledText {
                    width: 75
                    text: clockText.hours.length > 1 ? clockText.hours[0] : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    width: 75
                    text: clockText.hours.length > 1 ? clockText.hours[1] : clockText.hours.length > 0 ? clockText.hours[0] : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    text: ":"
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                }

                StyledText {
                    width: 75
                    text: clockText.minutes.length > 0 ? clockText.minutes[0] : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    width: 75
                    text: clockText.minutes.length > 1 ? clockText.minutes[1] : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    text: clockText.hasSeconds ? ":" : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    visible: clockText.hasSeconds
                }

                StyledText {
                    width: 75
                    text: clockText.hasSeconds && clockText.seconds.length > 0 ? clockText.seconds[0] : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    visible: clockText.hasSeconds
                }

                StyledText {
                    width: 75
                    text: clockText.hasSeconds && clockText.seconds.length > 1 ? clockText.seconds[1] : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    visible: clockText.hasSeconds
                }

                StyledText {
                    width: 20
                    text: " "
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    visible: clockText.ampm !== ""
                }

                StyledText {
                    text: clockText.ampm
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    visible: clockText.ampm !== ""
                }
            }
        }

        StyledText {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockContainer.bottom
            anchors.topMargin: 4
            text: {
                return systemClock.date.toLocaleDateString(I18n.locale(), GreetdSettings.getEffectiveLockDateFormat());
            }
            font.pixelSize: Theme.fontSizeXLarge
            color: "white"
            opacity: 0.9
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: dateText.bottom
            anchors.topMargin: Theme.spacingL
            width: 380
            height: 140

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.spacingM

                RowLayout {
                    spacing: Theme.spacingL
                    Layout.fillWidth: true

                    DankCircularImage {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 60
                        imageSource: {
                            if (PortalService.profileImage === "")
                                return "";
                            if (PortalService.profileImage.startsWith("/"))
                                return encodeFileUrl(PortalService.profileImage);
                            return PortalService.profileImage;
                        }
                        fallbackIcon: "person"
                        visible: GreetdSettings.lockScreenShowProfileImage
                    }

                    Rectangle {
                        property bool showPassword: false

                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
                        border.color: inputField.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.3)
                        border.width: inputField.activeFocus ? 2 : 1

                        DankIcon {
                            id: lockIcon

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            name: GreeterState.showPasswordInput ? "lock" : "person"
                            size: 20
                            color: inputField.activeFocus ? Theme.primary : Theme.surfaceVariantText
                        }

                        TextInput {
                            id: inputField

                            property bool syncingFromState: false

                            anchors.fill: parent
                            anchors.leftMargin: lockIcon.width + Theme.spacingM * 2
                            anchors.rightMargin: {
                                let margin = Theme.spacingM;
                                if (GreeterState.showPasswordInput && revealButton.visible) {
                                    margin += revealButton.width;
                                }
                                if (externalAuthButton.visible) {
                                    margin += externalAuthButton.width;
                                }
                                if (virtualKeyboardButton.visible) {
                                    margin += virtualKeyboardButton.width;
                                }
                                if (enterButton.visible) {
                                    margin += enterButton.width + 2;
                                }
                                return margin;
                            }
                            opacity: 0
                            focus: true
                            echoMode: GreeterState.showPasswordInput ? (parent.showPassword ? TextInput.Normal : TextInput.Password) : TextInput.Normal
                            onTextChanged: {
                                if (syncingFromState)
                                    return;
                                if (GreeterState.showPasswordInput) {
                                    GreeterState.passwordBuffer = text;
                                    if (!text || text.length === 0)
                                        root.passwordSubmitRequested = false;
                                } else {
                                    GreeterState.usernameInput = text;
                                }
                            }
                            onAccepted: {
                                if (GreeterState.showPasswordInput) {
                                    root.startAuthSession(true);
                                } else {
                                    if (text.trim()) {
                                        root.submitUsername(text);
                                        syncingFromState = true;
                                        text = "";
                                        syncingFromState = false;
                                    }
                                }
                            }

                            Component.onCompleted: {
                                syncingFromState = true;
                                text = GreeterState.showPasswordInput ? GreeterState.passwordBuffer : GreeterState.usernameInput;
                                syncingFromState = false;
                                if (isPrimaryScreen && !powerMenu.isVisible)
                                    forceActiveFocus();
                            }
                            onVisibleChanged: {
                                if (visible && isPrimaryScreen && !powerMenu.isVisible)
                                    forceActiveFocus();
                            }
                        }

                        KeyboardController {
                            id: keyboard_controller
                            target: inputField
                            rootObject: root
                        }

                        StyledText {
                            id: placeholder

                            anchors.left: lockIcon.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: (GreeterState.showPasswordInput && revealButton.visible ? revealButton.left : (externalAuthButton.visible ? externalAuthButton.left : (virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : parent.right))))
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (GreeterState.unlocking) {
                                    return I18n.tr("Logging in...");
                                }
                                if (Greetd.state !== GreetdState.Inactive && !awaitingExternalAuth && !pendingPasswordResponse) {
                                    return I18n.tr("Authenticating...");
                                }
                                if (GreeterState.showPasswordInput) {
                                    return I18n.tr("Password...");
                                }
                                return I18n.tr("Username...");
                            }
                            color: (GreeterState.unlocking || (Greetd.state !== GreetdState.Inactive && !awaitingExternalAuth && !pendingPasswordResponse)) ? Theme.primary : Theme.outline
                            font.pixelSize: Theme.fontSizeMedium
                            opacity: (GreeterState.showPasswordInput ? GreeterState.passwordBuffer.length === 0 : GreeterState.usernameInput.length === 0) ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.mediumDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        StyledText {
                            anchors.left: lockIcon.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: (GreeterState.showPasswordInput && revealButton.visible ? revealButton.left : (externalAuthButton.visible ? externalAuthButton.left : (virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : parent.right))))
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (GreeterState.showPasswordInput) {
                                    if (parent.showPassword) {
                                        return GreeterState.passwordBuffer;
                                    }
                                    return "•".repeat(GreeterState.passwordBuffer.length);
                                }
                                return GreeterState.usernameInput;
                            }
                            color: Theme.surfaceText
                            font.pixelSize: (GreeterState.showPasswordInput && !parent.showPassword) ? Theme.fontSizeLarge : Theme.fontSizeMedium
                            opacity: (GreeterState.showPasswordInput ? GreeterState.passwordBuffer.length > 0 : GreeterState.usernameInput.length > 0) ? 1 : 0
                            clip: true
                            elide: Text.ElideNone
                            horizontalAlignment: implicitWidth > width ? Text.AlignRight : Text.AlignLeft

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.mediumDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        DankActionButton {
                            id: revealButton

                            anchors.right: externalAuthButton.visible ? externalAuthButton.left : (virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : parent.right))
                            anchors.rightMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: parent.showPassword ? "visibility_off" : "visibility"
                            buttonSize: 32
                            visible: GreeterState.showPasswordInput && GreeterState.passwordBuffer.length > 0 && (Greetd.state === GreetdState.Inactive || awaitingExternalAuth || pendingPasswordResponse) && !GreeterState.unlocking
                            enabled: visible
                            onClicked: parent.showPassword = !parent.showPassword
                        }
                        DankActionButton {
                            id: externalAuthButton

                            anchors.right: virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : parent.right)
                            anchors.rightMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: root.greeterPamHasFprint ? "fingerprint" : "key"
                            buttonSize: 32
                            visible: GreeterState.showPasswordInput && root.greeterExternalAuthAvailable && GreeterState.passwordBuffer.length === 0 && (Greetd.state === GreetdState.Inactive || awaitingExternalAuth || pendingPasswordResponse) && !GreeterState.unlocking
                            enabled: visible
                            onClicked: root.startAuthSession(false)
                        }
                        DankActionButton {
                            id: virtualKeyboardButton

                            anchors.right: enterButton.visible ? enterButton.left : parent.right
                            anchors.rightMargin: enterButton.visible ? 0 : Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "keyboard"
                            buttonSize: 32
                            visible: (Greetd.state === GreetdState.Inactive || awaitingExternalAuth || pendingPasswordResponse) && !GreeterState.unlocking
                            enabled: visible
                            onClicked: {
                                if (keyboard_controller.isKeyboardActive) {
                                    keyboard_controller.hide();
                                } else {
                                    keyboard_controller.show();
                                }
                            }
                        }

                        DankActionButton {
                            id: enterButton

                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "keyboard_return"
                            buttonSize: 36
                            visible: (Greetd.state === GreetdState.Inactive || awaitingExternalAuth || pendingPasswordResponse) && !GreeterState.unlocking
                            enabled: true
                            onClicked: {
                                if (GreeterState.showPasswordInput) {
                                    root.startAuthSession(true);
                                } else {
                                    if (inputField.text.trim()) {
                                        root.submitUsername(inputField.text);
                                        inputField.text = "";
                                    }
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    Layout.topMargin: -Theme.spacingS
                    Layout.bottomMargin: -Theme.spacingS
                    text: root.authFeedbackMessage
                    color: Theme.error
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    opacity: root.authFeedbackMessage !== "" ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 0
                    Layout.preferredWidth: switchUserRow.width + Theme.spacingL * 2
                    Layout.preferredHeight: 40
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer
                    opacity: GreeterState.showPasswordInput ? 1 : 0
                    enabled: GreeterState.showPasswordInput

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.standardEasing
                        }
                    }

                    Row {
                        id: switchUserRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "people"
                            size: Theme.iconSize - 4
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Switch User")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StateLayer {
                        stateColor: Theme.primary
                        cornerRadius: parent.radius
                        enabled: !GreeterState.unlocking && Greetd.state === GreetdState.Inactive && GreeterState.showPasswordInput
                        onClicked: {
                            GreeterState.reset();
                            root.externalAuthAutoStartedForUser = "";
                            inputField.text = "";
                            PortalService.profileImage = "";
                        }
                    }
                }
            }
        }

        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL

            Item {
                width: keyboardLayoutRow.width
                height: keyboardLayoutRow.height
                anchors.verticalCenter: parent.verticalCenter
                visible: {
                    if (CompositorService.isNiri) {
                        return NiriService.keyboardLayoutNames.length > 1;
                    } else if (CompositorService.isHyprland) {
                        return hyprlandLayoutCount > 1;
                    }
                    return false;
                }

                Row {
                    id: keyboardLayoutRow
                    spacing: 4

                    Item {
                        width: Theme.iconSize
                        height: Theme.iconSize

                        DankIcon {
                            name: "keyboard"
                            size: Theme.iconSize
                            color: "white"
                            anchors.centerIn: parent
                        }
                    }

                    Item {
                        width: childrenRect.width
                        height: Theme.iconSize

                        StyledText {
                            text: {
                                if (CompositorService.isNiri) {
                                    const layout = NiriService.getCurrentKeyboardLayoutName();
                                    if (!layout)
                                        return "";
                                    const parts = layout.split(" ");
                                    if (parts.length > 0) {
                                        return parts[0].substring(0, 2).toUpperCase();
                                    }
                                    return layout.substring(0, 2).toUpperCase();
                                } else if (CompositorService.isHyprland) {
                                    return hyprlandCurrentLayout;
                                }
                                return "";
                            }
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Light
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                MouseArea {
                    id: keyboardLayoutArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (CompositorService.isNiri) {
                            NiriService.cycleKeyboardLayout();
                        } else if (CompositorService.isHyprland) {
                            Quickshell.execDetached(["hyprctl", "switchxkblayout", hyprlandKeyboard, "next"]);
                            updateHyprlandLayout();
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.2)
                anchors.verticalCenter: parent.verticalCenter
                visible: {
                    const keyboardVisible = (CompositorService.isNiri && NiriService.keyboardLayoutNames.length > 1) || (CompositorService.isHyprland && hyprlandLayoutCount > 1);
                    return keyboardVisible && GreetdSettings.weatherEnabled && WeatherService.weather.available;
                }
            }

            Row {
                spacing: 6
                visible: GreetdSettings.weatherEnabled && WeatherService.weather.available
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                    size: Theme.iconSize
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: (GreetdSettings.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Light
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.2)
                anchors.verticalCenter: parent.verticalCenter
                visible: GreetdSettings.weatherEnabled && WeatherService.weather.available && (NetworkService.networkStatus !== "disconnected" || BluetoothService.enabled || (AudioService.sink && AudioService.sink.audio) || BatteryService.batteryAvailable)
            }

            Row {
                spacing: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                visible: NetworkService.networkStatus !== "disconnected" || (BluetoothService.available && BluetoothService.enabled) || (AudioService.sink && AudioService.sink.audio)

                DankIcon {
                    name: NetworkService.networkStatus === "ethernet" ? "lan" : NetworkService.wifiSignalIcon
                    size: Theme.iconSize - 2
                    color: NetworkService.networkStatus !== "disconnected" ? "white" : Qt.rgba(255, 255, 255, 0.5)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: NetworkService.networkStatus !== "disconnected"
                }

                DankIcon {
                    name: "bluetooth"
                    size: Theme.iconSize - 2
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: BluetoothService.available && BluetoothService.enabled
                }

                DankIcon {
                    name: {
                        if (!AudioService.sink?.audio) {
                            return "volume_up";
                        }
                        if (AudioService.sink.audio.muted)
                            return "volume_off";
                        if (AudioService.sink.audio.volume === 0)
                            return "volume_mute";
                        if (AudioService.sink.audio.volume * 100 < 33) {
                            return "volume_down";
                        }
                        return "volume_up";
                    }
                    size: Theme.iconSize - 2
                    color: (AudioService.sink && AudioService.sink.audio && (AudioService.sink.audio.muted || AudioService.sink.audio.volume === 0)) ? Qt.rgba(255, 255, 255, 0.5) : "white"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: AudioService.sink && AudioService.sink.audio
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.2)
                anchors.verticalCenter: parent.verticalCenter
                visible: BatteryService.batteryAvailable && (NetworkService.networkStatus !== "disconnected" || BluetoothService.enabled || (AudioService.sink && AudioService.sink.audio))
            }

            Row {
                spacing: 4
                visible: BatteryService.batteryAvailable
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: {
                        if (BatteryService.isCharging) {
                            if (BatteryService.batteryLevel >= 90) {
                                return "battery_charging_full";
                            }

                            if (BatteryService.batteryLevel >= 80) {
                                return "battery_charging_90";
                            }

                            if (BatteryService.batteryLevel >= 60) {
                                return "battery_charging_80";
                            }

                            if (BatteryService.batteryLevel >= 50) {
                                return "battery_charging_60";
                            }

                            if (BatteryService.batteryLevel >= 30) {
                                return "battery_charging_50";
                            }

                            if (BatteryService.batteryLevel >= 20) {
                                return "battery_charging_30";
                            }

                            return "battery_charging_20";
                        }
                        if (BatteryService.isPluggedIn) {
                            if (BatteryService.batteryLevel >= 90) {
                                return "battery_charging_full";
                            }

                            if (BatteryService.batteryLevel >= 80) {
                                return "battery_charging_90";
                            }

                            if (BatteryService.batteryLevel >= 60) {
                                return "battery_charging_80";
                            }

                            if (BatteryService.batteryLevel >= 50) {
                                return "battery_charging_60";
                            }

                            if (BatteryService.batteryLevel >= 30) {
                                return "battery_charging_50";
                            }

                            if (BatteryService.batteryLevel >= 20) {
                                return "battery_charging_30";
                            }

                            return "battery_charging_20";
                        }
                        if (BatteryService.batteryLevel >= 95) {
                            return "battery_full";
                        }

                        if (BatteryService.batteryLevel >= 85) {
                            return "battery_6_bar";
                        }

                        if (BatteryService.batteryLevel >= 70) {
                            return "battery_5_bar";
                        }

                        if (BatteryService.batteryLevel >= 55) {
                            return "battery_4_bar";
                        }

                        if (BatteryService.batteryLevel >= 40) {
                            return "battery_3_bar";
                        }

                        if (BatteryService.batteryLevel >= 25) {
                            return "battery_2_bar";
                        }

                        return "battery_1_bar";
                    }
                    size: Theme.iconSize
                    color: {
                        if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                            return Theme.error;
                        }

                        if (BatteryService.isCharging || BatteryService.isPluggedIn) {
                            return Theme.primary;
                        }

                        return "white";
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: BatteryService.batteryLevel + "%"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Light
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        DankActionButton {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: Theme.spacingXL
            visible: GreetdSettings.lockScreenShowPowerActions
            iconName: "power_settings_new"
            iconColor: Theme.error
            buttonSize: 40
            onClicked: powerMenu.show()
        }

        Item {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Theme.spacingXL
            width: Math.max(200, currentSessionMetrics.width + 80)
            height: 60

            StyledTextMetrics {
                id: currentSessionMetrics
                text: root.currentSessionName
            }

            property real longestSessionWidth: {
                let maxWidth = 0;
                for (var i = 0; i < sessionMetricsRepeater.count; i++) {
                    const item = sessionMetricsRepeater.itemAt(i);
                    if (item && item.width > maxWidth) {
                        maxWidth = item.width;
                    }
                }
                return maxWidth;
            }

            Repeater {
                id: sessionMetricsRepeater
                model: GreeterState.sessionList
                delegate: StyledTextMetrics {
                    text: modelData
                }
            }

            DankDropdown {
                id: sessionDropdown
                anchors.fill: parent
                text: ""
                description: ""
                currentValue: root.currentSessionName
                options: GreeterState.sessionList
                enableFuzzySearch: GreeterState.sessionList.length > 5
                popupWidthOffset: 0
                popupWidth: Math.max(250, parent.longestSessionWidth + 100)
                openUpwards: true
                alignPopupRight: true
                onValueChanged: value => {
                    const idx = GreeterState.sessionList.indexOf(value);
                    if (idx < 0)
                        return;
                    GreeterState.currentSessionIndex = idx;
                    GreeterState.selectedSession = GreeterState.sessionExecs[idx];
                    GreeterState.selectedSessionPath = GreeterState.sessionPaths[idx];
                }
            }
        }
    }

    property string currentSessionName: GreeterState.sessionList[GreeterState.currentSessionIndex] || ""

    function finalizeSessionSelection() {
        if (GreeterState.sessionList.length === 0)
            return;
        if (!GreetdMemory.memoryReady)
            return;
        if (!GreetdSettings.settingsLoaded)
            return;

        const savedSession = GreetdSettings.rememberLastSession ? GreetdMemory.lastSessionId : "";
        if (savedSession && GreetdSettings.rememberLastSession) {
            for (var i = 0; i < GreeterState.sessionPaths.length; i++) {
                if (GreeterState.sessionPaths[i] === savedSession) {
                    GreeterState.currentSessionIndex = i;
                    GreeterState.selectedSession = GreeterState.sessionExecs[i] || "";
                    GreeterState.selectedSessionPath = GreeterState.sessionPaths[i];
                    return;
                }
            }
        }

        GreeterState.currentSessionIndex = 0;
        GreeterState.selectedSession = GreeterState.sessionExecs[0] || "";
        GreeterState.selectedSessionPath = GreeterState.sessionPaths[0] || "";
    }

    property var sessionDirs: {
        const homeDir = Quickshell.env("HOME") || "";
        const dirs = ["/usr/share/wayland-sessions", "/usr/share/xsessions", "/usr/local/share/wayland-sessions", "/usr/local/share/xsessions"];

        if (homeDir) {
            dirs.push(homeDir + "/.local/share/wayland-sessions");
            dirs.push(homeDir + "/.local/share/xsessions");
        }

        if (xdgDataDirs) {
            xdgDataDirs.split(":").forEach(dir => {
                if (dir) {
                    dirs.push(dir + "/wayland-sessions");
                    dirs.push(dir + "/xsessions");
                }
            });
        }
        return dirs;
    }

    property var _pendingFiles: ({})
    property int _pendingCount: 0

    function _addSession(path, name, exec) {
        if (!name || !exec || GreeterState.sessionList.includes(name))
            return;
        GreeterState.sessionList = GreeterState.sessionList.concat([name]);
        GreeterState.sessionExecs = GreeterState.sessionExecs.concat([exec]);
        GreeterState.sessionPaths = GreeterState.sessionPaths.concat([path]);
    }

    function _parseDesktopFile(content, path) {
        let name = "";
        let exec = "";
        const lines = content.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (!name && line.startsWith("Name="))
                name = line.substring(5).trim();
            else if (!exec && line.startsWith("Exec="))
                exec = line.substring(5).trim();
            if (name && exec)
                break;
        }
        _addSession(path, name, exec);
    }

    function _loadDesktopFile(filePath) {
        if (_pendingFiles[filePath])
            return;
        _pendingFiles[filePath] = true;
        _pendingCount++;

        const loader = desktopFileLoader.createObject(root, {
            "filePath": filePath
        });
    }

    function _onFileLoaded(filePath) {
        _pendingCount--;
        if (_pendingCount === 0)
            Qt.callLater(finalizeSessionSelection);
    }

    Component {
        id: desktopFileLoader

        FileView {
            id: fv
            property string filePath: ""
            path: filePath

            onLoaded: {
                root._parseDesktopFile(text(), filePath);
                root._onFileLoaded(filePath);
                fv.destroy();
            }

            onLoadFailed: {
                root._onFileLoaded(filePath);
                fv.destroy();
            }
        }
    }

    Repeater {
        model: isPrimaryScreen ? sessionDirs : []

        Item {
            required property string modelData

            FolderListModel {
                folder: encodeFileUrl(modelData)
                nameFilters: ["*.desktop"]
                showDirs: false
                showDotAndDotDot: false

                onStatusChanged: {
                    if (status !== FolderListModel.Ready)
                        return;
                    for (let i = 0; i < count; i++) {
                        let fp = get(i, "filePath");
                        if (fp.startsWith("file://"))
                            fp = fp.substring(7);
                        root._loadDesktopFile(fp);
                    }
                }
            }
        }
    }

    Connections {
        target: Greetd
        enabled: isPrimaryScreen

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                cancelingExternalAuthForPassword = false;
                passwordSessionTransitionRetryCount = 0;
                awaitingExternalAuth = false;
                pendingPasswordResponse = true;
                const hasPasswordBuffer = GreeterState.passwordBuffer && GreeterState.passwordBuffer.length > 0;
                if (!passwordSubmitRequested && hasPasswordBuffer)
                    passwordSubmitRequested = true;
                if (passwordSubmitRequested && !root.submitBufferedPassword())
                    passwordSubmitRequested = false;
                if (passwordSubmitRequested || hasPasswordBuffer) {
                    authTimeout.interval = defaultAuthTimeoutMs;
                    authTimeout.restart();
                } else {
                    authTimeout.stop();
                }
                return;
            }
            pendingPasswordResponse = false;
            const externalPrompt = root.isExternalAuthPrompt(message, responseRequired);
            if (!passwordSubmitRequested)
                awaitingExternalAuth = root.greeterExternalAuthAvailable && externalPrompt;
            if (awaitingExternalAuth || (passwordSubmitRequested && externalPrompt && root.greeterPamHasExternalAuth))
                authTimeout.interval = externalAuthTimeoutMs;
            else
                authTimeout.interval = defaultAuthTimeoutMs;
            authTimeout.restart();
            Greetd.respond("");
        }

        function onStateChanged() {
            if (Greetd.state === GreetdState.Inactive) {
                const resumePasswordSubmit = cancelingExternalAuthForPassword && passwordSubmitRequested;
                awaitingExternalAuth = false;
                pendingPasswordResponse = false;
                cancelingExternalAuthForPassword = false;
                authTimeout.interval = defaultAuthTimeoutMs;
                authTimeout.stop();
                if (resumePasswordSubmit) {
                    Qt.callLater(function () {
                        root.startAuthSession(true);
                    });
                    return;
                }
                resetPasswordSessionTransition(true);
            }
        }

        function onReadyToLaunch() {
            awaitingExternalAuth = false;
            pendingPasswordResponse = false;
            resetPasswordSessionTransition(true);
            authTimeout.interval = defaultAuthTimeoutMs;
            authTimeout.stop();
            passwordFailureCount = 0;
            clearAuthFeedback();
            const sessionCmd = GreeterState.selectedSession || GreeterState.sessionExecs[GreeterState.currentSessionIndex];
            const sessionPath = GreeterState.selectedSessionPath || GreeterState.sessionPaths[GreeterState.currentSessionIndex];
            if (!sessionCmd) {
                GreeterState.pamState = "error";
                authFeedbackMessage = currentAuthMessage();
                placeholderDelay.restart();
                return;
            }

            GreeterState.unlocking = true;
            launchTimeout.restart();
            if (GreetdSettings.rememberLastSession) {
                GreetdMemory.setLastSessionId(sessionPath);
            } else if (GreetdMemory.lastSessionId) {
                GreetdMemory.setLastSessionId("");
            }
            if (GreetdSettings.rememberLastUser) {
                GreetdMemory.setLastSuccessfulUser(GreeterState.username);
            } else if (GreetdMemory.lastSuccessfulUser) {
                GreetdMemory.setLastSuccessfulUser("");
            }
            pendingLaunchCommand = sessionCmd;
            pendingLaunchEnv = ["XDG_SESSION_TYPE=wayland"];
            memoryFlushTimer.restart();
        }

        function onAuthFailure(message) {
            awaitingExternalAuth = false;
            pendingPasswordResponse = false;
            resetPasswordSessionTransition(true);
            authTimeout.interval = defaultAuthTimeoutMs;
            authTimeout.stop();
            launchTimeout.stop();
            GreeterState.unlocking = false;
            if (isLikelyLockoutMessage(message)) {
                GreeterState.pamState = "max";
            } else {
                GreeterState.pamState = "fail";
                passwordFailureCount = passwordFailureCount + 1;
            }
            authFeedbackMessage = currentAuthMessage();
            GreeterState.passwordBuffer = "";
            inputField.text = "";
            placeholderDelay.restart();
            Greetd.cancelSession();
        }

        function onError(error) {
            awaitingExternalAuth = false;
            pendingPasswordResponse = false;
            resetPasswordSessionTransition(true);
            authTimeout.interval = defaultAuthTimeoutMs;
            authTimeout.stop();
            launchTimeout.stop();
            GreeterState.unlocking = false;
            GreeterState.pamState = "error";
            authFeedbackMessage = currentAuthMessage();
            GreeterState.passwordBuffer = "";
            inputField.text = "";
            placeholderDelay.restart();
            Greetd.cancelSession();
        }
    }

    Timer {
        id: memoryFlushTimer
        interval: memoryFlushDelayMs
        onTriggered: {
            if (!pendingLaunchCommand)
                return;
            const sessionCommand = pendingLaunchCommand;
            const launchEnv = pendingLaunchEnv;
            pendingLaunchCommand = "";
            pendingLaunchEnv = [];
            Greetd.launch(sessionCommand.split(" "), launchEnv);
        }
    }

    Timer {
        id: authTimeout
        interval: defaultAuthTimeoutMs
        onTriggered: {
            if (GreeterState.unlocking || Greetd.state === GreetdState.Inactive)
                return;
            awaitingExternalAuth = false;
            pendingPasswordResponse = false;
            resetPasswordSessionTransition(true);
            authTimeout.interval = defaultAuthTimeoutMs;
            GreeterState.pamState = "error";
            authFeedbackMessage = currentAuthMessage();
            GreeterState.passwordBuffer = "";
            inputField.text = "";
            placeholderDelay.restart();
            Greetd.cancelSession();
        }
    }

    Timer {
        id: launchTimeout
        interval: 8000
        onTriggered: {
            if (!GreeterState.unlocking)
                return;
            pendingPasswordResponse = false;
            resetPasswordSessionTransition(true);
            GreeterState.unlocking = false;
            GreeterState.pamState = "error";
            authFeedbackMessage = currentAuthMessage();
            placeholderDelay.restart();
            Greetd.cancelSession();
        }
    }

    Timer {
        id: placeholderDelay
        interval: 4000
        onTriggered: clearAuthFeedback()
    }

    LockPowerMenu {
        id: powerMenu
        showLogout: false
        powerActionConfirmOverride: GreetdSettings.powerActionConfirm
        powerActionHoldDurationOverride: GreetdSettings.powerActionHoldDuration
        powerMenuActionsOverride: GreetdSettings.powerMenuActions
        powerMenuDefaultActionOverride: GreetdSettings.powerMenuDefaultAction
        powerMenuGridLayoutOverride: GreetdSettings.powerMenuGridLayout
        requiredActions: ["poweroff"]
        onClosed: {
            if (isPrimaryScreen && inputField && inputField.forceActiveFocus) {
                Qt.callLater(() => inputField.forceActiveFocus());
            }
        }
    }
}
