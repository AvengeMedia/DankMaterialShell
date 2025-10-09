import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: dankBarTab

    property var parentModal: null

    function getWidgetsForPopup() {
        return baseWidgetDefinitions.filter(widget => {
            if (widget.warning && widget.warning.includes("Plugin is disabled")) {
                return false
            }
            return true
        })
    }

    property var baseWidgetDefinitions: {
        var coreWidgets = [{
            "id": "launcherButton",
            "text": I18n.tr("App Launcher"),
            "description": I18n.tr("Quick access to application launcher"),
            "icon": "apps",
            "enabled": true
        }, {
            "id": "workspaceSwitcher",
            "text": I18n.tr("Workspace Switcher"),
            "description": I18n.tr("Shows current workspace and allows switching"),
            "icon": "view_module",
            "enabled": true
        }, {
            "id": "focusedWindow",
            "text": I18n.tr("Focused Window"),
            "description": I18n.tr("Display currently focused application title"),
            "icon": "window",
            "enabled": true
        }, {
            "id": "runningApps",
            "text": I18n.tr("Running Apps"),
            "description": I18n.tr("Shows all running applications with focus indication"),
            "icon": "apps",
            "enabled": true
        }, {
            "id": "clock",
            "text": I18n.tr("Clock"),
            "description": I18n.tr("Current time and date display"),
            "icon": "schedule",
            "enabled": true
        }, {
            "id": "weather",
            "text": I18n.tr("Weather Widget"),
            "description": I18n.tr("Current weather conditions and temperature"),
            "icon": "wb_sunny",
            "enabled": true
        }, {
            "id": "music",
            "text": I18n.tr("Media Controls"),
            "description": I18n.tr("Control currently playing media"),
            "icon": "music_note",
            "enabled": true
        }, {
            "id": "clipboard",
            "text": I18n.tr("Clipboard Manager"),
            "description": I18n.tr("Access clipboard history"),
            "icon": "content_paste",
            "enabled": true
        }, {
            "id": "cpuUsage",
            "text": I18n.tr("CPU Usage"),
            "description": I18n.tr("CPU usage indicator"),
            "icon": "memory",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? I18n.tr("Requires 'dgop' tool") : undefined
        }, {
            "id": "memUsage",
            "text": I18n.tr("Memory Usage"),
            "description": I18n.tr("Memory usage indicator"),
            "icon": "developer_board",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? I18n.tr("Requires 'dgop' tool") : undefined
        }, {
            "id": "diskUsage",
            "text": I18n.tr("Disk Usage"),
            "description": I18n.tr("Percentage"),
            "icon": "storage",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? I18n.tr("Requires 'dgop' tool") : undefined
        }, {
            "id": "cpuTemp",
            "text": I18n.tr("CPU Temperature"),
            "description": I18n.tr("CPU temperature display"),
            "icon": "device_thermostat",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? I18n.tr("Requires 'dgop' tool") : undefined
        }, {
            "id": "gpuTemp",
            "text": I18n.tr("GPU Temperature"),
            "description": I18n.tr("GPU temperature display"),
            "icon": "auto_awesome_mosaic",
            "warning": !DgopService.dgopAvailable ? I18n.tr("Requires 'dgop' tool") : I18n.tr("This widget prevents GPU power off states, which can significantly impact battery life on laptops. It is not recommended to use this on laptops with hybrid graphics."),
            "enabled": DgopService.dgopAvailable
        }, {
            "id": "systemTray",
            "text": I18n.tr("System Tray"),
            "description": I18n.tr("System notification area icons"),
            "icon": "notifications",
            "enabled": true
        }, {
            "id": "privacyIndicator",
            "text": I18n.tr("Privacy Indicator"),
            "description": I18n.tr("Shows when microphone, camera, or screen sharing is active"),
            "icon": "privacy_tip",
            "enabled": true
        }, {
            "id": "controlCenterButton",
            "text": I18n.tr("Control Center"),
            "description": I18n.tr("Access to system controls and settings"),
            "icon": "settings",
            "enabled": true
        }, {
            "id": "notificationButton",
            "text": I18n.tr("Notification Center"),
            "description": I18n.tr("Access to notifications and do not disturb"),
            "icon": "notifications",
            "enabled": true
        }, {
            "id": "battery",
            "text": I18n.tr("Battery"),
            "description": I18n.tr("Battery level and power management"),
            "icon": "battery_std",
            "enabled": true
        }, {
            "id": "vpn",
            "text": I18n.tr("VPN"),
            "description": I18n.tr("VPN status and quick connect"),
            "icon": "vpn_lock",
            "enabled": true
        }, {
            "id": "idleInhibitor",
            "text": I18n.tr("Idle Inhibitor"),
            "description": I18n.tr("Prevent screen timeout"),
            "icon": "motion_sensor_active",
            "enabled": true
        }, {
            "id": "spacer",
            "text": I18n.tr("Spacer"),
            "description": I18n.tr("Customizable empty space"),
            "icon": "more_horiz",
            "enabled": true
        }, {
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
        }, {
            "id": "keyboard_layout_name",
            "text": I18n.tr("Keyboard Layout Name"),
            "description": I18n.tr("Displays the active keyboard layout and allows switching"),
            "icon": "keyboard",
        }, {
            "id": "notepadButton",
            "text": I18n.tr("Notepad"),
            "description": I18n.tr("Quick access to notepad"),
            "icon": "assignment",
            "enabled": true
        }, {
            "id": "colorPicker",
            "text": I18n.tr("Color Picker"),
            "description": I18n.tr("Quick access to color picker"),
            "icon": "palette",
            "enabled": true
        }, {
            "id": "systemUpdate",
            "text": I18n.tr("System Update"),
            "description": I18n.tr("Check for system updates"),
            "icon": "update",
            "enabled": SystemUpdateService.distributionSupported
        }]

        var allPluginVariants = PluginService.getAllPluginVariants()
        for (var i = 0; i < allPluginVariants.length; i++) {
            var variant = allPluginVariants[i]
            coreWidgets.push({
                "id": variant.fullId,
                "text": variant.name,
                "description": variant.description,
                "icon": variant.icon,
                "enabled": variant.loaded,
                "warning": !variant.loaded ? I18n.tr("Plugin is disabled - enable in Plugins settings to use") : undefined
            })
        }

        return coreWidgets
    }
    property var defaultLeftWidgets: [{
            "id": "launcherButton",
            "enabled": true
        }, {
            "id": "workspaceSwitcher",
            "enabled": true
        }, {
            "id": "focusedWindow",
            "enabled": true
        }]
    property var defaultCenterWidgets: [{
            "id": "music",
            "enabled": true
        }, {
            "id": "clock",
            "enabled": true
        }, {
            "id": "weather",
            "enabled": true
        }]
    property var defaultRightWidgets: [{
            "id": "systemTray",
            "enabled": true
        }, {
            "id": "clipboard",
            "enabled": true
        }, {
            "id": "notificationButton",
            "enabled": true
        }, {
            "id": "battery",
            "enabled": true
        }, {
            "id": "controlCenterButton",
            "enabled": true
        }]

    function addWidgetToSection(widgetId, targetSection) {
        var widgetObj = {
            "id": widgetId,
            "enabled": true
        }
        if (widgetId === "spacer")
            widgetObj.size = 20
        if (widgetId === "gpuTemp") {
            widgetObj.selectedGpuIndex = 0
            widgetObj.pciId = ""
        }
        if (widgetId === "controlCenterButton") {
            widgetObj.showNetworkIcon = true
            widgetObj.showBluetoothIcon = true
            widgetObj.showAudioIcon = true
        }
        if (widgetId === "diskUsage") {
            widgetObj.mountPath = "/"
        }
        if (widgetId === "cpuUsage" || widgetId === "memUsage" || widgetId === "cpuTemp" || widgetId === "gpuTemp") {
            widgetObj.minimumWidth = true
        }

        var widgets = []
        if (targetSection === "left") {
            widgets = SettingsData.dankBarLeftWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setDankBarLeftWidgets(widgets)
        } else if (targetSection === "center") {
            widgets = SettingsData.dankBarCenterWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setDankBarCenterWidgets(widgets)
        } else if (targetSection === "right") {
            widgets = SettingsData.dankBarRightWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setDankBarRightWidgets(widgets)
        }
    }

    function removeWidgetFromSection(sectionId, widgetIndex) {
        var widgets = []
        if (sectionId === "left") {
            widgets = SettingsData.dankBarLeftWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
            }
            SettingsData.setDankBarLeftWidgets(widgets)
        } else if (sectionId === "center") {
            widgets = SettingsData.dankBarCenterWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
            }
            SettingsData.setDankBarCenterWidgets(widgets)
        } else if (sectionId === "right") {
            widgets = SettingsData.dankBarRightWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
            }
            SettingsData.setDankBarRightWidgets(widgets)
        }
    }

    function handleItemEnabledChanged(sectionId, itemId, enabled) {
        var widgets = []
        if (sectionId === "left")
            widgets = SettingsData.dankBarLeftWidgets.slice()
        else if (sectionId === "center")
            widgets = SettingsData.dankBarCenterWidgets.slice()
        else if (sectionId === "right")
            widgets = SettingsData.dankBarRightWidgets.slice()
        for (var i = 0; i < widgets.length; i++) {
            var widget = widgets[i]
            var widgetId = typeof widget === "string" ? widget : widget.id
            if (widgetId === itemId) {
                if (typeof widget === "string") {
                    widgets[i] = {
                        "id": widget,
                        "enabled": enabled
                    }
                } else {
                    var newWidget = {
                        "id": widget.id,
                        "enabled": enabled
                    }
                    if (widget.size !== undefined)
                        newWidget.size = widget.size
                    if (widget.selectedGpuIndex !== undefined)
                        newWidget.selectedGpuIndex = widget.selectedGpuIndex
                    else if (widget.id === "gpuTemp")
                        newWidget.selectedGpuIndex = 0
                    if (widget.pciId !== undefined)
                        newWidget.pciId = widget.pciId
                    else if (widget.id === "gpuTemp")
                        newWidget.pciId = ""
                    if (widget.id === "controlCenterButton") {
                        newWidget.showNetworkIcon = widget.showNetworkIcon !== undefined ? widget.showNetworkIcon : true
                        newWidget.showBluetoothIcon = widget.showBluetoothIcon !== undefined ? widget.showBluetoothIcon : true
                        newWidget.showAudioIcon = widget.showAudioIcon !== undefined ? widget.showAudioIcon : true
                    }
                    widgets[i] = newWidget
                }
                break
            }
        }
        if (sectionId === "left")
            SettingsData.setDankBarLeftWidgets(widgets)
        else if (sectionId === "center")
            SettingsData.setDankBarCenterWidgets(widgets)
        else if (sectionId === "right")
            SettingsData.setDankBarRightWidgets(widgets)
    }

    function handleItemOrderChanged(sectionId, newOrder) {
        if (sectionId === "left")
            SettingsData.setDankBarLeftWidgets(newOrder)
        else if (sectionId === "center")
            SettingsData.setDankBarCenterWidgets(newOrder)
        else if (sectionId === "right")
            SettingsData.setDankBarRightWidgets(newOrder)
    }

    function handleSpacerSizeChanged(sectionId, widgetIndex, newSize) {
        var widgets = []
        if (sectionId === "left")
            widgets = SettingsData.dankBarLeftWidgets.slice()
        else if (sectionId === "center")
            widgets = SettingsData.dankBarCenterWidgets.slice()
        else if (sectionId === "right")
            widgets = SettingsData.dankBarRightWidgets.slice()
        
        if (widgetIndex >= 0 && widgetIndex < widgets.length) {
            var widget = widgets[widgetIndex]
            var widgetId = typeof widget === "string" ? widget : widget.id
            if (widgetId === "spacer") {
                if (typeof widget === "string") {
                    widgets[widgetIndex] = {
                        "id": widget,
                        "enabled": true,
                        "size": newSize
                    }
                } else {
                    var newWidget = {
                        "id": widget.id,
                        "enabled": widget.enabled,
                        "size": newSize
                    }
                    if (widget.selectedGpuIndex !== undefined)
                        newWidget.selectedGpuIndex = widget.selectedGpuIndex
                    if (widget.pciId !== undefined)
                        newWidget.pciId = widget.pciId
                    if (widget.id === "controlCenterButton") {
                        newWidget.showNetworkIcon = widget.showNetworkIcon !== undefined ? widget.showNetworkIcon : true
                        newWidget.showBluetoothIcon = widget.showBluetoothIcon !== undefined ? widget.showBluetoothIcon : true
                        newWidget.showAudioIcon = widget.showAudioIcon !== undefined ? widget.showAudioIcon : true
                    }
                    widgets[widgetIndex] = newWidget
                }
            }
        }
        
        if (sectionId === "left")
            SettingsData.setDankBarLeftWidgets(widgets)
        else if (sectionId === "center")
            SettingsData.setDankBarCenterWidgets(widgets)
        else if (sectionId === "right")
            SettingsData.setDankBarRightWidgets(widgets)
    }

    function handleGpuSelectionChanged(sectionId, widgetIndex, selectedGpuIndex) {
        var widgets = []
        if (sectionId === "left")
            widgets = SettingsData.dankBarLeftWidgets.slice()
        else if (sectionId === "center")
            widgets = SettingsData.dankBarCenterWidgets.slice()
        else if (sectionId === "right")
            widgets = SettingsData.dankBarRightWidgets.slice()

        if (widgetIndex >= 0 && widgetIndex < widgets.length) {
            var widget = widgets[widgetIndex]
            if (typeof widget === "string") {
                widgets[widgetIndex] = {
                    "id": widget,
                    "enabled": true,
                    "selectedGpuIndex": selectedGpuIndex,
                    "pciId": DgopService.availableGpus
                             && DgopService.availableGpus.length
                             > selectedGpuIndex ? DgopService.availableGpus[selectedGpuIndex].pciId : ""
                }
            } else {
                var newWidget = {
                    "id": widget.id,
                    "enabled": widget.enabled,
                    "selectedGpuIndex": selectedGpuIndex,
                    "pciId": DgopService.availableGpus
                             && DgopService.availableGpus.length
                             > selectedGpuIndex ? DgopService.availableGpus[selectedGpuIndex].pciId : ""
                }
                if (widget.size !== undefined)
                    newWidget.size = widget.size
                widgets[widgetIndex] = newWidget
            }
        }

        if (sectionId === "left")
            SettingsData.setDankBarLeftWidgets(widgets)
        else if (sectionId === "center")
            SettingsData.setDankBarCenterWidgets(widgets)
        else if (sectionId === "right")
            SettingsData.setDankBarRightWidgets(widgets)
    }

    function handleDiskMountSelectionChanged(sectionId, widgetIndex, mountPath) {
        var widgets = []
        if (sectionId === "left")
            widgets = SettingsData.dankBarLeftWidgets.slice()
        else if (sectionId === "center")
            widgets = SettingsData.dankBarCenterWidgets.slice()
        else if (sectionId === "right")
            widgets = SettingsData.dankBarRightWidgets.slice()

        if (widgetIndex >= 0 && widgetIndex < widgets.length) {
            var widget = widgets[widgetIndex]
            if (typeof widget === "string") {
                widgets[widgetIndex] = {
                    "id": widget,
                    "enabled": true,
                    "mountPath": mountPath
                }
            } else {
                var newWidget = {
                    "id": widget.id,
                    "enabled": widget.enabled,
                    "mountPath": mountPath
                }
                if (widget.size !== undefined)
                    newWidget.size = widget.size
                if (widget.selectedGpuIndex !== undefined)
                    newWidget.selectedGpuIndex = widget.selectedGpuIndex
                if (widget.pciId !== undefined)
                    newWidget.pciId = widget.pciId
                if (widget.id === "controlCenterButton") {
                    newWidget.showNetworkIcon = widget.showNetworkIcon !== undefined ? widget.showNetworkIcon : true
                    newWidget.showBluetoothIcon = widget.showBluetoothIcon !== undefined ? widget.showBluetoothIcon : true
                    newWidget.showAudioIcon = widget.showAudioIcon !== undefined ? widget.showAudioIcon : true
                }
                widgets[widgetIndex] = newWidget
            }
        }

        if (sectionId === "left")
            SettingsData.setDankBarLeftWidgets(widgets)
        else if (sectionId === "center")
            SettingsData.setDankBarCenterWidgets(widgets)
        else if (sectionId === "right")
            SettingsData.setDankBarRightWidgets(widgets)
    }

    function handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value) {
        // Control Center settings are global, not per-widget instance
        if (settingName === "showNetworkIcon") {
            SettingsData.setControlCenterShowNetworkIcon(value)
        } else if (settingName === "showBluetoothIcon") {
            SettingsData.setControlCenterShowBluetoothIcon(value)
        } else if (settingName === "showAudioIcon") {
            SettingsData.setControlCenterShowAudioIcon(value)
        }
    }

    function handleMinimumWidthChanged(sectionId, widgetIndex, enabled) {
        var widgets = []
        if (sectionId === "left")
            widgets = SettingsData.dankBarLeftWidgets.slice()
        else if (sectionId === "center")
            widgets = SettingsData.dankBarCenterWidgets.slice()
        else if (sectionId === "right")
            widgets = SettingsData.dankBarRightWidgets.slice()

        if (widgetIndex >= 0 && widgetIndex < widgets.length) {
            var widget = widgets[widgetIndex]
            if (typeof widget === "string") {
                widgets[widgetIndex] = {
                    "id": widget,
                    "enabled": true,
                    "minimumWidth": enabled
                }
            } else {
                var newWidget = {
                    "id": widget.id,
                    "enabled": widget.enabled,
                    "minimumWidth": enabled
                }
                if (widget.size !== undefined)
                    newWidget.size = widget.size
                if (widget.selectedGpuIndex !== undefined)
                    newWidget.selectedGpuIndex = widget.selectedGpuIndex
                if (widget.pciId !== undefined)
                    newWidget.pciId = widget.pciId
                if (widget.mountPath !== undefined)
                    newWidget.mountPath = widget.mountPath
                if (widget.id === "controlCenterButton") {
                    newWidget.showNetworkIcon = widget.showNetworkIcon !== undefined ? widget.showNetworkIcon : true
                    newWidget.showBluetoothIcon = widget.showBluetoothIcon !== undefined ? widget.showBluetoothIcon : true
                    newWidget.showAudioIcon = widget.showAudioIcon !== undefined ? widget.showAudioIcon : true
                }
                widgets[widgetIndex] = newWidget
            }
        }

        if (sectionId === "left")
            SettingsData.setDankBarLeftWidgets(widgets)
        else if (sectionId === "center")
            SettingsData.setDankBarCenterWidgets(widgets)
        else if (sectionId === "right")
            SettingsData.setDankBarRightWidgets(widgets)
    }

    function getItemsForSection(sectionId) {
        var widgets = []
        var widgetData = []
        if (sectionId === "left")
            widgetData = SettingsData.dankBarLeftWidgets || []
        else if (sectionId === "center")
            widgetData = SettingsData.dankBarCenterWidgets || []
        else if (sectionId === "right")
            widgetData = SettingsData.dankBarRightWidgets || []
        widgetData.forEach(widget => {
                               var widgetId = typeof widget === "string" ? widget : widget.id
                               var widgetEnabled = typeof widget
                               === "string" ? true : widget.enabled
                               var widgetSize = typeof widget === "string" ? undefined : widget.size
                               var widgetSelectedGpuIndex = typeof widget
                               === "string" ? undefined : widget.selectedGpuIndex
                               var widgetPciId = typeof widget
                               === "string" ? undefined : widget.pciId
                               var widgetMountPath = typeof widget
                               === "string" ? undefined : widget.mountPath
                               var widgetShowNetworkIcon = typeof widget === "string" ? undefined : widget.showNetworkIcon
                               var widgetShowBluetoothIcon = typeof widget === "string" ? undefined : widget.showBluetoothIcon
                               var widgetShowAudioIcon = typeof widget === "string" ? undefined : widget.showAudioIcon
                               var widgetMinimumWidth = typeof widget === "string" ? undefined : widget.minimumWidth
                               var widgetDef = baseWidgetDefinitions.find(w => {
                                                                              return w.id === widgetId
                                                                          })
                               if (widgetDef) {
                                   var item = Object.assign({}, widgetDef)
                                   item.enabled = widgetEnabled
                                   if (widgetSize !== undefined)
                                   item.size = widgetSize
                                   if (widgetSelectedGpuIndex !== undefined)
                                   item.selectedGpuIndex = widgetSelectedGpuIndex
                                   if (widgetPciId !== undefined)
                                   item.pciId = widgetPciId
                                   if (widgetMountPath !== undefined)
                                   item.mountPath = widgetMountPath
                                   if (widgetShowNetworkIcon !== undefined)
                                   item.showNetworkIcon = widgetShowNetworkIcon
                                   if (widgetShowBluetoothIcon !== undefined)
                                   item.showBluetoothIcon = widgetShowBluetoothIcon
                                   if (widgetShowAudioIcon !== undefined)
                                   item.showAudioIcon = widgetShowAudioIcon
                                   if (widgetMinimumWidth !== undefined)
                                   item.minimumWidth = widgetMinimumWidth

                                   widgets.push(item)
                               }
                           })
        return widgets
    }

    Component.onCompleted: {
        // Only set defaults if widgets have never been configured (null/undefined, not empty array)
        if (!SettingsData.dankBarLeftWidgets)
            SettingsData.setDankBarLeftWidgets(defaultLeftWidgets)

        if (!SettingsData.dankBarCenterWidgets)
            SettingsData.setDankBarCenterWidgets(defaultCenterWidgets)

        if (!SettingsData.dankBarRightWidgets)
            SettingsData.setDankBarRightWidgets(defaultRightWidgets)
        const sections = ["left", "center", "right"]
        sections.forEach(sectionId => {
                             var widgets = []
                             if (sectionId === "left")
                             widgets = SettingsData.dankBarLeftWidgets.slice()
                             else if (sectionId === "center")
                             widgets = SettingsData.dankBarCenterWidgets.slice()
                             else if (sectionId === "right")
                             widgets = SettingsData.dankBarRightWidgets.slice()
                             var updated = false
                             for (var i = 0; i < widgets.length; i++) {
                                 var widget = widgets[i]
                                 if (typeof widget === "object"
                                     && widget.id === "spacer"
                                     && !widget.size) {
                                     widgets[i] = Object.assign({}, widget, {
                                                                    "size": 20
                                                                })
                                     updated = true
                                 }
                             }
                             if (updated) {
                                 if (sectionId === "left")
                                 SettingsData.setDankBarLeftWidgets(widgets)
                                 else if (sectionId === "center")
                                 SettingsData.setDankBarCenterWidgets(widgets)
                                 else if (sectionId === "right")
                                 SettingsData.setDankBarRightWidgets(widgets)
                             }
                         })
    }

    DankFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        anchors.bottomMargin: Theme.spacingS
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            // Position Section
            StyledRect {
                width: parent.width
                height: positionSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

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
                            model: ["Top", "Bottom", "Left", "Right"]
                            currentIndex: {
                                switch (SettingsData.dankBarPosition) {
                                    case SettingsData.Position.Top: return 0
                                    case SettingsData.Position.Bottom: return 1
                                    case SettingsData.Position.Left: return 2
                                    case SettingsData.Position.Right: return 3
                                    default: return 0
                                }
                            }
                            onSelectionChanged: (index, selected) => {
                                if (selected) {
                                    switch (index) {
                                        case 0: SettingsData.setDankBarPosition(SettingsData.Position.Top); break
                                        case 1: SettingsData.setDankBarPosition(SettingsData.Position.Bottom); break
                                        case 2: SettingsData.setDankBarPosition(SettingsData.Position.Left); break
                                        case 3: SettingsData.setDankBarPosition(SettingsData.Position.Right); break
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // DankBar Auto-hide Section
            StyledRect {
                width: parent.width
                height: dankBarAutoHideSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

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
                            width: parent.width - Theme.iconSize - Theme.spacingM
                                   - autoHideToggle.width - Theme.spacingM
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
                            checked: SettingsData.dankBarAutoHide
                            onToggled: toggled => {
                                           return SettingsData.setDankBarAutoHide(
                                               toggled)
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
                            width: parent.width - Theme.iconSize - Theme.spacingM
                                   - visibilityToggle.width - Theme.spacingM
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
                            checked: SettingsData.dankBarVisible
                            onToggled: toggled => {
                                           return SettingsData.setDankBarVisible(
                                               toggled)
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
                            width: parent.width - Theme.iconSize - Theme.spacingM
                                   - overviewToggle.width - Theme.spacingM
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
                            checked: SettingsData.dankBarOpenOnOverview
                            onToggled: toggled => {
                                           return SettingsData.setDankBarOpenOnOverview(
                                               toggled)
                                       }
                        }
                    }
                }
            }


            // Spacing
            StyledRect {
                width: parent.width
                height: dankBarSpacingSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

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

                        StyledText {
                            text: I18n.tr("Edge Spacing (0 = edge-to-edge)")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.dankBarSpacing
                            minimum: 0
                            maximum: 32
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainerHigh
                            onSliderValueChanged: newValue => {
                                                      SettingsData.setDankBarSpacing(
                                                          newValue)
                                                  }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Exclusive Zone Offset")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.dankBarBottomGap
                            minimum: -100
                            maximum: 100
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainerHigh
                            onSliderValueChanged: newValue => {
                                                      SettingsData.setDankBarBottomGap(
                                                          newValue)
                                                  }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Size")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.dankBarInnerPadding
                            minimum: 0
                            maximum: 24
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainerHigh
                            onSliderValueChanged: newValue => {
                                                      SettingsData.setDankBarInnerPadding(
                                                          newValue)
                                                  }
                        }
                    }


                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Square Corners")
                        description: "Removes rounded corners from bar container."
                        checked: SettingsData.dankBarSquareCorners
                        onToggled: checked => {
                                       SettingsData.setDankBarSquareCorners(
                                           checked)
                                   }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("No Background")
                        description: "Remove widget backgrounds for a minimal look with tighter spacing."
                        checked: SettingsData.dankBarNoBackground
                        onToggled: checked => {
                                       SettingsData.setDankBarNoBackground(
                                           checked)
                                   }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Goth Corners")
                        description: "Add curved swooping tips at the bottom of the bar."
                        checked: SettingsData.dankBarGothCornersEnabled
                        onToggled: checked => {
                                       SettingsData.setDankBarGothCornersEnabled(
                                           checked)
                                   }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Border")
                        description: "Add a 1px border to the bar. Smart edge detection only shows border on exposed sides."
                        checked: SettingsData.dankBarBorderEnabled
                        onToggled: checked => {
                                       SettingsData.setDankBarBorderEnabled(checked)
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
                                enabled: SettingsData.dankBarFontScale > 0.5
                                backgroundColor: Theme.surfaceContainerHigh
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    var newScale = Math.max(0.5, SettingsData.dankBarFontScale - 0.05)
                                    SettingsData.setDankBarFontScale(newScale)
                                }
                            }

                            StyledRect {
                                width: 60
                                height: 32
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                border.width: 0

                                StyledText {
                                    anchors.centerIn: parent
                                    text: (SettingsData.dankBarFontScale * 100).toFixed(0) + "%"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                            }

                            DankActionButton {
                                buttonSize: 32
                                iconName: "add"
                                iconSize: Theme.iconSizeSmall
                                enabled: SettingsData.dankBarFontScale < 2.0
                                backgroundColor: Theme.surfaceContainerHigh
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    var newScale = Math.min(2.0, SettingsData.dankBarFontScale + 0.05)
                                    SettingsData.setDankBarFontScale(newScale)
                                }
                            }
                        }
                    }
                }
            }

            // Widget Management Section
            StyledRect {
                width: parent.width
                height: widgetManagementSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

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
                            border.color: resetArea.containsMouse ? Theme.outline : Qt.rgba(
                                                                        Theme.outline.r,
                                                                        Theme.outline.g,
                                                                        Theme.outline.b,
                                                                        0.5)

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
                                    SettingsData.setDankBarLeftWidgets(
                                                defaultLeftWidgets)
                                    SettingsData.setDankBarCenterWidgets(
                                                defaultCenterWidgets)
                                    SettingsData.setDankBarRightWidgets(
                                                defaultRightWidgets)
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

                // Left/Top Section
                StyledRect {
                    width: parent.width
                    height: leftSection.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                          Theme.outline.b, 0.2)
                    border.width: 0

                    WidgetsTabSection {
                        id: leftSection
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        title: SettingsData.dankBarIsVertical ? "Top Section" : "Left Section"
                        titleIcon: "format_align_left"
                        sectionId: "left"
                        allWidgets: dankBarTab.baseWidgetDefinitions
                        items: dankBarTab.getItemsForSection("left")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => {
                                                  dankBarTab.handleItemEnabledChanged(
                                                      sectionId,
                                                      itemId, enabled)
                                              }
                        onItemOrderChanged: newOrder => {
                                                dankBarTab.handleItemOrderChanged(
                                                    "left", newOrder)
                                            }
                        onAddWidget: sectionId => {
                                         widgetSelectionPopup.allWidgets
                                         = dankBarTab.getWidgetsForPopup()
                                         widgetSelectionPopup.targetSection = sectionId
                                         widgetSelectionPopup.show()
                                     }
                        onRemoveWidget: (sectionId, widgetIndex) => {
                                            dankBarTab.removeWidgetFromSection(
                                                sectionId, widgetIndex)
                                        }
                        onSpacerSizeChanged: (sectionId, widgetIndex, newSize) => {
                                                 dankBarTab.handleSpacerSizeChanged(
                                                     sectionId, widgetIndex, newSize)
                                             }
                        onCompactModeChanged: (widgetId, value) => {
                                                  if (widgetId === "clock") {
                                                      SettingsData.setClockCompactMode(
                                                          value)
                                                  } else if (widgetId === "music") {
                                                      SettingsData.setMediaSize(
                                                          value)
                                                  } else if (widgetId === "focusedWindow") {
                                                      SettingsData.setFocusedWindowCompactMode(
                                                          value)
                                                  } else if (widgetId === "runningApps") {
                                                      SettingsData.setRunningAppsCompactMode(
                                                          value)
                                                  }
                                              }
                        onControlCenterSettingChanged: (sectionId, widgetIndex, settingName, value) => {
                                                           handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value)
                                                       }
                        onGpuSelectionChanged: (sectionId, widgetIndex, selectedIndex) => {
                                                   dankBarTab.handleGpuSelectionChanged(
                                                       sectionId, widgetIndex,
                                                       selectedIndex)
                                               }
                        onDiskMountSelectionChanged: (sectionId, widgetIndex, mountPath) => {
                                                         dankBarTab.handleDiskMountSelectionChanged(
                                                             sectionId, widgetIndex, mountPath)
                                                     }
                        onMinimumWidthChanged: (sectionId, widgetIndex, enabled) => {
                                                   dankBarTab.handleMinimumWidthChanged(
                                                       sectionId, widgetIndex, enabled)
                                               }
                    }
                }

                // Center Section
                StyledRect {
                    width: parent.width
                    height: centerSection.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                          Theme.outline.b, 0.2)
                    border.width: 0

                    WidgetsTabSection {
                        id: centerSection
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        title: I18n.tr("Center Section")
                        titleIcon: "format_align_center"
                        sectionId: "center"
                        allWidgets: dankBarTab.baseWidgetDefinitions
                        items: dankBarTab.getItemsForSection("center")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => {
                                                  dankBarTab.handleItemEnabledChanged(
                                                      sectionId,
                                                      itemId, enabled)
                                              }
                        onItemOrderChanged: newOrder => {
                                                dankBarTab.handleItemOrderChanged(
                                                    "center", newOrder)
                                            }
                        onAddWidget: sectionId => {
                                         widgetSelectionPopup.allWidgets
                                         = dankBarTab.getWidgetsForPopup()
                                         widgetSelectionPopup.targetSection = sectionId
                                         widgetSelectionPopup.show()
                                     }
                        onRemoveWidget: (sectionId, widgetIndex) => {
                                            dankBarTab.removeWidgetFromSection(
                                                sectionId, widgetIndex)
                                        }
                        onSpacerSizeChanged: (sectionId, widgetIndex, newSize) => {
                                                 dankBarTab.handleSpacerSizeChanged(
                                                     sectionId, widgetIndex, newSize)
                                             }
                        onCompactModeChanged: (widgetId, value) => {
                                                  if (widgetId === "clock") {
                                                      SettingsData.setClockCompactMode(
                                                          value)
                                                  } else if (widgetId === "music") {
                                                      SettingsData.setMediaSize(
                                                          value)
                                                  } else if (widgetId === "focusedWindow") {
                                                      SettingsData.setFocusedWindowCompactMode(
                                                          value)
                                                  } else if (widgetId === "runningApps") {
                                                      SettingsData.setRunningAppsCompactMode(
                                                          value)
                                                  }
                                              }
                        onControlCenterSettingChanged: (sectionId, widgetIndex, settingName, value) => {
                                                           handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value)
                                                       }
                        onGpuSelectionChanged: (sectionId, widgetIndex, selectedIndex) => {
                                                   dankBarTab.handleGpuSelectionChanged(
                                                       sectionId, widgetIndex,
                                                       selectedIndex)
                                               }
                        onDiskMountSelectionChanged: (sectionId, widgetIndex, mountPath) => {
                                                         dankBarTab.handleDiskMountSelectionChanged(
                                                             sectionId, widgetIndex, mountPath)
                                                     }
                        onMinimumWidthChanged: (sectionId, widgetIndex, enabled) => {
                                                   dankBarTab.handleMinimumWidthChanged(
                                                       sectionId, widgetIndex, enabled)
                                               }
                    }
                }

                // Right/Bottom Section
                StyledRect {
                    width: parent.width
                    height: rightSection.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                          Theme.outline.b, 0.2)
                    border.width: 0

                    WidgetsTabSection {
                        id: rightSection
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        title: SettingsData.dankBarIsVertical ? "Bottom Section" : "Right Section"
                        titleIcon: "format_align_right"
                        sectionId: "right"
                        allWidgets: dankBarTab.baseWidgetDefinitions
                        items: dankBarTab.getItemsForSection("right")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => {
                                                  dankBarTab.handleItemEnabledChanged(
                                                      sectionId,
                                                      itemId, enabled)
                                              }
                        onItemOrderChanged: newOrder => {
                                                dankBarTab.handleItemOrderChanged(
                                                    "right", newOrder)
                                            }
                        onAddWidget: sectionId => {
                                         widgetSelectionPopup.allWidgets
                                         = dankBarTab.getWidgetsForPopup()
                                         widgetSelectionPopup.targetSection = sectionId
                                         widgetSelectionPopup.show()
                                     }
                        onRemoveWidget: (sectionId, widgetIndex) => {
                                            dankBarTab.removeWidgetFromSection(
                                                sectionId, widgetIndex)
                                        }
                        onSpacerSizeChanged: (sectionId, widgetIndex, newSize) => {
                                                 dankBarTab.handleSpacerSizeChanged(
                                                     sectionId, widgetIndex, newSize)
                                             }
                        onCompactModeChanged: (widgetId, value) => {
                                                  if (widgetId === "clock") {
                                                      SettingsData.setClockCompactMode(
                                                          value)
                                                  } else if (widgetId === "music") {
                                                      SettingsData.setMediaSize(
                                                          value)
                                                  } else if (widgetId === "focusedWindow") {
                                                      SettingsData.setFocusedWindowCompactMode(
                                                          value)
                                                  } else if (widgetId === "runningApps") {
                                                      SettingsData.setRunningAppsCompactMode(
                                                          value)
                                                  }
                                              }
                        onControlCenterSettingChanged: (sectionId, widgetIndex, settingName, value) => {
                                                           handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value)
                                                       }
                        onGpuSelectionChanged: (sectionId, widgetIndex, selectedIndex) => {
                                                   dankBarTab.handleGpuSelectionChanged(
                                                       sectionId, widgetIndex,
                                                       selectedIndex)
                                               }
                        onDiskMountSelectionChanged: (sectionId, widgetIndex, mountPath) => {
                                                         dankBarTab.handleDiskMountSelectionChanged(
                                                             sectionId, widgetIndex, mountPath)
                                                     }
                        onMinimumWidthChanged: (sectionId, widgetIndex, enabled) => {
                                                   dankBarTab.handleMinimumWidthChanged(
                                                       sectionId, widgetIndex, enabled)
                                               }
                    }
                }
            }
        }
    }

    WidgetSelectionPopup {
        id: widgetSelectionPopup

        parentModal: dankBarTab.parentModal
        onWidgetSelected: (widgetId, targetSection) => {
                              dankBarTab.addWidgetToSection(widgetId,
                                                           targetSection)
                          }
    }
}
