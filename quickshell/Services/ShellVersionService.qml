pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string shellVersion: ""
    property string shellCodename: ""
    property string semverVersion: ""

    function getParsedShellVersion() {
        return parseVersion(semverVersion);
    }

    Process {
        id: versionDetection
        running: true
        command: ["sh", "-c", `cd "${Quickshell.shellDir}" && if [ -d .git ]; then echo "(git) $(git rev-parse --short HEAD)"; elif [ -f VERSION ]; then cat VERSION; fi`]

        stdout: StdioCollector {
            onStreamFinished: shellVersion = text.trim()
        }
    }

    Process {
        id: semverDetection
        running: true
        command: ["sh", "-c", `cd "${Quickshell.shellDir}" && if [ -f VERSION ]; then cat VERSION; fi`]

        stdout: StdioCollector {
            onStreamFinished: semverVersion = text.trim()
        }
    }

    Process {
        id: codenameDetection
        running: true
        command: ["sh", "-c", `cd "${Quickshell.shellDir}" && if [ -f CODENAME ]; then cat CODENAME; fi`]

        stdout: StdioCollector {
            onStreamFinished: shellCodename = text.trim()
        }
    }

    function parseVersion(versionStr) {
        if (!versionStr || typeof versionStr !== "string") {
            return {
                major: 0,
                minor: 0,
                patch: 0
            };
        }
        let v = versionStr.trim();
        if (v.startsWith("v")) {
            v = v.substring(1);
        }
        const dashIdx = v.indexOf("-");
        if (dashIdx !== -1) {
            v = v.substring(0, dashIdx);
        }
        const plusIdx = v.indexOf("+");
        if (plusIdx !== -1) {
            v = v.substring(0, plusIdx);
        }
        const parts = v.split(".");
        return {
            major: parseInt(parts[0], 10) || 0,
            minor: parseInt(parts[1], 10) || 0,
            patch: parseInt(parts[2], 10) || 0
        };
    }

    function compareVersions(v1, v2) {
        if (v1.major !== v2.major) {
            return v1.major - v2.major;
        }
        if (v1.minor !== v2.minor) {
            return v1.minor - v2.minor;
        }
        return v1.patch - v2.patch;
    }

    function checkVersionRequirement(requirementStr, currentVersion) {
        if (!requirementStr || typeof requirementStr !== "string") {
            return true;
        }
        const req = requirementStr.trim();
        let operator = ">=";
        let versionPart = req;
        switch (true) {
        case req.startsWith(">="):
            operator = ">=";
            versionPart = req.substring(2);
            break;
        case req.startsWith("<="):
            operator = "<=";
            versionPart = req.substring(2);
            break;
        case req.startsWith(">"):
            operator = ">";
            versionPart = req.substring(1);
            break;
        case req.startsWith("<"):
            operator = "<";
            versionPart = req.substring(1);
            break;
        case req.startsWith("="):
            operator = "=";
            versionPart = req.substring(1);
            break;
        }

        const reqVersion = parseVersion(versionPart);
        const cmp = compareVersions(currentVersion, reqVersion);
        switch (operator) {
        case ">=":
            return cmp >= 0;
        case ">":
            return cmp > 0;
        case "<=":
            return cmp <= 0;
        case "<":
            return cmp < 0;
        case "=":
            return cmp === 0;
        default:
            return cmp >= 0;
        }
    }
}
