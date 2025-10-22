pragma Singleton

pragma ComponentBehavior

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool accountsServiceAvailable: false
    property string systemProfileImage: ""
    property string profileImage: ""
    property bool settingsPortalAvailable: false
    property int systemColorScheme: 0

    property bool freedeskAvailable: false
    property string colorSchemeCommand: ""
    property string pendingProfileImage: ""

    readonly property string socketPath: Quickshell.env("DMS_SOCKET")

    function init() {}

    function getSystemProfileImage() {
        if (!freedeskAvailable)
            return

        const username = Quickshell.env("USER")
        if (!username)
            return

        DMSService.sendRequest("freedesktop.accounts.getUserIconFile", {
                                   "username": username
                               }, response => {
                                   if (response.result && response.result.success) {
                                       const iconFile = response.result.value || ""
                                       if (iconFile && iconFile !== "" && iconFile !== "/var/lib/AccountsService/icons/") {
                                           systemProfileImage = iconFile
                                           if (!profileImage || profileImage === "") {
                                               profileImage = iconFile
                                           }
                                       }
                                   }
                               })
    }

    function getUserProfileImage(username) {
        if (!username) {
            profileImage = ""
            return
        }
        if (Quickshell.env("DMS_RUN_GREETER") === "1" || Quickshell.env("DMS_RUN_GREETER") === "true") {
            profileImage = ""
            return
        }

        if (!freedeskAvailable) {
            profileImage = ""
            return
        }

        DMSService.sendRequest("freedesktop.accounts.getUserIconFile", {
                                   "username": username
                               }, response => {
                                   if (response.result && response.result.success) {
                                       const icon = response.result.value || ""
                                       if (icon && icon !== "" && icon !== "/var/lib/AccountsService/icons/") {
                                           profileImage = icon
                                       } else {
                                           profileImage = ""
                                       }
                                   } else {
                                       profileImage = ""
                                   }
                               })
    }

    function setProfileImage(imagePath) {
        if (accountsServiceAvailable) {
            pendingProfileImage = imagePath
            setSystemProfileImage(imagePath || "")
        } else {
            profileImage = imagePath
        }
    }

    function getSystemColorScheme() {
        if (typeof SettingsData !== "undefined" && SettingsData.syncModeWithPortal === false) {
            return
        }
        if (!freedeskAvailable)
            return

        DMSService.sendRequest("freedesktop.settings.getColorScheme", null, response => {
                                   if (response.result) {
                                       systemColorScheme = response.result.value || 0
                                   }
                               })
    }

    function setLightMode(isLightMode) {
        if (typeof SettingsData !== "undefined" && SettingsData.syncModeWithPortal === false) {
            return
        }
        setSystemColorScheme(isLightMode)
    }

    function setSystemColorScheme(isLightMode) {
        if (typeof SettingsData !== "undefined" && SettingsData.syncModeWithPortal === false) {
            return
        }

        const targetScheme = isLightMode ? "default" : "prefer-dark"

        if (colorSchemeCommand === "gsettings") {
            Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", targetScheme])
        }
        if (colorSchemeCommand === "dconf") {
            Quickshell.execDetached(["dconf", "write", "/org/gnome/desktop/interface/color-scheme", `'${targetScheme}'`])
        }
    }

    function setSystemIconTheme(themeName) {
        if (!settingsPortalAvailable || !freedeskAvailable)
            return

        DMSService.sendRequest("freedesktop.settings.setIconTheme", {
                                   "iconTheme": themeName
                               }, response => {
                                   if (response.error) {
                                       console.warn("PortalService: Failed to set icon theme:", response.error)
                                   }
                               })
    }

    function setSystemProfileImage(imagePath) {
        if (!accountsServiceAvailable || !freedeskAvailable)
            return

        DMSService.sendRequest("freedesktop.accounts.setIconFile", {
                                   "path": imagePath || ""
                               }, response => {
                                   if (response.error) {
                                       console.warn("PortalService: Failed to set icon file:", response.error)

                                       const errorMsg = response.error.toString()
                                       let userMessage = I18n.tr("Failed to set profile image")

                                       if (errorMsg.includes("too large")) {
                                           userMessage = I18n.tr("Profile image is too large. Please use a smaller image.")
                                       } else if (errorMsg.includes("permission")) {
                                           userMessage = I18n.tr("Permission denied to set profile image.")
                                       } else if (errorMsg.includes("not found") || errorMsg.includes("does not exist")) {
                                           userMessage = I18n.tr("Selected image file not found.")
                                       } else {
                                           userMessage = I18n.tr("Failed to set profile image: ") + errorMsg.split(":").pop().trim()
                                       }

                                       Quickshell.execDetached(["notify-send", "-u", "normal", "-a", "DMS", "-i", "error", I18n.tr("Profile Image Error"), userMessage])

                                       pendingProfileImage = ""
                                   } else {
                                       profileImage = pendingProfileImage
                                       pendingProfileImage = ""
                                       Qt.callLater(() => getSystemProfileImage())
                                   }
                               })
    }

    Component.onCompleted: {
        if (socketPath && socketPath.length > 0) {
            checkDMSCapabilities()
        } else {
            console.log("PortalService: DMS_SOCKET not set")
        }
        colorSchemeDetector.running = true
    }

    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            if (DMSService.isConnected) {
                checkDMSCapabilities()
            }
        }
    }

    Connections {
        target: DMSService
        enabled: DMSService.isConnected

        function onCapabilitiesChanged() {
            checkDMSCapabilities()
        }
    }

    function checkDMSCapabilities() {
        if (!DMSService.isConnected) {
            return
        }

        if (DMSService.capabilities.length === 0) {
            return
        }

        freedeskAvailable = DMSService.capabilities.includes("freedesktop")
        if (freedeskAvailable) {
            checkAccountsService()
            checkSettingsPortal()
        } else {
            console.log("PortalService: freedesktop capability not available in DMS")
        }
    }

    function checkAccountsService() {
        if (!freedeskAvailable)
            return

        DMSService.sendRequest("freedesktop.getState", null, response => {
                                   if (response.result && response.result.accounts) {
                                       accountsServiceAvailable = response.result.accounts.available || false
                                       if (accountsServiceAvailable) {
                                           getSystemProfileImage()
                                       }
                                   }
                               })
    }

    function checkSettingsPortal() {
        if (!freedeskAvailable)
            return

        DMSService.sendRequest("freedesktop.getState", null, response => {
                                   if (response.result && response.result.settings) {
                                       settingsPortalAvailable = response.result.settings.available || false
                                       if (settingsPortalAvailable && SettingsData.syncModeWithPortal) {
                                           getSystemColorScheme()
                                       }
                                   }
                               })
    }

    function getGreeterUserProfileImage(username) {
        if (!username) {
            profileImage = ""
            return
        }
        userProfileCheckProcess.command = ["bash", "-c", `uid=$(id -u ${username} 2>/dev/null) && [ -n "$uid" ] && dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User$uid org.freedesktop.DBus.Properties.Get string:org.freedesktop.Accounts.User string:IconFile 2>/dev/null | grep -oP 'string "\\K[^"]+' || echo ""`]
        userProfileCheckProcess.running = true
    }

    Process {
        id: userProfileCheckProcess
        command: []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const trimmed = text.trim()
                if (trimmed && trimmed !== "" && !trimmed.includes("Error") && trimmed !== "/var/lib/AccountsService/icons/") {
                    root.profileImage = trimmed
                } else {
                    root.profileImage = ""
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.profileImage = ""
            }
        }
    }

    Process {
        id: colorSchemeDetector
        command: ["bash", "-c", "command -v gsettings || command -v dconf"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const cmd = text.trim()
                if (cmd.includes("gsettings")) {
                    root.colorSchemeCommand = "gsettings"
                } else if (cmd.includes("dconf")) {
                    root.colorSchemeCommand = "dconf"
                }
            }
        }
    }

    IpcHandler {
        target: "profile"

        function getImage(): string {
            return root.profileImage
        }

        function setImage(path: string): string {
            if (!path) {
                return "ERROR: No path provided"
            }

            const absolutePath = path.startsWith("/") ? path : `${StandardPaths.writableLocation(StandardPaths.HomeLocation)}/${path}`

            try {
                root.setProfileImage(absolutePath)
                return "SUCCESS: Profile image set to " + absolutePath
            } catch (e) {
                return "ERROR: Failed to set profile image: " + e.toString()
            }
        }

        function clearImage(): string {
            root.setProfileImage("")
            return "SUCCESS: Profile image cleared"
        }
    }
}
