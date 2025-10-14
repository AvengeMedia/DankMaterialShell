pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root

    property string username: ""
    property string fullName: ""
    property string profilePicture: ""
    property string uptime: ""
    property string shortUptime: ""
    property string hostname: ""
    property bool profileAvailable: false

    function getUserInfo() {
        Proc.runCommand("userInfo", ["bash", "-c", "echo \"$USER|$(getent passwd $USER | cut -d: -f5 | cut -d, -f1)|$(hostname)\""], (output, exitCode) => {
            if (exitCode !== 0) {
                root.username = "User"
                root.fullName = "User"
                root.hostname = "System"
                return
            }
            const parts = output.trim().split("|")
            if (parts.length >= 3) {
                root.username = parts[0] || ""
                root.fullName = parts[1] || parts[0] || ""
                root.hostname = parts[2] || ""
            }
        }, 0)
    }

    function getUptime() {
        Proc.runCommand("uptime", ["cat", "/proc/uptime"], (output, exitCode) => {
            if (exitCode !== 0) {
                root.uptime = "Unknown"
                return
            }
            const seconds = parseInt(output.split(" ")[0])
            const days = Math.floor(seconds / 86400)
            const hours = Math.floor((seconds % 86400) / 3600)
            const minutes = Math.floor((seconds % 3600) / 60)

            const parts = []
            if (days > 0) {
                parts.push(`${days} day${days === 1 ? "" : "s"}`)
            }
            if (hours > 0) {
                parts.push(`${hours} hour${hours === 1 ? "" : "s"}`)
            }
            if (minutes > 0) {
                parts.push(`${minutes} minute${minutes === 1 ? "" : "s"}`)
            }

            if (parts.length > 0) {
                root.uptime = `up ${parts.join(", ")}`
            } else {
                root.uptime = `up ${seconds} seconds`
            }

            let shortUptime = "up"
            if (days > 0) {
                shortUptime += ` ${days}d`
            }
            if (hours > 0) {
                shortUptime += ` ${hours}h`
            }
            if (minutes > 0) {
                shortUptime += ` ${minutes}m`
            }
            root.shortUptime = shortUptime
        }, 0)
    }

    function refreshUserInfo() {
        getUserInfo()
        getUptime()
    }

    Component.onCompleted: {
        getUserInfo()
        getUptime()
    }
}
