import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: widgetsTab

    property var parentModal: null
    property string selectedBarId: "default"

    property var selectedBarConfig: {
        selectedBarId;
        SettingsData.barConfigs;
        const index = SettingsData.barConfigs.findIndex(cfg => cfg.id === selectedBarId);
        return index !== -1 ? SettingsData.barConfigs[index] : SettingsData.barConfigs[0];
    }

    property bool selectedBarIsVertical: {
        selectedBarId;
        const pos = selectedBarConfig?.position ?? SettingsData.Position.Top;
        return pos === SettingsData.Position.Left || pos === SettingsData.Position.Right;
    }

    property bool hasMultipleBars: SettingsData.barConfigs.length > 1

    DankTooltipV2 {
        id: sharedTooltip
    }

    property var baseWidgetDefinitions: {
        var coreWidgets = [
            {
                "id": "layout",
                "text": I18n.tr("Layout"),
                "description": I18n.tr("Display and switch DWL layouts"),
                "icon": "view_quilt",
                "enabled": CompositorService.isDwl && DwlService.dwlAvailable,
                "warning": !CompositorService.isDwl ? I18n.tr("Requires DWL compositor") : (!DwlService.dwlAvailable ? I18n.tr("DWL service not available") : undefined)
            },
            {
                "id": "launcherButton",
                "text": I18n.tr("App Launcher"),
                "description": I18n.tr("Quick access to application launcher"),
                "icon": "apps",
                "enabled": true
            },
            {
                "id": "workspaceSwitcher",
                "text": I18n.tr("Workspace Switcher"),
                "description": I18n.tr("Shows current workspace and allows switching"),
                "icon": "view_module",
                "enabled": true
            },
            {
                "id": "focusedWindow",
                "text": I18n.tr("Focused Window"),
                "description": I18n.tr("Display currently focused application title"),
                "icon": "window",
                "enabled": true
            },
            {
                "id": "runningApps",
                "text": I18n.tr("Running Apps"),
                "description": I18n.tr("Shows all running applications with focus indication"),
                "icon": "apps",
                "enabled": true
            },
            {
                "id": "clock",
                "text": I18n.tr("Clock"),
                "description": I18n.tr("Current time and date display"),
                "icon": "schedule",
                "enabled": true
            },
            {
                "id": "weather",
                "text": I18n.tr("Weather Widget"),
                "description": I18n.tr("Current weather conditions and temperature"),
                "icon": "wb_sunny",
                "enabled": true
            },
            {
                "id": "music",
                "text": I18n.tr("Media Controls"),
                "description": I18n.tr("Control currently playing media"),
                "icon": "music_note",
                "enabled": true
            },
            {
                "id": "clipboard",
                "text": I18n.tr("Clipboard Manager"),
                "description": I18n.tr("Access clipboard history"),
                "icon": "content_paste",
                "enabled": true
            },
            {
                "id": "cpuUsage",
                "text": I18n.tr("CPU Usage"),
                "description": I18n.tr("CPU usage indicator"),
                "icon": "memory",
                "enabled": DgopService.dgopAvailable,
                "warning": !DgopService.dgopAvailable ? I18n.tr("Requires 'dgop' tool") : undefined
            },
            {
                "id": "memUsage",
                "text": I18n.tr("Memory Usage"),
                "description": I18n.tr("Memory usage indicator"),
                "icon": "developer_board",
                "enabled": DgopService.dgopAvailable,
                "warning": !DgopService.dgopAvailable ? I18n.tr("Requires 'dgop' tool") : undefined
            },
            {
                "id": "diskUsage",
                "text": I18n.tr("Disk Usage"),
                "description": I18n.tr("Percentage"),
                "icon": "storage",
                "enabled": DgopService.dgopAvailable,
                "warning": !DgopService.dgopAvailable ? I18n.tr("Requires 'dgop' tool") : undefined
            },
            {
                "id": "cpuTemp",
                "text": I18n.tr("CPU Temperature"),
                "description": I18n.tr("CPU temperature display"),
                "icon": "device_thermostat",
                "enabled": DgopService.dgopAvailable,
                "warning": !DgopService.dgopAvailable ? I18n.tr("Requires 'dgop' tool") : undefined
            },
            {
                "id": "gpuTemp",
                "text": I18n.tr("GPU Temperature"),
                "description": "",
                "icon": "auto_awesome_mosaic",
                "warning": !DgopService.dgopAvailable ? I18n.tr("Requires 'dgop' tool") : I18n.tr("This widget prevents GPU power off states, which can significantly impact battery life on laptops. It is not recommended to use this on laptops with hybrid graphics."),
                "enabled": DgopService.dgopAvailable
            },
            {
                "id": "systemTray",
                "text": I18n.tr("System Tray"),
                "description": I18n.tr("System notification area icons"),
                "icon": "notifications",
                "enabled": true
            },
            {
                "id": "privacyIndicator",
                "text": I18n.tr("Privacy Indicator"),
                "description": I18n.tr("Shows when microphone, camera, or screen sharing is active"),
                "icon": "privacy_tip",
                "enabled": true
            },
            {
                "id": "controlCenterButton",
                "text": I18n.tr("Control Center"),
                "description": I18n.tr("Access to system controls and settings"),
                "icon": "settings",
                "enabled": true
            },
            {
                "id": "notificationButton",
                "text": I18n.tr("Notification Center"),
                "description": I18n.tr("Access to notifications and do not disturb"),
                "icon": "notifications",
                "enabled": true
            },
            {
                "id": "battery",
                "text": I18n.tr("Battery"),
                "description": I18n.tr("Battery level and power management"),
                "icon": "battery_std",
                "enabled": true
            },
            {
                "id": "vpn",
                "text": I18n.tr("VPN"),
                "description": I18n.tr("VPN status and quick connect"),
                "icon": "vpn_lock",
                "enabled": true
            },
            {
                "id": "idleInhibitor",
                "text": I18n.tr("Idle Inhibitor"),
                "description": I18n.tr("Prevent screen timeout"),
                "icon": "motion_sensor_active",
                "enabled": true
            },
            {
                "id": "capsLockIndicator",
                "text": I18n.tr("Caps Lock Indicator"),
                "description": I18n.tr("Shows when caps lock is active"),
                "icon": "shift_lock",
                "enabled": true
            },
            {
                "id": "spacer",
                "text": I18n.tr("Spacer"),
                "description": I18n.tr("Customizable empty space"),
                "icon": "more_horiz",
                "enabled": true
            },
            {
                "id": "separator",
                "text": I18n.tr("Separator"),
                "description": I18n.tr("Visual divider between widgets"),
                "icon": "remove",
                "enabled": true
            },
            {
                "id": "network_speed_monitor",
                "text": I18n.tr("Network Speed Monitor"),
                "description": I18n.tr("Network download and upload speed display"),
                "icon": "network_check",
                "warning": !DgopService.dgopAvailable ? I18n.tr("Requires 'dgop' tool") : undefined,
                "enabled": DgopService.dgopAvailable
            },
            {
                "id": "keyboard_layout_name",
                "text": I18n.tr("Keyboard Layout Name"),
                "description": I18n.tr("Displays the active keyboard layout and allows switching"),
                "icon": "keyboard"
            },
            {
                "id": "notepadButton",
                "text": I18n.tr("Notepad"),
                "description": I18n.tr("Quick access to notepad"),
                "icon": "assignment",
                "enabled": true
            },
            {
                "id": "colorPicker",
                "text": I18n.tr("Color Picker"),
                "description": I18n.tr("Quick access to color picker"),
                "icon": "palette",
                "enabled": true
            },
            {
                "id": "systemUpdate",
                "text": I18n.tr("System Update"),
                "description": I18n.tr("Check for system updates"),
                "icon": "update",
                "enabled": SystemUpdateService.distributionSupported
            },
            {
                "id": "powerMenuButton",
                "text": I18n.tr("Power"),
                "description": I18n.tr("Display the power system menu"),
                "icon": "power_settings_new",
                "enabled": true
            },
        ];

        var allPluginVariants = PluginService.getAllPluginVariants();
        for (var i = 0; i < allPluginVariants.length; i++) {
            var variant = allPluginVariants[i];
            coreWidgets.push({
                "id": variant.fullId,
                "text": variant.name,
                "description": variant.description,
                "icon": variant.icon,
                "enabled": variant.loaded,
                "warning": !variant.loaded ? I18n.tr("Plugin is disabled - enable in Plugins settings to use") : undefined
            });
        }

        return coreWidgets;
    }

    property var defaultLeftWidgets: [
        {
            "id": "launcherButton",
            "enabled": true
        },
        {
            "id": "workspaceSwitcher",
            "enabled": true
        },
        {
            "id": "focusedWindow",
            "enabled": true
        }
    ]
    property var defaultCenterWidgets: [
        {
            "id": "music",
            "enabled": true
        },
        {
            "id": "clock",
            "enabled": true
        },
        {
            "id": "weather",
            "enabled": true
        }
    ]
    property var defaultRightWidgets: [
        {
            "id": "systemTray",
            "enabled": true
        },
        {
            "id": "clipboard",
            "enabled": true
        },
        {
            "id": "notificationButton",
            "enabled": true
        },
        {
            "id": "battery",
            "enabled": true
        },
        {
            "id": "controlCenterButton",
            "enabled": true
        }
    ]

    function getWidgetsForSection(sectionId) {
        switch (sectionId) {
        case "left":
            return selectedBarConfig?.leftWidgets || [];
        case "center":
            return selectedBarConfig?.centerWidgets || [];
        case "right":
            return selectedBarConfig?.rightWidgets || [];
        default:
            return [];
        }
    }

    function setWidgetsForSection(sectionId, widgets) {
        switch (sectionId) {
        case "left":
            SettingsData.updateBarConfig(selectedBarId, {
                leftWidgets: widgets
            });
            break;
        case "center":
            SettingsData.updateBarConfig(selectedBarId, {
                centerWidgets: widgets
            });
            break;
        case "right":
            SettingsData.updateBarConfig(selectedBarId, {
                rightWidgets: widgets
            });
            break;
        }
    }

    function getWidgetsForPopup() {
        return baseWidgetDefinitions.filter(widget => {
            if (widget.warning && widget.warning.includes("Plugin is disabled"))
                return false;
            if (widget.enabled === false)
                return false;
            return true;
        });
    }

    function addWidgetToSection(widgetId, targetSection) {
        var widgetObj = {
            "id": widgetId,
            "enabled": true
        };
        if (widgetId === "spacer")
            widgetObj.size = 20;
        if (widgetId === "gpuTemp") {
            widgetObj.selectedGpuIndex = 0;
            widgetObj.pciId = "";
        }
        if (widgetId === "controlCenterButton") {
            widgetObj.showNetworkIcon = true;
            widgetObj.showBluetoothIcon = true;
            widgetObj.showAudioIcon = true;
        }
        if (widgetId === "diskUsage")
            widgetObj.mountPath = "/";
        if (widgetId === "cpuUsage" || widgetId === "memUsage" || widgetId === "cpuTemp" || widgetId === "gpuTemp")
            widgetObj.minimumWidth = true;

        var widgets = getWidgetsForSection(targetSection).slice();
        widgets.push(widgetObj);
        setWidgetsForSection(targetSection, widgets);
    }

    function removeWidgetFromSection(sectionId, widgetIndex) {
        var widgets = getWidgetsForSection(sectionId).slice();
        if (widgetIndex >= 0 && widgetIndex < widgets.length)
            widgets.splice(widgetIndex, 1);
        setWidgetsForSection(sectionId, widgets);
    }

    function handleItemEnabledChanged(sectionId, itemId, enabled) {
        var widgets = getWidgetsForSection(sectionId).slice();
        for (var i = 0; i < widgets.length; i++) {
            var widget = widgets[i];
            var widgetId = typeof widget === "string" ? widget : widget.id;
            if (widgetId !== itemId)
                continue;

            if (typeof widget === "string") {
                widgets[i] = {
                    "id": widget,
                    "enabled": enabled
                };
                break;
            }

            var newWidget = {
                "id": widget.id,
                "enabled": enabled
            };
            if (widget.size !== undefined)
                newWidget.size = widget.size;
            if (widget.selectedGpuIndex !== undefined)
                newWidget.selectedGpuIndex = widget.selectedGpuIndex;
            else if (widget.id === "gpuTemp")
                newWidget.selectedGpuIndex = 0;
            if (widget.pciId !== undefined)
                newWidget.pciId = widget.pciId;
            else if (widget.id === "gpuTemp")
                newWidget.pciId = "";
            if (widget.id === "controlCenterButton") {
                newWidget.showNetworkIcon = widget.showNetworkIcon ?? true;
                newWidget.showBluetoothIcon = widget.showBluetoothIcon ?? true;
                newWidget.showAudioIcon = widget.showAudioIcon ?? true;
            }
            widgets[i] = newWidget;
            break;
        }
        setWidgetsForSection(sectionId, widgets);
    }

    function handleItemOrderChanged(sectionId, newOrder) {
        setWidgetsForSection(sectionId, newOrder);
    }

    function handleSpacerSizeChanged(sectionId, widgetIndex, newSize) {
        var widgets = getWidgetsForSection(sectionId).slice();
        if (widgetIndex < 0 || widgetIndex >= widgets.length) {
            setWidgetsForSection(sectionId, widgets);
            return;
        }

        var widget = widgets[widgetIndex];
        var widgetId = typeof widget === "string" ? widget : widget.id;
        if (widgetId !== "spacer") {
            setWidgetsForSection(sectionId, widgets);
            return;
        }

        if (typeof widget === "string") {
            widgets[widgetIndex] = {
                "id": widget,
                "enabled": true,
                "size": newSize
            };
            setWidgetsForSection(sectionId, widgets);
            return;
        }

        var newWidget = {
            "id": widget.id,
            "enabled": widget.enabled,
            "size": newSize
        };
        if (widget.selectedGpuIndex !== undefined)
            newWidget.selectedGpuIndex = widget.selectedGpuIndex;
        if (widget.pciId !== undefined)
            newWidget.pciId = widget.pciId;
        if (widget.id === "controlCenterButton") {
            newWidget.showNetworkIcon = widget.showNetworkIcon ?? true;
            newWidget.showBluetoothIcon = widget.showBluetoothIcon ?? true;
            newWidget.showAudioIcon = widget.showAudioIcon ?? true;
        }
        widgets[widgetIndex] = newWidget;
        setWidgetsForSection(sectionId, widgets);
    }

    function handleGpuSelectionChanged(sectionId, widgetIndex, selectedGpuIndex) {
        var widgets = getWidgetsForSection(sectionId).slice();
        if (widgetIndex < 0 || widgetIndex >= widgets.length) {
            setWidgetsForSection(sectionId, widgets);
            return;
        }

        var pciId = DgopService.availableGpus && DgopService.availableGpus.length > selectedGpuIndex ? DgopService.availableGpus[selectedGpuIndex].pciId : "";
        var widget = widgets[widgetIndex];
        if (typeof widget === "string") {
            widgets[widgetIndex] = {
                "id": widget,
                "enabled": true,
                "selectedGpuIndex": selectedGpuIndex,
                "pciId": pciId
            };
            setWidgetsForSection(sectionId, widgets);
            return;
        }

        var newWidget = {
            "id": widget.id,
            "enabled": widget.enabled,
            "selectedGpuIndex": selectedGpuIndex,
            "pciId": pciId
        };
        if (widget.size !== undefined)
            newWidget.size = widget.size;
        widgets[widgetIndex] = newWidget;
        setWidgetsForSection(sectionId, widgets);
    }

    function handleDiskMountSelectionChanged(sectionId, widgetIndex, mountPath) {
        var widgets = getWidgetsForSection(sectionId).slice();
        if (widgetIndex < 0 || widgetIndex >= widgets.length) {
            setWidgetsForSection(sectionId, widgets);
            return;
        }

        var widget = widgets[widgetIndex];
        if (typeof widget === "string") {
            widgets[widgetIndex] = {
                "id": widget,
                "enabled": true,
                "mountPath": mountPath
            };
            setWidgetsForSection(sectionId, widgets);
            return;
        }

        var newWidget = {
            "id": widget.id,
            "enabled": widget.enabled,
            "mountPath": mountPath
        };
        if (widget.size !== undefined)
            newWidget.size = widget.size;
        if (widget.selectedGpuIndex !== undefined)
            newWidget.selectedGpuIndex = widget.selectedGpuIndex;
        if (widget.pciId !== undefined)
            newWidget.pciId = widget.pciId;
        if (widget.id === "controlCenterButton") {
            newWidget.showNetworkIcon = widget.showNetworkIcon ?? true;
            newWidget.showBluetoothIcon = widget.showBluetoothIcon ?? true;
            newWidget.showAudioIcon = widget.showAudioIcon ?? true;
        }
        widgets[widgetIndex] = newWidget;
        setWidgetsForSection(sectionId, widgets);
    }

    function handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value) {
        switch (settingName) {
        case "showNetworkIcon":
            SettingsData.set("controlCenterShowNetworkIcon", value);
            break;
        case "showBluetoothIcon":
            SettingsData.set("controlCenterShowBluetoothIcon", value);
            break;
        case "showAudioIcon":
            SettingsData.set("controlCenterShowAudioIcon", value);
            break;
        case "showVpnIcon":
            SettingsData.set("controlCenterShowVpnIcon", value);
            break;
        case "showBrightnessIcon":
            SettingsData.set("controlCenterShowBrightnessIcon", value);
            break;
        case "showMicIcon":
            SettingsData.set("controlCenterShowMicIcon", value);
            break;
        case "showBatteryIcon":
            SettingsData.set("controlCenterShowBatteryIcon", value);
            break;
        case "showPrinterIcon":
            SettingsData.set("controlCenterShowPrinterIcon", value);
            break;
        }
    }

    function handlePrivacySettingChanged(sectionId, widgetIndex, settingName, value) {
        switch (settingName) {
        case "showMicIcon":
            SettingsData.set("privacyShowMicIcon", value);
            break;
        case "showCameraIcon":
            SettingsData.set("privacyShowCameraIcon", value);
            break;
        case "showScreenSharingIcon":
            SettingsData.set("privacyShowScreenShareIcon", value);
            break;
        }
    }

    function handleMinimumWidthChanged(sectionId, widgetIndex, enabled) {
        var widgets = getWidgetsForSection(sectionId).slice();
        if (widgetIndex < 0 || widgetIndex >= widgets.length) {
            setWidgetsForSection(sectionId, widgets);
            return;
        }

        var widget = widgets[widgetIndex];
        if (typeof widget === "string") {
            widgets[widgetIndex] = {
                "id": widget,
                "enabled": true,
                "minimumWidth": enabled
            };
            setWidgetsForSection(sectionId, widgets);
            return;
        }

        var newWidget = {
            "id": widget.id,
            "enabled": widget.enabled,
            "minimumWidth": enabled
        };
        if (widget.size !== undefined)
            newWidget.size = widget.size;
        if (widget.selectedGpuIndex !== undefined)
            newWidget.selectedGpuIndex = widget.selectedGpuIndex;
        if (widget.pciId !== undefined)
            newWidget.pciId = widget.pciId;
        if (widget.mountPath !== undefined)
            newWidget.mountPath = widget.mountPath;
        if (widget.showSwap !== undefined)
            newWidget.showSwap = widget.showSwap;
        if (widget.id === "controlCenterButton") {
            newWidget.showNetworkIcon = widget.showNetworkIcon ?? true;
            newWidget.showBluetoothIcon = widget.showBluetoothIcon ?? true;
            newWidget.showAudioIcon = widget.showAudioIcon ?? true;
        }
        widgets[widgetIndex] = newWidget;
        setWidgetsForSection(sectionId, widgets);
    }

    function handleShowSwapChanged(sectionId, widgetIndex, enabled) {
        var widgets = getWidgetsForSection(sectionId).slice();
        if (widgetIndex < 0 || widgetIndex >= widgets.length) {
            setWidgetsForSection(sectionId, widgets);
            return;
        }

        var widget = widgets[widgetIndex];
        if (typeof widget === "string") {
            widgets[widgetIndex] = {
                "id": widget,
                "enabled": true,
                "showSwap": enabled
            };
            setWidgetsForSection(sectionId, widgets);
            return;
        }

        var newWidget = {
            "id": widget.id,
            "enabled": widget.enabled,
            "showSwap": enabled
        };
        if (widget.size !== undefined)
            newWidget.size = widget.size;
        if (widget.selectedGpuIndex !== undefined)
            newWidget.selectedGpuIndex = widget.selectedGpuIndex;
        if (widget.pciId !== undefined)
            newWidget.pciId = widget.pciId;
        if (widget.mountPath !== undefined)
            newWidget.mountPath = widget.mountPath;
        if (widget.minimumWidth !== undefined)
            newWidget.minimumWidth = widget.minimumWidth;
        if (widget.mediaSize !== undefined)
            newWidget.mediaSize = widget.mediaSize;
        if (widget.clockCompactMode !== undefined)
            newWidget.clockCompactMode = widget.clockCompactMode;
        if (widget.focusedWindowCompactMode !== undefined)
            newWidget.focusedWindowCompactMode = widget.focusedWindowCompactMode;
        if (widget.runningAppsCompactMode !== undefined)
            newWidget.runningAppsCompactMode = widget.runningAppsCompactMode;
        if (widget.keyboardLayoutNameCompactMode !== undefined)
            newWidget.keyboardLayoutNameCompactMode = widget.keyboardLayoutNameCompactMode;
        if (widget.id === "controlCenterButton") {
            newWidget.showNetworkIcon = widget.showNetworkIcon ?? true;
            newWidget.showBluetoothIcon = widget.showBluetoothIcon ?? true;
            newWidget.showAudioIcon = widget.showAudioIcon ?? true;
        }
        widgets[widgetIndex] = newWidget;
        setWidgetsForSection(sectionId, widgets);
    }

    function handleCompactModeChanged(sectionId, widgetId, value) {
        var widgets = getWidgetsForSection(sectionId).slice();

        for (var i = 0; i < widgets.length; i++) {
            var widget = widgets[i];
            var currentId = typeof widget === "string" ? widget : widget.id;

            if (currentId !== widgetId)
                continue;

            if (typeof widget === "string") {
                widgets[i] = {
                    "id": widget,
                    "enabled": true
                };
                widget = widgets[i];
            } else {
                var newWidget = {
                    "id": widget.id,
                    "enabled": widget.enabled
                };
                if (widget.size !== undefined)
                    newWidget.size = widget.size;
                if (widget.selectedGpuIndex !== undefined)
                    newWidget.selectedGpuIndex = widget.selectedGpuIndex;
                if (widget.pciId !== undefined)
                    newWidget.pciId = widget.pciId;
                if (widget.mountPath !== undefined)
                    newWidget.mountPath = widget.mountPath;
                if (widget.minimumWidth !== undefined)
                    newWidget.minimumWidth = widget.minimumWidth;
                if (widget.showSwap !== undefined)
                    newWidget.showSwap = widget.showSwap;
                if (widget.mediaSize !== undefined)
                    newWidget.mediaSize = widget.mediaSize;
                if (widget.clockCompactMode !== undefined)
                    newWidget.clockCompactMode = widget.clockCompactMode;
                if (widget.focusedWindowCompactMode !== undefined)
                    newWidget.focusedWindowCompactMode = widget.focusedWindowCompactMode;
                if (widget.runningAppsCompactMode !== undefined)
                    newWidget.runningAppsCompactMode = widget.runningAppsCompactMode;
                if (widget.keyboardLayoutNameCompactMode !== undefined)
                    newWidget.keyboardLayoutNameCompactMode = widget.keyboardLayoutNameCompactMode;
                if (widget.id === "controlCenterButton") {
                    newWidget.showNetworkIcon = widget.showNetworkIcon ?? true;
                    newWidget.showBluetoothIcon = widget.showBluetoothIcon ?? true;
                    newWidget.showAudioIcon = widget.showAudioIcon ?? true;
                }
                widgets[i] = newWidget;
                widget = newWidget;
            }

            switch (widgetId) {
            case "music":
                widget.mediaSize = value;
                break;
            case "clock":
                widget.clockCompactMode = value;
                break;
            case "focusedWindow":
                widget.focusedWindowCompactMode = value;
                break;
            case "runningApps":
                widget.runningAppsCompactMode = value;
                break;
            case "keyboard_layout_name":
                widget.keyboardLayoutNameCompactMode = value;
                break;
            }

            break;
        }

        setWidgetsForSection(sectionId, widgets);
    }

    function getItemsForSection(sectionId) {
        var widgets = [];
        var widgetData = getWidgetsForSection(sectionId);
        widgetData.forEach(widget => {
            var isString = typeof widget === "string";
            var widgetId = isString ? widget : widget.id;
            var widgetDef = baseWidgetDefinitions.find(w => w.id === widgetId);
            if (!widgetDef)
                return;

            var item = Object.assign({}, widgetDef);
            item.enabled = isString ? true : widget.enabled;
            if (!isString) {
                if (widget.size !== undefined)
                    item.size = widget.size;
                if (widget.selectedGpuIndex !== undefined)
                    item.selectedGpuIndex = widget.selectedGpuIndex;
                if (widget.pciId !== undefined)
                    item.pciId = widget.pciId;
                if (widget.mountPath !== undefined)
                    item.mountPath = widget.mountPath;
                if (widget.showNetworkIcon !== undefined)
                    item.showNetworkIcon = widget.showNetworkIcon;
                if (widget.showBluetoothIcon !== undefined)
                    item.showBluetoothIcon = widget.showBluetoothIcon;
                if (widget.showAudioIcon !== undefined)
                    item.showAudioIcon = widget.showAudioIcon;
                if (widget.minimumWidth !== undefined)
                    item.minimumWidth = widget.minimumWidth;
                if (widget.showSwap !== undefined)
                    item.showSwap = widget.showSwap;
                if (widget.mediaSize !== undefined)
                    item.mediaSize = widget.mediaSize;
                if (widget.clockCompactMode !== undefined)
                    item.clockCompactMode = widget.clockCompactMode;
                if (widget.focusedWindowCompactMode !== undefined)
                    item.focusedWindowCompactMode = widget.focusedWindowCompactMode;
                if (widget.runningAppsCompactMode !== undefined)
                    item.runningAppsCompactMode = widget.runningAppsCompactMode;
                if (widget.keyboardLayoutNameCompactMode !== undefined)
                    item.keyboardLayoutNameCompactMode = widget.keyboardLayoutNameCompactMode;
            }
            widgets.push(item);
        });
        return widgets;
    }

    Component.onCompleted: {
        const leftWidgets = selectedBarConfig?.leftWidgets;
        const centerWidgets = selectedBarConfig?.centerWidgets;
        const rightWidgets = selectedBarConfig?.rightWidgets;

        if (!leftWidgets)
            setWidgetsForSection("left", defaultLeftWidgets);
        if (!centerWidgets)
            setWidgetsForSection("center", defaultCenterWidgets);
        if (!rightWidgets)
            setWidgetsForSection("right", defaultRightWidgets);

        const sections = ["left", "center", "right"];
        sections.forEach(sectionId => {
            var widgets = getWidgetsForSection(sectionId).slice();
            var updated = false;
            for (var i = 0; i < widgets.length; i++) {
                var widget = widgets[i];
                if (typeof widget === "object" && widget.id === "spacer" && !widget.size) {
                    widgets[i] = Object.assign({}, widget, {
                        "size": 20
                    });
                    updated = true;
                }
            }
            if (updated)
                setWidgetsForSection(sectionId, widgets);
        });
    }

    WidgetSelectionPopup {
        id: widgetSelectionPopup
        parentModal: widgetsTab.parentModal
        onWidgetSelected: (widgetId, targetSection) => {
            widgetsTab.addWidgetToSection(widgetId, targetSection);
        }
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            StyledRect {
                width: parent.width
                height: barSelectorContent.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 0
                visible: hasMultipleBars

                Column {
                    id: barSelectorContent
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "toolbar"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Select Bar")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankButtonGroup {
                        id: barSelectorGroup
                        width: parent.width
                        model: SettingsData.barConfigs.map(cfg => cfg.name || ("Bar " + (SettingsData.barConfigs.indexOf(cfg) + 1)))
                        currentIndex: {
                            const idx = SettingsData.barConfigs.findIndex(cfg => cfg.id === selectedBarId);
                            return idx >= 0 ? idx : 0;
                        }
                        checkEnabled: false
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            if (index >= 0 && index < SettingsData.barConfigs.length)
                                selectedBarId = SettingsData.barConfigs[index].id;
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: widgetManagementHeader.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 0

                Column {
                    id: widgetManagementHeader
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "widgets"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: I18n.tr("Widget Management")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            height: 1
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 80
                            height: 28
                            radius: Theme.cornerRadius
                            color: resetArea.containsMouse ? Theme.surfacePressed : Theme.surfaceVariant
                            Layout.alignment: Qt.AlignVCenter
                            border.width: 0

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "refresh"
                                    size: 14
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: I18n.tr("Reset")
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: resetArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    setWidgetsForSection("left", defaultLeftWidgets);
                                    setWidgetsForSection("center", defaultCenterWidgets);
                                    setWidgetsForSection("right", defaultRightWidgets);
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Drag widgets to reorder within sections. Use the eye icon to hide/show widgets (maintains spacing), or X to remove them completely.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingL

                StyledRect {
                    width: parent.width
                    height: leftSection.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 0

                    WidgetsTabSection {
                        id: leftSection
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        title: selectedBarIsVertical ? I18n.tr("Top Section") : I18n.tr("Left Section")
                        titleIcon: "format_align_left"
                        sectionId: "left"
                        allWidgets: widgetsTab.baseWidgetDefinitions
                        items: widgetsTab.getItemsForSection("left")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => {
                            widgetsTab.handleItemEnabledChanged(sectionId, itemId, enabled);
                        }
                        onItemOrderChanged: newOrder => {
                            widgetsTab.handleItemOrderChanged(sectionId, newOrder);
                        }
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.targetSection = sectionId;
                            widgetSelectionPopup.allWidgets = widgetsTab.getWidgetsForPopup();
                            widgetSelectionPopup.show();
                        }
                        onRemoveWidget: (sectionId, index) => {
                            widgetsTab.removeWidgetFromSection(sectionId, index);
                        }
                        onSpacerSizeChanged: (sectionId, index, size) => {
                            widgetsTab.handleSpacerSizeChanged(sectionId, index, size);
                        }
                        onGpuSelectionChanged: (sectionId, index, gpuIndex) => {
                            widgetsTab.handleGpuSelectionChanged(sectionId, index, gpuIndex);
                        }
                        onDiskMountSelectionChanged: (sectionId, index, mountPath) => {
                            widgetsTab.handleDiskMountSelectionChanged(sectionId, index, mountPath);
                        }
                        onControlCenterSettingChanged: (sectionId, index, setting, value) => {
                            widgetsTab.handleControlCenterSettingChanged(sectionId, index, setting, value);
                        }
                        onPrivacySettingChanged: (sectionId, index, setting, value) => {
                            widgetsTab.handlePrivacySettingChanged(sectionId, index, setting, value);
                        }
                        onMinimumWidthChanged: (sectionId, index, enabled) => {
                            widgetsTab.handleMinimumWidthChanged(sectionId, index, enabled);
                        }
                        onShowSwapChanged: (sectionId, index, enabled) => {
                            widgetsTab.handleShowSwapChanged(sectionId, index, enabled);
                        }
                        onCompactModeChanged: (widgetId, value) => {
                            widgetsTab.handleCompactModeChanged(sectionId, widgetId, value);
                        }
                    }
                }

                StyledRect {
                    width: parent.width
                    height: centerSection.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 0

                    WidgetsTabSection {
                        id: centerSection
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        title: selectedBarIsVertical ? I18n.tr("Middle Section") : I18n.tr("Center Section")
                        titleIcon: "format_align_center"
                        sectionId: "center"
                        allWidgets: widgetsTab.baseWidgetDefinitions
                        items: widgetsTab.getItemsForSection("center")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => {
                            widgetsTab.handleItemEnabledChanged(sectionId, itemId, enabled);
                        }
                        onItemOrderChanged: newOrder => {
                            widgetsTab.handleItemOrderChanged(sectionId, newOrder);
                        }
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.targetSection = sectionId;
                            widgetSelectionPopup.allWidgets = widgetsTab.getWidgetsForPopup();
                            widgetSelectionPopup.show();
                        }
                        onRemoveWidget: (sectionId, index) => {
                            widgetsTab.removeWidgetFromSection(sectionId, index);
                        }
                        onSpacerSizeChanged: (sectionId, index, size) => {
                            widgetsTab.handleSpacerSizeChanged(sectionId, index, size);
                        }
                        onGpuSelectionChanged: (sectionId, index, gpuIndex) => {
                            widgetsTab.handleGpuSelectionChanged(sectionId, index, gpuIndex);
                        }
                        onDiskMountSelectionChanged: (sectionId, index, mountPath) => {
                            widgetsTab.handleDiskMountSelectionChanged(sectionId, index, mountPath);
                        }
                        onControlCenterSettingChanged: (sectionId, index, setting, value) => {
                            widgetsTab.handleControlCenterSettingChanged(sectionId, index, setting, value);
                        }
                        onPrivacySettingChanged: (sectionId, index, setting, value) => {
                            widgetsTab.handlePrivacySettingChanged(sectionId, index, setting, value);
                        }
                        onMinimumWidthChanged: (sectionId, index, enabled) => {
                            widgetsTab.handleMinimumWidthChanged(sectionId, index, enabled);
                        }
                        onShowSwapChanged: (sectionId, index, enabled) => {
                            widgetsTab.handleShowSwapChanged(sectionId, index, enabled);
                        }
                        onCompactModeChanged: (widgetId, value) => {
                            widgetsTab.handleCompactModeChanged(sectionId, widgetId, value);
                        }
                    }
                }

                StyledRect {
                    width: parent.width
                    height: rightSection.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 0

                    WidgetsTabSection {
                        id: rightSection
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        title: selectedBarIsVertical ? I18n.tr("Bottom Section") : I18n.tr("Right Section")
                        titleIcon: "format_align_right"
                        sectionId: "right"
                        allWidgets: widgetsTab.baseWidgetDefinitions
                        items: widgetsTab.getItemsForSection("right")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => {
                            widgetsTab.handleItemEnabledChanged(sectionId, itemId, enabled);
                        }
                        onItemOrderChanged: newOrder => {
                            widgetsTab.handleItemOrderChanged(sectionId, newOrder);
                        }
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.targetSection = sectionId;
                            widgetSelectionPopup.allWidgets = widgetsTab.getWidgetsForPopup();
                            widgetSelectionPopup.show();
                        }
                        onRemoveWidget: (sectionId, index) => {
                            widgetsTab.removeWidgetFromSection(sectionId, index);
                        }
                        onSpacerSizeChanged: (sectionId, index, size) => {
                            widgetsTab.handleSpacerSizeChanged(sectionId, index, size);
                        }
                        onGpuSelectionChanged: (sectionId, index, gpuIndex) => {
                            widgetsTab.handleGpuSelectionChanged(sectionId, index, gpuIndex);
                        }
                        onDiskMountSelectionChanged: (sectionId, index, mountPath) => {
                            widgetsTab.handleDiskMountSelectionChanged(sectionId, index, mountPath);
                        }
                        onControlCenterSettingChanged: (sectionId, index, setting, value) => {
                            widgetsTab.handleControlCenterSettingChanged(sectionId, index, setting, value);
                        }
                        onPrivacySettingChanged: (sectionId, index, setting, value) => {
                            widgetsTab.handlePrivacySettingChanged(sectionId, index, setting, value);
                        }
                        onMinimumWidthChanged: (sectionId, index, enabled) => {
                            widgetsTab.handleMinimumWidthChanged(sectionId, index, enabled);
                        }
                        onShowSwapChanged: (sectionId, index, enabled) => {
                            widgetsTab.handleShowSwapChanged(sectionId, index, enabled);
                        }
                        onCompactModeChanged: (widgetId, value) => {
                            widgetsTab.handleCompactModeChanged(sectionId, widgetId, value);
                        }
                    }
                }
            }
        }
    }
}
