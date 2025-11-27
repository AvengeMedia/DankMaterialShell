import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: dankBarTab

    property var parentModal: null
    property string selectedBarId: "default"

    DankTooltipV2 {
        id: sharedTooltip
    }

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

    Timer {
        id: horizontalBarChangeDebounce
        interval: 500
        repeat: false
        onTriggered: {
            const verticalBars = SettingsData.barConfigs.filter(cfg => {
                const pos = cfg.position ?? SettingsData.Position.Top;
                return pos === SettingsData.Position.Left || pos === SettingsData.Position.Right;
            });

            verticalBars.forEach(bar => {
                if (bar.enabled) {
                    SettingsData.updateBarConfig(bar.id, {
                        enabled: false
                    });
                    Qt.callLater(() => {
                        SettingsData.updateBarConfig(bar.id, {
                            enabled: true
                        });
                    });
                }
            });
        }
    }

    Timer {
        id: edgeSpacingDebounce
        interval: 100
        repeat: false
        property real pendingValue: 4
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                spacing: pendingValue
            });
            notifyHorizontalBarChange();
        }
    }

    Timer {
        id: exclusiveZoneDebounce
        interval: 100
        repeat: false
        property real pendingValue: 0
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                bottomGap: pendingValue
            });
            notifyHorizontalBarChange();
        }
    }

    Timer {
        id: sizeDebounce
        interval: 100
        repeat: false
        property real pendingValue: 4
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                innerPadding: pendingValue
            });
            notifyHorizontalBarChange();
        }
    }

    Timer {
        id: popupGapsManualDebounce
        interval: 100
        repeat: false
        property real pendingValue: 4
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                popupGapsManual: pendingValue
            });
            notifyHorizontalBarChange();
        }
    }

    Timer {
        id: gothCornerRadiusDebounce
        interval: 100
        repeat: false
        property real pendingValue: 12
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                gothCornerRadiusValue: pendingValue
            });
        }
    }

    Timer {
        id: borderOpacityDebounce
        interval: 100
        repeat: false
        property real pendingValue: 1.0
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                borderOpacity: pendingValue
            });
        }
    }

    Timer {
        id: borderThicknessDebounce
        interval: 100
        repeat: false
        property real pendingValue: 1
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                borderThickness: pendingValue
            });
        }
    }

    Timer {
        id: widgetOutlineOpacityDebounce
        interval: 100
        repeat: false
        property real pendingValue: 1.0
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                widgetOutlineOpacity: pendingValue
            });
        }
    }

    Timer {
        id: widgetOutlineThicknessDebounce
        interval: 100
        repeat: false
        property real pendingValue: 1
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                widgetOutlineThickness: pendingValue
            });
        }
    }

    Timer {
        id: barTransparencyDebounce
        interval: 100
        repeat: false
        property real pendingValue: 1.0
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                transparency: pendingValue
            });
            notifyHorizontalBarChange();
        }
    }

    Timer {
        id: widgetTransparencyDebounce
        interval: 100
        repeat: false
        property real pendingValue: 1.0
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                widgetTransparency: pendingValue
            });
            notifyHorizontalBarChange();
        }
    }

    // ! Hacky workaround because we want to re-register any vertical bars after changing a hBar
    // ! That allows them to re-make with the right exclusiveZone
    function notifyHorizontalBarChange() {
        if (selectedBarIsVertical)
            return;
        horizontalBarChangeDebounce.restart();
    }

    function createNewBar() {
        const barCount = SettingsData.barConfigs.length;
        if (barCount >= 4)
            return;
        const defaultBar = SettingsData.getBarConfig("default");
        if (!defaultBar)
            return;
        const newId = "bar" + Date.now();
        const newBar = {
            id: newId,
            name: "Bar " + (barCount + 1),
            enabled: true,
            position: defaultBar.position ?? 0,
            screenPreferences: [],
            showOnLastDisplay: false,
            leftWidgets: defaultBar.leftWidgets || [],
            centerWidgets: defaultBar.centerWidgets || [],
            rightWidgets: defaultBar.rightWidgets || [],
            spacing: defaultBar.spacing ?? 4,
            innerPadding: defaultBar.innerPadding ?? 4,
            bottomGap: defaultBar.bottomGap ?? 0,
            transparency: defaultBar.transparency ?? 1.0,
            widgetTransparency: defaultBar.widgetTransparency ?? 1.0,
            squareCorners: defaultBar.squareCorners ?? false,
            noBackground: defaultBar.noBackground ?? false,
            gothCornersEnabled: defaultBar.gothCornersEnabled ?? false,
            gothCornerRadiusOverride: defaultBar.gothCornerRadiusOverride ?? false,
            gothCornerRadiusValue: defaultBar.gothCornerRadiusValue ?? 12,
            borderEnabled: defaultBar.borderEnabled ?? false,
            borderColor: defaultBar.borderColor || "surfaceText",
            borderOpacity: defaultBar.borderOpacity ?? 1.0,
            borderThickness: defaultBar.borderThickness ?? 1,
            widgetOutlineEnabled: defaultBar.widgetOutlineEnabled ?? false,
            widgetOutlineColor: defaultBar.widgetOutlineColor || "primary",
            widgetOutlineOpacity: defaultBar.widgetOutlineOpacity ?? 1.0,
            widgetOutlineThickness: defaultBar.widgetOutlineThickness ?? 1,
            fontScale: defaultBar.fontScale ?? 1.0,
            autoHide: defaultBar.autoHide ?? false,
            autoHideDelay: defaultBar.autoHideDelay ?? 250,
            openOnOverview: defaultBar.openOnOverview ?? false,
            visible: defaultBar.visible ?? true,
            popupGapsAuto: defaultBar.popupGapsAuto ?? true,
            popupGapsManual: defaultBar.popupGapsManual ?? 4
        };
        SettingsData.addBarConfig(newBar);
        selectedBarId = newId;
    }

    function deleteBar(barId) {
        if (barId === "default")
            return;
        if (SettingsData.barConfigs.length <= 1)
            return;
        SettingsData.deleteBarConfig(barId);
        selectedBarId = "default";
    }

    function toggleBarEnabled(barId) {
        if (barId === "default")
            return;
        const config = SettingsData.getBarConfig(barId);
        if (!config)
            return;
        SettingsData.updateBarConfig(barId, {
            enabled: !config.enabled
        });
    }

    function getBarScreenPreferences(barId) {
        const config = SettingsData.getBarConfig(barId);
        return config?.screenPreferences || ["all"];
    }

    function setBarScreenPreferences(barId, prefs) {
        SettingsData.updateBarConfig(barId, {
            screenPreferences: prefs
        });
    }

    function getBarShowOnLastDisplay(barId) {
        const config = SettingsData.getBarConfig(barId);
        return config?.showOnLastDisplay ?? true;
    }

    function setBarShowOnLastDisplay(barId, value) {
        SettingsData.updateBarConfig(barId, {
            showOnLastDisplay: value
        });
    }

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
                "description": I18n.tr("GPU temperature display"),
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
            }
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
        if (widgetId === "diskUsage") {
            widgetObj.mountPath = "/";
        }
        if (widgetId === "cpuUsage" || widgetId === "memUsage" || widgetId === "cpuTemp" || widgetId === "gpuTemp") {
            widgetObj.minimumWidth = true;
        }

        var widgets = getWidgetsForSection(targetSection).slice();
        widgets.push(widgetObj);
        setWidgetsForSection(targetSection, widgets);
    }

    function removeWidgetFromSection(sectionId, widgetIndex) {
        var widgets = getWidgetsForSection(sectionId).slice();
        if (widgetIndex >= 0 && widgetIndex < widgets.length) {
            widgets.splice(widgetIndex, 1);
        }
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

            if (currentId !== widgetId) {
                continue;
            }

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
            if (updated) {
                setWidgetsForSection(sectionId, widgets);
            }
        });
    }

    WidgetSelectionPopup {
        id: widgetSelectionPopup
        parentModal: dankBarTab.parentModal
        onWidgetSelected: (widgetId, targetSection) => {
            dankBarTab.addWidgetToSection(widgetId, targetSection);
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
                height: barManagementContent.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 0

                Column {
                    id: barManagementContent
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "dashboard"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: I18n.tr("Bar Configurations")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 1
                        }

                        DankButton {
                            text: I18n.tr("Add Bar")
                            iconName: "add"
                            buttonHeight: 32
                            visible: SettingsData.barConfigs.length < 4
                            Layout.alignment: Qt.AlignVCenter
                            onClicked: dankBarTab.createNewBar()
                        }
                    }

                    StyledText {
                        id: barConfigText
                        width: parent.width
                        text: I18n.tr("Manage up to 4 independent bar configurations. Each bar has its own position, widgets, styling, and display assignment.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: SettingsData.barConfigs

                            Rectangle {
                                width: parent.width
                                height: barCardContent.implicitHeight + Theme.spacingM * 2
                                radius: Theme.cornerRadius
                                color: dankBarTab.selectedBarId === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : Theme.surfaceVariant
                                border.width: dankBarTab.selectedBarId === modelData.id ? 2 : 0
                                border.color: Theme.primary

                                Row {
                                    id: barCardContent
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Column {
                                        width: parent.width - deleteBtn.width - Theme.spacingM
                                        spacing: Theme.spacingXS / 2

                                        StyledText {
                                            text: modelData.name || "Bar " + (index + 1)
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                        }

                                        Row {
                                            spacing: Theme.spacingS

                                            StyledText {
                                                text: {
                                                    switch (modelData.position) {
                                                    case SettingsData.Position.Top:
                                                        return I18n.tr("Top");
                                                    case SettingsData.Position.Bottom:
                                                        return I18n.tr("Bottom");
                                                    case SettingsData.Position.Left:
                                                        return I18n.tr("Left");
                                                    case SettingsData.Position.Right:
                                                        return I18n.tr("Right");
                                                    default:
                                                        return I18n.tr("Top");
                                                    }
                                                }
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }

                                            StyledText {
                                                text: "•"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }

                                            StyledText {
                                                text: {
                                                    const prefs = modelData.screenPreferences || ["all"];
                                                    if (prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all")) {
                                                        return I18n.tr("All displays");
                                                    }
                                                    return I18n.tr("%1 display(s)").replace("%1", prefs.length);
                                                }
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }

                                            StyledText {
                                                text: "•"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }

                                            StyledText {
                                                text: {
                                                    const left = modelData.leftWidgets?.length || 0;
                                                    const center = modelData.centerWidgets?.length || 0;
                                                    const right = modelData.rightWidgets?.length || 0;
                                                    return I18n.tr("%1 widgets").replace("%1", left + center + right);
                                                }
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }

                                            StyledText {
                                                text: "•"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                visible: !modelData.enabled && modelData.id !== "default"
                                            }

                                            StyledText {
                                                text: I18n.tr("Disabled")
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.error
                                                visible: !modelData.enabled && modelData.id !== "default"
                                            }
                                        }
                                    }

                                    DankActionButton {
                                        id: deleteBtn
                                        buttonSize: 32
                                        iconName: "delete"
                                        iconSize: 16
                                        backgroundColor: Theme.withAlpha(Theme.error, 0.15)
                                        iconColor: Theme.error
                                        visible: modelData.id !== "default"
                                        enabled: SettingsData.barConfigs.length > 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: dankBarTab.deleteBar(modelData.id)
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    z: -1
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: dankBarTab.selectedBarId = modelData.id
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }

                                Behavior on border.width {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: enabledSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 0
                visible: selectedBarId !== "default"

                Row {
                    id: enabledSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    DankIcon {
                        name: selectedBarConfig?.enabled ? "visibility" : "visibility_off"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - Theme.iconSize - Theme.spacingM - enabledToggle.width - Theme.spacingM
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: I18n.tr("Enable Bar")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: I18n.tr("Toggle visibility of this bar configuration")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    DankToggle {
                        id: enabledToggle
                        anchors.verticalCenter: parent.verticalCenter
                        checked: {
                            selectedBarId;
                            return selectedBarConfig?.enabled ?? false;
                        }
                        onToggled: toggled => {
                            dankBarTab.toggleBarEnabled(selectedBarId);
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: screenAssignmentSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 0
                visible: selectedBarConfig?.enabled

                Column {
                    id: screenAssignmentSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "display_settings"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Display Assignment")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Configure which displays show \"%1\"").replace("%1", selectedBarConfig.name || "this bar")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    Column {
                        id: displayAssignmentColumn
                        width: parent.width
                        spacing: Theme.spacingS

                        property bool showingAll: {
                            const prefs = selectedBarConfig?.screenPreferences || ["all"];
                            return prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all");
                        }

                        DankToggle {
                            width: parent.width
                            text: I18n.tr("All displays")
                            description: I18n.tr("Show on all connected displays")
                            checked: displayAssignmentColumn.showingAll
                            onToggled: checked => {
                                if (checked) {
                                    dankBarTab.setBarScreenPreferences(selectedBarId, ["all"]);
                                } else {
                                    dankBarTab.setBarScreenPreferences(selectedBarId, []);
                                }
                            }
                        }

                        DankToggle {
                            width: parent.width
                            text: I18n.tr("Show on Last Display")
                            description: I18n.tr("Always show when there's only one connected display")
                            checked: selectedBarConfig?.showOnLastDisplay ?? true
                            visible: !displayAssignmentColumn.showingAll
                            onToggled: checked => {
                                dankBarTab.setBarShowOnLastDisplay(selectedBarId, checked);
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outline
                            opacity: 0.2
                            visible: !displayAssignmentColumn.showingAll
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS
                            visible: !displayAssignmentColumn.showingAll

                            Repeater {
                                model: Quickshell.screens

                                delegate: DankToggle {
                                    property var screenData: modelData

                                    width: parent.width
                                    text: SettingsData.getScreenDisplayName(screenData)
                                    description: screenData.width + "×" + screenData.height + " • " + (SettingsData.displayNameMode === "system" ? (screenData.model || "Unknown Model") : screenData.name)
                                    checked: {
                                        const prefs = selectedBarConfig?.screenPreferences || [];
                                        if (typeof prefs[0] === "string" && prefs[0] === "all")
                                            return false;
                                        return SettingsData.isScreenInPreferences(screenData, prefs);
                                    }
                                    onToggled: checked => {
                                        let currentPrefs = selectedBarConfig?.screenPreferences || [];
                                        if (typeof currentPrefs[0] === "string" && currentPrefs[0] === "all") {
                                            currentPrefs = [];
                                        }

                                        const screenModelIndex = SettingsData.getScreenModelIndex(screenData);

                                        let newPrefs = currentPrefs.filter(pref => {
                                            if (typeof pref === "string")
                                                return false;
                                            if (pref.modelIndex !== undefined && screenModelIndex >= 0) {
                                                return !(pref.model === screenData.model && pref.modelIndex === screenModelIndex);
                                            }
                                            return pref.name !== screenData.name || pref.model !== screenData.model;
                                        });

                                        if (checked) {
                                            const prefObj = {
                                                name: screenData.name,
                                                model: screenData.model || ""
                                            };
                                            if (screenModelIndex >= 0) {
                                                prefObj.modelIndex = screenModelIndex;
                                            }
                                            newPrefs.push(prefObj);
                                        }

                                        dankBarTab.setBarScreenPreferences(selectedBarId, newPrefs);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: positionSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0
                visible: selectedBarConfig?.enabled

                Column {
                    id: positionSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "vertical_align_center"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Position")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankButtonGroup {
                            id: positionButtonGroup
                            anchors.verticalCenter: parent.verticalCenter
                            model: [I18n.tr("Top"), I18n.tr("Bottom"), I18n.tr("Left"), I18n.tr("Right")]
                            onSelectionChanged: (index, selected) => {
                                if (!selected)
                                    return;
                                let newPos = 0;
                                switch (index) {
                                case 0:
                                    newPos = SettingsData.Position.Top;
                                    break;
                                case 1:
                                    newPos = SettingsData.Position.Bottom;
                                    break;
                                case 2:
                                    newPos = SettingsData.Position.Left;
                                    break;
                                case 3:
                                    newPos = SettingsData.Position.Right;
                                    break;
                                }
                                const wasVertical = selectedBarIsVertical;
                                SettingsData.updateBarConfig(selectedBarId, {
                                    position: newPos
                                });
                                const isVertical = newPos === SettingsData.Position.Left || newPos === SettingsData.Position.Right;
                                if (wasVertical !== isVertical || !isVertical) {
                                    notifyHorizontalBarChange();
                                }
                            }

                            Binding {
                                target: positionButtonGroup
                                property: "currentIndex"
                                value: {
                                    selectedBarId;
                                    const config = SettingsData.getBarConfig(selectedBarId);
                                    const pos = config?.position ?? 0;
                                    switch (pos) {
                                    case SettingsData.Position.Top:
                                        return 0;
                                    case SettingsData.Position.Bottom:
                                        return 1;
                                    case SettingsData.Position.Left:
                                        return 2;
                                    case SettingsData.Position.Right:
                                        return 3;
                                    default:
                                        return 0;
                                    }
                                }
                                restoreMode: Binding.RestoreBinding
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: dankBarAutoHideSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0
                visible: selectedBarConfig?.enabled

                Column {
                    id: dankBarAutoHideSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "visibility_off"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM - autoHideToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Auto-hide")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Automatically hide the top bar to expand screen real estate")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: autoHideToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: selectedBarConfig?.autoHide ?? false
                            onToggled: toggled => {
                                SettingsData.updateBarConfig(selectedBarId, {
                                    autoHide: toggled
                                });
                                notifyHorizontalBarChange();
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: selectedBarConfig?.autoHide ?? false
                        leftPadding: Theme.spacingM

                        Rectangle {
                            width: parent.width - parent.leftPadding
                            height: 1
                            color: Theme.outline
                            opacity: 0.2
                        }

                        Row {
                            width: parent.width - parent.leftPadding
                            spacing: Theme.spacingS

                            StyledText {
                                text: I18n.tr("Hide Delay (ms)")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: parent.width - hideDelayText.implicitWidth - resetHideDelayBtn.width - Theme.spacingS - Theme.spacingM
                                height: 1

                                StyledText {
                                    id: hideDelayText
                                    visible: false
                                    text: I18n.tr("Hide Delay (ms)")
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }

                            DankActionButton {
                                id: resetHideDelayBtn
                                buttonSize: 20
                                iconName: "refresh"
                                iconSize: 12
                                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                iconColor: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    SettingsData.updateBarConfig(selectedBarId, {
                                        autoHideDelay: 250
                                    });
                                }
                            }

                            Item {
                                width: Theme.spacingS
                                height: 1
                            }
                        }

                        DankSlider {
                            id: hideDelaySlider
                            width: parent.width - parent.leftPadding
                            height: 24
                            value: selectedBarConfig?.autoHideDelay ?? 250
                            minimum: 0
                            maximum: 2000
                            unit: "ms"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            onSliderValueChanged: newValue => {
                                SettingsData.updateBarConfig(selectedBarId, {
                                    autoHideDelay: newValue
                                });
                                notifyHorizontalBarChange();
                            }

                            Binding {
                                target: hideDelaySlider
                                property: "value"
                                value: selectedBarConfig?.autoHideDelay ?? 250
                                restoreMode: Binding.RestoreBinding
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "visibility"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM - visibilityToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Manual Show/Hide")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Toggle top bar visibility manually (can be controlled via IPC)")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: visibilityToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: selectedBarConfig?.visible ?? true
                            onToggled: toggled => {
                                SettingsData.updateBarConfig(selectedBarId, {
                                    visible: toggled
                                });
                                notifyHorizontalBarChange();
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                        visible: CompositorService.isNiri
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: CompositorService.isNiri

                        DankIcon {
                            name: "fullscreen"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM - overviewToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Show on Overview")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Always show the top bar when niri's overview is open")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: overviewToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: selectedBarConfig?.openOnOverview ?? false
                            onToggled: toggled => {
                                SettingsData.updateBarConfig(selectedBarId, {
                                    openOnOverview: toggled
                                });
                                notifyHorizontalBarChange();
                            }
                        }
                    }
                }
            }
            StyledRect {
                width: parent.width
                height: dankBarSpacingSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0
                visible: selectedBarConfig?.enabled

                Column {
                    id: dankBarSpacingSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "space_bar"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Spacing")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: I18n.tr("Edge Spacing (0 = edge-to-edge)")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: parent.width - edgeSpacingText.implicitWidth - resetEdgeSpacingBtn.width - Theme.spacingS - Theme.spacingM
                                height: 1

                                StyledText {
                                    id: edgeSpacingText
                                    visible: false
                                    text: I18n.tr("Edge Spacing (0 = edge-to-edge)")
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }

                            DankActionButton {
                                id: resetEdgeSpacingBtn
                                buttonSize: 20
                                iconName: "refresh"
                                iconSize: 12
                                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                iconColor: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    SettingsData.updateBarConfig(selectedBarId, {
                                        spacing: 4
                                    });
                                }
                            }

                            Item {
                                width: Theme.spacingS
                                height: 1
                            }
                        }

                        DankSlider {
                            id: edgeSpacingSlider
                            width: parent.width
                            height: 24
                            value: selectedBarConfig?.spacing ?? 4
                            minimum: 0
                            maximum: 32
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            onSliderValueChanged: newValue => {
                                edgeSpacingDebounce.pendingValue = newValue;
                                edgeSpacingDebounce.restart();
                            }

                            Binding {
                                target: edgeSpacingSlider
                                property: "value"
                                value: selectedBarConfig?.spacing ?? 4
                                restoreMode: Binding.RestoreBinding
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: I18n.tr("Exclusive Zone Offset")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: parent.width - exclusiveZoneText.implicitWidth - resetExclusiveZoneBtn.width - Theme.spacingS - Theme.spacingM
                                height: 1

                                StyledText {
                                    id: exclusiveZoneText
                                    visible: false
                                    text: I18n.tr("Exclusive Zone Offset")
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }

                            DankActionButton {
                                id: resetExclusiveZoneBtn
                                buttonSize: 20
                                iconName: "refresh"
                                iconSize: 12
                                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                iconColor: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    SettingsData.updateBarConfig(selectedBarId, {
                                        bottomGap: 0
                                    });
                                }
                            }

                            Item {
                                width: Theme.spacingS
                                height: 1
                            }
                        }

                        DankSlider {
                            id: exclusiveZoneSlider
                            width: parent.width
                            height: 24
                            value: selectedBarConfig?.bottomGap ?? 0
                            minimum: -50
                            maximum: 50
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            onSliderValueChanged: newValue => {
                                exclusiveZoneDebounce.pendingValue = newValue;
                                exclusiveZoneDebounce.restart();
                            }

                            Binding {
                                target: exclusiveZoneSlider
                                property: "value"
                                value: selectedBarConfig?.bottomGap ?? 0
                                restoreMode: Binding.RestoreBinding
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: I18n.tr("Size")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: parent.width - sizeText.implicitWidth - resetSizeBtn.width - Theme.spacingS - Theme.spacingM
                                height: 1

                                StyledText {
                                    id: sizeText
                                    visible: false
                                    text: I18n.tr("Size")
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }

                            DankActionButton {
                                id: resetSizeBtn
                                buttonSize: 20
                                iconName: "refresh"
                                iconSize: 12
                                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                iconColor: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    SettingsData.updateBarConfig(selectedBarId, {
                                        innerPadding: 4
                                    });
                                }
                            }

                            Item {
                                width: Theme.spacingS
                                height: 1
                            }
                        }

                        DankSlider {
                            id: sizeSlider
                            width: parent.width
                            height: 24
                            value: selectedBarConfig?.innerPadding ?? 4
                            minimum: -8
                            maximum: 24
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            onSliderValueChanged: newValue => {
                                sizeDebounce.pendingValue = newValue;
                                sizeDebounce.restart();
                            }

                            Binding {
                                target: sizeSlider
                                property: "value"
                                value: selectedBarConfig?.innerPadding ?? 4
                                restoreMode: Binding.RestoreBinding
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankToggle {
                            width: parent.width
                            text: I18n.tr("Auto Popup Gaps")
                            description: I18n.tr("Automatically calculate popup distance from bar edge.")
                            checked: selectedBarConfig?.popupGapsAuto ?? true
                            onToggled: checked => {
                                SettingsData.updateBarConfig(selectedBarId, {
                                    popupGapsAuto: checked
                                });
                                notifyHorizontalBarChange();
                            }
                        }

                        Column {
                            width: parent.width
                            leftPadding: Theme.spacingM
                            spacing: Theme.spacingM
                            visible: !(selectedBarConfig?.popupGapsAuto ?? true)

                            Rectangle {
                                width: parent.width - parent.leftPadding
                                height: 1
                                color: Theme.outline
                                opacity: 0.2
                            }

                            Column {
                                width: parent.width - parent.leftPadding
                                spacing: Theme.spacingS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: I18n.tr("Manual Gap Size")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Item {
                                        width: parent.width - manualGapSizeText.implicitWidth - resetManualGapSizeBtn.width - Theme.spacingS - Theme.spacingM
                                        height: 1

                                        StyledText {
                                            id: manualGapSizeText
                                            visible: false
                                            text: I18n.tr("Manual Gap Size")
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                    }

                                    DankActionButton {
                                        id: resetManualGapSizeBtn
                                        buttonSize: 20
                                        iconName: "refresh"
                                        iconSize: 12
                                        backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                        iconColor: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: {
                                            SettingsData.updateBarConfig(selectedBarId, {
                                                popupGapsManual: 4
                                            });
                                        }
                                    }

                                    Item {
                                        width: Theme.spacingS
                                        height: 1
                                    }
                                }

                                DankSlider {
                                    id: popupGapsManualSlider
                                    width: parent.width
                                    height: 24
                                    value: selectedBarConfig?.popupGapsManual ?? 4
                                    minimum: 0
                                    maximum: 50
                                    unit: ""
                                    showValue: true
                                    wheelEnabled: false
                                    thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                    onSliderValueChanged: newValue => {
                                        popupGapsManualDebounce.pendingValue = newValue;
                                        popupGapsManualDebounce.restart();
                                    }

                                    Binding {
                                        target: popupGapsManualSlider
                                        property: "value"
                                        value: selectedBarConfig?.popupGapsManual ?? 4
                                        restoreMode: Binding.RestoreBinding
                                    }
                                }
                            }
                        }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Square Corners")
                        description: "Removes rounded corners from bar container."
                        checked: selectedBarConfig?.squareCorners ?? false
                        onToggled: checked => {
                            SettingsData.updateBarConfig(selectedBarId, {
                                squareCorners: checked
                            });
                        }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("No Background")
                        description: "Remove widget backgrounds for a minimal look with tighter spacing."
                        checked: selectedBarConfig?.noBackground ?? false
                        onToggled: checked => {
                            SettingsData.updateBarConfig(selectedBarId, {
                                noBackground: checked
                            });
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankToggle {
                            width: parent.width
                            text: I18n.tr("Goth Corners")
                            description: "Add curved swooping tips at the bottom of the bar."
                            checked: selectedBarConfig?.gothCornersEnabled ?? false
                            onToggled: checked => {
                                SettingsData.updateBarConfig(selectedBarId, {
                                    gothCornersEnabled: checked
                                });
                            }
                        }

                        DankToggle {
                            width: parent.width
                            text: I18n.tr("Corner Radius Override")
                            description: "Customize the goth corner radius independently."
                            checked: selectedBarConfig?.gothCornerRadiusOverride ?? false
                            visible: selectedBarConfig?.gothCornersEnabled ?? false
                            onToggled: checked => {
                                SettingsData.updateBarConfig(selectedBarId, {
                                    gothCornerRadiusOverride: checked
                                });
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS
                            visible: (selectedBarConfig?.gothCornersEnabled ?? false) && (selectedBarConfig?.gothCornerRadiusOverride ?? false)

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledText {
                                    text: I18n.tr("Goth Corner Radius")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item {
                                    width: parent.width - gothCornerRadiusText.implicitWidth - resetGothCornerRadiusBtn.width - Theme.spacingS - Theme.spacingM
                                    height: 1

                                    StyledText {
                                        id: gothCornerRadiusText
                                        visible: false
                                        text: I18n.tr("Goth Corner Radius")
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }

                                DankActionButton {
                                    id: resetGothCornerRadiusBtn
                                    buttonSize: 20
                                    iconName: "refresh"
                                    iconSize: 12
                                    backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                    iconColor: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: {
                                        SettingsData.updateBarConfig(selectedBarId, {
                                            gothCornerRadiusValue: 12
                                        });
                                    }
                                }

                                Item {
                                    width: Theme.spacingS
                                    height: 1
                                }
                            }

                            DankSlider {
                                id: gothCornerRadiusSlider
                                width: parent.width
                                height: 24
                                value: selectedBarConfig?.gothCornerRadiusValue ?? 12
                                minimum: 0
                                maximum: 64
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                onSliderValueChanged: newValue => {
                                    gothCornerRadiusDebounce.pendingValue = newValue;
                                    gothCornerRadiusDebounce.restart();
                                }

                                Binding {
                                    target: gothCornerRadiusSlider
                                    property: "value"
                                    value: selectedBarConfig?.gothCornerRadiusValue ?? 12
                                    restoreMode: Binding.RestoreBinding
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankToggle {
                            width: parent.width
                            text: I18n.tr("Border")
                            description: "Add a 1px border to the bar. Smart edge detection only shows border on exposed sides."
                            checked: selectedBarConfig?.borderEnabled ?? false
                            onToggled: checked => {
                                SettingsData.updateBarConfig(selectedBarId, {
                                    borderEnabled: checked
                                });
                            }
                        }

                        Column {
                            width: parent.width
                            leftPadding: Theme.spacingM
                            spacing: Theme.spacingM
                            visible: selectedBarConfig?.borderEnabled ?? false

                            Rectangle {
                                width: parent.width - parent.leftPadding
                                height: 1
                                color: Theme.outline
                                opacity: 0.2
                            }

                            Row {
                                width: parent.width - parent.leftPadding
                                spacing: Theme.spacingM

                                Column {
                                    width: parent.width - borderColorGroup.width - Theme.spacingM
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: I18n.tr("Border Color")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                    }

                                    StyledText {
                                        text: I18n.tr("Choose the border accent color")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        width: parent.width
                                    }
                                }

                                DankButtonGroup {
                                    id: borderColorGroup
                                    anchors.verticalCenter: parent.verticalCenter
                                    model: ["Surface", "Secondary", "Primary"]
                                    currentIndex: {
                                        const colorOption = selectedBarConfig?.borderColor || "surfaceText";
                                        switch (colorOption) {
                                        case "surfaceText":
                                            return 0;
                                        case "secondary":
                                            return 1;
                                        case "primary":
                                            return 2;
                                        default:
                                            return 0;
                                        }
                                    }
                                    onSelectionChanged: (index, selected) => {
                                        if (selected) {
                                            let newColor = "surfaceText";
                                            switch (index) {
                                            case 0:
                                                newColor = "surfaceText";
                                                break;
                                            case 1:
                                                newColor = "secondary";
                                                break;
                                            case 2:
                                                newColor = "primary";
                                                break;
                                            }
                                            SettingsData.updateBarConfig(selectedBarId, {
                                                borderColor: newColor
                                            });
                                        }
                                    }
                                }
                            }

                            Column {
                                width: parent.width - parent.leftPadding
                                spacing: Theme.spacingS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: I18n.tr("Border Opacity")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Item {
                                        width: parent.width - borderOpacityText.implicitWidth - resetBorderOpacityBtn.width - Theme.spacingS - Theme.spacingM
                                        height: 1

                                        StyledText {
                                            id: borderOpacityText
                                            visible: false
                                            text: I18n.tr("Border Opacity")
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                    }

                                    DankActionButton {
                                        id: resetBorderOpacityBtn
                                        buttonSize: 20
                                        iconName: "refresh"
                                        iconSize: 12
                                        backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                        iconColor: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: {
                                            SettingsData.updateBarConfig(selectedBarId, {
                                                borderOpacity: 1.0
                                            });
                                        }
                                    }

                                    Item {
                                        width: Theme.spacingS
                                        height: 1
                                    }
                                }

                                DankSlider {
                                    id: borderOpacitySlider
                                    width: parent.width
                                    height: 24
                                    value: (selectedBarConfig?.borderOpacity ?? 1.0) * 100
                                    minimum: 0
                                    maximum: 100
                                    unit: "%"
                                    showValue: true
                                    wheelEnabled: false
                                    thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                    onSliderValueChanged: newValue => {
                                        borderOpacityDebounce.pendingValue = newValue / 100;
                                        borderOpacityDebounce.restart();
                                    }

                                    Binding {
                                        target: borderOpacitySlider
                                        property: "value"
                                        value: (selectedBarConfig?.borderOpacity ?? 1.0) * 100
                                        restoreMode: Binding.RestoreBinding
                                    }
                                }
                            }

                            Column {
                                width: parent.width - parent.leftPadding
                                spacing: Theme.spacingS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: I18n.tr("Border Thickness")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Item {
                                        width: parent.width - borderThicknessText.implicitWidth - resetBorderThicknessBtn.width - Theme.spacingS - Theme.spacingM
                                        height: 1

                                        StyledText {
                                            id: borderThicknessText
                                            visible: false
                                            text: I18n.tr("Border Thickness")
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                    }

                                    DankActionButton {
                                        id: resetBorderThicknessBtn
                                        buttonSize: 20
                                        iconName: "refresh"
                                        iconSize: 12
                                        backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                        iconColor: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: {
                                            SettingsData.updateBarConfig(selectedBarId, {
                                                borderThickness: 1
                                            });
                                        }
                                    }

                                    Item {
                                        width: Theme.spacingS
                                        height: 1
                                    }
                                }

                                DankSlider {
                                    id: borderThicknessSlider
                                    width: parent.width
                                    height: 24
                                    value: selectedBarConfig?.borderThickness ?? 1
                                    minimum: 1
                                    maximum: 10
                                    unit: "px"
                                    showValue: true
                                    wheelEnabled: false
                                    thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                    onSliderValueChanged: newValue => {
                                        borderThicknessDebounce.pendingValue = newValue;
                                        borderThicknessDebounce.restart();
                                    }

                                    Binding {
                                        target: borderThicknessSlider
                                        property: "value"
                                        value: selectedBarConfig?.borderThickness ?? 1
                                        restoreMode: Binding.RestoreBinding
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankToggle {
                            width: parent.width
                            text: I18n.tr("Widget Outline")
                            description: "Add outlines to individual widgets."
                            checked: selectedBarConfig?.widgetOutlineEnabled ?? false
                            onToggled: checked => {
                                SettingsData.updateBarConfig(selectedBarId, {
                                    widgetOutlineEnabled: checked
                                });
                            }
                        }

                        Column {
                            width: parent.width
                            leftPadding: Theme.spacingM
                            spacing: Theme.spacingM
                            visible: selectedBarConfig?.widgetOutlineEnabled ?? false

                            Rectangle {
                                width: parent.width - parent.leftPadding
                                height: 1
                                color: Theme.outline
                                opacity: 0.2
                            }

                            Row {
                                width: parent.width - parent.leftPadding
                                spacing: Theme.spacingM

                                Column {
                                    width: parent.width - widgetOutlineColorGroup.width - Theme.spacingM
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: I18n.tr("Outline Color")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                    }

                                    StyledText {
                                        text: I18n.tr("Choose the widget outline accent color")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        width: parent.width
                                    }
                                }

                                DankButtonGroup {
                                    id: widgetOutlineColorGroup
                                    anchors.verticalCenter: parent.verticalCenter
                                    model: ["Surface", "Secondary", "Primary"]
                                    currentIndex: {
                                        const colorOption = selectedBarConfig?.widgetOutlineColor || "primary";
                                        switch (colorOption) {
                                        case "surfaceText":
                                            return 0;
                                        case "secondary":
                                            return 1;
                                        case "primary":
                                            return 2;
                                        default:
                                            return 2;
                                        }
                                    }
                                    onSelectionChanged: (index, selected) => {
                                        if (!selected)
                                            return;
                                        let newColor = "primary";
                                        switch (index) {
                                        case 0:
                                            newColor = "surfaceText";
                                            break;
                                        case 1:
                                            newColor = "secondary";
                                            break;
                                        case 2:
                                            newColor = "primary";
                                            break;
                                        }
                                        SettingsData.updateBarConfig(selectedBarId, {
                                            widgetOutlineColor: newColor
                                        });
                                    }
                                }
                            }

                            Column {
                                width: parent.width - parent.leftPadding
                                spacing: Theme.spacingS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: I18n.tr("Outline Opacity")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Item {
                                        width: parent.width - widgetOutlineOpacityText.implicitWidth - resetWidgetOutlineOpacityBtn.width - Theme.spacingS - Theme.spacingM
                                        height: 1

                                        StyledText {
                                            id: widgetOutlineOpacityText
                                            visible: false
                                            text: I18n.tr("Outline Opacity")
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                    }

                                    DankActionButton {
                                        id: resetWidgetOutlineOpacityBtn
                                        buttonSize: 20
                                        iconName: "refresh"
                                        iconSize: 12
                                        backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                        iconColor: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: {
                                            SettingsData.updateBarConfig(selectedBarId, {
                                                widgetOutlineOpacity: 1.0
                                            });
                                        }
                                    }

                                    Item {
                                        width: Theme.spacingS
                                        height: 1
                                    }
                                }

                                DankSlider {
                                    id: widgetOutlineOpacitySlider
                                    width: parent.width
                                    height: 24
                                    value: (selectedBarConfig?.widgetOutlineOpacity ?? 1.0) * 100
                                    minimum: 0
                                    maximum: 100
                                    unit: "%"
                                    showValue: true
                                    wheelEnabled: false
                                    thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                    onSliderValueChanged: newValue => {
                                        widgetOutlineOpacityDebounce.pendingValue = newValue / 100;
                                        widgetOutlineOpacityDebounce.restart();
                                    }

                                    Binding {
                                        target: widgetOutlineOpacitySlider
                                        property: "value"
                                        value: (selectedBarConfig?.widgetOutlineOpacity ?? 1.0) * 100
                                        restoreMode: Binding.RestoreBinding
                                    }
                                }
                            }

                            Column {
                                width: parent.width - parent.leftPadding
                                spacing: Theme.spacingS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: I18n.tr("Outline Thickness")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Item {
                                        width: parent.width - widgetOutlineThicknessText.implicitWidth - resetWidgetOutlineThicknessBtn.width - Theme.spacingS - Theme.spacingM
                                        height: 1

                                        StyledText {
                                            id: widgetOutlineThicknessText
                                            visible: false
                                            text: I18n.tr("Outline Thickness")
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                    }

                                    DankActionButton {
                                        id: resetWidgetOutlineThicknessBtn
                                        buttonSize: 20
                                        iconName: "refresh"
                                        iconSize: 12
                                        backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                        iconColor: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: {
                                            SettingsData.updateBarConfig(selectedBarId, {
                                                widgetOutlineThickness: 1
                                            });
                                        }
                                    }

                                    Item {
                                        width: Theme.spacingS
                                        height: 1
                                    }
                                }

                                DankSlider {
                                    id: widgetOutlineThicknessSlider
                                    width: parent.width
                                    height: 24
                                    value: selectedBarConfig?.widgetOutlineThickness ?? 1
                                    minimum: 1
                                    maximum: 10
                                    unit: "px"
                                    showValue: true
                                    wheelEnabled: false
                                    thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                    onSliderValueChanged: newValue => {
                                        widgetOutlineThicknessDebounce.pendingValue = newValue;
                                        widgetOutlineThicknessDebounce.restart();
                                    }

                                    Binding {
                                        target: widgetOutlineThicknessSlider
                                        property: "value"
                                        value: selectedBarConfig?.widgetOutlineThickness ?? 1
                                        restoreMode: Binding.RestoreBinding
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: I18n.tr("Bar Transparency")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: parent.width - barTransparencyText.implicitWidth - resetBarTransparencyBtn.width - Theme.spacingS - Theme.spacingM
                                height: 1

                                StyledText {
                                    id: barTransparencyText
                                    visible: false
                                    text: I18n.tr("Bar Transparency")
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }

                            DankActionButton {
                                id: resetBarTransparencyBtn
                                buttonSize: 20
                                iconName: "refresh"
                                iconSize: 12
                                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                iconColor: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    SettingsData.updateBarConfig(selectedBarId, {
                                        transparency: 1.0
                                    });
                                }
                            }

                            Item {
                                width: Theme.spacingS
                                height: 1
                            }
                        }

                        DankSlider {
                            id: barTransparencySlider
                            width: parent.width
                            height: 24
                            value: (selectedBarConfig?.transparency ?? 1.0) * 100
                            minimum: 0
                            maximum: 100
                            unit: "%"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            onSliderValueChanged: newValue => {
                                barTransparencyDebounce.pendingValue = newValue / 100;
                                barTransparencyDebounce.restart();
                            }

                            Binding {
                                target: barTransparencySlider
                                property: "value"
                                value: (selectedBarConfig?.transparency ?? 1.0) * 100
                                restoreMode: Binding.RestoreBinding
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: I18n.tr("Widget Transparency")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: parent.width - widgetTransparencyText.implicitWidth - resetWidgetTransparencyBtn.width - Theme.spacingS - Theme.spacingM
                                height: 1

                                StyledText {
                                    id: widgetTransparencyText
                                    visible: false
                                    text: I18n.tr("Widget Transparency")
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }

                            DankActionButton {
                                id: resetWidgetTransparencyBtn
                                buttonSize: 20
                                iconName: "refresh"
                                iconSize: 12
                                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                iconColor: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    SettingsData.updateBarConfig(selectedBarId, {
                                        widgetTransparency: 1.0
                                    });
                                    notifyHorizontalBarChange();
                                }
                            }

                            Item {
                                width: Theme.spacingS
                                height: 1
                            }
                        }

                        DankSlider {
                            id: widgetTransparencySlider
                            width: parent.width
                            height: 24
                            value: (selectedBarConfig?.widgetTransparency ?? 1.0) * 100
                            minimum: 0
                            maximum: 100
                            unit: "%"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            onSliderValueChanged: newValue => {
                                widgetTransparencyDebounce.pendingValue = newValue / 100;
                                widgetTransparencyDebounce.restart();
                            }

                            Binding {
                                target: widgetTransparencySlider
                                property: "value"
                                value: (selectedBarConfig?.widgetTransparency ?? 1.0) * 100
                                restoreMode: Binding.RestoreBinding
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                    }

                    Rectangle {
                        width: parent.width
                        height: 60
                        radius: Theme.cornerRadius
                        color: "transparent"

                        Column {
                            anchors.left: parent.left
                            anchors.right: dankBarFontScaleControls.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("DankBar Font Scale")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Scale DankBar font sizes independently")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                            }
                        }

                        Row {
                            id: dankBarFontScaleControls

                            width: 180
                            height: 36
                            anchors.right: parent.right
                            anchors.rightMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankActionButton {
                                buttonSize: 32
                                iconName: "remove"
                                iconSize: Theme.iconSizeSmall
                                enabled: (selectedBarConfig?.fontScale ?? 1.0) > 0.5
                                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    var currentScale = selectedBarConfig?.fontScale ?? 1.0;
                                    var newScale = Math.max(0.5, currentScale - 0.05);
                                    SettingsData.updateBarConfig(selectedBarId, {
                                        fontScale: newScale
                                    });
                                    notifyHorizontalBarChange();
                                }
                            }

                            StyledRect {
                                width: 60
                                height: 32
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                border.width: 0

                                StyledText {
                                    anchors.centerIn: parent
                                    text: ((selectedBarConfig?.fontScale ?? 1.0) * 100).toFixed(0) + "%"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                            }

                            DankActionButton {
                                buttonSize: 32
                                iconName: "add"
                                iconSize: Theme.iconSizeSmall
                                enabled: (selectedBarConfig?.fontScale ?? 1.0) < 2.0
                                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    var currentScale = selectedBarConfig?.fontScale ?? 1.0;
                                    var newScale = Math.min(2.0, currentScale + 0.05);
                                    SettingsData.updateBarConfig(selectedBarId, {
                                        fontScale: newScale
                                    });
                                    notifyHorizontalBarChange();
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: widgetManagementSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0
                visible: selectedBarConfig?.enabled

                Column {
                    id: widgetManagementSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            id: widgetIcon
                            name: "widgets"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            id: widgetTitle
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
                            id: resetButton
                            width: 80
                            height: 28
                            radius: Theme.cornerRadius
                            color: resetArea.containsMouse ? Theme.surfacePressed : Theme.surfaceVariant
                            Layout.alignment: Qt.AlignVCenter
                            border.width: 0
                            border.color: resetArea.containsMouse ? Theme.outline : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.5)

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

                            Behavior on border.color {
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
                visible: selectedBarConfig?.enabled

                StyledRect {
                    width: parent.width
                    height: leftSection.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 0

                    WidgetsTabSection {
                        id: leftSection
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        title: selectedBarIsVertical ? I18n.tr("Top Section") : I18n.tr("Left Section")
                        titleIcon: "format_align_left"
                        sectionId: "left"
                        allWidgets: dankBarTab.baseWidgetDefinitions
                        items: dankBarTab.getItemsForSection("left")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => {
                            dankBarTab.handleItemEnabledChanged(sectionId, itemId, enabled);
                        }
                        onItemOrderChanged: newOrder => {
                            dankBarTab.handleItemOrderChanged(sectionId, newOrder);
                        }
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.targetSection = sectionId;
                            widgetSelectionPopup.allWidgets = dankBarTab.getWidgetsForPopup();
                            widgetSelectionPopup.show();
                        }
                        onRemoveWidget: (sectionId, index) => {
                            dankBarTab.removeWidgetFromSection(sectionId, index);
                        }
                        onSpacerSizeChanged: (sectionId, index, size) => {
                            dankBarTab.handleSpacerSizeChanged(sectionId, index, size);
                        }
                        onGpuSelectionChanged: (sectionId, index, gpuIndex) => {
                            dankBarTab.handleGpuSelectionChanged(sectionId, index, gpuIndex);
                        }
                        onDiskMountSelectionChanged: (sectionId, index, mountPath) => {
                            dankBarTab.handleDiskMountSelectionChanged(sectionId, index, mountPath);
                        }
                        onControlCenterSettingChanged: (sectionId, index, setting, value) => {
                            dankBarTab.handleControlCenterSettingChanged(sectionId, index, setting, value);
                        }
                        onPrivacySettingChanged: (sectionId, index, setting, value) => {
                            dankBarTab.handlePrivacySettingChanged(sectionId, index, setting, value);
                        }
                        onMinimumWidthChanged: (sectionId, index, enabled) => {
                            dankBarTab.handleMinimumWidthChanged(sectionId, index, enabled);
                        }
                        onShowSwapChanged: (sectionId, index, enabled) => {
                            dankBarTab.handleShowSwapChanged(sectionId, index, enabled);
                        }
                        onCompactModeChanged: (widgetId, value) => {
                            dankBarTab.handleCompactModeChanged(sectionId, widgetId, value);
                        }
                    }
                }

                StyledRect {
                    width: parent.width
                    height: centerSection.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 0

                    WidgetsTabSection {
                        id: centerSection
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        title: selectedBarIsVertical ? I18n.tr("Middle Section") : I18n.tr("Center Section")
                        titleIcon: "format_align_center"
                        sectionId: "center"
                        allWidgets: dankBarTab.baseWidgetDefinitions
                        items: dankBarTab.getItemsForSection("center")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => {
                            dankBarTab.handleItemEnabledChanged(sectionId, itemId, enabled);
                        }
                        onItemOrderChanged: newOrder => {
                            dankBarTab.handleItemOrderChanged(sectionId, newOrder);
                        }
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.targetSection = sectionId;
                            widgetSelectionPopup.allWidgets = dankBarTab.getWidgetsForPopup();
                            widgetSelectionPopup.show();
                        }
                        onRemoveWidget: (sectionId, index) => {
                            dankBarTab.removeWidgetFromSection(sectionId, index);
                        }
                        onSpacerSizeChanged: (sectionId, index, size) => {
                            dankBarTab.handleSpacerSizeChanged(sectionId, index, size);
                        }
                        onGpuSelectionChanged: (sectionId, index, gpuIndex) => {
                            dankBarTab.handleGpuSelectionChanged(sectionId, index, gpuIndex);
                        }
                        onDiskMountSelectionChanged: (sectionId, index, mountPath) => {
                            dankBarTab.handleDiskMountSelectionChanged(sectionId, index, mountPath);
                        }
                        onControlCenterSettingChanged: (sectionId, index, setting, value) => {
                            dankBarTab.handleControlCenterSettingChanged(sectionId, index, setting, value);
                        }
                        onPrivacySettingChanged: (sectionId, index, setting, value) => {
                            dankBarTab.handlePrivacySettingChanged(sectionId, index, setting, value);
                        }
                        onMinimumWidthChanged: (sectionId, index, enabled) => {
                            dankBarTab.handleMinimumWidthChanged(sectionId, index, enabled);
                        }
                        onShowSwapChanged: (sectionId, index, enabled) => {
                            dankBarTab.handleShowSwapChanged(sectionId, index, enabled);
                        }
                        onCompactModeChanged: (widgetId, value) => {
                            dankBarTab.handleCompactModeChanged(sectionId, widgetId, value);
                        }
                    }
                }

                StyledRect {
                    width: parent.width
                    height: rightSection.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 0

                    WidgetsTabSection {
                        id: rightSection
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        title: selectedBarIsVertical ? I18n.tr("Bottom Section") : I18n.tr("Right Section")
                        titleIcon: "format_align_right"
                        sectionId: "right"
                        allWidgets: dankBarTab.baseWidgetDefinitions
                        items: dankBarTab.getItemsForSection("right")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => {
                            dankBarTab.handleItemEnabledChanged(sectionId, itemId, enabled);
                        }
                        onItemOrderChanged: newOrder => {
                            dankBarTab.handleItemOrderChanged(sectionId, newOrder);
                        }
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.targetSection = sectionId;
                            widgetSelectionPopup.allWidgets = dankBarTab.getWidgetsForPopup();
                            widgetSelectionPopup.show();
                        }
                        onRemoveWidget: (sectionId, index) => {
                            dankBarTab.removeWidgetFromSection(sectionId, index);
                        }
                        onSpacerSizeChanged: (sectionId, index, size) => {
                            dankBarTab.handleSpacerSizeChanged(sectionId, index, size);
                        }
                        onGpuSelectionChanged: (sectionId, index, gpuIndex) => {
                            dankBarTab.handleGpuSelectionChanged(sectionId, index, gpuIndex);
                        }
                        onDiskMountSelectionChanged: (sectionId, index, mountPath) => {
                            dankBarTab.handleDiskMountSelectionChanged(sectionId, index, mountPath);
                        }
                        onControlCenterSettingChanged: (sectionId, index, setting, value) => {
                            dankBarTab.handleControlCenterSettingChanged(sectionId, index, setting, value);
                        }
                        onPrivacySettingChanged: (sectionId, index, setting, value) => {
                            dankBarTab.handlePrivacySettingChanged(sectionId, index, setting, value);
                        }
                        onMinimumWidthChanged: (sectionId, index, enabled) => {
                            dankBarTab.handleMinimumWidthChanged(sectionId, index, enabled);
                        }
                        onShowSwapChanged: (sectionId, index, enabled) => {
                            dankBarTab.handleShowSwapChanged(sectionId, index, enabled);
                        }
                        onCompactModeChanged: (widgetId, value) => {
                            dankBarTab.handleCompactModeChanged(sectionId, widgetId, value);
                        }
                    }
                }
            }
        }
    }
}
