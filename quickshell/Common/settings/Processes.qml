pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

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
    property bool fingerprintProbeStreamFinished: false
    property bool fingerprintProbeExited: false
    property string fingerprintProbeState: "probe_failed"

    property string pamSupportProbeOutput: ""
    property bool pamSupportProbeStreamFinished: false
    property bool pamSupportProbeExited: false
    property int pamSupportProbeExitCode: 0
    property bool pamFprintSupportDetected: false
    property bool pamU2fSupportDetected: false

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

    function detectQtTools() {
        qtToolsDetectionProcess.running = true;
    }

    function detectAuthCapabilities() {
        if (!settingsRoot)
            return;

        if (forcedFprintAvailable === null) {
            fingerprintProbeOutput = "";
            fingerprintProbeStreamFinished = false;
            fingerprintProbeExited = false;
            fingerprintProbeProcess.running = true;
        } else {
            fingerprintProbeState = forcedFprintAvailable ? "ready" : "probe_failed";
        }

        if (forcedFprintAvailable === null || forcedU2fAvailable === null) {
            pamFprintSupportDetected = false;
            pamU2fSupportDetected = false;
            pamSupportProbeOutput = "";
            pamSupportProbeStreamFinished = false;
            pamSupportProbeExited = false;
            pamSupportDetectionProcess.running = true;
        }

        recomputeAuthCapabilities();
    }

    function detectFprintd() {
        detectAuthCapabilities();
    }

    function detectU2f() {
        detectAuthCapabilities();
    }

    function checkPluginSettings() {
        pluginSettingsCheckProcess.running = true;
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
        const includedPamStacks = [
            ["system-auth", systemAuthPamText],
            ["common-auth", commonAuthPamText],
            ["password-auth", passwordAuthPamText],
            ["system-login", systemLoginPamText],
            ["system-local-login", systemLocalLoginPamText],
            ["common-auth-pc", commonAuthPcPamText],
            ["login", loginPamText]
        ];
        for (let i = 0; i < includedPamStacks.length; i++) {
            const stack = includedPamStacks[i];
            if (pamTextIncludesFile(greetdPamText, stack[0]) && pamModuleEnabled(stack[1], moduleName))
                return true;
        }
        return false;
    }

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
        return lower.includes("no fingers enrolled")
            || lower.includes("no fingerprints enrolled")
            || lower.includes("no prints enrolled");
    }

    function hasMissingFingerprintReaderOutput(output) {
        const lower = (output || "").toLowerCase();
        return lower.includes("no devices available")
            || lower.includes("no device available")
            || lower.includes("no devices found")
            || lower.includes("list_devices failed")
            || lower.includes("no device");
    }

    function parseFingerprintProbe(exitCode, output) {
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
        return pamFprintSupportDetected ? "probe_failed" : "missing_pam_support";
    }

    function setLockFingerprintCapability(canEnable, ready, reason) {
        settingsRoot.lockFingerprintCanEnable = canEnable;
        settingsRoot.lockFingerprintReady = ready;
        settingsRoot.lockFingerprintReason = reason;
    }

    function setLockU2fCapability(canEnable, ready, reason) {
        settingsRoot.lockU2fCanEnable = canEnable;
        settingsRoot.lockU2fReady = ready;
        settingsRoot.lockU2fReason = reason;
    }

    function setGreeterFingerprintCapability(canEnable, ready, reason, source) {
        settingsRoot.greeterFingerprintCanEnable = canEnable;
        settingsRoot.greeterFingerprintReady = ready;
        settingsRoot.greeterFingerprintReason = reason;
        settingsRoot.greeterFingerprintSource = source;
    }

    function setGreeterU2fCapability(canEnable, ready, reason, source) {
        settingsRoot.greeterU2fCanEnable = canEnable;
        settingsRoot.greeterU2fReady = ready;
        settingsRoot.greeterU2fReason = reason;
        settingsRoot.greeterU2fSource = source;
    }

    function recomputeFingerprintCapabilities() {
        if (forcedFprintAvailable !== null) {
            const reason = forcedFprintAvailable ? "ready" : "probe_failed";
            const source = forcedFprintAvailable ? "dms" : "none";
            setLockFingerprintCapability(forcedFprintAvailable, forcedFprintAvailable, reason);
            setGreeterFingerprintCapability(forcedFprintAvailable, forcedFprintAvailable, reason, source);
            return;
        }

        const state = fingerprintProbeState;

        switch (state) {
        case "ready":
            setLockFingerprintCapability(true, true, "ready");
            break;
        case "missing_enrollment":
            setLockFingerprintCapability(true, false, "missing_enrollment");
            break;
        case "missing_reader":
            setLockFingerprintCapability(false, false, "missing_reader");
            break;
        case "missing_pam_support":
            setLockFingerprintCapability(false, false, "missing_pam_support");
            break;
        default:
            setLockFingerprintCapability(false, false, "probe_failed");
            break;
        }

        if (greeterPamHasFprint) {
            switch (state) {
            case "ready":
                setGreeterFingerprintCapability(true, true, "configured_externally", "pam");
                break;
            case "missing_enrollment":
                setGreeterFingerprintCapability(true, false, "missing_enrollment", "pam");
                break;
            case "missing_reader":
                setGreeterFingerprintCapability(false, false, "missing_reader", "pam");
                break;
            default:
                setGreeterFingerprintCapability(true, false, "probe_failed", "pam");
                break;
            }
            return;
        }

        switch (state) {
        case "ready":
            setGreeterFingerprintCapability(true, true, "ready", "dms");
            break;
        case "missing_enrollment":
            setGreeterFingerprintCapability(true, false, "missing_enrollment", "dms");
            break;
        case "missing_reader":
            setGreeterFingerprintCapability(false, false, "missing_reader", "none");
            break;
        case "missing_pam_support":
            setGreeterFingerprintCapability(false, false, "missing_pam_support", "none");
            break;
        default:
            setGreeterFingerprintCapability(false, false, "probe_failed", "none");
            break;
        }
    }

    function recomputeU2fCapabilities() {
        if (forcedU2fAvailable !== null) {
            const reason = forcedU2fAvailable ? "ready" : "probe_failed";
            const source = forcedU2fAvailable ? "dms" : "none";
            setLockU2fCapability(forcedU2fAvailable, forcedU2fAvailable, reason);
            setGreeterU2fCapability(forcedU2fAvailable, forcedU2fAvailable, reason, source);
            return;
        }

        const lockReady = lockU2fCustomConfigDetected || homeU2fKeysDetected;
        const lockCanEnable = lockReady || pamU2fSupportDetected;
        const lockReason = lockReady ? "ready" : (lockCanEnable ? "missing_key_registration" : "missing_pam_support");
        setLockU2fCapability(lockCanEnable, lockReady, lockReason);

        if (greeterPamHasU2f) {
            setGreeterU2fCapability(true, true, "configured_externally", "pam");
            return;
        }

        const greeterReady = homeU2fKeysDetected;
        const greeterCanEnable = greeterReady || pamU2fSupportDetected;
        const greeterReason = greeterReady ? "ready" : (greeterCanEnable ? "missing_key_registration" : "missing_pam_support");
        setGreeterU2fCapability(greeterCanEnable, greeterReady, greeterReason, greeterCanEnable ? "dms" : "none");
    }

    function recomputeAuthCapabilities() {
        if (!settingsRoot)
            return;
        recomputeFingerprintCapabilities();
        recomputeU2fCapabilities();
        settingsRoot.fprintdAvailable = settingsRoot.lockFingerprintReady || settingsRoot.greeterFingerprintReady;
        settingsRoot.u2fAvailable = settingsRoot.lockU2fReady || settingsRoot.greeterU2fReady;
    }

    function finalizeFingerprintProbe() {
        if (!fingerprintProbeStreamFinished || !fingerprintProbeExited)
            return;
        fingerprintProbeState = parseFingerprintProbe(fingerprintProbeExitCode, fingerprintProbeOutput);
        recomputeAuthCapabilities();
    }

    function finalizePamSupportProbe() {
        if (!pamSupportProbeStreamFinished || !pamSupportProbeExited)
            return;

        pamFprintSupportDetected = false;
        pamU2fSupportDetected = false;

        const lines = (pamSupportProbeOutput || "").trim().split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split(":");
            if (parts.length !== 2)
                continue;
            if (parts[0] === "pam_fprintd.so")
                pamFprintSupportDetected = parts[1] === "true";
            else if (parts[0] === "pam_u2f.so")
                pamU2fSupportDetected = parts[1] === "true";
        }

        if (forcedFprintAvailable === null && fingerprintProbeState === "missing_pam_support")
            fingerprintProbeState = parseFingerprintProbe(fingerprintProbeExitCode, fingerprintProbeOutput);

        recomputeAuthCapabilities();
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

    property var fingerprintProbeProcess: Process {
        command: ["sh", "-c", "if command -v fprintd-list >/dev/null 2>&1; then fprintd-list \"${USER:-$(id -un)}\" 2>&1; else printf '__missing_command__\\n'; exit 127; fi"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.fingerprintProbeOutput = text || "";
                root.fingerprintProbeStreamFinished = true;
                root.finalizeFingerprintProbe();
            }
        }

        onExited: function (exitCode) {
            root.fingerprintProbeExitCode = exitCode;
            root.fingerprintProbeExited = true;
            root.finalizeFingerprintProbe();
        }
    }

    property var pamSupportDetectionProcess: Process {
        command: ["sh", "-c", "for module in pam_fprintd.so pam_u2f.so; do found=false; for dir in /usr/lib64/security /usr/lib/security /lib/security /lib/x86_64-linux-gnu/security /usr/lib/x86_64-linux-gnu/security /usr/lib/aarch64-linux-gnu/security /run/current-system/sw/lib/security; do if [ -f \"$dir/$module\" ]; then found=true; break; fi; done; printf '%s:%s\\n' \"$module\" \"$found\"; done"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.pamSupportProbeOutput = text || "";
                root.pamSupportProbeStreamFinished = true;
                root.finalizePamSupportProbe();
            }
        }

        onExited: function (exitCode) {
            root.pamSupportProbeExitCode = exitCode;
            root.pamSupportProbeExited = true;
            root.finalizePamSupportProbe();
        }
    }

    FileView {
        id: greetdPamWatcher
        path: "/etc/pam.d/greetd"
        printErrors: false
        onLoaded: {
            root.greetdPamText = text();
            root.recomputeAuthCapabilities();
        }
        onLoadFailed: {
            root.greetdPamText = "";
            root.recomputeAuthCapabilities();
        }
    }

    FileView {
        id: systemAuthPamWatcher
        path: "/etc/pam.d/system-auth"
        printErrors: false
        onLoaded: {
            root.systemAuthPamText = text();
            root.recomputeAuthCapabilities();
        }
        onLoadFailed: {
            root.systemAuthPamText = "";
            root.recomputeAuthCapabilities();
        }
    }

    FileView {
        id: commonAuthPamWatcher
        path: "/etc/pam.d/common-auth"
        printErrors: false
        onLoaded: {
            root.commonAuthPamText = text();
            root.recomputeAuthCapabilities();
        }
        onLoadFailed: {
            root.commonAuthPamText = "";
            root.recomputeAuthCapabilities();
        }
    }

    FileView {
        id: passwordAuthPamWatcher
        path: "/etc/pam.d/password-auth"
        printErrors: false
        onLoaded: {
            root.passwordAuthPamText = text();
            root.recomputeAuthCapabilities();
        }
        onLoadFailed: {
            root.passwordAuthPamText = "";
            root.recomputeAuthCapabilities();
        }
    }

    FileView {
        id: systemLoginPamWatcher
        path: "/etc/pam.d/system-login"
        printErrors: false
        onLoaded: {
            root.systemLoginPamText = text();
            root.recomputeAuthCapabilities();
        }
        onLoadFailed: {
            root.systemLoginPamText = "";
            root.recomputeAuthCapabilities();
        }
    }

    FileView {
        id: systemLocalLoginPamWatcher
        path: "/etc/pam.d/system-local-login"
        printErrors: false
        onLoaded: {
            root.systemLocalLoginPamText = text();
            root.recomputeAuthCapabilities();
        }
        onLoadFailed: {
            root.systemLocalLoginPamText = "";
            root.recomputeAuthCapabilities();
        }
    }

    FileView {
        id: commonAuthPcPamWatcher
        path: "/etc/pam.d/common-auth-pc"
        printErrors: false
        onLoaded: {
            root.commonAuthPcPamText = text();
            root.recomputeAuthCapabilities();
        }
        onLoadFailed: {
            root.commonAuthPcPamText = "";
            root.recomputeAuthCapabilities();
        }
    }

    FileView {
        id: loginPamWatcher
        path: "/etc/pam.d/login"
        printErrors: false
        onLoaded: {
            root.loginPamText = text();
            root.recomputeAuthCapabilities();
        }
        onLoadFailed: {
            root.loginPamText = "";
            root.recomputeAuthCapabilities();
        }
    }

    FileView {
        id: dankshellU2fPamWatcher
        path: "/etc/pam.d/dankshell-u2f"
        printErrors: false
        onLoaded: {
            root.dankshellU2fPamText = text();
            root.recomputeAuthCapabilities();
        }
        onLoadFailed: {
            root.dankshellU2fPamText = "";
            root.recomputeAuthCapabilities();
        }
    }

    FileView {
        id: u2fKeysWatcher
        path: root.u2fKeysPath
        printErrors: false
        onLoaded: {
            root.u2fKeysText = text();
            root.recomputeAuthCapabilities();
        }
        onLoadFailed: {
            root.u2fKeysText = "";
            root.recomputeAuthCapabilities();
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
