import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.I3
import qs.Common
import qs.Services

Item {
    id: root

    required property var barConfig

    signal colorPickerRequested
    signal barReady(var barConfig)

    property alias barVariants: barVariants
    property var hyprlandOverviewLoader: null
    property bool systemTrayMenuOpen: false

    property alias leftWidgetsModel: leftWidgetsModel
    property alias centerWidgetsModel: centerWidgetsModel
    property alias rightWidgetsModel: rightWidgetsModel

    ScriptModel {
        id: leftWidgetsModel
        values: {
            root.barConfig;
            const leftWidgets = root.barConfig?.leftWidgets || [];
            return leftWidgets.map((w, index) => {
                if (typeof w === "string") {
                    return {
                        widgetId: w,
                        id: w + "_" + index,
                        enabled: true
                    };
                } else {
                    const obj = Object.assign({}, w);
                    obj.widgetId = w.id || w.widgetId;
                    obj.id = (w.id || w.widgetId) + "_" + index;
                    obj.enabled = w.enabled !== false;
                    return obj;
                }
            });
        }
    }

    ScriptModel {
        id: centerWidgetsModel
        values: {
            root.barConfig;
            const centerWidgets = root.barConfig?.centerWidgets || [];
            return centerWidgets.map((w, index) => {
                if (typeof w === "string") {
                    return {
                        widgetId: w,
                        id: w + "_" + index,
                        enabled: true
                    };
                } else {
                    const obj = Object.assign({}, w);
                    obj.widgetId = w.id || w.widgetId;
                    obj.id = (w.id || w.widgetId) + "_" + index;
                    obj.enabled = w.enabled !== false;
                    return obj;
                }
            });
        }
    }

    ScriptModel {
        id: rightWidgetsModel
        values: {
            root.barConfig;
            const rightWidgets = root.barConfig?.rightWidgets || [];
            return rightWidgets.map((w, index) => {
                if (typeof w === "string") {
                    return {
                        widgetId: w,
                        id: w + "_" + index,
                        enabled: true
                    };
                } else {
                    const obj = Object.assign({}, w);
                    obj.widgetId = w.id || w.widgetId;
                    obj.id = (w.id || w.widgetId) + "_" + index;
                    obj.enabled = w.enabled !== false;
                    return obj;
                }
            });
        }
    }

    function triggerControlCenterOnFocusedScreen() {
        let focusedScreenName = "";
        if (CompositorService.isHyprland && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor) {
            focusedScreenName = Hyprland.focusedWorkspace.monitor.name;
        } else if (CompositorService.isNiri && NiriService.currentOutput) {
            focusedScreenName = NiriService.currentOutput;
        } else if (CompositorService.isSway) {
            const focusedWs = I3.workspaces?.values?.find(ws => ws.focused === true);
            focusedScreenName = focusedWs?.monitor?.name || "";
        }

        if (!focusedScreenName && barVariants.instances.length > 0) {
            const firstBar = barVariants.instances[0];
            firstBar.triggerControlCenter();
            return true;
        }

        for (var i = 0; i < barVariants.instances.length; i++) {
            const barInstance = barVariants.instances[i];
            if (barInstance.modelData && barInstance.modelData.name === focusedScreenName) {
                barInstance.triggerControlCenter();
                return true;
            }
        }
        return false;
    }

    function triggerWallpaperBrowserOnFocusedScreen() {
        let focusedScreenName = "";
        if (CompositorService.isHyprland && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor) {
            focusedScreenName = Hyprland.focusedWorkspace.monitor.name;
        } else if (CompositorService.isNiri && NiriService.currentOutput) {
            focusedScreenName = NiriService.currentOutput;
        } else if (CompositorService.isSway) {
            const focusedWs = I3.workspaces?.values?.find(ws => ws.focused === true);
            focusedScreenName = focusedWs?.monitor?.name || "";
        }

        if (!focusedScreenName && barVariants.instances.length > 0) {
            const firstBar = barVariants.instances[0];
            firstBar.triggerWallpaperBrowser();
            return true;
        }

        for (var i = 0; i < barVariants.instances.length; i++) {
            const barInstance = barVariants.instances[i];
            if (barInstance.modelData && barInstance.modelData.name === focusedScreenName) {
                barInstance.triggerWallpaperBrowser();
                return true;
            }
        }
        return false;
    }

    Variants {
        id: barVariants
        model: {
            const prefs = root.barConfig?.screenPreferences || ["all"];
            if (prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all")) {
                return Quickshell.screens;
            }
            const filtered = Quickshell.screens.filter(screen => SettingsData.isScreenInPreferences(screen, prefs));
            if (filtered.length === 0 && root.barConfig?.showOnLastDisplay && Quickshell.screens.length === 1) {
                return Quickshell.screens;
            }
            return filtered;
        }

        delegate: DankBarWindow {
            rootWindow: root
            barConfig: root.barConfig
            leftWidgetsModel: root.leftWidgetsModel
            centerWidgetsModel: root.centerWidgetsModel
            rightWidgetsModel: root.rightWidgetsModel
        }
    }
}
