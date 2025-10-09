pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool accountsServiceAvailable: false
    property string systemProfileImage: ""
    property string profileImage: ""
    property bool settingsPortalAvailable: false
    property int systemColorScheme: 0

    property bool freedeskAvailable: false

    readonly property string socketPath: Quickshell.env("DMS_SOCKET")

    function init() {}

    function getSystemProfileImage() {
        if (freedeskAvailable) {
            const username = Quickshell.env("USER")
            if (!username) return

            DMSService.sendRequest("freedesktop.accounts.getUserIconFile", { username: username }, response => {
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
        } else {
            systemProfileCheckProcess.running = true
        }
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

        if (freedeskAvailable) {
            DMSService.sendRequest("freedesktop.accounts.getUserIconFile", { username: username }, response => {
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
        } else {
            userProfileCheckProcess.command = [
                "bash", "-c",
                `uid=$(id -u ${username} 2>/dev/null) && [ -n "$uid" ] && dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User$uid org.freedesktop.DBus.Properties.Get string:org.freedesktop.Accounts.User string:IconFile 2>/dev/null | grep -oP 'string "\\K[^"]+' || echo ""`
            ]
            userProfileCheckProcess.running = true
        }
    }

    function setProfileImage(imagePath) {
        profileImage = imagePath
        if (accountsServiceAvailable) {
            if (imagePath) {
                setSystemProfileImage(imagePath)
            } else {
                setSystemProfileImage("")
            }
        }
    }

    function getSystemColorScheme() {
        if (freedeskAvailable) {
            DMSService.sendRequest("freedesktop.settings.getColorScheme", null, response => {
                if (response.result) {
                    systemColorScheme = response.result.value || 0

                    if (typeof Theme !== "undefined") {
                        const shouldBeLightMode = (systemColorScheme === 2)
                        if (Theme.isLightMode !== shouldBeLightMode) {
                            Theme.isLightMode = shouldBeLightMode
                            if (typeof SessionData !== "undefined") {
                                SessionData.setLightMode(shouldBeLightMode)
                            }
                        }
                    }
                }
            })
        } else {
            systemColorSchemeCheckProcess.running = true
        }
    }

    function setLightMode(isLightMode) {
        if (settingsPortalAvailable) {
            setSystemColorScheme(isLightMode)
        }
    }

    function setSystemColorScheme(isLightMode) {
        if (!settingsPortalAvailable) return

        const colorScheme = isLightMode ? "default" : "prefer-dark"
        colorSchemeSetProcess.command = ["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", colorScheme]
        colorSchemeSetProcess.running = true
    }

    Process {
        id: colorSchemeSetProcess
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                Qt.callLater(() => getSystemColorScheme())
            }
        }
    }

    function setSystemProfileImage(imagePath) {
        if (!accountsServiceAvailable) return

        if (freedeskAvailable) {
            DMSService.sendRequest("freedesktop.accounts.setIconFile", { path: imagePath || "" }, response => {
                if (response.error) {
                    console.warn("PortalService: Failed to set icon file:", response.error)
                } else {
                    Qt.callLater(() => getSystemProfileImage())
                }
            })
        } else {
            const path = imagePath || ""
            systemProfileSetProcess.command = ["bash", "-c", `dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User$(id -u) org.freedesktop.Accounts.User.SetIconFile string:'${path}'`]
            systemProfileSetProcess.running = true
        }
    }

    Component.onCompleted: {
        if (socketPath && socketPath.length > 0) {
            checkDMSCapabilities()
        } else {
            console.log("PortalService: DMS_SOCKET not set, using fallback methods")
            checkAccountsServiceFallback()
            checkSettingsPortalFallback()
        }
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
            console.log("PortalService: freedesktop capability not available in DMS, using fallback methods")
            checkAccountsServiceFallback()
            checkSettingsPortalFallback()
        }
    }

    function checkAccountsService() {
        if (!freedeskAvailable) return

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
        if (!freedeskAvailable) return

        DMSService.sendRequest("freedesktop.getState", null, response => {
            if (response.result && response.result.settings) {
                settingsPortalAvailable = response.result.settings.available || false
                if (settingsPortalAvailable) {
                    getSystemColorScheme()
                }
            }
        })
    }

    function checkAccountsServiceFallback() {
        accountsServiceCheckProcess.running = true
    }

    function checkSettingsPortalFallback() {
        settingsPortalCheckProcess.running = true
    }

    function getGreeterUserProfileImage(username) {
        if (!username) {
            profileImage = ""
            return
        }
        userProfileCheckProcess.command = [
            "bash", "-c",
            `uid=$(id -u ${username} 2>/dev/null) && [ -n "$uid" ] && dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User$uid org.freedesktop.DBus.Properties.Get string:org.freedesktop.Accounts.User string:IconFile 2>/dev/null | grep -oP 'string "\\K[^"]+' || echo ""`
        ]
        userProfileCheckProcess.running = true
    }

    Process {
        id: accountsServiceCheckProcess
        command: ["bash", "-c", "dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts org.freedesktop.Accounts.FindUserByName string:\"$USER\""]
        running: false

        onExited: exitCode => {
            accountsServiceAvailable = (exitCode === 0)
            if (accountsServiceAvailable) {
                getSystemProfileImage()
            }
        }
    }

    Process {
        id: systemProfileCheckProcess
        command: ["bash", "-c", "dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User$(id -u) org.freedesktop.DBus.Properties.Get string:org.freedesktop.Accounts.User string:IconFile"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/string\s+"([^"]+)"/)
                if (match && match[1] && match[1] !== "" && match[1] !== "/var/lib/AccountsService/icons/") {
                    systemProfileImage = match[1]
                    if (!profileImage || profileImage === "") {
                        profileImage = systemProfileImage
                    }
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                systemProfileImage = ""
            }
        }
    }

    Process {
        id: systemProfileSetProcess
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                getSystemProfileImage()
            }
        }
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
        id: settingsPortalCheckProcess
        command: ["gdbus", "call", "--session", "--dest", "org.freedesktop.portal.Desktop", "--object-path", "/org/freedesktop/portal/desktop", "--method", "org.freedesktop.portal.Settings.ReadOne", "org.freedesktop.appearance", "color-scheme"]
        running: false

        onExited: exitCode => {
            settingsPortalAvailable = (exitCode === 0)
            if (settingsPortalAvailable) {
                getSystemColorScheme()
            }
        }
    }

    Process {
        id: systemColorSchemeCheckProcess
        command: ["gdbus", "call", "--session", "--dest", "org.freedesktop.portal.Desktop", "--object-path", "/org/freedesktop/portal/desktop", "--method", "org.freedesktop.portal.Settings.ReadOne", "org.freedesktop.appearance", "color-scheme"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/uint32 (\d+)/)
                if (match && match[1]) {
                    systemColorScheme = parseInt(match[1])

                    if (typeof Theme !== "undefined") {
                        const shouldBeLightMode = (systemColorScheme === 2)
                        if (Theme.isLightMode !== shouldBeLightMode) {
                            Theme.isLightMode = shouldBeLightMode
                            if (typeof SessionData !== "undefined") {
                                SessionData.setLightMode(shouldBeLightMode)
                            }
                        }
                    }
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                systemColorScheme = 0
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
