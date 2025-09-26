import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: topBarTab

    property var baseWidgetDefinitions: [{
            "id": "launcherButton",
            "text": "App Launcher",
            "description": "Quick access to application launcher",
            "icon": "apps",
            "enabled": true
        }, {
            "id": "workspaceSwitcher",
            "text": "Workspace Switcher",
            "description": "Shows current workspace and allows switching",
            "icon": "view_module",
            "enabled": true
        }, {
            "id": "focusedWindow",
            "text": "Focused Window",
            "description": "Display currently focused application title",
            "icon": "window",
            "enabled": true
        }, {
            "id": "runningApps",
            "text": "Running Apps",
            "description": "Shows all running applications with focus indication",
            "icon": "apps",
            "enabled": true
        }, {
            "id": "clock",
            "text": "Clock",
            "description": "Current time and date display",
            "icon": "schedule",
            "enabled": true
        }, {
            "id": "weather",
            "text": "Weather Widget",
            "description": "Current weather conditions and temperature",
            "icon": "wb_sunny",
            "enabled": true
        }, {
            "id": "music",
            "text": "Media Controls",
            "description": "Control currently playing media",
            "icon": "music_note",
            "enabled": true
        }, {
            "id": "clipboard",
            "text": "Clipboard Manager",
            "description": "Access clipboard history",
            "icon": "content_paste",
            "enabled": true
        }, {
            "id": "cpuUsage",
            "text": "CPU Usage",
            "description": "CPU usage indicator",
            "icon": "memory",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? "Requires 'dgop' tool" : undefined
        }, {
            "id": "memUsage",
            "text": "Memory Usage",
            "description": "Memory usage indicator",
            "icon": "developer_board",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? "Requires 'dgop' tool" : undefined
        }, {
            "id": "diskUsage",
            "text": "Disk Usage",
            "description": "Percentage",
            "icon": "storage",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? "Requires 'dgop' tool" : undefined
        }, {
            "id": "cpuTemp",
            "text": "CPU Temperature",
            "description": "CPU temperature display",
            "icon": "device_thermostat",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? "Requires 'dgop' tool" : undefined
        }, {
            "id": "gpuTemp",
            "text": "GPU Temperature",
            "description": "GPU temperature display",
            "icon": "auto_awesome_mosaic",
            "warning": !DgopService.dgopAvailable ? "Requires 'dgop' tool" : "This widget prevents GPU power off states, which can significantly impact battery life on laptops. It is not recommended to use this on laptops with hybrid graphics.",
            "enabled": DgopService.dgopAvailable
        }, {
            "id": "systemTray",
            "text": "System Tray",
            "description": "System notification area icons",
            "icon": "notifications",
            "enabled": true
        }, {
            "id": "privacyIndicator",
            "text": "Privacy Indicator",
            "description": "Shows when microphone, camera, or screen sharing is active",
            "icon": "privacy_tip",
            "enabled": true
        }, {
            "id": "controlCenterButton",
            "text": "Control Center",
            "description": "Access to system controls and settings",
            "icon": "settings",
            "enabled": true
        }, {
            "id": "notificationButton",
            "text": "Notification Center",
            "description": "Access to notifications and do not disturb",
            "icon": "notifications",
            "enabled": true
        }, {
            "id": "battery",
            "text": "Battery",
            "description": "Battery level and power management",
            "icon": "battery_std",
            "enabled": true
        }, {
            "id": "vpn",
            "text": "VPN",
            "description": "VPN status and quick connect",
            "icon": "vpn_lock",
            "enabled": true
        }, {
            "id": "idleInhibitor",
            "text": "Idle Inhibitor",
            "description": "Prevent screen timeout",
            "icon": "motion_sensor_active",
            "enabled": true
        }, {
            "id": "spacer",
            "text": "Spacer",
            "description": "Customizable empty space",
            "icon": "more_horiz",
            "enabled": true
        }, {
            "id": "separator",
            "text": "Separator",
            "description": "Visual divider between widgets",
            "icon": "remove",
            "enabled": true
        },
        {
            "id": "network_speed_monitor",
            "text": "Network Speed Monitor",
            "description": "Network download and upload speed display",
            "icon": "network_check",
            "warning": !DgopService.dgopAvailable ? "Requires 'dgop' tool" : undefined,
            "enabled": DgopService.dgopAvailable
        }, {
            "id": "keyboard_layout_name",
            "text": "Keyboard Layout Name",
            "description": "Displays the active keyboard layout and allows switching",
            "icon": "keyboard",
        }, {
            "id": "notepadButton",
            "text": "Notepad",
            "description": "Quick access to notepad",
            "icon": "assignment",
            "enabled": true
        }, {
            "id": "colorPicker",
            "text": "Color Picker",
            "description": "Quick access to color picker",
            "icon": "palette",
            "enabled": true
        }, {
            "id": "systemUpdate",
            "text": "System Update",
            "description": "Check for system updates",
            "icon": "update",
            "enabled": SystemUpdateService.distributionSupported
        }]
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

        var widgets = []
        if (targetSection === "left") {
            widgets = SettingsData.statusBarLeftWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setStatusBarLeftWidgets(widgets)
        } else if (targetSection === "center") {
            widgets = SettingsData.statusBarCenterWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setStatusBarCenterWidgets(widgets)
        } else if (targetSection === "right") {
            widgets = SettingsData.statusBarRightWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setStatusBarRightWidgets(widgets)
        }
    }

    function removeWidgetFromSection(sectionId, widgetIndex) {
        var widgets = []
        if (sectionId === "left") {
            widgets = SettingsData.statusBarLeftWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
            }
            SettingsData.setStatusBarLeftWidgets(widgets)
        } else if (sectionId === "center") {
            widgets = SettingsData.statusBarCenterWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
            }
            SettingsData.setStatusBarCenterWidgets(widgets)
        } else if (sectionId === "right") {
            widgets = SettingsData.statusBarRightWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
            }
            SettingsData.setStatusBarRightWidgets(widgets)
        }
    }

    function handleItemEnabledChanged(sectionId, itemId, enabled) {
        var widgets = []
        if (sectionId === "left")
            widgets = SettingsData.statusBarLeftWidgets.slice()
        else if (sectionId === "center")
            widgets = SettingsData.statusBarCenterWidgets.slice()
        else if (sectionId === "right")
            widgets = SettingsData.statusBarRightWidgets.slice()
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
            SettingsData.setStatusBarLeftWidgets(widgets)
        else if (sectionId === "center")
            SettingsData.setStatusBarCenterWidgets(widgets)
        else if (sectionId === "right")
            SettingsData.setStatusBarRightWidgets(widgets)
    }

    function handleItemOrderChanged(sectionId, newOrder) {
        if (sectionId === "left")
            SettingsData.setStatusBarLeftWidgets(newOrder)
        else if (sectionId === "center")
            SettingsData.setStatusBarCenterWidgets(newOrder)
        else if (sectionId === "right")
            SettingsData.setStatusBarRightWidgets(newOrder)
    }

    function handleSpacerSizeChanged(sectionId, widgetIndex, newSize) {
        var widgets = []
        if (sectionId === "left")
            widgets = SettingsData.statusBarLeftWidgets.slice()
        else if (sectionId === "center")
            widgets = SettingsData.statusBarCenterWidgets.slice()
        else if (sectionId === "right")
            widgets = SettingsData.statusBarRightWidgets.slice()
        
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
            SettingsData.setStatusBarLeftWidgets(widgets)
        else if (sectionId === "center")
            SettingsData.setStatusBarCenterWidgets(widgets)
        else if (sectionId === "right")
            SettingsData.setStatusBarRightWidgets(widgets)
    }

    function handleGpuSelectionChanged(sectionId, widgetIndex, selectedGpuIndex) {
        var widgets = []
        if (sectionId === "left")
            widgets = SettingsData.statusBarLeftWidgets.slice()
        else if (sectionId === "center")
            widgets = SettingsData.statusBarCenterWidgets.slice()
        else if (sectionId === "right")
            widgets = SettingsData.statusBarRightWidgets.slice()

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
            SettingsData.setStatusBarLeftWidgets(widgets)
        else if (sectionId === "center")
            SettingsData.setStatusBarCenterWidgets(widgets)
        else if (sectionId === "right")
            SettingsData.setStatusBarRightWidgets(widgets)
    }

    function handleDiskMountSelectionChanged(sectionId, widgetIndex, mountPath) {
        var widgets = []
        if (sectionId === "left")
            widgets = SettingsData.statusBarLeftWidgets.slice()
        else if (sectionId === "center")
            widgets = SettingsData.statusBarCenterWidgets.slice()
        else if (sectionId === "right")
            widgets = SettingsData.statusBarRightWidgets.slice()

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
            SettingsData.setStatusBarLeftWidgets(widgets)
        else if (sectionId === "center")
            SettingsData.setStatusBarCenterWidgets(widgets)
        else if (sectionId === "right")
            SettingsData.setStatusBarRightWidgets(widgets)
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

    function getItemsForSection(sectionId) {
        var widgets = []
        var widgetData = []
        if (sectionId === "left")
            widgetData = SettingsData.statusBarLeftWidgets || []
        else if (sectionId === "center")
            widgetData = SettingsData.statusBarCenterWidgets || []
        else if (sectionId === "right")
            widgetData = SettingsData.statusBarRightWidgets || []
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

                                   widgets.push(item)
                               }
                           })
        return widgets
    }

    Component.onCompleted: {
        // Only set defaults if widgets have never been configured (null/undefined, not empty array)
        if (!SettingsData.statusBarLeftWidgets)
            SettingsData.setStatusBarLeftWidgets(defaultLeftWidgets)

        if (!SettingsData.statusBarCenterWidgets)
            SettingsData.setStatusBarCenterWidgets(defaultCenterWidgets)

        if (!SettingsData.statusBarRightWidgets)
            SettingsData.setStatusBarRightWidgets(defaultRightWidgets)
        const sections = ["left", "center", "right"]
        sections.forEach(sectionId => {
                             var widgets = []
                             if (sectionId === "left")
                             widgets = SettingsData.statusBarLeftWidgets.slice()
                             else if (sectionId === "center")
                             widgets = SettingsData.statusBarCenterWidgets.slice()
                             else if (sectionId === "right")
                             widgets = SettingsData.statusBarRightWidgets.slice()
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
                                 SettingsData.setStatusBarLeftWidgets(widgets)
                                 else if (sectionId === "center")
                                 SettingsData.setStatusBarCenterWidgets(widgets)
                                 else if (sectionId === "right")
                                 SettingsData.setStatusBarRightWidgets(widgets)
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

            // TopBar Auto-hide Section
            StyledRect {
                width: parent.width
                height: topBarAutoHideSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: topBarAutoHideSection

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
                                text: "Auto-hide"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Automatically hide the top bar to expand screen real estate"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: autoHideToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.statusBarAutoHide
                            onToggled: toggled => {
                                           return SettingsData.setStatusBarAutoHide(
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
                                text: "Manual Show/Hide"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Toggle top bar visibility manually (can be controlled via IPC)"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: visibilityToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.statusBarVisible
                            onToggled: toggled => {
                                           return SettingsData.setStatusBarVisible(
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
                                text: "Show on Overview"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Always show the top bar when niri's overview is open"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: overviewToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.statusBarOpenOnOverview
                            onToggled: toggled => {
                                           return SettingsData.setStatusBarOpenOnOverview(
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

                    DankDropdown {
                        width: parent.width
                        text: "Status Bar Position"
                        description: "Position status bar at top or bottom of display"
                        currentValue: SettingsData.statusBarAtBottom ? "Bottom" : "Top"
                        options: ["Top", "Bottom"]
                        onValueChanged: value => {
                                            SettingsData.setStatusBarAtBottom(value === "Bottom")
                                        }
                    }
                }
            }


            // Spacing
            StyledRect {
                width: parent.width
                height: topBarSpacingSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: topBarSpacingSection

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
                            text: "Spacing"
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
                            text: "Top/Left/Right Gaps (0 = edge-to-edge)"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.statusBarSpacing
                            minimum: 0
                            maximum: 32
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainerHigh
                            onSliderValueChanged: newValue => {
                                                      SettingsData.setStatusBarSpacing(
                                                          newValue)
                                                  }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Bottom Gap (Exclusive Zone)"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.statusBarBottomGap
                            minimum: -100
                            maximum: 100
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainerHigh
                            onSliderValueChanged: newValue => {
                                                      SettingsData.setStatusBarBottomGap(
                                                          newValue)
                                                  }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Size"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.statusBarInnerPadding
                            minimum: 0
                            maximum: 24
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainerHigh
                            onSliderValueChanged: newValue => {
                                                      SettingsData.setStatusBarInnerPadding(
                                                          newValue)
                                                  }
                        }
                    }


                    DankToggle {
                        width: parent.width
                        text: "Square Corners"
                        description: "Removes rounded corners from bar container."
                        checked: SettingsData.statusBarSquareCorners
                        onToggled: checked => {
                                       SettingsData.setStatusBarSquareCorners(
                                           checked)
                                   }
                    }

                    DankToggle {
                        width: parent.width
                        text: "No Background"
                        description: "Remove widget backgrounds for a minimal look with tighter spacing."
                        checked: SettingsData.statusBarNoBackground
                        onToggled: checked => {
                                       SettingsData.setStatusBarNoBackground(
                                           checked)
                                   }
                    }

                    DankToggle {
                        width: parent.width
                        text: "Goth Corners"
                        description: "Add curved swooping tips at the bottom of the bar."
                        checked: SettingsData.statusBarGothCornersEnabled
                        onToggled: checked => {
                                       SettingsData.setStatusBarGothCornersEnabled(
                                           checked)
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
                            text: "Widget Management"
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
                                    text: "Reset"
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
                                    SettingsData.setStatusBarLeftWidgets(
                                                defaultLeftWidgets)
                                    SettingsData.setStatusBarCenterWidgets(
                                                defaultCenterWidgets)
                                    SettingsData.setStatusBarRightWidgets(
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
                        text: "Drag widgets to reorder within sections. Use the eye icon to hide/show widgets (maintains spacing), or X to remove them completely."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingL

                // Left Section
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
                        title: "Left Section"
                        titleIcon: "format_align_left"
                        sectionId: "left"
                        allWidgets: topBarTab.baseWidgetDefinitions
                        items: topBarTab.getItemsForSection("left")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => {
                                                  topBarTab.handleItemEnabledChanged(
                                                      sectionId,
                                                      itemId, enabled)
                                              }
                        onItemOrderChanged: newOrder => {
                                                topBarTab.handleItemOrderChanged(
                                                    "left", newOrder)
                                            }
                        onAddWidget: sectionId => {
                                         widgetSelectionPopup.allWidgets
                                         = topBarTab.baseWidgetDefinitions
                                         widgetSelectionPopup.targetSection = sectionId
                                         widgetSelectionPopup.safeOpen()
                                     }
                        onRemoveWidget: (sectionId, widgetIndex) => {
                                            topBarTab.removeWidgetFromSection(
                                                sectionId, widgetIndex)
                                        }
                        onSpacerSizeChanged: (sectionId, widgetIndex, newSize) => {
                                                 topBarTab.handleSpacerSizeChanged(
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
                                                   topBarTab.handleGpuSelectionChanged(
                                                       sectionId, widgetIndex,
                                                       selectedIndex)
                                               }
                        onDiskMountSelectionChanged: (sectionId, widgetIndex, mountPath) => {
                                                         topBarTab.handleDiskMountSelectionChanged(
                                                             sectionId, widgetIndex, mountPath)
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
                        title: "Center Section"
                        titleIcon: "format_align_center"
                        sectionId: "center"
                        allWidgets: topBarTab.baseWidgetDefinitions
                        items: topBarTab.getItemsForSection("center")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => {
                                                  topBarTab.handleItemEnabledChanged(
                                                      sectionId,
                                                      itemId, enabled)
                                              }
                        onItemOrderChanged: newOrder => {
                                                topBarTab.handleItemOrderChanged(
                                                    "center", newOrder)
                                            }
                        onAddWidget: sectionId => {
                                         widgetSelectionPopup.allWidgets
                                         = topBarTab.baseWidgetDefinitions
                                         widgetSelectionPopup.targetSection = sectionId
                                         widgetSelectionPopup.safeOpen()
                                     }
                        onRemoveWidget: (sectionId, widgetIndex) => {
                                            topBarTab.removeWidgetFromSection(
                                                sectionId, widgetIndex)
                                        }
                        onSpacerSizeChanged: (sectionId, widgetIndex, newSize) => {
                                                 topBarTab.handleSpacerSizeChanged(
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
                                                   topBarTab.handleGpuSelectionChanged(
                                                       sectionId, widgetIndex,
                                                       selectedIndex)
                                               }
                        onDiskMountSelectionChanged: (sectionId, widgetIndex, mountPath) => {
                                                         topBarTab.handleDiskMountSelectionChanged(
                                                             sectionId, widgetIndex, mountPath)
                                                     }
                    }
                }

                // Right Section
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
                        title: "Right Section"
                        titleIcon: "format_align_right"
                        sectionId: "right"
                        allWidgets: topBarTab.baseWidgetDefinitions
                        items: topBarTab.getItemsForSection("right")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => {
                                                  topBarTab.handleItemEnabledChanged(
                                                      sectionId,
                                                      itemId, enabled)
                                              }
                        onItemOrderChanged: newOrder => {
                                                topBarTab.handleItemOrderChanged(
                                                    "right", newOrder)
                                            }
                        onAddWidget: sectionId => {
                                         widgetSelectionPopup.allWidgets
                                         = topBarTab.baseWidgetDefinitions
                                         widgetSelectionPopup.targetSection = sectionId
                                         widgetSelectionPopup.safeOpen()
                                     }
                        onRemoveWidget: (sectionId, widgetIndex) => {
                                            topBarTab.removeWidgetFromSection(
                                                sectionId, widgetIndex)
                                        }
                        onSpacerSizeChanged: (sectionId, widgetIndex, newSize) => {
                                                 topBarTab.handleSpacerSizeChanged(
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
                                                   topBarTab.handleGpuSelectionChanged(
                                                       sectionId, widgetIndex,
                                                       selectedIndex)
                                               }
                        onDiskMountSelectionChanged: (sectionId, widgetIndex, mountPath) => {
                                                         topBarTab.handleDiskMountSelectionChanged(
                                                             sectionId, widgetIndex, mountPath)
                                                     }
                    }
                }
            }
        }
    }

    WidgetSelectionPopup {
        id: widgetSelectionPopup

        anchors.centerIn: parent
        onWidgetSelected: (widgetId, targetSection) => {
                              topBarTab.addWidgetToSection(widgetId,
                                                           targetSection)
                          }
    }
}
