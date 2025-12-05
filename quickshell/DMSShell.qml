import QtQuick
import Quickshell
import qs.Common
import qs.Modals
import qs.Modals.Clipboard
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
import qs.Modules.DankBar
import qs.Modules.DankBar.Popouts
import qs.Modules.WorkspaceOverlays
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
                    item.pluginService = PluginService;
                    if (item.popoutService !== undefined) {
                        item.popoutService = PopoutService;
                    }
                    item.pluginId = pluginId;
                    console.info("Daemon plugin loaded:", pluginId);
                }
            }
        }
    }

    Loader {
        id: blurredWallpaperBackgroundLoader
        active: SettingsData.blurredWallpaperLayer && CompositorService.isNiri
        asynchronous: false

        sourceComponent: BlurredWallpaperBackground {}
    }

    WallpaperBackground {}

    Lock {
        id: lock
    }

    Variants {
        model: Quickshell.screens

        delegate: Loader {
            id: fadeWindowLoader
            required property var modelData
            active: SettingsData.fadeToLockEnabled
            asynchronous: false

            sourceComponent: FadeToLockWindow {
                screen: fadeWindowLoader.modelData

                onFadeCompleted: {
                    IdleService.lockRequested();
                }

                onFadeCancelled: {
                    console.log("Fade to lock cancelled by user on screen:", fadeWindowLoader.modelData.name);
                }
            }

            Connections {
                target: IdleService
                enabled: fadeWindowLoader.item !== null

                function onFadeToLockRequested() {
                    if (fadeWindowLoader.item) {
                        fadeWindowLoader.item.startFade();
                    }
                }

                function onCancelFadeToLock() {
                    if (fadeWindowLoader.item) {
                        fadeWindowLoader.item.cancelFade();
                    }
                }
            }
        }
    }

    Repeater {
        id: dankBarRepeater
        model: ScriptModel {
            id: barRepeaterModel
            values: {
                const configs = SettingsData.barConfigs;
                return configs
                    .map(c => ({ id: c.id, position: c.position }))
                    .sort((a, b) => {
                        const aVertical = a.position === SettingsData.Position.Left || a.position === SettingsData.Position.Right;
                        const bVertical = b.position === SettingsData.Position.Left || b.position === SettingsData.Position.Right;
                        return aVertical - bVertical;
                    });
            }
        }

        property var hyprlandOverviewLoaderRef: hyprlandOverviewLoader

        delegate: Loader {
            id: barLoader
            required property var modelData
            property var barConfig: SettingsData.barConfigs.find(cfg => cfg.id === modelData.id) || null
            active: barConfig?.enabled ?? false
            asynchronous: false

            sourceComponent: DankBar {
                barConfig: barLoader.barConfig
                hyprlandOverviewLoader: dankBarRepeater.hyprlandOverviewLoaderRef

                onColorPickerRequested: {
                    if (colorPickerModal.shouldBeVisible) {
                        colorPickerModal.close();
                    } else {
                        colorPickerModal.show();
                    }
                }
            }
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
                dockContextMenuLoader.active = true;
            }
        }

        Component.onCompleted: {
            initialized = true;
        }

        onCurrentPositionChanged: {
            if (!initialized)
                return;
            const comp = sourceComponent;
            sourceComponent = null;
            sourceComponent = comp;
        }
    }

    Loader {
        id: dankDashPopoutLoader

        active: false
        asynchronous: false

        sourceComponent: Component {
            DankDashPopout {
                id: dankDashPopout

                Component.onCompleted: {
                    PopoutService.dankDashPopout = dankDashPopout;
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
                PopoutService.notificationCenterPopout = notificationCenter;
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
                lock.activate();
            }

            Component.onCompleted: {
                PopoutService.controlCenterPopout = controlCenterPopout;
            }
        }
    }

    WifiPasswordModal {
        id: wifiPasswordModal

        Component.onCompleted: {
            PopoutService.wifiPasswordModal = wifiPasswordModal;
        }
    }

    PolkitAuthModal {
        id: polkitAuthModal

        Component.onCompleted: {
            PopoutService.polkitAuthModal = polkitAuthModal;
        }
    }

    BluetoothPairingModal {
        id: bluetoothPairingModal

        Component.onCompleted: {
            PopoutService.bluetoothPairingModal = bluetoothPairingModal;
        }
    }

    property string lastCredentialsToken: ""
    property var lastCredentialsTime: 0

    Connections {
        target: NetworkService

        function onCredentialsNeeded(token, ssid, setting, fields, hints, reason, connType, connName, vpnService, fieldsInfo) {
            const now = Date.now();
            const timeSinceLastPrompt = now - lastCredentialsTime;

            if (wifiPasswordModal.visible && timeSinceLastPrompt < 1000) {
                NetworkService.cancelCredentials(lastCredentialsToken);
                lastCredentialsToken = token;
                lastCredentialsTime = now;
                wifiPasswordModal.showFromPrompt(token, ssid, setting, fields, hints, reason, connType, connName, vpnService, fieldsInfo);
                return;
            }

            lastCredentialsToken = token;
            lastCredentialsTime = now;
            wifiPasswordModal.showFromPrompt(token, ssid, setting, fields, hints, reason, connType, connName, vpnService, fieldsInfo);
        }
    }

    LazyLoader {
        id: networkInfoModalLoader

        active: false

        NetworkInfoModal {
            id: networkInfoModal

            Component.onCompleted: {
                PopoutService.networkInfoModal = networkInfoModal;
            }
        }
    }

    LazyLoader {
        id: batteryPopoutLoader

        active: false

        BatteryPopout {
            id: batteryPopout

            Component.onCompleted: {
                PopoutService.batteryPopout = batteryPopout;
            }
        }
    }

    LazyLoader {
        id: layoutPopoutLoader

        active: false

        DWLLayoutPopout {
            id: layoutPopout

            Component.onCompleted: {
                PopoutService.layoutPopout = layoutPopout;
            }
        }
    }

    LazyLoader {
        id: vpnPopoutLoader

        active: false

        VpnPopout {
            id: vpnPopout

            Component.onCompleted: {
                PopoutService.vpnPopout = vpnPopout;
            }
        }
    }

    LazyLoader {
        id: processListPopoutLoader

        active: false

        ProcessListPopout {
            id: processListPopout

            Component.onCompleted: {
                PopoutService.processListPopout = processListPopout;
            }
        }
    }

    LazyLoader {
        id: settingsModalLoader

        active: false

        Component.onCompleted: {
            PopoutService.settingsModalLoader = settingsModalLoader;
        }

        onActiveChanged: {
            if (active && item) {
                PopoutService.settingsModal = item;
                PopoutService._onSettingsModalLoaded();
            }
        }

        SettingsModal {
            id: settingsModal
            property bool wasShown: false

            onVisibleChanged: {
                if (visible) {
                    wasShown = true;
                } else if (wasShown) {
                    PopoutService.unloadSettings();
                }
            }
        }
    }

    LazyLoader {
        id: appDrawerLoader

        active: false

        AppDrawerPopout {
            id: appDrawerPopout

            Component.onCompleted: {
                PopoutService.appDrawerPopout = appDrawerPopout;
            }
        }
    }

    SpotlightModal {
        id: spotlightModal

        Component.onCompleted: {
            PopoutService.spotlightModal = spotlightModal;
        }
    }

    ClipboardHistoryModal {
        id: clipboardHistoryModalPopup

        Component.onCompleted: {
            PopoutService.clipboardHistoryModal = clipboardHistoryModalPopup;
        }
    }

    NotificationModal {
        id: notificationModal

        Component.onCompleted: {
            PopoutService.notificationModal = notificationModal;
        }
    }

    BrowserPickerModal {
        id: browserPickerModal
    }

    AppPickerModal {
        id: filePickerModal
        title: I18n.tr("Open with...")

        function shellEscape(str) {
            return "'" + str.replace(/'/g, "'\\''") + "'"
        }

        onApplicationSelected: (app, filePath) => {
            if (!app) return

            let cmd = app.exec || ""
            const escapedPath = shellEscape(filePath)
            const escapedUri = shellEscape("file://" + filePath)

            let hasField = false
            if (cmd.includes("%f")) { cmd = cmd.replace("%f", escapedPath); hasField = true }
            else if (cmd.includes("%F")) { cmd = cmd.replace("%F", escapedPath); hasField = true }
            else if (cmd.includes("%u")) { cmd = cmd.replace("%u", escapedUri); hasField = true }
            else if (cmd.includes("%U")) { cmd = cmd.replace("%U", escapedUri); hasField = true }

            cmd = cmd.replace(/%[ikc]/g, "")

            if (!hasField) {
                cmd += " " + escapedPath
            }

            console.log("FilePicker: Launching", cmd)

            Quickshell.execDetached({
                command: ["sh", "-c", cmd]
            })
        }
    }

    Connections {
        target: DMSService
        function onOpenUrlRequested(url) {
            browserPickerModal.url = url
            browserPickerModal.open()
        }

        function onAppPickerRequested(data) {
            console.log("DMSShell: App picker requested with data:", JSON.stringify(data))

            if (!data || !data.target) {
                console.warn("DMSShell: Invalid app picker request data")
                return
            }

            filePickerModal.targetData = data.target
            filePickerModal.targetDataLabel = data.requestType || "file"

            if (data.categories && data.categories.length > 0) {
                filePickerModal.categoryFilter = data.categories
            } else {
                filePickerModal.categoryFilter = []
            }

            filePickerModal.usageHistoryKey = "filePickerUsageHistory"
            filePickerModal.open()
        }
    }

    DankColorPickerModal {
        id: colorPickerModal

        Component.onCompleted: {
            PopoutService.colorPickerModal = colorPickerModal;
        }
    }

    LazyLoader {
        id: processListModalLoader

        active: false

        ProcessListModal {
            id: processListModal

            Component.onCompleted: {
                PopoutService.processListModal = processListModal;
            }
        }
    }

    LazyLoader {
        id: systemUpdateLoader

        active: false

        SystemUpdatePopout {
            id: systemUpdatePopout

            Component.onCompleted: {
                PopoutService.systemUpdatePopout = systemUpdatePopout;
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
                        notepadSlideout.hide();
                    }
                }
            }

            function toggle() {
                if (isVisible) {
                    hide();
                } else {
                    show();
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
                switch (action) {
                case "logout":
                    SessionService.logout();
                    break;
                case "suspend":
                    SessionService.suspend();
                    break;
                case "hibernate":
                    SessionService.hibernate();
                    break;
                case "reboot":
                    SessionService.reboot();
                    break;
                case "poweroff":
                    SessionService.poweroff();
                    break;
                }
            }

            onLockRequested: {
                lock.activate();
            }

            Component.onCompleted: {
                PopoutService.powerMenuModal = powerMenuModal;
            }
        }
    }

    LazyLoader {
        id: hyprKeybindsModalLoader

        active: false

        KeybindsModal {
            id: keybindsModal

            Component.onCompleted: {
                PopoutService.hyprKeybindsModal = keybindsModal;
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
        dankBarRepeater: dankBarRepeater
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

        delegate: MediaVolumeOSD {
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

    Loader {
        id: powerProfileWatcherLoader
        active: SettingsData.osdPowerProfileEnabled
        source: "Services/PowerProfileWatcher.qml"
    }

    Variants {
        model: SettingsData.osdPowerProfileEnabled ? SettingsData.getFilteredScreens("osd") : []

        delegate: PowerProfileOSD {
            modelData: item
        }
    }

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: CapsLockOSD {
            modelData: item
        }
    }

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: AudioOutputOSD {
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

    LazyLoader {
        id: niriOverviewOverlayLoader
        active: CompositorService.isNiri && SettingsData.niriOverviewOverlayEnabled
        component: NiriOverviewOverlay {
            id: niriOverviewOverlay
        }
    }
}
