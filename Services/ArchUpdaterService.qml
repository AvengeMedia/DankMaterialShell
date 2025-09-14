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
    property string aurHelper: ""

    readonly property int updateCount: availableUpdates.length
    readonly property bool helperAvailable: aurHelper !== ""

    Process {
        id: helperDetection
        command: ["sh", "-c", "which paru || which yay"]
        running: true

        onExited: (exitCode) => {
            if (exitCode === 0) {
                const helperPath = stdout.text.trim()
                aurHelper = helperPath.split('/').pop()
                checkForUpdates()
            } else {
                console.warn("ArchUpdater: No AUR helper found")
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
                console.warn("ArchUpdater: Update check failed with code:", exitCode)
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
        if (!helperAvailable || isChecking) return

        isChecking = true
        hasError = false
        updateChecker.command = [aurHelper, "-Qu"]
        updateChecker.running = true
    }

    function parseUpdates(output) {
        const lines = output.trim().split('\n').filter(line => line.trim())
        const updates = []

        for (const line of lines) {
            const match = line.match(/^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/)
            if (match) {
                updates.push({
                    name: match[1],
                    currentVersion: match[2],
                    newVersion: match[3],
                    description: `${match[1]} ${match[2]} → ${match[3]}`
                })
            }
        }

        availableUpdates = updates
    }

    function runUpdates() {
        if (!helperAvailable || updateCount === 0) return

        const terminal = Quickshell.env("TERMINAL") || "xterm"
        const updateCommand = `${aurHelper} -Syu && echo "Updates complete! Press Enter to close..." && read`

        updater.command = [terminal, "-e", "sh", "-c", updateCommand]
        updater.running = true
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: helperAvailable
        onTriggered: checkForUpdates()
    }
}