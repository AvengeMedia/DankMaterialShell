pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

Singleton {
    id: root

    property var controlCenterPopout: null
    property var notificationCenterPopout: null
    property var appDrawerPopout: null
    property var processListPopout: null
    property var dankDashPopout: null
    property var batteryPopout: null
    property var vpnPopout: null
    property var systemUpdatePopout: null

    property var settingsModal: null
    property var settingsModalLoader: null
    property var clipboardHistoryModal: null
    property var dankLauncherV2Modal: null
    property var dankLauncherV2ModalLoader: null
    property var powerMenuModal: null
    property var processListModal: null
    property var processListModalLoader: null
    property var colorPickerModal: null
    property var notificationModal: null
    property var wifiPasswordModal: null
    property var wifiPasswordModalLoader: null
    property var polkitAuthModal: null
    property var polkitAuthModalLoader: null
    property var bluetoothPairingModal: null
    property var networkInfoModal: null

    property var notepadSlideouts: []

    property string pendingThemeInstall: ""
    property string pendingPluginInstall: ""

    function setPosition(popout, x, y, width, section, screen) {
        if (popout && popout.setTriggerPosition && arguments.length >= 6) {
            popout.setTriggerPosition(x, y, width, section, screen);
        }
    }

    function openControlCenter(x, y, width, section, screen) {
        if (controlCenterPopout) {
            setPosition(controlCenterPopout, x, y, width, section, screen);
            controlCenterPopout.open();
        }
    }

    function closeControlCenter() {
        controlCenterPopout?.close();
    }

    function toggleControlCenter(x, y, width, section, screen) {
        if (controlCenterPopout) {
            setPosition(controlCenterPopout, x, y, width, section, screen);
            controlCenterPopout.toggle();
        }
    }

    function openNotificationCenter(x, y, width, section, screen) {
        if (notificationCenterPopout) {
            setPosition(notificationCenterPopout, x, y, width, section, screen);
            notificationCenterPopout.open();
        }
    }

    function closeNotificationCenter() {
        notificationCenterPopout?.close();
    }

    function toggleNotificationCenter(x, y, width, section, screen) {
        if (notificationCenterPopout) {
            setPosition(notificationCenterPopout, x, y, width, section, screen);
            notificationCenterPopout.toggle();
        }
    }

    function openAppDrawer(x, y, width, section, screen) {
        if (appDrawerPopout) {
            setPosition(appDrawerPopout, x, y, width, section, screen);
            appDrawerPopout.open();
        }
    }

    function closeAppDrawer() {
        appDrawerPopout?.close();
    }

    function toggleAppDrawer(x, y, width, section, screen) {
        if (appDrawerPopout) {
            setPosition(appDrawerPopout, x, y, width, section, screen);
            appDrawerPopout.toggle();
        }
    }

    function openProcessList(x, y, width, section, screen) {
        if (processListPopout) {
            setPosition(processListPopout, x, y, width, section, screen);
            processListPopout.open();
        }
    }

    function closeProcessList() {
        processListPopout?.close();
    }

    function toggleProcessList(x, y, width, section, screen) {
        if (processListPopout) {
            setPosition(processListPopout, x, y, width, section, screen);
            processListPopout.toggle();
        }
    }

    function openDankDash(tabIndex, x, y, width, section, screen) {
        if (dankDashPopout) {
            if (arguments.length >= 6) {
                setPosition(dankDashPopout, x, y, width, section, screen);
            }
            dankDashPopout.currentTabIndex = tabIndex || 0;
            dankDashPopout.dashVisible = true;
        }
    }

    function closeDankDash() {
        if (dankDashPopout) {
            dankDashPopout.dashVisible = false;
        }
    }

    function toggleDankDash(tabIndex, x, y, width, section, screen) {
        if (dankDashPopout) {
            if (arguments.length >= 6) {
                setPosition(dankDashPopout, x, y, width, section, screen);
            }
            if (dankDashPopout.dashVisible) {
                dankDashPopout.dashVisible = false;
            } else {
                dankDashPopout.currentTabIndex = tabIndex || 0;
                dankDashPopout.dashVisible = true;
            }
        }
    }

    function openBattery(x, y, width, section, screen) {
        if (batteryPopout) {
            setPosition(batteryPopout, x, y, width, section, screen);
            batteryPopout.open();
        }
    }

    function closeBattery() {
        batteryPopout?.close();
    }

    function toggleBattery(x, y, width, section, screen) {
        if (batteryPopout) {
            setPosition(batteryPopout, x, y, width, section, screen);
            batteryPopout.toggle();
        }
    }

    function openVpn(x, y, width, section, screen) {
        if (vpnPopout) {
            setPosition(vpnPopout, x, y, width, section, screen);
            vpnPopout.open();
        }
    }

    function closeVpn() {
        vpnPopout?.close();
    }

    function toggleVpn(x, y, width, section, screen) {
        if (vpnPopout) {
            setPosition(vpnPopout, x, y, width, section, screen);
            vpnPopout.toggle();
        }
    }

    function openSystemUpdate(x, y, width, section, screen) {
        if (systemUpdatePopout) {
            setPosition(systemUpdatePopout, x, y, width, section, screen);
            systemUpdatePopout.open();
        }
    }

    function closeSystemUpdate() {
        systemUpdatePopout?.close();
    }

    function toggleSystemUpdate(x, y, width, section, screen) {
        if (systemUpdatePopout) {
            setPosition(systemUpdatePopout, x, y, width, section, screen);
            systemUpdatePopout.toggle();
        }
    }

    property bool _settingsWantsOpen: false
    property bool _settingsWantsToggle: false

    property string _settingsPendingTab: ""
    property int _settingsPendingTabIndex: -1

    function openSettings() {
        if (settingsModal) {
            settingsModal.show();
        } else if (settingsModalLoader) {
            _settingsWantsOpen = true;
            _settingsWantsToggle = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function openSettingsWithTab(tabName: string) {
        if (settingsModal) {
            settingsModal.showWithTabName(tabName);
            return;
        }
        if (settingsModalLoader) {
            _settingsPendingTab = tabName;
            _settingsWantsOpen = true;
            _settingsWantsToggle = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function openSettingsWithTabIndex(tabIndex: int) {
        if (settingsModal) {
            settingsModal.showWithTab(tabIndex);
            return;
        }
        if (settingsModalLoader) {
            _settingsPendingTabIndex = tabIndex;
            _settingsWantsOpen = true;
            _settingsWantsToggle = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function closeSettings() {
        settingsModal?.close();
    }

    function toggleSettings() {
        if (settingsModal) {
            settingsModal.toggle();
        } else if (settingsModalLoader) {
            _settingsWantsToggle = true;
            _settingsWantsOpen = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function toggleSettingsWithTab(tabName: string) {
        if (settingsModal) {
            var idx = settingsModal.resolveTabIndex(tabName);
            if (idx >= 0)
                settingsModal.currentTabIndex = idx;
            settingsModal.toggle();
            return;
        }
        if (settingsModalLoader) {
            _settingsPendingTab = tabName;
            _settingsWantsToggle = true;
            _settingsWantsOpen = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function focusOrToggleSettings() {
        if (settingsModal?.visible) {
            const settingsTitle = I18n.tr("Settings", "settings window title");
            for (const toplevel of ToplevelManager.toplevels.values) {
                if (toplevel.title !== "Settings" && toplevel.title !== settingsTitle)
                    continue;
                if (toplevel.activated) {
                    settingsModal.hide();
                    return;
                }
                toplevel.activate();
                return;
            }
        }
        openSettings();
    }

    function focusOrToggleSettingsWithTab(tabName: string) {
        if (settingsModal?.visible) {
            const settingsTitle = I18n.tr("Settings", "settings window title");
            for (const toplevel of ToplevelManager.toplevels.values) {
                if (toplevel.title !== "Settings" && toplevel.title !== settingsTitle)
                    continue;
                if (toplevel.activated) {
                    settingsModal.hide();
                    return;
                }
                var idx = settingsModal.resolveTabIndex(tabName);
                if (idx >= 0)
                    settingsModal.currentTabIndex = idx;
                toplevel.activate();
                return;
            }
        }
        openSettingsWithTab(tabName);
    }

    function unloadSettings() {
        if (settingsModalLoader) {
            settingsModal = null;
            settingsModalLoader.active = false;
        }
    }

    function _onSettingsModalLoaded() {
        if (_settingsWantsOpen) {
            _settingsWantsOpen = false;
            if (_settingsPendingTabIndex >= 0) {
                settingsModal?.showWithTab(_settingsPendingTabIndex);
                _settingsPendingTabIndex = -1;
            } else if (_settingsPendingTab) {
                settingsModal?.showWithTabName(_settingsPendingTab);
                _settingsPendingTab = "";
            } else {
                settingsModal?.show();
            }
            return;
        }
        if (_settingsWantsToggle) {
            _settingsWantsToggle = false;
            if (_settingsPendingTabIndex >= 0) {
                settingsModal.currentTabIndex = _settingsPendingTabIndex;
                _settingsPendingTabIndex = -1;
            } else if (_settingsPendingTab) {
                var idx = settingsModal?.resolveTabIndex(_settingsPendingTab) ?? -1;
                if (idx >= 0)
                    settingsModal.currentTabIndex = idx;
                _settingsPendingTab = "";
            }
            settingsModal?.toggle();
        }
    }

    function openClipboardHistory() {
        clipboardHistoryModal?.show();
    }

    function closeClipboardHistory() {
        clipboardHistoryModal?.close();
    }

    property bool _dankLauncherV2WantsOpen: false
    property bool _dankLauncherV2WantsToggle: false
    property string _dankLauncherV2PendingQuery: ""
    property string _dankLauncherV2PendingMode: ""

    function openDankLauncherV2() {
        if (dankLauncherV2Modal) {
            dankLauncherV2Modal.show();
        } else if (dankLauncherV2ModalLoader) {
            _dankLauncherV2WantsOpen = true;
            _dankLauncherV2WantsToggle = false;
            dankLauncherV2ModalLoader.active = true;
        }
    }

    function openDankLauncherV2WithQuery(query: string) {
        if (dankLauncherV2Modal) {
            dankLauncherV2Modal.showWithQuery(query);
        } else if (dankLauncherV2ModalLoader) {
            _dankLauncherV2PendingQuery = query;
            _dankLauncherV2WantsOpen = true;
            _dankLauncherV2WantsToggle = false;
            dankLauncherV2ModalLoader.active = true;
        }
    }

    function openDankLauncherV2WithMode(mode: string) {
        if (dankLauncherV2Modal) {
            dankLauncherV2Modal.showWithMode(mode);
        } else if (dankLauncherV2ModalLoader) {
            _dankLauncherV2PendingMode = mode;
            _dankLauncherV2WantsOpen = true;
            _dankLauncherV2WantsToggle = false;
            dankLauncherV2ModalLoader.active = true;
        }
    }

    function closeDankLauncherV2() {
        dankLauncherV2Modal?.hide();
    }

    function toggleDankLauncherV2() {
        if (dankLauncherV2Modal) {
            dankLauncherV2Modal.toggle();
        } else if (dankLauncherV2ModalLoader) {
            _dankLauncherV2WantsToggle = true;
            _dankLauncherV2WantsOpen = false;
            dankLauncherV2ModalLoader.active = true;
        }
    }

    function toggleDankLauncherV2WithMode(mode: string) {
        if (dankLauncherV2Modal) {
            dankLauncherV2Modal.toggleWithMode(mode);
        } else if (dankLauncherV2ModalLoader) {
            _dankLauncherV2PendingMode = mode;
            _dankLauncherV2WantsToggle = true;
            _dankLauncherV2WantsOpen = false;
            dankLauncherV2ModalLoader.active = true;
        }
    }

    function toggleDankLauncherV2WithQuery(query: string) {
        if (dankLauncherV2Modal) {
            dankLauncherV2Modal.toggleWithQuery(query);
        } else if (dankLauncherV2ModalLoader) {
            _dankLauncherV2PendingQuery = query;
            _dankLauncherV2WantsOpen = true;
            _dankLauncherV2WantsToggle = false;
            dankLauncherV2ModalLoader.active = true;
        }
    }

    function _onDankLauncherV2ModalLoaded() {
        if (_dankLauncherV2WantsOpen) {
            _dankLauncherV2WantsOpen = false;
            if (_dankLauncherV2PendingQuery) {
                dankLauncherV2Modal?.showWithQuery(_dankLauncherV2PendingQuery);
                _dankLauncherV2PendingQuery = "";
            } else if (_dankLauncherV2PendingMode) {
                dankLauncherV2Modal?.showWithMode(_dankLauncherV2PendingMode);
                _dankLauncherV2PendingMode = "";
            } else {
                dankLauncherV2Modal?.show();
            }
            return;
        }
        if (_dankLauncherV2WantsToggle) {
            _dankLauncherV2WantsToggle = false;
            if (_dankLauncherV2PendingMode) {
                dankLauncherV2Modal?.toggleWithMode(_dankLauncherV2PendingMode);
                _dankLauncherV2PendingMode = "";
            } else {
                dankLauncherV2Modal?.toggle();
            }
        }
    }

    function openPowerMenu() {
        powerMenuModal?.openCentered();
    }

    function closePowerMenu() {
        powerMenuModal?.close();
    }

    function togglePowerMenu() {
        if (powerMenuModal) {
            if (powerMenuModal.shouldBeVisible) {
                powerMenuModal.close();
            } else {
                powerMenuModal.openCentered();
            }
        }
    }

    function showProcessListModal() {
        if (processListModal) {
            processListModal.show();
        } else if (processListModalLoader) {
            processListModalLoader.active = true;
            Qt.callLater(() => processListModal?.show());
        }
    }

    function hideProcessListModal() {
        processListModal?.hide();
    }

    function toggleProcessListModal() {
        if (processListModal) {
            processListModal.toggle();
        } else if (processListModalLoader) {
            processListModalLoader.active = true;
            Qt.callLater(() => processListModal?.show());
        }
    }

    function showColorPicker() {
        colorPickerModal?.show();
    }

    function hideColorPicker() {
        colorPickerModal?.close();
    }

    function showNotificationModal() {
        notificationModal?.show();
    }

    function hideNotificationModal() {
        notificationModal?.close();
    }

    function showWifiPasswordModal(ssid) {
        if (wifiPasswordModalLoader)
            wifiPasswordModalLoader.active = true;
        if (wifiPasswordModal)
            wifiPasswordModal.show(ssid);
    }

    function showHiddenNetworkModal() {
        if (wifiPasswordModalLoader)
            wifiPasswordModalLoader.active = true;
        if (wifiPasswordModal)
            wifiPasswordModal.showHidden();
    }

    function hideWifiPasswordModal() {
        wifiPasswordModal?.hide();
    }

    function showNetworkInfoModal() {
        networkInfoModal?.show();
    }

    function hideNetworkInfoModal() {
        networkInfoModal?.close();
    }

    function openNotepad() {
        if (notepadSlideouts.length > 0) {
            notepadSlideouts[0]?.show();
        }
    }

    function closeNotepad() {
        if (notepadSlideouts.length > 0) {
            notepadSlideouts[0]?.hide();
        }
    }

    function toggleNotepad() {
        if (notepadSlideouts.length > 0) {
            notepadSlideouts[0]?.toggle();
        }
    }
}
