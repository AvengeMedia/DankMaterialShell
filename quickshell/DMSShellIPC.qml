import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import qs.Common
import qs.Services

Item {
    id: root

    required property var powerMenuModalLoader
    required property var processListModalLoader
    required property var controlCenterLoader
    required property var dankDashPopoutLoader
    required property var notepadSlideoutVariants
    required property var hyprKeybindsModalLoader
    required property var dankBarRepeater
    required property var hyprlandOverviewLoader

    function getFirstBar() {
        if (!root.dankBarRepeater || root.dankBarRepeater.count === 0)
            return null;
        const firstLoader = root.dankBarRepeater.itemAt(0);
        return firstLoader ? firstLoader.item : null;
    }

    IpcHandler {
        function open() {
            root.powerMenuModalLoader.active = true;
            if (root.powerMenuModalLoader.item)
                root.powerMenuModalLoader.item.openCentered();

            return "POWERMENU_OPEN_SUCCESS";
        }

        function close() {
            if (root.powerMenuModalLoader.item)
                root.powerMenuModalLoader.item.close();

            return "POWERMENU_CLOSE_SUCCESS";
        }

        function toggle() {
            root.powerMenuModalLoader.active = true;
            if (root.powerMenuModalLoader.item) {
                if (root.powerMenuModalLoader.item.shouldBeVisible) {
                    root.powerMenuModalLoader.item.close();
                } else {
                    root.powerMenuModalLoader.item.openCentered();
                }
            }

            return "POWERMENU_TOGGLE_SUCCESS";
        }

        target: "powermenu"
    }

    IpcHandler {
        function open(): string {
            root.processListModalLoader.active = true;
            if (root.processListModalLoader.item)
                root.processListModalLoader.item.show();

            return "PROCESSLIST_OPEN_SUCCESS";
        }

        function close(): string {
            if (root.processListModalLoader.item)
                root.processListModalLoader.item.hide();

            return "PROCESSLIST_CLOSE_SUCCESS";
        }

        function toggle(): string {
            root.processListModalLoader.active = true;
            if (root.processListModalLoader.item)
                root.processListModalLoader.item.toggle();

            return "PROCESSLIST_TOGGLE_SUCCESS";
        }

        function focusOrToggle(): string {
            root.processListModalLoader.active = true;
            if (root.processListModalLoader.item)
                root.processListModalLoader.item.focusOrToggle();

            return "PROCESSLIST_FOCUS_OR_TOGGLE_SUCCESS";
        }

        target: "processlist"
    }

    IpcHandler {
        function open(): string {
            const bar = root.getFirstBar();
            if (bar) {
                bar.triggerControlCenterOnFocusedScreen();
                return "CONTROL_CENTER_OPEN_SUCCESS";
            }
            return "CONTROL_CENTER_OPEN_FAILED";
        }

        function hide(): string {
            if (root.controlCenterLoader.item && root.controlCenterLoader.item.shouldBeVisible) {
                root.controlCenterLoader.item.close();
                return "CONTROL_CENTER_HIDE_SUCCESS";
            }
            return "CONTROL_CENTER_HIDE_FAILED";
        }

        function toggle(): string {
            const bar = root.getFirstBar();
            if (bar) {
                bar.triggerControlCenterOnFocusedScreen();
                return "CONTROL_CENTER_TOGGLE_SUCCESS";
            }
            return "CONTROL_CENTER_TOGGLE_FAILED";
        }

        function status(): string {
            return (root.controlCenterLoader.item && root.controlCenterLoader.item.shouldBeVisible) ? "visible" : "hidden";
        }

        target: "control-center"
    }

    IpcHandler {
        function open(tab: string): string {
            root.dankDashPopoutLoader.active = true;
            if (root.dankDashPopoutLoader.item) {
                switch (tab.toLowerCase()) {
                case "media":
                    root.dankDashPopoutLoader.item.currentTabIndex = 1;
                    break;
                case "weather":
                    root.dankDashPopoutLoader.item.currentTabIndex = SettingsData.weatherEnabled ? 2 : 0;
                    break;
                default:
                    root.dankDashPopoutLoader.item.currentTabIndex = 0;
                    break;
                }
                root.dankDashPopoutLoader.item.setTriggerPosition(Screen.width / 2, Theme.barHeight + Theme.spacingS, 100, "center", Screen);
                root.dankDashPopoutLoader.item.dashVisible = true;
                return "DASH_OPEN_SUCCESS";
            }
            return "DASH_OPEN_FAILED";
        }

        function close(): string {
            if (root.dankDashPopoutLoader.item) {
                root.dankDashPopoutLoader.item.dashVisible = false;
                return "DASH_CLOSE_SUCCESS";
            }
            return "DASH_CLOSE_FAILED";
        }

        function toggle(tab: string): string {
            const bar = root.getFirstBar();
            if (bar && bar.triggerWallpaperBrowserOnFocusedScreen()) {
                if (root.dankDashPopoutLoader.item) {
                    switch (tab.toLowerCase()) {
                    case "media":
                        root.dankDashPopoutLoader.item.currentTabIndex = 1;
                        break;
                    case "wallpaper":
                        root.dankDashPopoutLoader.item.currentTabIndex = 2;
                        break;
                    case "weather":
                        root.dankDashPopoutLoader.item.currentTabIndex = SettingsData.weatherEnabled ? 3 : 0;
                        break;
                    default:
                        root.dankDashPopoutLoader.item.currentTabIndex = 0;
                        break;
                    }
                }
                return "DASH_TOGGLE_SUCCESS";
            }
            return "DASH_TOGGLE_FAILED";
        }

        target: "dash"
    }

    IpcHandler {
        function getFocusedScreenName() {
            if (CompositorService.isHyprland && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor) {
                return Hyprland.focusedWorkspace.monitor.name;
            }
            if (CompositorService.isNiri && NiriService.currentOutput) {
                return NiriService.currentOutput;
            }
            return "";
        }

        function getActiveNotepadInstance() {
            if (root.notepadSlideoutVariants.instances.length === 0) {
                return null;
            }

            if (root.notepadSlideoutVariants.instances.length === 1) {
                return root.notepadSlideoutVariants.instances[0];
            }

            var focusedScreen = getFocusedScreenName();
            if (focusedScreen && root.notepadSlideoutVariants.instances.length > 0) {
                for (var i = 0; i < root.notepadSlideoutVariants.instances.length; i++) {
                    var slideout = root.notepadSlideoutVariants.instances[i];
                    if (slideout.modelData && slideout.modelData.name === focusedScreen) {
                        return slideout;
                    }
                }
            }

            for (var i = 0; i < root.notepadSlideoutVariants.instances.length; i++) {
                var slideout = root.notepadSlideoutVariants.instances[i];
                if (slideout.isVisible) {
                    return slideout;
                }
            }

            return root.notepadSlideoutVariants.instances[0];
        }

        function open(): string {
            var instance = getActiveNotepadInstance();
            if (instance) {
                instance.show();
                return "NOTEPAD_OPEN_SUCCESS";
            }
            return "NOTEPAD_OPEN_FAILED";
        }

        function close(): string {
            var instance = getActiveNotepadInstance();
            if (instance) {
                instance.hide();
                return "NOTEPAD_CLOSE_SUCCESS";
            }
            return "NOTEPAD_CLOSE_FAILED";
        }

        function toggle(): string {
            var instance = getActiveNotepadInstance();
            if (instance) {
                instance.toggle();
                return "NOTEPAD_TOGGLE_SUCCESS";
            }
            return "NOTEPAD_TOGGLE_FAILED";
        }

        target: "notepad"
    }

    IpcHandler {
        function toggle(): string {
            SessionService.toggleIdleInhibit();
            return SessionService.idleInhibited ? "Idle inhibit enabled" : "Idle inhibit disabled";
        }

        function enable(): string {
            SessionService.enableIdleInhibit();
            return "Idle inhibit enabled";
        }

        function disable(): string {
            SessionService.disableIdleInhibit();
            return "Idle inhibit disabled";
        }

        function status(): string {
            return SessionService.idleInhibited ? "Idle inhibit is enabled" : "Idle inhibit is disabled";
        }

        function reason(newReason: string): string {
            if (!newReason) {
                return `Current reason: ${SessionService.inhibitReason}`;
            }

            SessionService.setInhibitReason(newReason);
            return `Inhibit reason set to: ${newReason}`;
        }

        target: "inhibit"
    }

    IpcHandler {
        function list(): string {
            return MprisController.availablePlayers.map(p => p.identity).join("\n");
        }

        function play(): void {
            if (MprisController.activePlayer && MprisController.activePlayer.canPlay) {
                MprisController.activePlayer.play();
            }
        }

        function pause(): void {
            if (MprisController.activePlayer && MprisController.activePlayer.canPause) {
                MprisController.activePlayer.pause();
            }
        }

        function playPause(): void {
            if (MprisController.activePlayer && MprisController.activePlayer.canTogglePlaying) {
                MprisController.activePlayer.togglePlaying();
            }
        }

        function previous(): void {
            if (MprisController.activePlayer && MprisController.activePlayer.canGoPrevious) {
                MprisController.activePlayer.previous();
            }
        }

        function next(): void {
            if (MprisController.activePlayer && MprisController.activePlayer.canGoNext) {
                MprisController.activePlayer.next();
            }
        }

        function stop(): void {
            if (MprisController.activePlayer) {
                MprisController.activePlayer.stop();
            }
        }

        target: "mpris"
    }

    IpcHandler {
        function toggle(provider: string): string {
            if (!provider)
                return "ERROR: No provider specified";

            KeybindsService.currentProvider = provider;
            KeybindsService.loadBinds();
            root.hyprKeybindsModalLoader.active = true;

            if (!root.hyprKeybindsModalLoader.item)
                return `KEYBINDS_TOGGLE_FAILED: ${provider}`;

            if (root.hyprKeybindsModalLoader.item.shouldBeVisible) {
                root.hyprKeybindsModalLoader.item.close();
            } else {
                root.hyprKeybindsModalLoader.item.open();
            }
            return `KEYBINDS_TOGGLE_SUCCESS: ${provider}`;
        }

        function toggleWithPath(provider: string, path: string): string {
            if (!provider)
                return "ERROR: No provider specified";

            KeybindsService.currentProvider = provider;
            KeybindsService.loadBinds();
            root.hyprKeybindsModalLoader.active = true;

            if (!root.hyprKeybindsModalLoader.item)
                return `KEYBINDS_TOGGLE_FAILED: ${provider}`;

            if (root.hyprKeybindsModalLoader.item.shouldBeVisible) {
                root.hyprKeybindsModalLoader.item.close();
            } else {
                root.hyprKeybindsModalLoader.item.open();
            }
            return `KEYBINDS_TOGGLE_SUCCESS: ${provider} (${path})`;
        }

        function open(provider: string): string {
            if (!provider)
                return "ERROR: No provider specified";

            KeybindsService.currentProvider = provider;
            KeybindsService.loadBinds();
            root.hyprKeybindsModalLoader.active = true;

            if (!root.hyprKeybindsModalLoader.item)
                return `KEYBINDS_OPEN_FAILED: ${provider}`;

            root.hyprKeybindsModalLoader.item.open();
            return `KEYBINDS_OPEN_SUCCESS: ${provider}`;
        }

        function openWithPath(provider: string, path: string): string {
            if (!provider)
                return "ERROR: No provider specified";

            KeybindsService.currentProvider = provider;
            KeybindsService.loadBinds();
            root.hyprKeybindsModalLoader.active = true;

            if (!root.hyprKeybindsModalLoader.item)
                return `KEYBINDS_OPEN_FAILED: ${provider}`;

            root.hyprKeybindsModalLoader.item.open();
            return `KEYBINDS_OPEN_SUCCESS: ${provider} (${path})`;
        }

        function close(): string {
            if (!root.hyprKeybindsModalLoader.item)
                return "KEYBINDS_CLOSE_FAILED";

            root.hyprKeybindsModalLoader.item.close();
            return "KEYBINDS_CLOSE_SUCCESS";
        }

        target: "keybinds"
    }

    IpcHandler {
        function openBinds(): string {
            if (!CompositorService.isHyprland)
                return "HYPR_NOT_AVAILABLE";

            KeybindsService.currentProvider = "hyprland";
            KeybindsService.loadBinds();
            root.hyprKeybindsModalLoader.active = true;

            if (!root.hyprKeybindsModalLoader.item)
                return "HYPR_KEYBINDS_OPEN_FAILED";

            root.hyprKeybindsModalLoader.item.open();
            return "HYPR_KEYBINDS_OPEN_SUCCESS";
        }

        function closeBinds(): string {
            if (!CompositorService.isHyprland)
                return "HYPR_NOT_AVAILABLE";

            if (!root.hyprKeybindsModalLoader.item)
                return "HYPR_KEYBINDS_CLOSE_FAILED";

            root.hyprKeybindsModalLoader.item.close();
            return "HYPR_KEYBINDS_CLOSE_SUCCESS";
        }

        function toggleBinds(): string {
            if (!CompositorService.isHyprland)
                return "HYPR_NOT_AVAILABLE";

            KeybindsService.currentProvider = "hyprland";
            KeybindsService.loadBinds();
            root.hyprKeybindsModalLoader.active = true;

            if (!root.hyprKeybindsModalLoader.item)
                return "HYPR_KEYBINDS_TOGGLE_FAILED";

            if (root.hyprKeybindsModalLoader.item.shouldBeVisible) {
                root.hyprKeybindsModalLoader.item.close();
            } else {
                root.hyprKeybindsModalLoader.item.open();
            }
            return "HYPR_KEYBINDS_TOGGLE_SUCCESS";
        }

        function toggleOverview(): string {
            if (!CompositorService.isHyprland || !root.hyprlandOverviewLoader.item) {
                return "HYPR_NOT_AVAILABLE";
            }
            root.hyprlandOverviewLoader.item.overviewOpen = !root.hyprlandOverviewLoader.item.overviewOpen;
            return root.hyprlandOverviewLoader.item.overviewOpen ? "OVERVIEW_OPEN_SUCCESS" : "OVERVIEW_CLOSE_SUCCESS";
        }

        function closeOverview(): string {
            if (!CompositorService.isHyprland || !root.hyprlandOverviewLoader.item) {
                return "HYPR_NOT_AVAILABLE";
            }
            root.hyprlandOverviewLoader.item.overviewOpen = false;
            return "OVERVIEW_CLOSE_SUCCESS";
        }

        function openOverview(): string {
            if (!CompositorService.isHyprland || !root.hyprlandOverviewLoader.item) {
                return "HYPR_NOT_AVAILABLE";
            }
            root.hyprlandOverviewLoader.item.overviewOpen = true;
            return "OVERVIEW_OPEN_SUCCESS";
        }

        target: "hypr"
    }

    IpcHandler {
        function wallpaper(): string {
            const bar = root.getFirstBar();
            if (bar && bar.triggerWallpaperBrowserOnFocusedScreen()) {
                return "SUCCESS: Toggled wallpaper browser";
            }
            return "ERROR: Failed to toggle wallpaper browser";
        }

        target: "dankdash"
    }

    function getBarConfig(selector: string, value: string): var {
        const barSelectors = ["id", "name", "index"];
        if (!barSelectors.includes(selector))
            return {
                error: "BAR_INVALID_SELECTOR"
            };
        const index = selector === "index" ? Number(value) : SettingsData.barConfigs.findIndex(bar => bar[selector] == value);
        const barConfig = SettingsData.barConfigs?.[index];
        if (!barConfig)
            return {
                error: "BAR_NOT_FOUND"
            };
        return {
            barConfig
        };
    }

    IpcHandler {
        function reveal(selector: string, value: string): string {
            const {
                barConfig,
                error
            } = getBarConfig(selector, value);
            if (error)
                return error;
            SettingsData.updateBarConfig(barConfig.id, {
                visible: true
            });
            return "BAR_SHOW_SUCCESS";
        }

        function hide(selector: string, value: string): string {
            const {
                barConfig,
                error
            } = getBarConfig(selector, value);
            if (error)
                return error;
            SettingsData.updateBarConfig(barConfig.id, {
                visible: false
            });
            return "BAR_HIDE_SUCCESS";
        }

        function toggle(selector: string, value: string): string {
            const {
                barConfig,
                error
            } = getBarConfig(selector, value);
            if (error)
                return error;
            SettingsData.updateBarConfig(barConfig.id, {
                visible: !barConfig.visible
            });
            return !barConfig.visible ? "BAR_SHOW_SUCCESS" : "BAR_HIDE_SUCCESS";
        }

        function status(selector: string, value: string): string {
            const {
                barConfig,
                error
            } = getBarConfig(selector, value);
            if (error)
                return error;
            return barConfig.visible ? "visible" : "hidden";
        }

        function autoHide(selector: string, value: string): string {
            const {
                barConfig,
                error
            } = getBarConfig(selector, value);
            if (error)
                return error;
            SettingsData.updateBarConfig(barConfig.id, {
                autoHide: true
            });
            return "BAR_AUTO_HIDE_SUCCESS";
        }

        function manualHide(selector: string, value: string): string {
            const {
                barConfig,
                error
            } = getBarConfig(selector, value);
            if (error)
                return error;
            SettingsData.updateBarConfig(barConfig.id, {
                autoHide: false
            });
            return "BAR_MANUAL_HIDE_SUCCESS";
        }

        function toggleAutoHide(selector: string, value: string): string {
            const {
                barConfig,
                error
            } = getBarConfig(selector, value);
            if (error)
                return error;
            SettingsData.updateBarConfig(barConfig.id, {
                autoHide: !barConfig.autoHide
            });
            return barConfig.autoHide ? "BAR_MANUAL_HIDE_SUCCESS" : "BAR_AUTO_HIDE_SUCCESS";
        }

        target: "bar"
    }

    IpcHandler {
        function reveal(): string {
            SettingsData.setShowDock(true);
            return "DOCK_SHOW_SUCCESS";
        }

        function hide(): string {
            SettingsData.setShowDock(false);
            return "DOCK_HIDE_SUCCESS";
        }

        function toggle(): string {
            SettingsData.toggleShowDock();
            return SettingsData.showDock ? "DOCK_SHOW_SUCCESS" : "DOCK_HIDE_SUCCESS";
        }

        function status(): string {
            return SettingsData.showDock ? "visible" : "hidden";
        }

        function autoHide(): string {
            SettingsData.dockAutoHide = true;
            SettingsData.saveSettings();
            return "BAR_AUTO_HIDE_SUCCESS";
        }

        function manualHide(): string {
            SettingsData.dockAutoHide = false;
            SettingsData.saveSettings();
            return "BAR_MANUAL_HIDE_SUCCESS";
        }

        function toggleAutoHide(): string {
            SettingsData.dockAutoHide = !SettingsData.dockAutoHide;
            SettingsData.saveSettings();
            return SettingsData.dockAutoHide ? "BAR_AUTO_HIDE_SUCCESS" : "BAR_MANUAL_HIDE_SUCCESS";
        }

        target: "dock"
    }

    IpcHandler {
        function open(): string {
            PopoutService.openSettings();
            return "SETTINGS_OPEN_SUCCESS";
        }

        function openWith(tab: string): string {
            if (!tab)
                return "SETTINGS_OPEN_FAILED: No tab specified";
            PopoutService.openSettingsWithTab(tab);
            return `SETTINGS_OPEN_SUCCESS: ${tab}`;
        }

        function close(): string {
            PopoutService.closeSettings();
            return "SETTINGS_CLOSE_SUCCESS";
        }

        function toggle(): string {
            PopoutService.toggleSettings();
            return "SETTINGS_TOGGLE_SUCCESS";
        }

        function toggleWith(tab: string): string {
            if (!tab)
                return "SETTINGS_TOGGLE_FAILED: No tab specified";
            PopoutService.toggleSettingsWithTab(tab);
            return `SETTINGS_TOGGLE_SUCCESS: ${tab}`;
        }

        function focusOrToggle(): string {
            PopoutService.focusOrToggleSettings();
            return "SETTINGS_FOCUS_OR_TOGGLE_SUCCESS";
        }

        function focusOrToggleWith(tab: string): string {
            if (!tab)
                return "SETTINGS_FOCUS_OR_TOGGLE_FAILED: No tab specified";
            PopoutService.focusOrToggleSettingsWithTab(tab);
            return `SETTINGS_FOCUS_OR_TOGGLE_SUCCESS: ${tab}`;
        }

        function tabs(): string {
            if (!PopoutService.settingsModal)
                return "wallpaper\ntheme\ntypography\ntime_weather\nsounds\ndankbar\ndankbar_settings\ndankbar_widgets\nworkspaces\nmedia_player\nnotifications\nosd\nrunning_apps\nupdater\ndock\nlauncher\nkeybinds\ndisplays\nnetwork\nprinters\nlock_screen\npower_sleep\nplugins\nabout";
            var modal = PopoutService.settingsModal;
            var ids = [];
            var structure = modal.sidebar?.categoryStructure ?? [];
            for (var i = 0; i < structure.length; i++) {
                var cat = structure[i];
                if (cat.separator)
                    continue;
                if (cat.id)
                    ids.push(cat.id);
                if (cat.children) {
                    for (var j = 0; j < cat.children.length; j++) {
                        if (cat.children[j].id)
                            ids.push(cat.children[j].id);
                    }
                }
            }
            return ids.join("\n");
        }

        function get(key: string): string {
            return JSON.stringify(SettingsData?.[key]);
        }

        function set(key: string, value: string): string {
            if (!(key in SettingsData)) {
                console.warn("Cannot set property, not found:", key);
                return "SETTINGS_INVALID_KEY";
            }

            const typeName = typeof SettingsData?.[key];

            try {
                switch (typeName) {
                case "boolean":
                    if (value === "true" || value === "false")
                        value = (value === "true");
                    else
                        throw `${value} is not a Boolean`;
                    break;
                case "number":
                    value = Number(value);
                    if (isNaN(value))
                        throw `${value} is not a Number`;
                    break;
                case "string":
                    value = String(value);
                    break;
                case "object":
                    // NOTE: Parsing lists is messed up upstream and not sure if we want
                    // to make sure objects are well structured or just let people set
                    // whatever they want but risking messed up settings.
                    // Objects & Arrays are disabled for now
                    // https://github.com/quickshell-mirror/quickshell/pull/22
                    throw "Setting Objects and Arrays not supported";
                default:
                    throw "Unsupported type";
                }

                console.warn("Setting:", key, value);
                SettingsData[key] = value;
                SettingsData.saveSettings();
                return "SETTINGS_SET_SUCCESS";
            } catch (e) {
                console.warn("Failed to set property:", key, "error:", e);
                return "SETTINGS_SET_FAILURE";
            }
        }

        target: "settings"
    }

    IpcHandler {
        function browse(type: string) {
            const modal = PopoutService.settingsModal;
            if (modal) {
                if (type === "wallpaper") {
                    modal.wallpaperBrowser.allowStacking = false;
                    modal.wallpaperBrowser.open();
                } else if (type === "profile") {
                    modal.profileBrowser.allowStacking = false;
                    modal.profileBrowser.open();
                }
            } else {
                PopoutService.openSettings();
            }
        }

        target: "file"
    }

    IpcHandler {
        function toggle(widgetId: string): string {
            if (!widgetId)
                return "ERROR: No widget ID specified";

            if (!BarWidgetService.hasWidget(widgetId))
                return `WIDGET_NOT_FOUND: ${widgetId}`;

            const success = BarWidgetService.triggerWidgetPopout(widgetId);
            return success ? `WIDGET_TOGGLE_SUCCESS: ${widgetId}` : `WIDGET_TOGGLE_FAILED: ${widgetId}`;
        }

        function list(): string {
            const widgets = BarWidgetService.getRegisteredWidgetIds();
            if (widgets.length === 0)
                return "No widgets registered";
            return widgets.join("\n");
        }

        function status(widgetId: string): string {
            if (!widgetId)
                return "ERROR: No widget ID specified";

            if (!BarWidgetService.hasWidget(widgetId))
                return `WIDGET_NOT_FOUND: ${widgetId}`;

            const widget = BarWidgetService.getWidgetOnFocusedScreen(widgetId);
            if (!widget)
                return `WIDGET_NOT_AVAILABLE: ${widgetId}`;

            if (widget.popoutTarget?.shouldBeVisible)
                return "visible";
            return "hidden";
        }

        target: "widget"
    }

    IpcHandler {
        function reload(pluginId: string): string {
            if (!pluginId)
                return "ERROR: No plugin ID specified";

            if (!PluginService.availablePlugins[pluginId])
                return `PLUGIN_NOT_FOUND: ${pluginId}`;

            if (!PluginService.isPluginLoaded(pluginId))
                return `PLUGIN_NOT_LOADED: ${pluginId}`;

            const success = PluginService.reloadPlugin(pluginId);
            return success ? `PLUGIN_RELOAD_SUCCESS: ${pluginId}` : `PLUGIN_RELOAD_FAILED: ${pluginId}`;
        }

        function enable(pluginId: string): string {
            if (!pluginId)
                return "ERROR: No plugin ID specified";

            if (!PluginService.availablePlugins[pluginId])
                return `PLUGIN_NOT_FOUND: ${pluginId}`;

            const success = PluginService.enablePlugin(pluginId);
            return success ? `PLUGIN_ENABLE_SUCCESS: ${pluginId}` : `PLUGIN_ENABLE_FAILED: ${pluginId}`;
        }

        function disable(pluginId: string): string {
            if (!pluginId)
                return "ERROR: No plugin ID specified";

            if (!PluginService.availablePlugins[pluginId])
                return `PLUGIN_NOT_FOUND: ${pluginId}`;

            const success = PluginService.disablePlugin(pluginId);
            return success ? `PLUGIN_DISABLE_SUCCESS: ${pluginId}` : `PLUGIN_DISABLE_FAILED: ${pluginId}`;
        }

        function list(): string {
            const plugins = PluginService.getAvailablePlugins();
            if (plugins.length === 0)
                return "No plugins available";
            return plugins.map(p => `${p.id} [${p.loaded ? "loaded" : "disabled"}]`).join("\n");
        }

        function status(pluginId: string): string {
            if (!pluginId)
                return "ERROR: No plugin ID specified";

            if (!PluginService.availablePlugins[pluginId])
                return `PLUGIN_NOT_FOUND: ${pluginId}`;

            return PluginService.isPluginLoaded(pluginId) ? "loaded" : "disabled";
        }

        target: "plugins"
    }
}
