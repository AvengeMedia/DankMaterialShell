pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.I3
import qs.Common

Singleton {
    id: root

    property var widgetRegistry: ({})
    property var dankBarRepeater: null

    // Bars rendered inside the frame surface (connected mode) have no DankBarWindow in the
    // repeater, so they self-register here (screenName -> barId -> DankBarBody) for trigger routing.
    property var frameHostedBars: ({})

    // Shared dock context-menu windows (created in DMSShell) so a frame-hosted dock can reach them.
    property var dockContextMenu: null
    property var dockTrashContextMenu: null

    function registerFrameBar(screenName, barId, body) {
        if (!screenName || !barId || !body)
            return;
        const next = Object.assign({}, frameHostedBars);
        const bars = Object.assign({}, next[screenName] ?? {});
        bars[barId] = body;
        next[screenName] = bars;
        frameHostedBars = next;
    }

    function unregisterFrameBar(screenName, barId, body) {
        if (!screenName || !barId || frameHostedBars[screenName]?.[barId] !== body)
            return;
        const next = Object.assign({}, frameHostedBars);
        const bars = Object.assign({}, next[screenName]);
        delete bars[barId];
        if (Object.keys(bars).length === 0)
            delete next[screenName];
        else
            next[screenName] = bars;
        frameHostedBars = next;
    }

    // Horizontal bars first, then config order, matching the standalone repeater order.
    function frameBarsForScreen(screenName) {
        const bars = frameHostedBars[screenName] ?? {};
        const order = SettingsData.barConfigs.map(cfg => cfg.id);
        const vertical = barId => {
            const position = SettingsData.getBarConfig(barId)?.position ?? SettingsData.Position.Top;
            return (position === SettingsData.Position.Left || position === SettingsData.Position.Right) ? 1 : 0;
        };
        return Object.keys(bars).sort((a, b) => (vertical(a) - vertical(b)) || (order.indexOf(a) - order.indexOf(b))).map(barId => bars[barId]);
    }

    // DankBar items self-register here (barConfig id -> DankBar) so frame-hosted bars can
    // resolve their models/rootWindow reactively, independent of repeater load ordering.
    property var dankBarItems: ({})

    function registerDankBarItem(barId, item) {
        if (!barId || !item)
            return;
        const next = Object.assign({}, dankBarItems);
        next[barId] = item;
        dankBarItems = next;
    }

    function unregisterDankBarItem(barId, item) {
        if (!barId || dankBarItems[barId] !== item)
            return;
        const next = Object.assign({}, dankBarItems);
        delete next[barId];
        dankBarItems = next;
    }

    signal widgetRegistered(string widgetId, string screenName)
    signal widgetUnregistered(string widgetId, string screenName)

    function registerWidget(widgetId, screenName, widgetRef) {
        if (!widgetId || !screenName || !widgetRef)
            return;

        const nextRegistry = (typeof widgetRegistry === "object" && widgetRegistry !== null) ? Object.assign({}, widgetRegistry) : {};
        const screenMap = (typeof nextRegistry[widgetId] === "object" && nextRegistry[widgetId] !== null) ? Object.assign({}, nextRegistry[widgetId]) : {};
        screenMap[screenName] = widgetRef;
        nextRegistry[widgetId] = screenMap;
        widgetRegistry = nextRegistry;
        widgetRegistered(widgetId, screenName);
    }

    function unregisterWidget(widgetId, screenName, widgetRef) {
        if (!widgetId || !screenName)
            return;
        if (typeof widgetRegistry !== "object" || widgetRegistry === null)
            return;
        if (!widgetRegistry[widgetId])
            return;
        if (widgetRef && widgetRegistry[widgetId][screenName] !== widgetRef)
            return;

        const nextRegistry = Object.assign({}, widgetRegistry);
        const screenMap = (typeof nextRegistry[widgetId] === "object" && nextRegistry[widgetId] !== null) ? Object.assign({}, nextRegistry[widgetId]) : {};
        delete screenMap[screenName];
        if (Object.keys(screenMap).length === 0) {
            delete nextRegistry[widgetId];
        } else {
            nextRegistry[widgetId] = screenMap;
        }
        widgetRegistry = nextRegistry;

        widgetUnregistered(widgetId, screenName);
    }

    function getWidget(widgetId, screenName) {
        if (typeof widgetRegistry !== "object" || widgetRegistry === null || !widgetRegistry[widgetId])
            return null;
        if (screenName)
            return widgetRegistry[widgetId][screenName] || null;

        const screens = Object.keys(widgetRegistry[widgetId]);
        return screens.length > 0 ? widgetRegistry[widgetId][screens[0]] : null;
    }

    function getWidgetOnFocusedScreen(widgetId) {
        if (typeof widgetRegistry !== "object" || widgetRegistry === null || !widgetRegistry[widgetId])
            return null;

        const focusedScreen = getFocusedScreenName();
        if (focusedScreen && widgetRegistry[widgetId][focusedScreen])
            return widgetRegistry[widgetId][focusedScreen];

        const screens = Object.keys(widgetRegistry[widgetId]);
        return screens.length > 0 ? widgetRegistry[widgetId][screens[0]] : null;
    }

    readonly property bool focusedScreenDetectionSupported: CompositorService.isHyprland || CompositorService.isNiri || CompositorService.isMango || CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle

    function getFocusedScreenName() {
        if (CompositorService.isHyprland && Hyprland.focusedWorkspace?.monitor)
            return Hyprland.focusedWorkspace.monitor.name;
        if (CompositorService.isNiri && NiriService.currentOutput)
            return NiriService.currentOutput;
        if (CompositorService.isMango && MangoService.activeOutput)
            return MangoService.activeOutput;
        if (CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle) {
            const focusedWs = I3.workspaces?.values?.find(ws => ws.focused === true);
            return focusedWs?.monitor?.name || "";
        }
        return "";
    }

    function getRegisteredWidgetIds() {
        if (typeof widgetRegistry !== "object" || widgetRegistry === null)
            return [];
        return Object.keys(widgetRegistry);
    }

    function hasWidget(widgetId) {
        if (typeof widgetRegistry !== "object" || widgetRegistry === null)
            return false;
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
        const hosted = frameBarsForScreen(screenName);
        if (hosted.length > 0)
            return hosted[0];

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
        if (dankBarRepeater) {
            for (var i = 0; i < dankBarRepeater.count; i++) {
                const barItem = dankBarRepeater.itemAt(i)?.item;
                if (barItem?.barVariants?.instances?.length > 0)
                    return barItem.barVariants.instances[0];
            }
        }

        for (const screenName in frameHostedBars) {
            const hosted = frameBarsForScreen(screenName);
            if (hosted.length > 0)
                return hosted[0];
        }
        return null;
    }
}
