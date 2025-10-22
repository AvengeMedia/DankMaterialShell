import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals
import qs.Modals.Clipboard
import qs.Modals.Common
import qs.Modals.Settings
import qs.Modals.Spotlight
import qs.Modules
import qs.Modules.AppDrawer
import qs.Modules.DankDash
import qs.Modules.ControlCenter
import qs.Modules.Dock
import qs.Modules.Lock
import qs.Modules.Notepad
import qs.Modules.Notifications.Center
import qs.Widgets
import qs.Modules.Notifications.Popup
import qs.Modules.OSD
import qs.Modules.ProcessList
import qs.Modules.Settings
import qs.Modules.DankBar
import qs.Modules.DankBar.Popouts
import qs.Modules.HyprWorkspaces
import qs.Modules.Plugins
import qs.Services

Item {
    id: root

    Instantiator {
        id: daemonPluginInstantiator
        asynchronous: true
        model: Object.keys(PluginService.pluginDaemonComponents)

        delegate: Loader {
            id: daemonLoader
            property string pluginId: modelData
            sourceComponent: PluginService.pluginDaemonComponents[pluginId]

            onLoaded: {
                if (item) {
                    item.pluginService = PluginService
                    if (item.popoutService !== undefined) {
                        item.popoutService = PopoutService
                    }
                    item.pluginId = pluginId
                    console.log("Daemon plugin loaded:", pluginId)
                }
            }
        }
    }

    WallpaperBackground {}

    Lock {
        id: lock
    }

    Loader {
        id: dankBarLoader
        asynchronous: false

        property var currentPosition: SettingsData.dankBarPosition
        property bool initialized: false
        property var hyprlandOverviewLoaderRef: hyprlandOverviewLoader

        sourceComponent: DankBar {
            hyprlandOverviewLoader: dankBarLoader.hyprlandOverviewLoaderRef

            onColorPickerRequested: {
                if (colorPickerModal.shouldBeVisible) {
                    colorPickerModal.close()
                } else {
                    colorPickerModal.show()
                }
            }
        }

        Component.onCompleted: {
            initialized = true
        }

        onCurrentPositionChanged: {
            if (!initialized)
                return

            const component = sourceComponent
            sourceComponent = null
            sourceComponent = component
        }
    }

    Loader {
        id: dockLoader
        active: true
        asynchronous: false

        property var currentPosition: SettingsData.dockPosition
        property bool initialized: false

        sourceComponent: Dock {
            contextMenu: dockContextMenuLoader.item ? dockContextMenuLoader.item : null
        }

        onLoaded: {
            if (item) {
                dockContextMenuLoader.active = true
            }
        }

        Component.onCompleted: {
            initialized = true
        }

        onCurrentPositionChanged: {
            if (!initialized)
                return

            console.log("DEBUG: Dock position changed to:", currentPosition, "- recreating dock")
            const comp = sourceComponent
            sourceComponent = null
            sourceComponent = comp
        }
    }

    Loader {
        id: dankDashPopoutLoader

        active: false
        asynchronous: true

        sourceComponent: Component {
            DankDashPopout {
                id: dankDashPopout

                Component.onCompleted: {
                    PopoutService.dankDashPopout = dankDashPopout
                }
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

            Component.onCompleted: {
                PopoutService.notificationCenterPopout = notificationCenter
            }
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

        property var modalRef: colorPickerModal
        property LazyLoader powerModalLoaderRef: powerMenuModalLoader

        ControlCenterPopout {
            id: controlCenterPopout
            colorPickerModal: controlCenterLoader.modalRef
            powerMenuModalLoader: controlCenterLoader.powerModalLoaderRef

            onLockRequested: {
                lock.activate()
            }

            Component.onCompleted: {
                PopoutService.controlCenterPopout = controlCenterPopout
            }
        }
    }

    WifiPasswordModal {
        id: wifiPasswordModal

        Component.onCompleted: {
            PopoutService.wifiPasswordModal = wifiPasswordModal
        }
    }

    Connections {
        target: NetworkService

        function onCredentialsNeeded(token, ssid, setting, fields, hints, reason) {
            wifiPasswordModal.showFromPrompt(token, ssid, setting, fields, hints, reason)
        }
    }

    LazyLoader {
        id: networkInfoModalLoader

        active: false

        NetworkInfoModal {
            id: networkInfoModal

            Component.onCompleted: {
                PopoutService.networkInfoModal = networkInfoModal
            }
        }
    }

    LazyLoader {
        id: batteryPopoutLoader

        active: false

        BatteryPopout {
            id: batteryPopout

            Component.onCompleted: {
                PopoutService.batteryPopout = batteryPopout
            }
        }
    }

    LazyLoader {
        id: vpnPopoutLoader

        active: false

        VpnPopout {
            id: vpnPopout

            Component.onCompleted: {
                PopoutService.vpnPopout = vpnPopout
            }
        }
    }

    LazyLoader {
        id: powerMenuLoader

        active: false

        PowerMenu {
            id: powerMenu

            onPowerActionRequested: (action, title, message) => {
                                        if (SettingsData.powerActionConfirm) {
                                            powerConfirmModalLoader.active = true
                                            if (powerConfirmModalLoader.item) {
                                                powerConfirmModalLoader.item.confirmButtonColor = action === "poweroff" ? Theme.error : action === "reboot" ? Theme.warning : Theme.primary
                                                powerConfirmModalLoader.item.show(title, message, () => actionApply(action), function () {})
                                            }
                                        } else {
                                            actionApply(action)
                                        }
                                    }

            function actionApply(action) {
                switch (action) {
                case "logout":
                    SessionService.logout()
                    break
                case "suspend":
                    SessionService.suspend()
                    break
                case "hibernate":
                    SessionService.hibernate()
                    break
                case "reboot":
                    SessionService.reboot()
                    break
                case "poweroff":
                    SessionService.poweroff()
                    break
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

            Component.onCompleted: {
                PopoutService.processListPopout = processListPopout
            }
        }
    }

    SettingsModal {
        id: settingsModal

        Component.onCompleted: {
            PopoutService.settingsModal = settingsModal
        }
    }

    LazyLoader {
        id: appDrawerLoader

        active: false

        AppDrawerPopout {
            id: appDrawerPopout

            Component.onCompleted: {
                PopoutService.appDrawerPopout = appDrawerPopout
            }
        }
    }

    SpotlightModal {
        id: spotlightModal

        Component.onCompleted: {
            PopoutService.spotlightModal = spotlightModal
        }
    }

    ClipboardHistoryModal {
        id: clipboardHistoryModalPopup

        Component.onCompleted: {
            PopoutService.clipboardHistoryModal = clipboardHistoryModalPopup
        }
    }

    NotificationModal {
        id: notificationModal

        Component.onCompleted: {
            PopoutService.notificationModal = notificationModal
        }
    }

    DankColorPickerModal {
        id: colorPickerModal

        Component.onCompleted: {
            PopoutService.colorPickerModal = colorPickerModal
        }
    }

    LazyLoader {
        id: processListModalLoader

        active: false

        ProcessListModal {
            id: processListModal

            Component.onCompleted: {
                PopoutService.processListModal = processListModal
            }
        }
    }

    LazyLoader {
        id: systemUpdateLoader

        active: false

        SystemUpdatePopout {
            id: systemUpdatePopout

            Component.onCompleted: {
                PopoutService.systemUpdatePopout = systemUpdatePopout
            }
        }
    }

    Variants {
        id: notepadSlideoutVariants
        model: SettingsData.getFilteredScreens("notepad")

        delegate: DankSlideout {
            id: notepadSlideout
            modelData: item
            title: I18n.tr("Notepad")
            slideoutWidth: 480
            expandable: true
            expandedWidthValue: 960
            customTransparency: SettingsData.notepadTransparencyOverride

            content: Component {
                Notepad {
                    onHideRequested: {
                        notepadSlideout.hide()
                    }
                }
            }

            function toggle() {
                if (isVisible) {
                    hide()
                } else {
                    show()
                }
            }
        }
    }

    LazyLoader {
        id: powerMenuModalLoader

        active: false

        PowerMenuModal {
            id: powerMenuModal

            onPowerActionRequested: (action, title, message) => {
                                        if (SettingsData.powerActionConfirm) {
                                            powerConfirmModalLoader.active = true
                                            if (powerConfirmModalLoader.item) {
                                                powerConfirmModalLoader.item.confirmButtonColor = action === "poweroff" ? Theme.error : action === "reboot" ? Theme.warning : Theme.primary
                                                powerConfirmModalLoader.item.show(title, message, () => actionApply(action), function () {})
                                            }
                                        } else {
                                            actionApply(action)
                                        }
                                    }

            function actionApply(action) {
                switch (action) {
                case "logout":
                    SessionService.logout()
                    break
                case "suspend":
                    SessionService.suspend()
                    break
                case "hibernate":
                    SessionService.hibernate()
                    break
                case "reboot":
                    SessionService.reboot()
                    break
                case "poweroff":
                    SessionService.poweroff()
                    break
                }
            }

            Component.onCompleted: {
                PopoutService.powerMenuModal = powerMenuModal
            }
        }
    }

    LazyLoader {
        id: hyprKeybindsModalLoader

        active: false

        HyprKeybindsModal {
            id: hyprKeybindsModal

            Component.onCompleted: {
                PopoutService.hyprKeybindsModal = hyprKeybindsModal
            }
        }
    }

    DMSShellIPC {
        powerMenuModalLoader: powerMenuModalLoader
        processListModalLoader: processListModalLoader
        controlCenterLoader: controlCenterLoader
        dankDashPopoutLoader: dankDashPopoutLoader
        notepadSlideoutVariants: notepadSlideoutVariants
        hyprKeybindsModalLoader: hyprKeybindsModalLoader
        dankBarLoader: dankBarLoader
        hyprlandOverviewLoader: hyprlandOverviewLoader
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

    LazyLoader {
        id: hyprlandOverviewLoader
        active: CompositorService.isHyprland
        component: HyprlandOverview {
            id: hyprlandOverview
        }
    }
}
