import QtQuick
import Quickshell.Services.Mpris
import qs.Services

Loader {
    id: root

    property string widgetId: ""
    property var widgetData: null
    property int spacerSize: 20
    property var components: null
    property bool isInColumn: false
    property var axis: null
    property string section: "center"
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    property bool isFirst: false
    property bool isLast: false
    property real sectionSpacing: 0
    property bool isLeftBarEdge: false
    property bool isRightBarEdge: false
    property bool isTopBarEdge: false
    property bool isBottomBarEdge: false

    asynchronous: false

    readonly property bool orientationMatches: (axis?.isVertical ?? false) === isInColumn

    active: orientationMatches &&
            getWidgetVisible(widgetId, DgopService.dgopAvailable) &&
            (widgetId !== "music" || MprisController.activePlayer !== null)
    sourceComponent: getWidgetComponent(widgetId, components)
    opacity: getWidgetEnabled(widgetData?.enabled) ? 1 : 0

    signal contentItemReady(var item)

    Binding {
        target: root.item
        when: root.item && "parentScreen" in root.item
        property: "parentScreen"
        value: root.parentScreen
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root.item
        when: root.item && "section" in root.item
        property: "section"
        value: root.section
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root.item
        when: root.item && "widgetThickness" in root.item
        property: "widgetThickness"
        value: root.widgetThickness
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root.item
        when: root.item && "barThickness" in root.item
        property: "barThickness"
        value: root.barThickness
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root.item
        when: root.item && "axis" in root.item
        property: "axis"
        value: root.axis
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root.item
        when: root.item && "widgetData" in root.item
        property: "widgetData"
        value: root.widgetData
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root.item
        when: root.item && "isFirst" in root.item
        property: "isFirst"
        value: root.isFirst
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root.item
        when: root.item && "isLast" in root.item
        property: "isLast"
        value: root.isLast
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root.item
        when: root.item && "sectionSpacing" in root.item
        property: "sectionSpacing"
        value: root.sectionSpacing
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root.item
        when: root.item && "isLeftBarEdge" in root.item
        property: "isLeftBarEdge"
        value: root.isLeftBarEdge
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root.item
        when: root.item && "isRightBarEdge" in root.item
        property: "isRightBarEdge"
        value: root.isRightBarEdge
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root.item
        when: root.item && "isTopBarEdge" in root.item
        property: "isTopBarEdge"
        value: root.isTopBarEdge
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root.item
        when: root.item && "isBottomBarEdge" in root.item
        property: "isBottomBarEdge"
        value: root.isBottomBarEdge
        restoreMode: Binding.RestoreNone
    }

    onLoaded: {
        if (item) {
            contentItemReady(item)            
            if (axis && "isVertical" in item) {
                try {
                    item.isVertical = axis.isVertical
                } catch (e) {
                }
            }

            if (item.pluginService !== undefined) {
                var parts = widgetId.split(":")
                var pluginId = parts[0]
                var variantId = parts.length > 1 ? parts[1] : null

                if (item.pluginId !== undefined) {
                    item.pluginId = pluginId
                }
                if (item.variantId !== undefined) {
                    item.variantId = variantId
                }
                if (item.variantData !== undefined && variantId) {
                    item.variantData = PluginService.getPluginVariantData(pluginId, variantId)
                }
                item.pluginService = PluginService
            }

            if (item.popoutService !== undefined) {
                item.popoutService = PopoutService
            }
        }
    }

    function getWidgetComponent(widgetId, components) {
        const componentMap = {
            "launcherButton": components.launcherButtonComponent,
            "workspaceSwitcher": components.workspaceSwitcherComponent,
            "focusedWindow": components.focusedWindowComponent,
            "runningApps": components.runningAppsComponent,
            "clock": components.clockComponent,
            "music": components.mediaComponent,
            "weather": components.weatherComponent,
            "systemTray": components.systemTrayComponent,
            "privacyIndicator": components.privacyIndicatorComponent,
            "clipboard": components.clipboardComponent,
            "cpuUsage": components.cpuUsageComponent,
            "memUsage": components.memUsageComponent,
            "diskUsage": components.diskUsageComponent,
            "cpuTemp": components.cpuTempComponent,
            "gpuTemp": components.gpuTempComponent,
            "notificationButton": components.notificationButtonComponent,
            "battery": components.batteryComponent,
            "controlCenterButton": components.controlCenterButtonComponent,
            "capsLockIndicator": components.capsLockIndicatorComponent,
            "idleInhibitor": components.idleInhibitorComponent,
            "spacer": components.spacerComponent,
            "separator": components.separatorComponent,
            "network_speed_monitor": components.networkComponent,
            "keyboard_layout_name": components.keyboardLayoutNameComponent,
            "vpn": components.vpnComponent,
            "notepadButton": components.notepadButtonComponent,
            "colorPicker": components.colorPickerComponent,
            "systemUpdate": components.systemUpdateComponent,
            "layout": components.layoutComponent
        }

        if (componentMap[widgetId]) {
            return componentMap[widgetId]
        }

        var parts = widgetId.split(":")
        var pluginId = parts[0]

        let pluginMap = PluginService.getWidgetComponents()
        return pluginMap[pluginId] || null
    }

    function getWidgetVisible(widgetId, dgopAvailable) {
        const widgetVisibility = {
            "cpuUsage": dgopAvailable,
            "memUsage": dgopAvailable,
            "cpuTemp": dgopAvailable,
            "gpuTemp": dgopAvailable,
            "network_speed_monitor": dgopAvailable,
            "layout": CompositorService.isDwl && DwlService.dwlAvailable
        }

        return widgetVisibility[widgetId] ?? true
    }

    function getWidgetEnabled(enabled) {
        return enabled !== false
    }
}
