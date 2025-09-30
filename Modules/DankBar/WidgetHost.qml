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

    asynchronous: false

    active: getWidgetVisible(widgetId, DgopService.dgopAvailable) &&
            (widgetId !== "music" || MprisController.activePlayer !== null)
    sourceComponent: getWidgetComponent(widgetId, components)
    opacity: getWidgetEnabled(widgetData?.enabled) ? 1 : 0

    signal contentItemReady(var item)

    onLoaded: {
        if (item) {
            contentItemReady(item)
            if (widgetId === "spacer") {
                item.spacerSize = Qt.binding(() => spacerSize)
            }
            if (axis && "axis" in item) {
                item.axis = axis
            }
            if (axis && "isVertical" in item) {
                item.isVertical = axis.isVertical
            }

            // Inject PluginService for plugin widgets
            if (item.pluginService !== undefined) {
                console.log("WidgetHost: Injecting PluginService into plugin widget:", widgetId)
                item.pluginService = PluginService
                if (item.loadTimezones) {
                    console.log("WidgetHost: Calling loadTimezones for widget:", widgetId)
                    item.loadTimezones()
                }
            }
        }
    }

    function getWidgetComponent(widgetId, components) {
        // Build component map for built-in widgets
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
            "idleInhibitor": components.idleInhibitorComponent,
            "spacer": components.spacerComponent,
            "separator": components.separatorComponent,
            "network_speed_monitor": components.networkComponent,
            "keyboard_layout_name": components.keyboardLayoutNameComponent,
            "vpn": components.vpnComponent,
            "notepadButton": components.notepadButtonComponent,
            "colorPicker": components.colorPickerComponent,
            "systemUpdate": components.systemUpdateComponent
        }

        // Check for built-in component first
        if (componentMap[widgetId]) {
            return componentMap[widgetId]
        }

        // Check for plugin component
        let pluginMap = PluginService.getWidgetComponents()
        return pluginMap[widgetId] || null
    }

    function getWidgetVisible(widgetId, dgopAvailable) {
        const widgetVisibility = {
            "cpuUsage": dgopAvailable,
            "memUsage": dgopAvailable,
            "cpuTemp": dgopAvailable,
            "gpuTemp": dgopAvailable,
            "network_speed_monitor": dgopAvailable
        }

        return widgetVisibility[widgetId] ?? true
    }

    function getWidgetEnabled(enabled) {
        return enabled !== false
    }
}