pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    property var settingsRoot: null

    property string greetdPamText: ""
    property string systemAuthPamText: ""
    property string commonAuthPamText: ""
    property string passwordAuthPamText: ""
    property string systemLoginPamText: ""
    property string systemLocalLoginPamText: ""
    property string commonAuthPcPamText: ""
    property string loginPamText: ""
    property string dankshellU2fPamText: ""
    property string u2fKeysText: ""

    property string fingerprintProbeOutput: ""
    property int fingerprintProbeExitCode: 0
    property bool fingerprintProbeFinalized: false

    property string pamProbeOutput: ""
    property bool pamProbeFinalized: false

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string u2fKeysPath: homeDir ? homeDir + "/.config/Yubico/u2f_keys" : ""
    readonly property bool homeU2fKeysDetected: u2fKeysPath !== "" && u2fKeysWatcher.loaded && u2fKeysText.trim() !== ""
    readonly property bool lockU2fCustomConfigDetected: pamModuleEnabled(dankshellU2fPamText, "pam_u2f")
    readonly property bool greeterPamHasFprint: greeterPamStackHasModule("pam_fprintd")
    readonly property bool greeterPamHasU2f: greeterPamStackHasModule("pam_u2f")

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

    // --- Derived auth probe state ---

    readonly property bool pamFprintSupportDetected: pamProbeFinalized && pamProbeOutput.includes("pam_fprintd.so:true")
    readonly property bool pamU2fSupportDetected: pamProbeFinalized && pamProbeOutput.includes("pam_u2f.so:true")

    readonly property string fingerprintProbeState: {
        if (forcedFprintAvailable !== null)
            return forcedFprintAvailable ? "ready" : "probe_failed";
        if (!fingerprintProbeFinalized)
            return "probe_failed";
        return parseFingerprintProbe(fingerprintProbeExitCode, fingerprintProbeOutput, pamFprintSupportDetected);
    }

    // --- Lock fingerprint capabilities ---

    readonly property bool lockFingerprintCanEnable: {
        if (forcedFprintAvailable !== null)
            return forcedFprintAvailable;
        switch (fingerprintProbeState) {
        case "ready":
        case "missing_enrollment":
            return true;
        default:
            return false;
        }
    }

    readonly property bool lockFingerprintReady: {
        if (forcedFprintAvailable !== null)
            return forcedFprintAvailable;
        return fingerprintProbeState === "ready";
    }

    readonly property string lockFingerprintReason: {
        if (forcedFprintAvailable !== null)
            return forcedFprintAvailable ? "ready" : "probe_failed";
        return fingerprintProbeState;
    }

    // --- Greeter fingerprint capabilities ---

    readonly property bool greeterFingerprintCanEnable: {
        if (forcedFprintAvailable !== null)
            return forcedFprintAvailable;
        if (greeterPamHasFprint)
            return fingerprintProbeState !== "missing_reader";
        switch (fingerprintProbeState) {
        case "ready":
        case "missing_enrollment":
            return true;
        default:
            return false;
        }
    }

    readonly property bool greeterFingerprintReady: {
        if (forcedFprintAvailable !== null)
            return forcedFprintAvailable;
        return fingerprintProbeState === "ready";
    }

    readonly property string greeterFingerprintReason: {
        if (forcedFprintAvailable !== null)
            return forcedFprintAvailable ? "ready" : "probe_failed";
        if (greeterPamHasFprint) {
            switch (fingerprintProbeState) {
            case "ready":
                return "configured_externally";
            case "missing_enrollment":
                return "missing_enrollment";
            case "missing_reader":
                return "missing_reader";
            default:
                return "probe_failed";
            }
        }
        return fingerprintProbeState;
    }

    readonly property string greeterFingerprintSource: {
        if (forcedFprintAvailable !== null)
            return forcedFprintAvailable ? "dms" : "none";
        if (greeterPamHasFprint)
            return "pam";
        switch (fingerprintProbeState) {
        case "ready":
        case "missing_enrollment":
            return "dms";
        default:
            return "none";
        }
    }

    // --- Lock U2F capabilities ---

    readonly property bool lockU2fReady: {
        if (forcedU2fAvailable !== null)
            return forcedU2fAvailable;
        return lockU2fCustomConfigDetected || homeU2fKeysDetected;
    }

    readonly property bool lockU2fCanEnable: {
        if (forcedU2fAvailable !== null)
            return forcedU2fAvailable;
        return lockU2fReady || pamU2fSupportDetected;
    }

    readonly property string lockU2fReason: {
        if (forcedU2fAvailable !== null)
            return forcedU2fAvailable ? "ready" : "probe_failed";
        if (lockU2fReady)
            return "ready";
        if (lockU2fCanEnable)
            return "missing_key_registration";
        return "missing_pam_support";
    }

    // --- Greeter U2F capabilities ---

    readonly property bool greeterU2fReady: {
        if (forcedU2fAvailable !== null)
            return forcedU2fAvailable;
        if (greeterPamHasU2f)
            return true;
        return homeU2fKeysDetected;
    }

    readonly property bool greeterU2fCanEnable: {
        if (forcedU2fAvailable !== null)
            return forcedU2fAvailable;
        if (greeterPamHasU2f)
            return true;
        return greeterU2fReady || pamU2fSupportDetected;
    }

    readonly property string greeterU2fReason: {
        if (forcedU2fAvailable !== null)
            return forcedU2fAvailable ? "ready" : "probe_failed";
        if (greeterPamHasU2f)
            return "configured_externally";
        if (greeterU2fReady)
            return "ready";
        if (greeterU2fCanEnable)
            return "missing_key_registration";
        return "missing_pam_support";
    }

    readonly property string greeterU2fSource: {
        if (forcedU2fAvailable !== null)
            return forcedU2fAvailable ? "dms" : "none";
        if (greeterPamHasU2f)
            return "pam";
        if (greeterU2fCanEnable)
            return "dms";
        return "none";
    }

    // --- Aggregates ---

    readonly property bool fprintdAvailable: lockFingerprintReady || greeterFingerprintReady
    readonly property bool u2fAvailable: lockU2fReady || greeterU2fReady

    // --- Auth detection ---

    readonly property var _fprintProbeCommand: ["sh", "-c", "if command -v fprintd-list >/dev/null 2>&1; then fprintd-list \"${USER:-$(id -un)}\" 2>&1; else printf '__missing_command__\\n'; exit 127; fi"]
    readonly property var _pamProbeCommand: ["sh", "-c", "for module in pam_fprintd.so pam_u2f.so; do found=false; for dir in /usr/lib64/security /usr/lib/security /lib/security /lib/x86_64-linux-gnu/security /usr/lib/x86_64-linux-gnu/security /usr/lib/aarch64-linux-gnu/security /run/current-system/sw/lib/security; do if [ -f \"$dir/$module\" ]; then found=true; break; fi; done; printf '%s:%s\\n' \"$module\" \"$found\"; done"]

    function detectAuthCapabilities() {
        if (forcedFprintAvailable === null) {
            fingerprintProbeFinalized = false;
            Proc.runCommand("fprint-probe", _fprintProbeCommand, (output, exitCode) => {
                fingerprintProbeOutput = output || "";
                fingerprintProbeExitCode = exitCode;
                fingerprintProbeFinalized = true;
            }, 0);
        }

        pamProbeFinalized = false;
        Proc.runCommand("pam-probe", _pamProbeCommand, (output, _exitCode) => {
            pamProbeOutput = output || "";
            pamProbeFinalized = true;
        }, 0);
    }

    function detectFprintd() {
        detectAuthCapabilities();
    }

    function detectU2f() {
        detectAuthCapabilities();
    }

    // --- Auth apply pipeline ---

    property bool authApplyRunning: false
    property bool authApplyQueued: false
    property bool authApplyRerunRequested: false
    property bool authApplyTerminalFallbackFromPrecheck: false
    property string authApplyStdout: ""
    property string authApplyStderr: ""
    property string authApplySudoProbeStderr: ""
    property string authApplyTerminalFallbackStderr: ""

    function scheduleAuthApply() {
        if (!settingsRoot || settingsRoot.isGreeterMode)
            return;

        authApplyQueued = true;
        if (authApplyRunning) {
            authApplyRerunRequested = true;
            return;
        }

        authApplyDebounce.restart();
    }

    function beginAuthApply() {
        if (!authApplyQueued || authApplyRunning || !settingsRoot || settingsRoot.isGreeterMode)
            return;

        authApplyQueued = false;
        authApplyRerunRequested = false;
        authApplyStdout = "";
        authApplyStderr = "";
        authApplySudoProbeStderr = "";
        authApplyTerminalFallbackStderr = "";
        authApplyTerminalFallbackFromPrecheck = false;
        authApplyRunning = true;
        authApplySudoProbeProcess.running = true;
    }

    function launchAuthApplyTerminalFallback(fromPrecheck, details) {
        authApplyTerminalFallbackFromPrecheck = fromPrecheck;
        if (details && details !== "")
            ToastService.showInfo(I18n.tr("Authentication changes need sudo. Opening terminal so you can use password or fingerprint."), details, "", "auth-sync");
        authApplyTerminalFallbackStderr = "";
        authApplyTerminalFallbackProcess.running = true;
    }

    function finishAuthApply() {
        const shouldRerun = authApplyQueued || authApplyRerunRequested;
        authApplyRunning = false;
        authApplyRerunRequested = false;
        if (shouldRerun)
            authApplyDebounce.restart();
    }

    // --- PAM parsing helpers ---

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

    // --- Fingerprint probe output parsing ---

    function hasEnrolledFingerprintOutput(output) {
        const lower = (output || "").toLowerCase();
        if (lower.includes("has fingers enrolled") || lower.includes("has fingerprints enrolled"))
            return true;
        const lines = lower.split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
            const trimmed = lines[i].trim();
            if (trimmed.startsWith("finger:"))
                return true;
            if (trimmed.startsWith("- ") && trimmed.includes("finger"))
                return true;
        }
        return false;
    }

    function hasMissingFingerprintEnrollmentOutput(output) {
        const lower = (output || "").toLowerCase();
        return lower.includes("no fingers enrolled") || lower.includes("no fingerprints enrolled") || lower.includes("no prints enrolled");
    }

    function hasMissingFingerprintReaderOutput(output) {
        const lower = (output || "").toLowerCase();
        return lower.includes("no devices available") || lower.includes("no device available") || lower.includes("no devices found") || lower.includes("list_devices failed") || lower.includes("no device");
    }

    function parseFingerprintProbe(exitCode, output, pamFprintDetected) {
        if (hasEnrolledFingerprintOutput(output))
            return "ready";
        if (hasMissingFingerprintEnrollmentOutput(output))
            return "missing_enrollment";
        if (hasMissingFingerprintReaderOutput(output))
            return "missing_reader";
        if (exitCode === 0)
            return "missing_enrollment";
        if (exitCode === 127 || (output || "").includes("__missing_command__"))
            return "probe_failed";
        return pamFprintDetected ? "probe_failed" : "missing_pam_support";
    }

    // --- Qt tools detection ---

    function detectQtTools() {
        qtToolsDetectionProcess.running = true;
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
                    const lines = text.trim().split("\n");
                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i];
                        if (line.startsWith("qt5ct:")) {
                            settingsRoot.qt5ctAvailable = line.split(":")[1] === "true";
                        } else if (line.startsWith("qt6ct:")) {
                            settingsRoot.qt6ctAvailable = line.split(":")[1] === "true";
                        } else if (line.startsWith("gtk:")) {
                            settingsRoot.gtkAvailable = line.split(":")[1] === "true";
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: authApplyDebounce
        interval: 300
        repeat: false
        onTriggered: root.beginAuthApply()
    }

    property var authApplyProcess: Process {
        command: ["dms", "auth", "sync", "--yes"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.authApplyStdout = text || ""
        }

        stderr: StdioCollector {
            onStreamFinished: root.authApplyStderr = text || ""
        }

        onExited: exitCode => {
            const out = (root.authApplyStdout || "").trim();
            const err = (root.authApplyStderr || "").trim();

            if (exitCode === 0) {
                let details = out;
                if (err !== "")
                    details = details !== "" ? details + "\n\nstderr:\n" + err : "stderr:\n" + err;
                ToastService.showInfo(I18n.tr("Authentication changes applied."), details, "", "auth-sync");
                root.detectAuthCapabilities();
                root.finishAuthApply();
                return;
            }

            let details = "";
            if (out !== "")
                details = out;
            if (err !== "")
                details = details !== "" ? details + "\n\nstderr:\n" + err : "stderr:\n" + err;
            ToastService.showWarning(I18n.tr("Background authentication sync failed. Trying terminal mode."), details, "", "auth-sync");
            root.launchAuthApplyTerminalFallback(false, "");
        }
    }

    property var authApplySudoProbeProcess: Process {
        command: ["sudo", "-n", "true"]
        running: false

        stderr: StdioCollector {
            onStreamFinished: root.authApplySudoProbeStderr = text || ""
        }

        onExited: exitCode => {
            const err = (root.authApplySudoProbeStderr || "").trim();
            if (exitCode === 0) {
                ToastService.showInfo(I18n.tr("Applying authentication changes…"), "", "", "auth-sync");
                root.authApplyProcess.running = true;
                return;
            }

            root.launchAuthApplyTerminalFallback(true, err);
        }
    }

    property var authApplyTerminalFallbackProcess: Process {
        command: ["dms", "auth", "sync", "--terminal", "--yes"]
        running: false

        stderr: StdioCollector {
            onStreamFinished: root.authApplyTerminalFallbackStderr = text || ""
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                const message = root.authApplyTerminalFallbackFromPrecheck ? I18n.tr("Terminal opened. Complete authentication setup there; it will close automatically when done.") : I18n.tr("Terminal fallback opened. Complete authentication setup there; it will close automatically when done.");
                ToastService.showInfo(message, "", "", "auth-sync");
            } else {
                let details = (root.authApplyTerminalFallbackStderr || "").trim();
                ToastService.showError(I18n.tr("Terminal fallback failed. Install a supported terminal emulator or run 'dms auth sync' manually.") + " (exit " + exitCode + ")", details, "", "auth-sync");
            }
            root.finishAuthApply();
        }
    }

    FileView {
        id: greetdPamWatcher
        path: "/etc/pam.d/greetd"
        printErrors: false
        onLoaded: root.greetdPamText = text()
        onLoadFailed: root.greetdPamText = ""
    }

    FileView {
        id: systemAuthPamWatcher
        path: "/etc/pam.d/system-auth"
        printErrors: false
        onLoaded: root.systemAuthPamText = text()
        onLoadFailed: root.systemAuthPamText = ""
    }

    FileView {
        id: commonAuthPamWatcher
        path: "/etc/pam.d/common-auth"
        printErrors: false
        onLoaded: root.commonAuthPamText = text()
        onLoadFailed: root.commonAuthPamText = ""
    }

    FileView {
        id: passwordAuthPamWatcher
        path: "/etc/pam.d/password-auth"
        printErrors: false
        onLoaded: root.passwordAuthPamText = text()
        onLoadFailed: root.passwordAuthPamText = ""
    }

    FileView {
        id: systemLoginPamWatcher
        path: "/etc/pam.d/system-login"
        printErrors: false
        onLoaded: root.systemLoginPamText = text()
        onLoadFailed: root.systemLoginPamText = ""
    }

    FileView {
        id: systemLocalLoginPamWatcher
        path: "/etc/pam.d/system-local-login"
        printErrors: false
        onLoaded: root.systemLocalLoginPamText = text()
        onLoadFailed: root.systemLocalLoginPamText = ""
    }

    FileView {
        id: commonAuthPcPamWatcher
        path: "/etc/pam.d/common-auth-pc"
        printErrors: false
        onLoaded: root.commonAuthPcPamText = text()
        onLoadFailed: root.commonAuthPcPamText = ""
    }

    FileView {
        id: loginPamWatcher
        path: "/etc/pam.d/login"
        printErrors: false
        onLoaded: root.loginPamText = text()
        onLoadFailed: root.loginPamText = ""
    }

    FileView {
        id: dankshellU2fPamWatcher
        path: "/etc/pam.d/dankshell-u2f"
        printErrors: false
        onLoaded: root.dankshellU2fPamText = text()
        onLoadFailed: root.dankshellU2fPamText = ""
    }

    FileView {
        id: u2fKeysWatcher
        path: root.u2fKeysPath
        printErrors: false
        onLoaded: root.u2fKeysText = text()
        onLoadFailed: root.u2fKeysText = ""
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
