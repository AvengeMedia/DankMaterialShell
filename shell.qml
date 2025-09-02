//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Modals
import qs.Modules
import qs.Modules.AppDrawer
import qs.Modules.CentcomCenter
import qs.Modules.ControlCenter
import qs.Modules.Dock
import qs.Modules.Lock
import qs.Modules.Notifications.Center
import qs.Modules.Notifications.Popup
import qs.Modules.OSD
import qs.Modules.ProcessList
import qs.Modules.Settings
import qs.Modules.TopBar
import qs.Services

ShellRoot {
    id: root

    Component.onCompleted: {
        PortalService.init()
        // Initialize DisplayService night mode functionality
        DisplayService.nightModeEnabled
    }

    WallpaperBackground {
    }

    Lock {
        id: lock

        anchors.fill: parent
    }

    Variants {
        model: SettingsData.getFilteredScreens("topBar")

        delegate: TopBar {
            modelData: item
        }

    }

    Variants {
        model: SettingsData.getFilteredScreens("dock")

        delegate: Dock {
            modelData: item
            contextMenu: dockContextMenuLoader.item ? dockContextMenuLoader.item : null
            Component.onCompleted: {
                dockContextMenuLoader.active = true
            }
        }

    }

    Loader {
        id: centcomPopoutLoader

        active: false

        sourceComponent: Component {
            CentcomPopout {
                id: centcomPopout
            }

        }

    }

    LazyLoader {
        id: dockContextMenuLoader

        active: false

        DockContextMenu {
            id: dockContextMenu
        }

    }

    LazyLoader {
        id: notificationCenterLoader

        active: false

        NotificationCenterPopout {
            id: notificationCenter
        }

    }

    Variants {
        model: SettingsData.getFilteredScreens("notifications")

        delegate: NotificationPopupManager {
            modelData: item
        }

    }

    LazyLoader {
        id: controlCenterLoader

        active: false

        ControlCenterPopout {
            id: controlCenterPopout

            onPowerActionRequested: (action, title, message) => {
                powerConfirmModalLoader.active = true
                if (powerConfirmModalLoader.item) {
                    powerConfirmModalLoader.item.confirmButtonColor = 
                        action === "poweroff" ? Theme.error : 
                        action === "reboot" ? Theme.warning : Theme.primary
                    powerConfirmModalLoader.item.show(title, message, function() {
                        switch (action) {
                        case "logout":
                            SessionService.logout()
                            break
                        case "suspend":
                            SessionService.suspend()
                            break
                        case "reboot":
                            SessionService.reboot()
                            break
                        case "poweroff":
                            SessionService.poweroff()
                            break
                        }
                    }, function() {})
                }
            }
            onLockRequested: {
                lock.activate()
            }
        }

    }

    LazyLoader {
        id: wifiPasswordModalLoader

        active: false

        WifiPasswordModal {
            id: wifiPasswordModal
        }

    }

    LazyLoader {
        id: networkInfoModalLoader

        active: false

        NetworkInfoModal {
            id: networkInfoModal
        }

    }

    LazyLoader {
        id: batteryPopoutLoader

        active: false

        BatteryPopout {
            id: batteryPopout
        }

    }

    LazyLoader {
        id: vpnPopoutLoader

        active: false

        VpnPopout {
            id: vpnPopout
        }

    }

    LazyLoader {
        id: powerMenuLoader

        active: false

        PowerMenu {
            id: powerMenu

            onPowerActionRequested: (action, title, message) => {
                powerConfirmModalLoader.active = true
                if (powerConfirmModalLoader.item) {
                    powerConfirmModalLoader.item.confirmButtonColor = 
                        action === "poweroff" ? Theme.error : 
                        action === "reboot" ? Theme.warning : Theme.primary
                    powerConfirmModalLoader.item.show(title, message, function() {
                        switch (action) {
                        case "logout":
                            SessionService.logout()
                            break
                        case "suspend":
                            SessionService.suspend()
                            break
                        case "reboot":
                            SessionService.reboot()
                            break
                        case "poweroff":
                            SessionService.poweroff()
                            break
                        }
                    }, function() {})
                }
            }
        }

    }

    LazyLoader {
        id: powerConfirmModalLoader

        active: false

        ConfirmModal {
            id: powerConfirmModal
        }

    }

    LazyLoader {
        id: processListPopoutLoader

        active: false

        ProcessListPopout {
            id: processListPopout
        }

    }

    SettingsModal {
        id: settingsModal
    }

    LazyLoader {
        id: appDrawerLoader

        active: false

        AppDrawerPopout {
            id: appDrawerPopout
        }

    }

    SpotlightModal {
        id: spotlightModal
    }

    ClipboardHistoryModal {
        id: clipboardHistoryModalPopup
    }

    NotificationModal {
        id: notificationModal
    }

    LazyLoader {
        id: processListModalLoader

        active: false

        ProcessListModal {
            id: processListModal
        }

    }

    LazyLoader {
        id: notepadModalLoader

        active: false

        NotepadModal {
            id: notepadModal
        }
    }

    LazyLoader {
        id: powerMenuModalLoader

        active: false

        PowerMenuModal {
            id: powerMenuModal

            onPowerActionRequested: (action, title, message) => {
                powerConfirmModalLoader.active = true
                if (powerConfirmModalLoader.item) {
                    powerConfirmModalLoader.item.confirmButtonColor = 
                        action === "poweroff" ? Theme.error : 
                        action === "reboot" ? Theme.warning : Theme.primary
                    powerConfirmModalLoader.item.show(title, message, function() {
                        switch (action) {
                        case "logout":
                            SessionService.logout()
                            break
                        case "suspend":
                            SessionService.suspend()
                            break
                        case "reboot":
                            SessionService.reboot()
                            break
                        case "poweroff":
                            SessionService.poweroff()
                            break
                        }
                    }, function() {})
                }
            }
        }

    }

    IpcHandler {
        function open() {
            powerMenuModalLoader.active = true
            if (powerMenuModalLoader.item)
                powerMenuModalLoader.item.open()

            return "POWERMENU_OPEN_SUCCESS"
        }

        function close() {
            if (powerMenuModalLoader.item)
                powerMenuModalLoader.item.close()

            return "POWERMENU_CLOSE_SUCCESS"
        }

        function toggle() {
            powerMenuModalLoader.active = true
            if (powerMenuModalLoader.item)
                powerMenuModalLoader.item.toggle()

            return "POWERMENU_TOGGLE_SUCCESS"
        }

        target: "powermenu"
    }

    IpcHandler {
        function open() {
            processListModalLoader.active = true
            if (processListModalLoader.item)
                processListModalLoader.item.show()

            return "PROCESSLIST_OPEN_SUCCESS"
        }

        function close() {
            if (processListModalLoader.item)
                processListModalLoader.item.hide()

            return "PROCESSLIST_CLOSE_SUCCESS"
        }

        function toggle() {
            processListModalLoader.active = true
            if (processListModalLoader.item)
                processListModalLoader.item.toggle()

            return "PROCESSLIST_TOGGLE_SUCCESS"
        }

        target: "processlist"
    }

    IpcHandler {
        function open() {
            notepadModalLoader.active = true
            if (notepadModalLoader.item)
                notepadModalLoader.item.show()

            return "NOTEPAD_OPEN_SUCCESS"
        }

        function close() {
            if (notepadModalLoader.item)
                notepadModalLoader.item.hide()

            return "NOTEPAD_CLOSE_SUCCESS"
        }

        function toggle() {
            notepadModalLoader.active = true
            if (notepadModalLoader.item)
                notepadModalLoader.item.toggle()

            return "NOTEPAD_TOGGLE_SUCCESS"
        }

        target: "notepad"
    }

    Variants {
        model: SettingsData.getFilteredScreens("toast")

        delegate: Toast {
            modelData: item
            visible: ToastService.toastVisible
        }

    }

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: VolumeOSD {
            modelData: item
        }

    }

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: MicMuteOSD {
            modelData: item
        }

    }

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: BrightnessOSD {
            modelData: item
        }

    }

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: IdleInhibitorOSD {
            modelData: item
        }

    }

}
