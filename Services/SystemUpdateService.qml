pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property var availableUpdates: []
    property bool isChecking: false
    property bool hasError: false
    property string errorMessage: ""
    property string pkgManager: ""
    property string distribution: ""
    property bool distributionSupported: false
    property string shellVersion: ""

    readonly property var archBasedSettings: {
        "listUpdatesParams": ["-Qu"],
        "upgradeSettings": {
            "params": ["-Syu"],
            "requiresSudo": false
        },
        "parserSettings": {
            "lineRegex": /^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/,
            "entryProducer": function (match) {
                return {
                    "name": match[1],
                    "currentVersion": match[2],
                    "newVersion": match[3],
                    "description": `${match[1]} ${match[2]} → ${match[3]}`
                }
            }
        }
    }

    readonly property var packageManagerParams: {
        "yay": archBasedSettings,
        "paru": archBasedSettings,
        "dnf": {
            "listUpdatesParams": ["list", "--upgrades", "--quiet", "--color=never"],
            "upgradeSettings": {
                "params": ["upgrade"],
                "requiresSudo": true
            },
            "parserSettings": {
                "lineRegex": /^([^\s]+)\s+([^\s]+)\s+.*$/,
                "entryProducer": function (match) {
                    return {
                        "name": match[1],
                        "currentVersion": "",
                        "newVersion": match[2],
                        "description": `${match[1]} → ${match[2]}`
                    }
                }
            }
        }
    }
    readonly property list<string> supportedDistributions: ["arch", "cachyos", "manjaro", "endeavouros", "fedora"]
    readonly property int updateCount: availableUpdates.length
    readonly property bool helperAvailable: pkgManager !== "" && distributionSupported

    Process {
        id: distributionDetection
        command: ["sh", "-c", "cat /etc/os-release | grep '^ID=' | cut -d'=' -f2 | tr -d '\"'"]
        running: true

        onExited: (exitCode) => {
            if (exitCode === 0) {
                distribution = stdout.text.trim().toLowerCase()
                distributionSupported = supportedDistributions.includes(distribution)

                if (distributionSupported) {
                    helperDetection.running = true
                } else {
                    console.warn("SystemUpdate: Unsupported distribution:", distribution)
                }
            } else {
                console.warn("SystemUpdate: Failed to detect distribution")
            }
        }

        stdout: StdioCollector {}

        Component.onCompleted: {
            versionDetection.running = true
        }
    }

    Process {
        id: versionDetection
        command: ["sh", "-c", "if [ -d .git ]; then echo \"(git) $(git rev-parse --short HEAD)\"; elif [ -f VERSION ]; then cat VERSION; fi"]

        stdout: StdioCollector {
            onStreamFinished: {
                shellVersion = text.trim()
            }            
        }
    }

    Process {
        id: helperDetection
        command: ["sh", "-c", "which paru || which yay || which dnf"]

        onExited: (exitCode) => {
            if (exitCode === 0) {
                const helperPath = stdout.text.trim()
                pkgManager = helperPath.split('/').pop()
                checkForUpdates()
            } else {
                console.warn("SystemUpdate: No package manager found")
            }
        }

        stdout: StdioCollector {}
    }

    Process {
        id: updateChecker

        onExited: (exitCode) => {
            isChecking = false
            if (exitCode === 0 || exitCode === 1) {
                // Exit code 0 = updates available, 1 = no updates
                parseUpdates(stdout.text)
                hasError = false
                errorMessage = ""
            } else {
                hasError = true
                errorMessage = "Failed to check for updates"
                console.warn("SystemUpdate: Update check failed with code:", exitCode)
            }
        }

        stdout: StdioCollector {}
    }

    Process {
        id: updater
        onExited: (exitCode) => {
            checkForUpdates()
        }
    }

    function checkForUpdates() {
        if (!distributionSupported || !pkgManager || isChecking) return

        isChecking = true
        hasError = false
        updateChecker.command = [pkgManager].concat(packageManagerParams[pkgManager].listUpdatesParams)
        updateChecker.running = true
    }

    function parseUpdates(output) {
        const lines = output.trim().split('\n').filter(line => line.trim())
        const updates = []

        const regex = packageManagerParams[pkgManager].parserSettings.lineRegex
        const entryProducer = packageManagerParams[pkgManager].parserSettings.entryProducer

        for (const line of lines) {
            const match = line.match(regex)
            if (match) {
                updates.push(entryProducer(match))
            }
        }

        availableUpdates = updates
    }

    function runUpdates() {
        if (!distributionSupported || !pkgManager || updateCount === 0) return

        const terminal = Quickshell.env("TERMINAL") || "xterm"
        const params = packageManagerParams[pkgManager].upgradeSettings.params.join(" ")
        const sudo = packageManagerParams[pkgManager].upgradeSettings.requiresSudo ? "sudo" : ""
        const updateCommand = `${sudo} ${pkgManager} ${params} && echo "Updates complete! Press Enter to close..." && read`

        updater.command = [terminal, "-e", "sh", "-c", updateCommand]
        updater.running = true
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: distributionSupported && pkgManager
        onTriggered: checkForUpdates()
    }
}
