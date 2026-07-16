pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modals
import qs.Modals.Changelog
import qs.Modals.Clipboard
import qs.Modals.Common
import qs.Modals.Greeter
import qs.Modals.Settings
import qs.Modals.DankLauncherV2
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
import qs.Modules.DankBar.Popouts
import qs.Modules.WorkspaceOverlays
import qs.Modules.Settings.DisplayConfig
import qs.Services

Item {
    id: root
    readonly property var log: Log.scoped("DMSShell")
    readonly property var _sessionsServiceRef: SessionsService

    property var core: null

    property bool osdSurfacesLoaded: false
    property int pendingOsdResumeReloads: 0

    function recreateOsdSurfaces() {
        OSDManager.currentOSDsByScreen = ({});
        osdSurfacesLoaded = false;
        osdSurfaceReloadTimer.restart();
    }

    DesktopWidgetLayer {}

    Lock {
        id: lock
    }

    Variants {
        model: Quickshell.screens

        delegate: Loader {
            id: fadeWindowLoader
            required property var modelData
            readonly property FadeToLockWindow loadedWindow: item as FadeToLockWindow
            active: SettingsData.fadeToLockEnabled
            asynchronous: false

            sourceComponent: FadeToLockWindow {
                screen: fadeWindowLoader.modelData

                onFadeCompleted: {
                    IdleService.lockRequested();
                }

                onFadeCancelled: {
                    root.log.debug("Fade to lock cancelled by user on screen:", fadeWindowLoader.modelData.name);
                }
            }

            Connections {
                target: IdleService
                enabled: fadeWindowLoader.loadedWindow !== null

                function onFadeToLockRequested() {
                    if (fadeWindowLoader.loadedWindow) {
                        fadeWindowLoader.loadedWindow.startFade();
                    }
                }

                function onCancelFadeToLock() {
                    if (fadeWindowLoader.loadedWindow) {
                        fadeWindowLoader.loadedWindow.cancelFade();
                    }
                }

                function onDismissFadeToLock() {
                    if (fadeWindowLoader.loadedWindow) {
                        fadeWindowLoader.loadedWindow.dismiss();
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Loader {
            id: fadeDpmsWindowLoader
            required property var modelData
            readonly property FadeToDpmsWindow loadedWindow: item as FadeToDpmsWindow
            active: SettingsData.fadeToDpmsEnabled
            asynchronous: false

            sourceComponent: FadeToDpmsWindow {
                screen: fadeDpmsWindowLoader.modelData

                onFadeCompleted: {
                    IdleService.requestMonitorOff();
                }

                onFadeCancelled: {
                    root.log.debug("Fade to DPMS cancelled by user on screen:", fadeDpmsWindowLoader.modelData.name);
                }
            }

            Connections {
                target: IdleService
                enabled: fadeDpmsWindowLoader.loadedWindow !== null

                function onFadeToDpmsRequested() {
                    if (fadeDpmsWindowLoader.loadedWindow) {
                        fadeDpmsWindowLoader.loadedWindow.startFade();
                    }
                }

                function onCancelFadeToDpms() {
                    if (fadeDpmsWindowLoader.loadedWindow) {
                        fadeDpmsWindowLoader.loadedWindow.cancelFade();
                    }
                }

                function onRequestMonitorOn() {
                    if (!fadeDpmsWindowLoader.loadedWindow)
                        return;
                    fadeDpmsWindowLoader.loadedWindow.cancelFade();
                }
            }
        }
    }

    Connections {
        target: root.core

        function on_BarLayoutStateJsonChanged() {
            dockRecreateDebounce.restart();
        }

        function onSurfaceRecoveryPass() {
            root.dockEnabled = false;
            Qt.callLater(() => {
                root.dockEnabled = true;
            });
        }
    }

    property bool dockEnabled: false

    Timer {
        id: dockRecreateDebounce
        interval: 500
        repeat: false
        onTriggered: {
            root.dockEnabled = false;
            Qt.callLater(() => {
                root.dockEnabled = true;
            });
        }
    }

    Timer {
        id: loginSoundTimer
        // Half a second delay before playing login sound, otherwise the sound may be cut off
        // 50 is the minimum that seems to work, but 500 is safer
        interval: 500
        repeat: false
        onTriggered: {
            AudioService.playLoginSoundIfApplicable();
        }
    }

    Timer {
        id: osdResumeRecreateTimer
        interval: 400
        repeat: false
        onTriggered: {
            root.recreateOsdSurfaces();
            root.pendingOsdResumeReloads--;

            if (root.pendingOsdResumeReloads <= 0) {
                root.pendingOsdResumeReloads = 0;
                interval = 400;
                return;
            }

            interval = 1400;
            restart();
        }
    }

    Timer {
        id: osdSurfaceReloadTimer
        interval: 120
        repeat: false
        onTriggered: root.osdSurfacesLoaded = true
    }

    Timer {
        id: osdStartupTimer
        interval: 1000
        repeat: false
        onTriggered: root.osdSurfacesLoaded = true
    }

    Component.onCompleted: {
        dockEnabled = true;
        loginSoundTimer.start();
        osdStartupTimer.start();

        // These are dummy references just to trigger the singletons onCompleted to trigger
        PolkitService.polkitAvailable;
        DisplayConfigState.hasOutputBackend;
        PortalService.systemColorScheme;
    }

    Loader {
        id: dockLoader
        active: root.dockEnabled
        asynchronous: false

        property var currentPosition: SettingsData.dockPosition
        property bool initialized: false

        sourceComponent: Dock {
            contextMenu: dockContextMenuLoader.item ? dockContextMenuLoader.item : null
            trashContextMenu: dockTrashContextMenuLoader.item ? dockTrashContextMenuLoader.item : null
        }

        onLoaded: {
            if (item) {
                dockContextMenuLoader.active = true;
                if (SettingsData.dockShowTrash) {
                    dockTrashContextMenuLoader.active = true;
                }
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

        Component.onCompleted: {
            PopoutService.dankDashPopoutLoader = dankDashPopoutLoader;
        }

        onLoaded: {
            if (item) {
                PopoutService.dankDashPopout = item;
                PopoutService._onDankDashPopoutLoaded();
            }
        }

        sourceComponent: Component {
            DankDashPopout {
                id: dankDashPopout
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
        id: dockTrashContextMenuLoader

        active: false

        DockTrashContextMenu {
            id: dockTrashContextMenu
        }
    }

    Connections {
        target: SettingsData
        function onDockShowTrashChanged() {
            if (SettingsData.dockShowTrash) {
                dockTrashContextMenuLoader.active = true;
            }
        }
    }

    ConfirmModal {
        id: emptyTrashConfirm
    }

    Connections {
        target: TrashService
        function onEmptyTrashConfirmRequested(itemCount) {
            emptyTrashConfirm.showWithOptions({
                title: I18n.tr("Empty Trash?"),
                message: I18n.tr("Permanently delete %1 item(s)? This cannot be undone.").arg(itemCount),
                confirmText: I18n.tr("Empty"),
                cancelText: I18n.tr("Cancel"),
                confirmColor: Theme.error,
                onConfirm: () => TrashService.emptyTrash()
            });
        }
    }

    LazyLoader {
        id: notificationCenterLoader

        active: false

        Component.onCompleted: {
            PopoutService.notificationCenterLoader = notificationCenterLoader;
        }

        NotificationCenterPopout {
            id: notificationCenter
            onPopoutClosed: PopoutService.unloadNotificationCenter()

            Component.onCompleted: {
                PopoutService.notificationCenterPopout = notificationCenter;
            }
        }
    }

    Variants {
        model: SettingsData.notificationFocusedMonitor ? Quickshell.screens : SettingsData.getFilteredScreens("notifications")

        delegate: NotificationPopupManager {}
    }

    LazyLoader {
        id: controlCenterLoader

        active: false

        property var modalRef: colorPickerModal
        property LazyLoader powerModalLoaderRef: powerMenuModalLoader

        Component.onCompleted: {
            PopoutService.controlCenterLoader = controlCenterLoader;
        }

        ControlCenterPopout {
            id: controlCenterPopout
            colorPickerModal: controlCenterLoader.modalRef
            powerMenuModalLoader: controlCenterLoader.powerModalLoaderRef
            onPopoutClosed: PopoutService.unloadControlCenter()

            onLockRequested: {
                lock.activate();
            }

            Component.onCompleted: {
                PopoutService.controlCenterPopout = controlCenterPopout;
            }
        }
    }

    LazyLoader {
        id: wifiPasswordModalLoader
        active: false
        readonly property WifiPasswordModal loadedModal: item as WifiPasswordModal

        Component.onCompleted: {
            PopoutService.wifiPasswordModalLoader = wifiPasswordModalLoader;
        }

        WifiPasswordModal {
            id: wifiPasswordModalItem

            Component.onCompleted: {
                PopoutService.wifiPasswordModal = wifiPasswordModalItem;
            }
        }
    }

    LazyLoader {
        id: wifiQRCodeModalLoader
        active: false

        Component.onCompleted: {
            PopoutService.wifiQRCodeModalLoader = wifiQRCodeModalLoader;
        }

        WifiQRCodeModal {
            id: wifiQRCodeModalItem

            Component.onCompleted: {
                PopoutService.wifiQRCodeModal = wifiQRCodeModalItem;
            }
        }
    }

    LazyLoader {
        id: polkitAuthModalLoader
        active: false
        readonly property PolkitAuthModal loadedModal: item as PolkitAuthModal

        PolkitAuthModal {
            id: polkitAuthModal

            Component.onCompleted: {
                PopoutService.polkitAuthModal = polkitAuthModal;
            }
        }
    }

    Connections {
        target: PolkitService.agent
        enabled: PolkitService.polkitAvailable

        function onAuthenticationRequestStarted() {
            if (PopoutService.systemUpdatePopout?.shouldBeVisible)
                return;
            polkitAuthModalLoader.active = true;
            if (polkitAuthModalLoader.loadedModal)
                polkitAuthModalLoader.loadedModal.show();
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
            const alreadyShown = wifiPasswordModalLoader.loadedModal && wifiPasswordModalLoader.loadedModal.shouldBeVisible;
            if (alreadyShown && token === root.lastCredentialsToken)
                return;

            wifiPasswordModalLoader.active = true;
            if (!wifiPasswordModalLoader.loadedModal)
                return;

            if (alreadyShown && root.lastCredentialsToken !== "" && root.lastCredentialsToken !== token)
                NetworkService.cancelCredentials(root.lastCredentialsToken);

            root.lastCredentialsToken = token;
            root.lastCredentialsTime = Date.now();
            wifiPasswordModalLoader.loadedModal.showFromPrompt(token, ssid, setting, fields, hints, reason, connType, connName, vpnService, fieldsInfo);
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

        Component.onCompleted: {
            PopoutService.batteryPopoutLoader = batteryPopoutLoader;
        }

        BatteryPopout {
            id: batteryPopout
            onPopoutClosed: PopoutService.unloadBattery()

            Component.onCompleted: {
                PopoutService.batteryPopout = batteryPopout;
            }
        }
    }

    LazyLoader {
        id: layoutPopoutLoader

        active: false

        Component.onCompleted: {
            PopoutService.layoutPopoutLoader = layoutPopoutLoader;
        }

        DWLLayoutPopout {
            id: layoutPopout
            onPopoutClosed: PopoutService.unloadLayoutPopout()

            Component.onCompleted: {
                PopoutService.layoutPopout = layoutPopout;
            }
        }
    }

    LazyLoader {
        id: vpnPopoutLoader

        active: false

        Component.onCompleted: {
            PopoutService.vpnPopoutLoader = vpnPopoutLoader;
        }

        VpnPopout {
            id: vpnPopout
            onPopoutClosed: PopoutService.unloadVpn()

            Component.onCompleted: {
                PopoutService.vpnPopout = vpnPopout;
            }
        }
    }

    LazyLoader {
        id: processListPopoutLoader

        active: false

        Component.onCompleted: {
            PopoutService.processListPopoutLoader = processListPopoutLoader;
        }

        ProcessListPopout {
            id: processListPopout
            onPopoutClosed: PopoutService.unloadProcessListPopout()

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

        Component.onCompleted: {
            PopoutService.appDrawerLoader = appDrawerLoader;
        }

        AppDrawerPopout {
            id: appDrawerPopout
            onPopoutClosed: PopoutService.unloadAppDrawer()

            Component.onCompleted: {
                PopoutService.appDrawerPopout = appDrawerPopout;
            }
        }
    }

    LazyLoader {
        id: dankLauncherV2ModalLoader

        active: false

        Component.onCompleted: {
            PopoutService.dankLauncherV2ModalLoader = dankLauncherV2ModalLoader;
        }

        DankLauncherV2Modal {
            id: dankLauncherV2Modal

            Component.onCompleted: {
                PopoutService.dankLauncherV2Modal = dankLauncherV2Modal;
                PopoutService._onDankLauncherV2ModalLoaded();
            }
        }
    }

    LazyLoader {
        id: spotlightBarModalLoader

        active: false

        Component.onCompleted: {
            PopoutService.spotlightBarModalLoader = spotlightBarModalLoader;
        }

        DankLauncherV2ModalSpotlight {
            id: spotlightBarModal

            Component.onCompleted: {
                PopoutService.spotlightBarModal = spotlightBarModal;
                PopoutService._onSpotlightBarModalLoaded();
            }
        }
    }

    LazyLoader {
        id: clipboardHistoryPopoutLoader

        active: false

        Component.onCompleted: {
            PopoutService.clipboardHistoryPopoutLoader = clipboardHistoryPopoutLoader;
        }

        ClipboardHistoryPopout {
            id: clipboardHistoryPopout
            onPopoutClosed: PopoutService.unloadClipboardHistoryPopout()

            Component.onCompleted: {
                PopoutService.clipboardHistoryPopout = clipboardHistoryPopout;
            }
        }
    }

    MuxModal {
        id: muxModal
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
        viewMode: SettingsData.appPickerViewMode || "grid"

        onViewModeChanged: {
            SettingsData.set("appPickerViewMode", viewMode);
        }

        function shellEscape(str) {
            return "'" + str.replace(/'/g, "'\\''") + "'";
        }

        onApplicationSelected: (app, filePath) => {
            if (!app)
                return;
            let cmd = app.exec || "";
            const escapedPath = shellEscape(filePath);
            const escapedUri = shellEscape("file://" + filePath);

            let hasField = false;
            if (cmd.includes("%f")) {
                cmd = cmd.replace("%f", escapedPath);
                hasField = true;
            } else if (cmd.includes("%F")) {
                cmd = cmd.replace("%F", escapedPath);
                hasField = true;
            } else if (cmd.includes("%u")) {
                cmd = cmd.replace("%u", escapedUri);
                hasField = true;
            } else if (cmd.includes("%U")) {
                cmd = cmd.replace("%U", escapedUri);
                hasField = true;
            }

            cmd = cmd.replace(/%[ikc]/g, "");

            if (!hasField) {
                cmd += " " + escapedPath;
            }

            log.debug("FilePicker: Launching", cmd);

            Quickshell.execDetached({
                command: ["sh", "-c", cmd]
            });
        }
    }

    Connections {
        target: DMSService
        function onOpenUrlRequested(url) {
            if (url.startsWith("dms://theme/install/")) {
                var themeId = url.replace("dms://theme/install/", "").split(/[?#]/)[0];
                if (themeId) {
                    PopoutService.pendingThemeInstall = themeId;
                    PopoutService.openSettingsWithTab("theme");
                }
                return;
            }
            if (url.startsWith("dms://plugin/install/")) {
                var pluginId = url.replace("dms://plugin/install/", "").split(/[?#]/)[0];
                if (pluginId) {
                    PopoutService.pendingPluginInstall = pluginId;
                    PopoutService.openSettingsWithTab("plugins");
                }
                return;
            }
            browserPickerModal.url = url;
            browserPickerModal.open();
        }

        function onAppPickerRequested(data) {
            root.log.debug("App picker requested with data:", JSON.stringify(data));

            if (!data || !data.target) {
                root.log.warn("Invalid app picker request data");
                return;
            }

            filePickerModal.targetData = data.target;
            filePickerModal.targetDataLabel = data.requestType || "file";
            filePickerModal.mimeType = data.mimeType || "";
            filePickerModal.rememberMimeTypes = [];

            if (data.categories && data.categories.length > 0) {
                filePickerModal.categoryFilter = data.categories;
            } else {
                filePickerModal.categoryFilter = [];
            }

            filePickerModal.usageHistoryKey = "filePickerUsageHistory";
            filePickerModal.open();
        }
    }

    Connections {
        target: SessionService

        function onSessionResumed() {
            root.pendingOsdResumeReloads = 2;
            osdResumeRecreateTimer.interval = 400;
            osdResumeRecreateTimer.restart();
        }
    }

    DankColorPickerModal {
        id: colorPickerModal

        Component.onCompleted: {
            PopoutService.colorPickerModal = colorPickerModal;
        }
    }

    LazyLoader {
        id: workspaceRenameModalLoader

        active: false

        Component.onCompleted: PopoutService.workspaceRenameModalLoader = workspaceRenameModalLoader

        WorkspaceRenameModal {
            id: workspaceRenameModal
        }
    }

    LazyLoader {
        id: windowRuleModalLoader

        active: false

        Component.onCompleted: PopoutService.windowRuleModalLoader = windowRuleModalLoader

        WindowRuleModal {
            id: windowRuleModal
        }
    }

    LazyLoader {
        id: processListModalLoader

        active: false

        Component.onCompleted: PopoutService.processListModalLoader = processListModalLoader

        ProcessListModal {
            id: processListModal
            property bool wasShown: false

            Component.onCompleted: {
                PopoutService.processListModal = processListModal;
            }

            onVisibleChanged: {
                if (visible) {
                    wasShown = true;
                } else if (wasShown) {
                    PopoutService.unloadProcessListModal();
                }
            }
        }
    }

    LazyLoader {
        id: systemUpdateLoader

        active: false

        Component.onCompleted: {
            PopoutService.systemUpdateLoader = systemUpdateLoader;
        }

        SystemUpdatePopout {
            id: systemUpdatePopout
            onPopoutClosed: {
                if (systemUpdatePopout._reopenAfterUpgrade) {
                    return;
                }
                PopoutService.unloadSystemUpdate();
            }

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
            title: I18n.tr("Notepad")
            slideoutWidth: 480
            expandable: true
            expandedWidthValue: 960
            edgeGap: SettingsData.notepadEffectiveEdgeGap
            slideEdge: SettingsData.notepadSlideoutSide

            onIsVisibleChanged: {
                if (isVisible)
                    PopoutService.notepadPopout?.hide();
            }

            content: Component {
                Notepad {
                    slideout: notepadSlideout
                    onHideRequested: notepadSlideout.hide()
                    onPopoutRequested: {
                        notepadSlideout.hide();
                        PopoutService.openNotepadPopout();
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

        onInstancesChanged: PopoutService.notepadSlideouts = instances
        Component.onCompleted: PopoutService.notepadSlideouts = instances
    }

    LazyLoader {
        id: notepadPopoutLoader
        active: false

        Component.onCompleted: {
            PopoutService.notepadPopoutLoader = notepadPopoutLoader;
        }

        onActiveChanged: {
            if (active && item) {
                PopoutService.notepadPopout = item;
                PopoutService._onNotepadPopoutLoaded();
            }
        }

        NotepadPopoutWindow {}
    }

    LazyLoader {
        id: powerMenuModalLoader

        active: false

        Component.onCompleted: {
            PopoutService.powerMenuModalLoader = powerMenuModalLoader;
        }

        PowerMenuModal {
            id: powerMenuModal

            onPowerActionRequested: (action, title, message) => {
                PopoutService.closeControlCenter();
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
                PopoutService.closeControlCenter();
                lock.activate();
            }

            onSwitchUserRequested: {
                switchUserModalLoader.active = true;
                Qt.callLater(() => {
                    if (switchUserModalLoader.loadedModal)
                        switchUserModalLoader.loadedModal.showFromPowerMenu();
                });
            }

            Component.onCompleted: {
                PopoutService.powerMenuModal = powerMenuModal;
            }
        }
    }

    LazyLoader {
        id: switchUserModalLoader

        active: false
        readonly property SwitchUserModal loadedModal: item as SwitchUserModal

        SwitchUserModal {
            id: switchUserModal
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

    LazyLoader {
        id: powerProfileModalLoader

        active: false

        PowerProfileModal {
            id: powerProfileModal

            Component.onCompleted: {
                PopoutService.powerProfileModal = powerProfileModal;
            }
        }

        Component.onCompleted: {
            PopoutService.powerProfileModalLoader = powerProfileModalLoader;
        }
    }

    DMSShellIPC {
        powerMenuModalLoader: powerMenuModalLoader
        processListModalLoader: processListModalLoader
        controlCenterLoader: controlCenterLoader
        dankDashPopoutLoader: dankDashPopoutLoader
        notepadSlideoutVariants: notepadSlideoutVariants
        hyprKeybindsModalLoader: hyprKeybindsModalLoader
        dankBarRepeater: root.core?.dankBarRepeater ?? null
        hyprlandOverviewLoader: root.core?.hyprlandOverviewLoader ?? null
        workspaceRenameModalLoader: workspaceRenameModalLoader
        windowRuleModalLoader: windowRuleModalLoader
    }

    Variants {
        model: SettingsData.getFilteredScreens("toast")

        delegate: Toast {
            visible: ToastService.toastVisible
        }
    }

    Loader {
        id: osdSurfacesLoader
        active: root.osdSurfacesLoaded
        asynchronous: false

        sourceComponent: Component {
            Item {
                Variants {
                    model: SettingsData.getFilteredScreens("osd")

                    delegate: VolumeOSD {}
                }

                Variants {
                    model: SettingsData.getFilteredScreens("osd")

                    delegate: MediaVolumeOSD {}
                }

                Variants {
                    model: SettingsData.getFilteredScreens("osd")

                    delegate: MediaPlaybackOSD {}
                }

                Variants {
                    model: SettingsData.getFilteredScreens("osd")

                    delegate: MicVolumeOSD {}
                }

                Variants {
                    model: SettingsData.getFilteredScreens("osd")

                    delegate: BrightnessOSD {}
                }

                Variants {
                    model: SettingsData.getFilteredScreens("osd")

                    delegate: IdleInhibitorOSD {}
                }

                Variants {
                    model: SettingsData.osdPowerProfileEnabled ? SettingsData.getFilteredScreens("osd") : []

                    delegate: PowerProfileOSD {}
                }

                Variants {
                    model: SettingsData.getFilteredScreens("osd")

                    delegate: CapsLockOSD {}
                }

                Variants {
                    model: SettingsData.getFilteredScreens("osd")

                    delegate: AudioOutputOSD {}
                }
            }
        }
    }

    LazyLoader {
        id: niriOverviewOverlayLoader
        active: CompositorService.isNiri && SettingsData.niriOverviewOverlayEnabled
        component: NiriOverviewOverlay {
            id: niriOverviewOverlay
        }
    }

    Loader {
        id: greeterLoader
        active: false
        readonly property GreeterModal loadedModal: item as GreeterModal
        sourceComponent: GreeterModal {
            onGreeterCompleted: greeterLoader.active = false
            Component.onCompleted: show()
        }

        Connections {
            target: FirstLaunchService
            function onGreeterRequested() {
                if (greeterLoader.active && greeterLoader.loadedModal) {
                    greeterLoader.loadedModal.show();
                    return;
                }
                greeterLoader.active = true;
            }
        }
    }

    Loader {
        id: changelogLoader
        active: false
        readonly property ChangelogModal loadedModal: item as ChangelogModal
        sourceComponent: ChangelogModal {
            onChangelogDismissed: changelogLoader.active = false
            Component.onCompleted: show()
        }

        Connections {
            target: ChangelogService
            function onChangelogRequested() {
                if (changelogLoader.active && changelogLoader.loadedModal) {
                    changelogLoader.loadedModal.show();
                    return;
                }
                changelogLoader.active = true;
            }
        }
    }
}
