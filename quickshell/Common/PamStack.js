.pragma library

var FAILLOCK_DEFAULT_DENY = 3;
const LOCKOUT_MODULES = ["pam_faillock.so", "pam_tally2.so", "pam_tally.so"];

function stripComment(line) {
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

function liveLines(text) {
    if (!text)
        return [];
    return text.split(/\r?\n/).map(stripComment).filter(line => line);
}

function isLockoutLine(line) {
    return LOCKOUT_MODULES.some(module => line.includes(module));
}

function moduleEnabled(text, moduleName) {
    if (!moduleName)
        return false;
    return liveLines(text).some(line => line.includes(moduleName));
}

function includesFile(text, filename) {
    if (!filename)
        return false;
    return liveLines(text).some(line => line.includes(filename) && (line.includes("include") || line.includes("substack") || line.startsWith("@include")));
}

function stackHasModule(primaryText, includedStacks, moduleName) {
    if (moduleEnabled(primaryText, moduleName))
        return true;
    return includedStacks.some(([filename, text]) => includesFile(primaryText, filename) && moduleEnabled(text, moduleName));
}

function usesLockoutPolicy(text) {
    return liveLines(text).some(isLockoutLine);
}

function pamDenyValue(text) {
    for (const line of liveLines(text)) {
        if (!isLockoutLine(line))
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

function faillockDenyValue(configText) {
    for (const line of liveLines(configText)) {
        const denyMatch = line.match(/^deny\s*=\s*(\d+)\s*$/i);
        if (!denyMatch)
            continue;
        const parsed = parseInt(denyMatch[1], 10);
        if (!isNaN(parsed))
            return parsed;
    }
    return -1;
}

function attemptLimitHint(pamTexts, faillockText) {
    let lockoutConfigured = false;
    let denyFromPam = -1;
    for (const text of pamTexts) {
        if (!text)
            continue;
        if (usesLockoutPolicy(text))
            lockoutConfigured = true;
        const denyValue = pamDenyValue(text);
        if (denyValue >= 0 && (denyFromPam < 0 || denyValue < denyFromPam))
            denyFromPam = denyValue;
    }
    if (!lockoutConfigured)
        return 0;
    const denyFromConfig = faillockDenyValue(faillockText);
    if (denyFromConfig >= 0)
        return denyFromConfig;
    if (denyFromPam >= 0)
        return denyFromPam;
    return FAILLOCK_DEFAULT_DENY;
}

function isLikelyLockoutMessage(message) {
    const lower = (message || "").toLowerCase();
    return lower.includes("account is locked") || lower.includes("too many") || lower.includes("maximum number of");
}

function hasEnrolledFingerprintOutput(output) {
    const lower = (output || "").toLowerCase();
    if (lower.includes("has fingers enrolled") || lower.includes("has fingerprints enrolled"))
        return true;
    return lower.split(/\r?\n/).some(line => {
        const trimmed = line.trim();
        return trimmed.startsWith("finger:") || (trimmed.startsWith("- ") && trimmed.includes("finger"));
    });
}

function hasMissingFingerprintEnrollmentOutput(output) {
    const lower = (output || "").toLowerCase();
    return lower.includes("no fingers enrolled") || lower.includes("no fingerprints enrolled") || lower.includes("no prints enrolled");
}

function hasMissingFingerprintReaderOutput(output) {
    const lower = (output || "").toLowerCase();
    return lower.includes("no devices available") || lower.includes("no device available") || lower.includes("no devices found") || lower.includes("list_devices failed") || lower.includes("no device");
}

function fingerprintProbeState(exitCode, output, pamFprintDetected) {
    if (hasEnrolledFingerprintOutput(output))
        return "ready";
    if (hasMissingFingerprintEnrollmentOutput(output))
        return "missing_enrollment";
    if (hasMissingFingerprintReaderOutput(output))
        return "missing_reader";
    if (exitCode === 0)
        return "missing_enrollment";
    if (exitCode === 127 || (output || "").includes("__missing_command__"))
        return "missing_pam_support";
    return pamFprintDetected ? "probe_failed" : "missing_pam_support";
}
