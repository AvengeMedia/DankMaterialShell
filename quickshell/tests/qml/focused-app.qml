import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar.Widgets
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var browser: ({
            appId: "firefox",
            title: "Mozilla Firefox",
            pid: 7
        })
    property var barConfig: ({
            widgetPadding: 12,
            fontScale: 1,
            iconScale: 1,
            spacing: 4
        })
    property var axes: [
        {
            isVertical: false,
            edge: "top"
        },
        {
            isVertical: true,
            edge: "left"
        }
    ]
    property var instances: []
    property int step: 0

    function stateFor(index) {
        const here = Quickshell.screens[0].name;
        const workspaces = [
            {
                id: 1,
                idx: 1,
                name: null,
                output: here,
                is_active: true,
                is_focused: true
            },
            {
                id: 2,
                idx: 1,
                name: null,
                output: "OTHER",
                is_active: true,
                is_focused: false
            }
        ];
        const window = workspaceId => ({
                    id: 1,
                    pid: 100,
                    app_id: "firefox",
                    title: "Mozilla Firefox",
                    workspace_id: workspaceId,
                    is_focused: true,
                    is_floating: false,
                    layout: {
                        tile_pos_in_workspace_view: [0, 0],
                        window_size: [1280, 800],
                        tile_size: [1280, 800]
                    }
                });
        switch (index) {
        case 0:
            return {
                name: "no-windows",
                workspaces,
                windows: [],
                currentOutput: here,
                expectWindows: false,
                expectAppId: null
            };
        case 1:
            return {
                name: "focused-here",
                workspaces,
                windows: [window(1)],
                currentOutput: here,
                expectWindows: true,
                expectAppId: "firefox"
            };
        case 2:
            return {
                name: "focused-elsewhere",
                workspaces,
                windows: [window(2)],
                currentOutput: "OTHER",
                expectWindows: false,
                expectAppId: null
            };
        case 3:
            return {
                name: "current-output-elsewhere",
                workspaces,
                windows: [window(1)],
                currentOutput: "OTHER",
                expectWindows: true,
                expectAppId: "firefox"
            };
        default:
            return null;
        }
    }

    function applyBackend(state) {
        NiriService.allWorkspaces = state.workspaces;
        NiriService.currentOutput = state.currentOutput;
        NiriService.windows = state.windows;
    }

    function applySorted(state) {
        CompositorService.sortedToplevels = state.windows.map(w => ({
                    niriWindowId: w.id,
                    niriWorkspaceId: w.workspace_id,
                    appId: w.app_id,
                    title: w.title,
                    sourceToplevel: root.browser
                }));
        CompositorService.toplevelsChanged();
    }

    property bool failed: false

    function signature() {
        return root.instances.map(instance => {
            const item = instance.item;
            return [item.hasWindowsOnCurrentWorkspace, item.activeWindow?.appId ?? null, item.visible, item.width > 0 && item.height > 0].join();
        }).join("|");
    }

    function check(state, instance, item) {
        const appId = item.activeWindow?.appId ?? null;
        const shown = item.hasWindowsOnCurrentWorkspace && item.visible && item.width > 0 && item.height > 0;
        if (item.hasWindowsOnCurrentWorkspace === state.expectWindows && appId === state.expectAppId && shown === state.expectWindows)
            return;
        root.failed = true;
        console.log("FIXTURE_FAIL " + state.name + (instance.vertical ? " vertical" : " horizontal") + " expected windows=" + state.expectWindows + " appId=" + state.expectAppId);
    }

    Item {
        id: stage
        width: 900
        height: 400
    }

    Component {
        id: focusedApp
        FocusedApp {}
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        const created = [];
        let y = 0;
        for (const axis of root.axes) {
            const item = focusedApp.createObject(stage, {
                axis: axis,
                parentScreen: Quickshell.screens[0],
                barThickness: 48,
                widgetThickness: 30,
                barSpacing: 4,
                barConfig: root.barConfig,
                widgetData: {},
                y: y
            });
            y += 120;
            created.push({
                vertical: axis.isVertical,
                item: item
            });
        }
        root.instances = created;
    }

    Timer {
        interval: 25
        running: true
        repeat: true
        property int waited: 0
        property int stable: 0
        property string last: ""
        onTriggered: {
            if (CompositorService.compositor !== "niri" || Quickshell.screens.length === 0)
                return;
            const state = root.stateFor(root.step);
            if (!state) {
                console.log(root.failed ? "FIXTURE_FAIL" : "FIXTURE_PASS");
                stop();
                Qt.quit();
                return;
            }
            root.applyBackend(state);
            root.applySorted(state);
            const current = root.signature();
            stable = current === last ? stable + 1 : 0;
            last = current;
            if (++waited > 200) {
                root.failed = true;
                console.log("FIXTURE_FAIL " + state.name + " never settled, signature " + current);
                stop();
                Qt.quit();
                return;
            }
            if (stable < 4)
                return;
            for (const instance of root.instances)
                root.check(state, instance, instance.item);
            waited = 0;
            stable = 0;
            last = "";
            root.step++;
        }
    }
}
