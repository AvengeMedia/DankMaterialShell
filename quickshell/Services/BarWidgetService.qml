pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.I3

Singleton {
    id: root

    property var widgetRegistry: ({})
    property var dankBarRepeater: null

    signal widgetRegistered(string widgetId, string screenName)
    signal widgetUnregistered(string widgetId, string screenName)

    function registerWidget(widgetId, screenName, widgetRef) {
        if (!widgetId || !screenName || !widgetRef)
            return;

        if (!widgetRegistry[widgetId])
            widgetRegistry[widgetId] = {};

        widgetRegistry[widgetId][screenName] = widgetRef;
        widgetRegistered(widgetId, screenName);
    }

    function unregisterWidget(widgetId, screenName) {
        if (!widgetId || !screenName)
            return;
        if (!widgetRegistry[widgetId])
            return;

        delete widgetRegistry[widgetId][screenName];
        if (Object.keys(widgetRegistry[widgetId]).length === 0)
            delete widgetRegistry[widgetId];

        widgetUnregistered(widgetId, screenName);
    }

    function getWidget(widgetId, screenName) {
        if (!widgetRegistry[widgetId])
            return null;
        if (screenName)
            return widgetRegistry[widgetId][screenName] || null;

        const screens = Object.keys(widgetRegistry[widgetId]);
        return screens.length > 0 ? widgetRegistry[widgetId][screens[0]] : null;
    }

    function getWidgetOnFocusedScreen(widgetId) {
        if (!widgetRegistry[widgetId])
            return null;

        const focusedScreen = getFocusedScreenName();
        if (focusedScreen && widgetRegistry[widgetId][focusedScreen])
            return widgetRegistry[widgetId][focusedScreen];

        const screens = Object.keys(widgetRegistry[widgetId]);
        return screens.length > 0 ? widgetRegistry[widgetId][screens[0]] : null;
    }

    function getFocusedScreenName() {
        if (CompositorService.isHyprland && Hyprland.focusedWorkspace?.monitor)
            return Hyprland.focusedWorkspace.monitor.name;
        if (CompositorService.isNiri && NiriService.currentOutput)
            return NiriService.currentOutput;
        if (CompositorService.isSway) {
            const focusedWs = I3.workspaces?.values?.find(ws => ws.focused === true);
            return focusedWs?.monitor?.name || "";
        }
        return "";
    }

    function getRegisteredWidgetIds() {
        return Object.keys(widgetRegistry);
    }

    function hasWidget(widgetId) {
        return widgetRegistry[widgetId] && Object.keys(widgetRegistry[widgetId]).length > 0;
    }

    function triggerWidgetPopout(widgetId) {
        const widget = getWidgetOnFocusedScreen(widgetId);
        if (!widget)
            return false;

        if (typeof widget.triggerPopout === "function") {
            widget.triggerPopout();
            return true;
        }

        const signalMap = {
            "battery": "toggleBatteryPopup",
            "vpn": "toggleVpnPopup",
            "layout": "toggleLayoutPopup",
            "clock": "clockClicked",
            "cpuUsage": "cpuClicked",
            "memUsage": "ramClicked",
            "cpuTemp": "cpuTempClicked",
            "gpuTemp": "gpuTempClicked"
        };

        const signalName = signalMap[widgetId];
        if (signalName && typeof widget[signalName] === "function") {
            widget[signalName]();
            return true;
        }

        if (typeof widget.clicked === "function") {
            widget.clicked();
            return true;
        }

        if (widget.popoutTarget?.toggle) {
            widget.popoutTarget.toggle();
            return true;
        }

        return false;
    }

    function getBarWindowForScreen(screenName) {
        if (!dankBarRepeater)
            return null;

        for (var i = 0; i < dankBarRepeater.count; i++) {
            const loader = dankBarRepeater.itemAt(i);
            if (!loader?.item)
                continue;

            const barItem = loader.item;
            if (!barItem.barVariants?.instances)
                continue;

            for (var j = 0; j < barItem.barVariants.instances.length; j++) {
                const barInstance = barItem.barVariants.instances[j];
                if (barInstance.modelData?.name === screenName)
                    return barInstance;
            }
        }
        return null;
    }

    function getBarWindowOnFocusedScreen() {
        const focusedScreen = getFocusedScreenName();
        if (!focusedScreen)
            return getFirstBarWindow();
        return getBarWindowForScreen(focusedScreen) || getFirstBarWindow();
    }

    function getFirstBarWindow() {
        if (!dankBarRepeater || dankBarRepeater.count === 0)
            return null;

        const loader = dankBarRepeater.itemAt(0);
        if (!loader?.item)
            return null;

        const barItem = loader.item;
        if (!barItem.barVariants?.instances || barItem.barVariants.instances.length === 0)
            return null;

        return barItem.barVariants.instances[0];
    }
}
