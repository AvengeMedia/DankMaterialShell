import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Dock
import qs.Modules.Frame
import qs.DankCommon.Common as DC
import "Common/settings/DockConfig.js" as DockConfig

ShellRoot {
    id: root
    property var retainedBody: null
    property var retainedModel: null
    property var lease: null
    property string retractOwner: ""
    property int activations: 0

    function check(condition, message) {
        if (!condition)
            throw new Error(message);
    }
    function find(item, predicate) {
        if (!item)
            return null;
        if (predicate(item))
            return item;
        for (const child of item.children || []) {
            const found = find(child, predicate);
            if (found)
                return found;
        }
        return null;
    }
    function body() {
        return BarWidgetService.resolveWidget("attached", {
            kind: "dock"
        })?.context.surface.host ?? docks.instances[0]?.body;
    }
    function strip() {
        return find(body(), item => typeof item.movePinnedApp === "function");
    }
    QtObject {
        id: first
        property string appId: "browser"
        property string title: "first"
        property int niriWindowId: 11
        property bool activated: true
        property bool minimized: false
        property var screens: Quickshell.screens
        function activate() {
            root.activations++;
        }
    }
    QtObject {
        id: second
        property string appId: "browser"
        property string title: "second"
        property int niriWindowId: 12
        property bool activated: false
        property bool minimized: false
        property var screens: Quickshell.screens
        function activate() {
            root.activations++;
        }
    }
    Component {
        id: leaseComponent
        ConnectedSurfaceLease {
            claimPrefix: "fixture"
            slot: "modal"
            retractsDock: true
            isCurrentOwner: name => true
        }
    }
    DockContextMenu {
        id: menu
    }
    Dock {
        id: docks
        contextMenu: menu
    }
    Frame {}
    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        const attached = Qt.createComponent("PLUGINS/AttachedPanelExample/AttachedPanelExample.qml");
        check(attached.status === Component.Ready, attached.errorString());
        PluginService.availablePlugins = {
            attached: {
                id: "attached"
            }
        };
        PluginService.pluginWidgetComponents = {
            attached
        };
        const config = DockConfig.create("fixture", "fixture");
        config.enabled = true;
        config.widgetExpansion = "inline";
        config.groupByApp = true;
        config.maxVisibleApps = 1;
        config.widgets.push({
            id: "attached_a",
            widgetId: "attached"
        }, {
            id: "attached_b",
            widgetId: "attached"
        });
        BarWidgetService.dockContextMenu = menu;
        SettingsData.barConfigs = [];
        SettingsData.frameScreenPreferences = ["all"];
        SettingsData.dockConfigs = [config];
        SessionData.setDockPins("fixture", ["browser", "missing"]);
        SessionData.setBarPinnedApps(["other"]);
    }
    Timer {
        interval: 600
        repeat: true
        running: true
        property int step: 0
        onTriggered: {
            try {
                const screen = Quickshell.screens[0];
                const body = root.body();
                const strip = root.strip();
                switch (step++) {
                case 0:
                    root.check(body && strip, "dock and shared model loaded");
                    const from = strip.items.findIndex(item => item.isPinned && item.appId === "browser");
                    const to = strip.items.findIndex(item => item.isPinned && item.appId === "missing");
                    strip.movePinnedApp(from, to);
                    root.check(SessionData.getDockPins("fixture").join() === "missing,browser", "runtime pin reorder uses the originating dock store");
                    SessionData.setDockPins("fixture", ["browser", "missing"]);
                    CompositorService.sortedToplevels = [first, second];
                    break;
                case 1:
                    root.check(strip.items.find(item => item.appId === "browser").windowCount === 2, "grouped windows");
                    root.check(strip.overflowItemCount === 1, "pinned overflow");
                    root.check(SessionData.barPinnedApps.join() === "other", "separate bar pins");
                    const button = root.find(body, item => item.appData?.appId === "browser" && typeof item.activate === "function");
                    root.check(button.isWindowFocused, "group focus from model windows");
                    button.activate();
                    root.check(root.activations === 1, "group activation");
                    strip.contextMenu.showForButton(button, button.appData, button.height, false, null, screen, strip);
                    root.check(strip.contextMenu.anchorItem === button && strip.contextMenu.surfaceContext.host === body, "menu origin");
                    root.check(strip.contextMenu.anchorPos.y > screen.height / 2, "bottom menu uses screen coordinates");
                    strip.contextMenu.close();
                    const plugin = BarWidgetService.resolveWidget("attached", {
                        occurrenceId: "attached_b"
                    }).item;
                    plugin.triggerPopout();
                    root.check(body.expansionOwner === plugin, "duplicate plugin inline origin");
                    root.retainedBody = body;
                    root.retainedModel = strip.items;
                    SettingsData.updateDockConfig("fixture", {
                        iconSize: 42
                    });
                    break;
                case 2:
                    root.check(body === root.retainedBody, "config edits retain dock body");
                    root.check(strip.items === root.retainedModel, "appearance edit retains model");
                    root.check(body.expansionOwner !== null, "appearance edit retains expansion owner");
                    SettingsData.updateDockConfig("fixture", {
                        widgets: SettingsData.getDockConfig("fixture").widgets.filter(item => item.id !== "attached_b")
                    });
                    strip.draggedIndex = 0;
                    CompositorService.sortedToplevels = [first];
                    break;
                case 3:
                    root.check(body.expansionOwner === null, "removed owner closes expansion");
                    root.check(strip.items.find(item => item.appId === "browser").windowCount === 2, "model held during drag");
                    strip.draggedIndex = -1;
                    break;
                case 4:
                    root.check(strip.items.find(item => item.appId === "browser").windowCount === 1, "model catches up after cancelled drag");
                    first.appId = "editor";
                    break;
                case 5:
                    root.check(strip.items.some(item => item.appId === "editor" && item.isRunning), "native window identity change updates model");
                    const anchor = root.find(body, item => item.appData?.appId === "editor" && typeof item.activate === "function");
                    menu.showForButton(anchor, anchor.appData, anchor.height, false, null, screen, strip);
                    SettingsData.frameEnabled = true;
                    SettingsData.frameMode = "connected";
                    Qt.callLater(() => {
                        FrameTransitionState.acknowledge(FrameTransitionState.revision);
                        FrameTransitionState.syncEffective();
                        NiriService._layoutAppliedRevision = NiriService._frameTransitionRevision;
                    });
                    break;
                case 6:
                    root.check(docks.instances.length === 0 && body, "frame takes over dock host");
                    root.check(!menu.visible && !menu.anchorItem, "menu closes when originating host is replaced");
                    root.check(ConnectedModeState.surfaceOwnerId(screen.name, "dock:fixture") === body.chromeOwnerId, "connected dock claim");
                    ConnectedModeState.claimSurface(screen.name, "dock:fixture", ConnectedModeState.surfaceDescriptor(screen.name, "dock:fixture"), "replacement");
                    body._syncDockChromeState();
                    root.check(ConnectedModeState.surfaceOwnerId(screen.name, "dock:fixture") === "replacement", "stale dock cannot reclaim newer state");
                    ConnectedModeState.releaseSurface(screen.name, "dock:fixture", "replacement");
                    body._syncDockChromeState();
                    root.check(!ConnectedModeState.surfaceOwnerId(screen.name, "dock:fixture"), "superseded dock cannot recover after replacement leaves");
                    root.lease = leaseComponent.createObject(root, {
                        screenName: screen.name,
                        enabled: true,
                        active: true,
                        presented: true,
                        dockBlocked: true,
                        dockSide: "bottom"
                    });
                    root.lease.publish({});
                    root.retractOwner = root.lease.claimId;
                    root.check(ConnectedModeState.dockRetractRequests[root.retractOwner] !== undefined, "retract claim");
                    root.lease.destroy();
                    SettingsData.dockConfigs = [];
                    break;
                case 7:
                    root.check(!ConnectedModeState.dockRetractRequests[root.retractOwner], "teardown releases retract claim");
                    root.check(!ConnectedModeState.surfaceOwnerId(screen.name, "dock:fixture"), "teardown releases connected dock state");
                    root.check(Object.keys(BarWidgetService.widgetRegistry).length === 0, "dock teardown releases widgets");
                    console.log("FIXTURE_PASS");
                    stop();
                    Qt.quit();
                }
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
                stop();
                Qt.quit();
            }
        }
    }
}
