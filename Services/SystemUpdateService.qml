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
    property string updChecker: ""
    property string pkgManager: ""
    property string distribution: ""
    property bool distributionSupported: false
    property string shellVersion: ""

    readonly property var archBasedUCSettings: {
        "listUpdatesSettings": {
            "params": [],
            "correctExitCodes": [0, 2]   // Exit code 0 = updates available, 2 = no updates
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

    readonly property var archBasedPMSettings: {
        "listUpdatesSettings": {
            "params": ["-Qu"],
            "correctExitCodes": [0, 1]   // Exit code 0 = updates available, 1 = no updates
        },
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

    readonly property var fedoraBasedPMSettings: {
        "listUpdatesSettings": {
            "params": ["list", "--upgrades", "--quiet", "--color=never"],
            "correctExitCodes": [0, 1]   // Exit code 0 = updates available, 1 = no updates
        },
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

    readonly property var updateCheckerParams: {
        "checkupdates": archBasedUCSettings
    }
    readonly property var packageManagerParams: {
        "yay": archBasedPMSettings,
        "paru": archBasedPMSettings,
        "dnf": fedoraBasedPMSettings
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
                    updateFinderDetection.running = true
                    pkgManagerDetection.running = true
                    checkForUpdates()
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
        id: updateFinderDetection
        command: ["sh", "-c", "which checkupdates"]

        onExited: (exitCode) => {
            if (exitCode === 0) {
                const exeFound = stdout.text.trim()
                updChecker = exeFound.split('/').pop()
            } else {
                console.warn("SystemUpdate: No update checker found. Will use package manager.")
            }
        }

        stdout: StdioCollector {}
    }

    Process {
        id: pkgManagerDetection
        command: ["sh", "-c", "which paru || which yay || which dnf"]

        onExited: (exitCode) => {
            if (exitCode === 0) {
                const exeFound = stdout.text.trim()
                pkgManager = exeFound.split('/').pop()
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
            const correctExitCodes = updChecker.length > 0 ?
                [updChecker].concat(updateCheckerParams[updChecker].listUpdatesSettings.correctExitCodes) :
                [pkgManager].concat(packageManagerParams[pkgManager].listUpdatesSettings.correctExitCodes)
            if (correctExitCodes.includes(exitCode)) {
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
        if (!distributionSupported || (!pkgManager || !updChecker) || isChecking) return

        isChecking = true
        hasError = false
        if (updChecker.length > 0) {
            updateChecker.command = [updChecker].concat(updateCheckerParams[updChecker].listUpdatesSettings.params)
        } else {
            updateChecker.command = [pkgManager].concat(packageManagerParams[pkgManager].listUpdatesSettings.params)
        }
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

        if (SettingsData.updaterUseCustomCommand && SettingsData.updaterCustomCommand.length > 0) {
            const updateCommand = `${SettingsData.updaterCustomCommand} && echo "Updates complete! Press Enter to close..." && read`
            const termClass = SettingsData.updaterTerminalAdditionalParams

            var finalCommand = [terminal]
            if (termClass.length > 0) {
                finalCommand = finalCommand.concat(termClass.split(" "))
            }
            finalCommand.push("-e")
            finalCommand.push("sh")
            finalCommand.push("-c")
            finalCommand.push(updateCommand)
            updater.command = finalCommand
        } else {
            const params = packageManagerParams[pkgManager].upgradeSettings.params.join(" ")
            const sudo = packageManagerParams[pkgManager].upgradeSettings.requiresSudo ? "sudo" : ""
            const updateCommand = `${sudo} ${pkgManager} ${params} && echo "Updates complete! Press Enter to close..." && read`

            updater.command = [terminal, "-e", "sh", "-c", updateCommand]
        }
        updater.running = true
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: distributionSupported && pkgManager
        onTriggered: checkForUpdates()
    }
}
