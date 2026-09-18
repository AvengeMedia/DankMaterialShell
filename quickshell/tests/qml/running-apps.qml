import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar.Widgets
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property bool failed: false

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function finish() {
        console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
    }

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
    property var cases: [
        {
            name: "compact",
            data: {
                runningAppsCurrentWorkspace: false
            }
        },
        {
            name: "compact-grouped",
            data: {
                runningAppsCurrentWorkspace: false,
                runningAppsGroupByApp: true
            }
        },
        {
            name: "full",
            data: {
                runningAppsCurrentWorkspace: false,
                runningAppsCompactMode: false
            }
        },
        {
            name: "full-grouped",
            data: {
                runningAppsCurrentWorkspace: false,
                runningAppsCompactMode: false,
                runningAppsGroupByApp: true
            }
        }
    ]
    property var phases: [
        {
            name: "firefox-active",
            active: "0x1"
        },
        {
            name: "kitty-active",
            active: "0x3"
        },
        {
            name: "none-active",
            active: ""
        }
    ]
    property var instances: []
    property int phase: 0

    Component {
        id: runningApps
        RunningApps {}
    }

    Item {
        id: stage
        width: 900
        height: 900
    }

    function toplevels(activeAddress) {
        const rows = [
            {
                address: "0x1",
                appId: "firefox",
                title: "Mozilla Firefox",
                minimized: false
            },
            {
                address: "0x2",
                appId: "firefox",
                title: "Downloads",
                minimized: false
            },
            {
                address: "0x3",
                appId: "kitty",
                title: "zsh",
                minimized: true
            },
            {
                address: "0x4",
                appId: "",
                title: "",
                minimized: false
            }
        ];
        return rows.map(row => Object.assign({
                activated: row.address === activeAddress
            }, row));
    }

    function applyPhase(p) {
        CompositorService.compositor = "unknown";
        CompositorService.sortedToplevels = toplevels(p.active);
    }

    function delegates(item, out) {
        if (item.isFocused !== undefined && item.windowCount !== undefined)
            out.push(item);
        for (const child of item.children || [])
            delegates(child, out);
        return out;
    }

    property var baselineSizes: ({})

    function snapshot() {
        const phase = root.phases[root.phase];
        for (const instance of root.instances) {
            const item = instance.item;
            const label = phase.name + " " + instance.name + (instance.vertical ? " vertical" : " horizontal");
            const grouped = instance.name.endsWith("grouped");
            const rows = delegates(item.visualContent, []);
            const tooltips = rows.map(row => row.tooltipText);
            check(item.visible && item.windowCount === (grouped ? 3 : 4), label + " window count " + item.windowCount);
            check(rows.length === item.windowCount, label + " renders one delegate per window, got " + rows.length);
            check(tooltips.includes("kitty • zsh"), label + " shows the kitty window");
            if (grouped)
                check(rows.some(row => row.tooltipText === "Firefox (2 windows)" && row.windowCount === 2), label + " groups the two firefox windows, got " + JSON.stringify(tooltips));
            else
                check(tooltips.includes("Firefox • Mozilla Firefox") && tooltips.includes("Firefox • Downloads"), label + " lists both firefox windows, got " + JSON.stringify(tooltips));
            const focused = rows.filter(row => row.isFocused).map(row => row.tooltipText);
            switch (phase.active) {
            case "0x1":
                check(focused.length === 1 && focused[0].startsWith("Firefox"), label + " focuses firefox, got " + JSON.stringify(focused));
                break;
            case "0x3":
                check(JSON.stringify(focused) === JSON.stringify(["kitty • zsh"]), label + " focuses kitty, got " + JSON.stringify(focused));
                break;
            default:
                check(focused.length === 0, label + " has no focused window, got " + JSON.stringify(focused));
            }
            const key = instance.name + (instance.vertical ? "/v" : "/h");
            const size = instance.vertical ? item.height : item.width;
            check(size > 0, label + " has extent along the bar");
            if (root.baselineSizes[key] === undefined)
                root.baselineSizes[key] = size;
            else
                check(root.baselineSizes[key] === size, label + " keeps its size across focus changes, " + root.baselineSizes[key] + " vs " + size);
        }
        if (root.phase === 0) {
            const width = name => root.instances.find(instance => instance.name === name && !instance.vertical).item.width;
            check(width("full") > width("compact") && width("full-grouped") > width("compact-grouped"), "full mode is wider than compact");
            check(width("compact-grouped") < width("compact"), "grouping shrinks the widget");
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        applyPhase(root.phases[0]);
        const created = [];
        let y = 0;
        for (const axis of root.axes) {
            for (const testCase of root.cases) {
                const item = runningApps.createObject(stage, {
                    axis: axis,
                    barThickness: 48,
                    widgetThickness: 30,
                    barSpacing: 4,
                    barConfig: root.barConfig,
                    widgetData: testCase.data,
                    y: y
                });
                y += 220;
                created.push({
                    name: testCase.name,
                    vertical: axis.isVertical,
                    item: item
                });
            }
        }
        root.instances = created;
    }

    Timer {
        interval: 1200
        running: true
        repeat: true
        property bool armed: false
        onTriggered: {
            if (!armed) {
                armed = true;
                root.applyPhase(root.phases[0]);
                return;
            }
            root.snapshot();
            root.phase++;
            if (root.phase >= root.phases.length) {
                root.finish();
                stop();
                Qt.quit();
                return;
            }
            root.applyPhase(root.phases[root.phase]);
        }
    }
}
