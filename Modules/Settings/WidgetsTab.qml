import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: widgetsTab

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
            "id": "notepadButton",
            "text": "Notepad",
            "description": "Quick access to notepad",
            "icon": "assignment",
            "enabled": true
        }, {
            "id": "battery",
            "text": "Battery",
            "description": "Battery level and power management",
            "icon": "battery_std",
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
        }, {
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
            "id": "privacyIndicator",
            "enabled": true
        }, {
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

        var widgets = []
        if (targetSection === "left") {
            widgets = SettingsData.topBarLeftWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setTopBarLeftWidgets(widgets)
        } else if (targetSection === "center") {
            widgets = SettingsData.topBarCenterWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setTopBarCenterWidgets(widgets)
        } else if (targetSection === "right") {
            widgets = SettingsData.topBarRightWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setTopBarRightWidgets(widgets)
        }
    }

    function removeWidgetFromSection(sectionId, widgetIndex) {
        var widgets = []
        if (sectionId === "left") {
            widgets = SettingsData.topBarLeftWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
            }
            SettingsData.setTopBarLeftWidgets(widgets)
        } else if (sectionId === "center") {
            widgets = SettingsData.topBarCenterWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
            }
            SettingsData.setTopBarCenterWidgets(widgets)
        } else if (sectionId === "right") {
            widgets = SettingsData.topBarRightWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
            }
            SettingsData.setTopBarRightWidgets(widgets)
        }
    }

    function handleItemEnabledChanged(sectionId, itemId, enabled) {
        var widgets = []
        if (sectionId === "left")
            widgets = SettingsData.topBarLeftWidgets.slice()
        else if (sectionId === "center")
            widgets = SettingsData.topBarCenterWidgets.slice()
        else if (sectionId === "right")
            widgets = SettingsData.topBarRightWidgets.slice()
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
                    widgets[i] = newWidget
                }
                break
            }
        }
        if (sectionId === "left")
            SettingsData.setTopBarLeftWidgets(widgets)
        else if (sectionId === "center")
            SettingsData.setTopBarCenterWidgets(widgets)
        else if (sectionId === "right")
            SettingsData.setTopBarRightWidgets(widgets)
    }

    function handleItemOrderChanged(sectionId, newOrder) {
        if (sectionId === "left")
            SettingsData.setTopBarLeftWidgets(newOrder)
        else if (sectionId === "center")
            SettingsData.setTopBarCenterWidgets(newOrder)
        else if (sectionId === "right")
            SettingsData.setTopBarRightWidgets(newOrder)
    }

    function handleSpacerSizeChanged(sectionId, itemId, newSize) {
        var widgets = []
        if (sectionId === "left")
            widgets = SettingsData.topBarLeftWidgets.slice()
        else if (sectionId === "center")
            widgets = SettingsData.topBarCenterWidgets.slice()
        else if (sectionId === "right")
            widgets = SettingsData.topBarRightWidgets.slice()
        for (var i = 0; i < widgets.length; i++) {
            var widget = widgets[i]
            var widgetId = typeof widget === "string" ? widget : widget.id
            if (widgetId === itemId && widgetId === "spacer") {
                if (typeof widget === "string") {
                    widgets[i] = {
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
                    widgets[i] = newWidget
                }
                break
            }
        }
        if (sectionId === "left")
            SettingsData.setTopBarLeftWidgets(widgets)
        else if (sectionId === "center")
            SettingsData.setTopBarCenterWidgets(widgets)
        else if (sectionId === "right")
            SettingsData.setTopBarRightWidgets(widgets)
    }

    function handleGpuSelectionChanged(sectionId, widgetIndex, selectedGpuIndex) {
        var widgets = []
        if (sectionId === "left")
            widgets = SettingsData.topBarLeftWidgets.slice()
        else if (sectionId === "center")
            widgets = SettingsData.topBarCenterWidgets.slice()
        else if (sectionId === "right")
            widgets = SettingsData.topBarRightWidgets.slice()

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
            SettingsData.setTopBarLeftWidgets(widgets)
        else if (sectionId === "center")
            SettingsData.setTopBarCenterWidgets(widgets)
        else if (sectionId === "right")
            SettingsData.setTopBarRightWidgets(widgets)
    }

    function getItemsForSection(sectionId) {
        var widgets = []
        var widgetData = []
        if (sectionId === "left")
            widgetData = SettingsData.topBarLeftWidgets || []
        else if (sectionId === "center")
            widgetData = SettingsData.topBarCenterWidgets || []
        else if (sectionId === "right")
            widgetData = SettingsData.topBarRightWidgets || []
        widgetData.forEach(widget => {
                               var widgetId = typeof widget === "string" ? widget : widget.id
                               var widgetEnabled = typeof widget
                               === "string" ? true : widget.enabled
                               var widgetSize = typeof widget === "string" ? undefined : widget.size
                               var widgetSelectedGpuIndex = typeof widget
                               === "string" ? undefined : widget.selectedGpuIndex
                               var widgetPciId = typeof widget
                               === "string" ? undefined : widget.pciId
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

                                   widgets.push(item)
                               }
                           })
        return widgets
    }

    Component.onCompleted: {
        // Only set defaults if widgets have never been configured (null/undefined, not empty array)
        if (!SettingsData.topBarLeftWidgets)
            SettingsData.setTopBarLeftWidgets(defaultLeftWidgets)

        if (!SettingsData.topBarCenterWidgets)
            SettingsData.setTopBarCenterWidgets(defaultCenterWidgets)

        if (!SettingsData.topBarRightWidgets)
            SettingsData.setTopBarRightWidgets(defaultRightWidgets)

        ["left", "center", "right"].forEach(sectionId => {
                            var widgets = []
                            if (sectionId === "left")
                            widgets = SettingsData.topBarLeftWidgets.slice()
                            else if (sectionId === "center")
                            widgets = SettingsData.topBarCenterWidgets.slice()
                            else if (sectionId === "right")
                            widgets = SettingsData.topBarRightWidgets.slice()
                            var updated = false
                            for (var i = 0; i < widgets.length; i++) {
                                var widget = widgets[i]
                                if (typeof widget === "object"
                                    && widget.id === "spacer" && !widget.size) {
                                    widgets[i] = Object.assign({}, widget, {
                                                                   "size": 20
                                                               })
                                    updated = true
                                }
                            }
                            if (updated) {
                                if (sectionId === "left")
                                SettingsData.setTopBarLeftWidgets(widgets)
                                else if (sectionId === "center")
                                SettingsData.setTopBarCenterWidgets(widgets)
                                else if (sectionId === "right")
                                SettingsData.setTopBarRightWidgets(widgets)
                            }
                        })
    }

    DankFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            Row {
                width: parent.width
                spacing: Theme.spacingM

                DankIcon {
                    name: "widgets"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Top Bar Widget Management"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: parent.width - 400
                    height: 1
                }

                Rectangle {
                    width: 80
                    height: 28
                    radius: Theme.cornerRadius
                    color: resetArea.containsMouse ? Theme.surfacePressed : Theme.surfaceVariant
                    anchors.verticalCenter: parent.verticalCenter
                    border.width: 1
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
                            SettingsData.setTopBarLeftWidgets(
                                        defaultLeftWidgets)
                            SettingsData.setTopBarCenterWidgets(
                                        defaultCenterWidgets)
                            SettingsData.setTopBarRightWidgets(
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

            Rectangle {
                width: parent.width
                height: messageText.contentHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                StyledText {
                    id: messageText

                    anchors.centerIn: parent
                    text: "Drag widgets to reorder within sections. Use the eye icon to hide/show widgets (maintains spacing), or X to remove them completely."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.outline
                    width: parent.width - Theme.spacingM * 2
                    wrapMode: Text.WordWrap
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingL

                WidgetsTabSection {
                    width: parent.width
                    title: "Left Section"
                    titleIcon: "format_align_left"
                    sectionId: "left"
                    allWidgets: widgetsTab.baseWidgetDefinitions
                    items: widgetsTab.getItemsForSection("left")
                    onItemEnabledChanged: (sectionId, itemId, enabled) => {
                                              widgetsTab.handleItemEnabledChanged(
                                                  sectionId, itemId, enabled)
                                          }
                    onItemOrderChanged: newOrder => {
                                            widgetsTab.handleItemOrderChanged(
                                                "left", newOrder)
                                        }
                    onAddWidget: sectionId => {
                                     widgetSelectionPopup.allWidgets
                                     = widgetsTab.baseWidgetDefinitions
                                     widgetSelectionPopup.targetSection = sectionId
                                     widgetSelectionPopup.safeOpen()
                                 }
                    onRemoveWidget: (sectionId, widgetIndex) => {
                                        widgetsTab.removeWidgetFromSection(
                                            sectionId, widgetIndex)
                                    }
                    onSpacerSizeChanged: (sectionId, itemId, newSize) => {
                                             widgetsTab.handleSpacerSizeChanged(
                                                 sectionId, itemId, newSize)
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
                    onGpuSelectionChanged: (sectionId, widgetIndex, selectedIndex) => {
                                               widgetsTab.handleGpuSelectionChanged(
                                                   sectionId, widgetIndex,
                                                   selectedIndex)
                                           }
                }

                WidgetsTabSection {
                    width: parent.width
                    title: "Center Section"
                    titleIcon: "format_align_center"
                    sectionId: "center"
                    allWidgets: widgetsTab.baseWidgetDefinitions
                    items: widgetsTab.getItemsForSection("center")
                    onItemEnabledChanged: (sectionId, itemId, enabled) => {
                                              widgetsTab.handleItemEnabledChanged(
                                                  sectionId, itemId, enabled)
                                          }
                    onItemOrderChanged: newOrder => {
                                            widgetsTab.handleItemOrderChanged(
                                                "center", newOrder)
                                        }
                    onAddWidget: sectionId => {
                                     widgetSelectionPopup.allWidgets
                                     = widgetsTab.baseWidgetDefinitions
                                     widgetSelectionPopup.targetSection = sectionId
                                     widgetSelectionPopup.safeOpen()
                                 }
                    onRemoveWidget: (sectionId, widgetIndex) => {
                                        widgetsTab.removeWidgetFromSection(
                                            sectionId, widgetIndex)
                                    }
                    onSpacerSizeChanged: (sectionId, itemId, newSize) => {
                                             widgetsTab.handleSpacerSizeChanged(
                                                 sectionId, itemId, newSize)
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
                    onGpuSelectionChanged: (sectionId, widgetIndex, selectedIndex) => {
                                               widgetsTab.handleGpuSelectionChanged(
                                                   sectionId, widgetIndex,
                                                   selectedIndex)
                                           }
                }

                WidgetsTabSection {
                    width: parent.width
                    title: "Right Section"
                    titleIcon: "format_align_right"
                    sectionId: "right"
                    allWidgets: widgetsTab.baseWidgetDefinitions
                    items: widgetsTab.getItemsForSection("right")
                    onItemEnabledChanged: (sectionId, itemId, enabled) => {
                                              widgetsTab.handleItemEnabledChanged(
                                                  sectionId, itemId, enabled)
                                          }
                    onItemOrderChanged: newOrder => {
                                            widgetsTab.handleItemOrderChanged(
                                                "right", newOrder)
                                        }
                    onAddWidget: sectionId => {
                                     widgetSelectionPopup.allWidgets
                                     = widgetsTab.baseWidgetDefinitions
                                     widgetSelectionPopup.targetSection = sectionId
                                     widgetSelectionPopup.safeOpen()
                                 }
                    onRemoveWidget: (sectionId, widgetIndex) => {
                                        widgetsTab.removeWidgetFromSection(
                                            sectionId, widgetIndex)
                                    }
                    onSpacerSizeChanged: (sectionId, itemId, newSize) => {
                                             widgetsTab.handleSpacerSizeChanged(
                                                 sectionId, itemId, newSize)
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
                    onGpuSelectionChanged: (sectionId, widgetIndex, selectedIndex) => {
                                               widgetsTab.handleGpuSelectionChanged(
                                                   sectionId, widgetIndex,
                                                   selectedIndex)
                                           }
                }
            }

            StyledRect {
                width: parent.width
                height: workspaceSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: workspaceSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "view_module"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Workspace Settings"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        width: parent.width
                        text: "Workspace Index Numbers"
                        description: "Show workspace index numbers in the top bar workspace switcher"
                        checked: SettingsData.showWorkspaceIndex
                        onToggled: checked => {
                                       return SettingsData.setShowWorkspaceIndex(
                                           checked)
                                   }
                    }

                    DankToggle {
                        width: parent.width
                        text: "Workspace Padding"
                        description: "Always show a minimum of 3 workspaces, even if fewer are available"
                        checked: SettingsData.showWorkspacePadding
                        onToggled: checked => {
                                       return SettingsData.setShowWorkspacePadding(
                                           checked)
                                   }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: workspaceIconsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1
                visible: SettingsData.hasNamedWorkspaces()

                Column {
                    id: workspaceIconsSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "label"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Named Workspace Icons"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: "Configure icons for named workspaces. Icons take priority over numbers when both are enabled."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.outline
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: SettingsData.getNamedWorkspaces()

                        Rectangle {
                            width: parent.width
                            height: workspaceIconRow.implicitHeight + Theme.spacingM
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceContainer.r,
                                           Theme.surfaceContainer.g,
                                           Theme.surfaceContainer.b, 0.5)
                            border.color: Qt.rgba(Theme.outline.r,
                                                  Theme.outline.g,
                                                  Theme.outline.b, 0.3)
                            border.width: 1

                            Row {
                                id: workspaceIconRow

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: Theme.spacingM

                                StyledText {
                                    text: "\"" + modelData + "\""
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 150
                                    elide: Text.ElideRight
                                }

                                DankIconPicker {
                                    id: iconPicker
                                    anchors.verticalCenter: parent.verticalCenter

                                    Component.onCompleted: {
                                        var iconData = SettingsData.getWorkspaceNameIcon(
                                                    modelData)
                                        if (iconData) {
                                            setIcon(iconData.value,
                                                    iconData.type)
                                        }
                                    }

                                    onIconSelected: (iconName, iconType) => {
                                                        SettingsData.setWorkspaceNameIcon(
                                                            modelData, {
                                                                "type": iconType,
                                                                "value": iconName
                                                            })
                                                        setIcon(iconName,
                                                                iconType)
                                                    }

                                    Connections {
                                        target: SettingsData
                                        function onWorkspaceIconsUpdated() {
                                            var iconData = SettingsData.getWorkspaceNameIcon(
                                                        modelData)
                                            if (iconData) {
                                                iconPicker.setIcon(
                                                            iconData.value,
                                                            iconData.type)
                                            } else {
                                                iconPicker.setIcon("", "icon")
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: Theme.cornerRadius
                                    color: clearMouseArea.containsMouse ? Theme.errorHover : Theme.surfaceContainer
                                    border.color: clearMouseArea.containsMouse ? Theme.error : Theme.outline
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        name: "close"
                                        size: 16
                                        color: clearMouseArea.containsMouse ? Theme.error : Theme.outline
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: clearMouseArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            SettingsData.removeWorkspaceNameIcon(
                                                        modelData)
                                        }
                                    }
                                }

                                Item {
                                    width: parent.width - 150 - 240 - 28 - Theme.spacingM * 4
                                    height: 1
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    DankWidgetSelectionPopup {
        id: widgetSelectionPopup

        anchors.centerIn: parent
        onWidgetSelected: (widgetId, targetSection) => {
                              widgetsTab.addWidgetToSection(widgetId,
                                                            targetSection)
                          }
    }
}
