import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.Modules.DankIsland
import qs.Modules.Frame
import qs.Modules.Dock
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var cases: []
    property int caseIndex: -1
    property string rowsBeforeExpansion: ""
    property bool captureBaseline: Quickshell.env("DMS_FIXTURE_BASELINE") === "1"

    function config(id, position, island) {
        return {
            id,
            enabled: true,
            visible: true,
            position,
            island,
            spacing: 4,
            innerPadding: 4,
            leftWidgets: ["clock"],
            centerWidgets: [],
            rightWidgets: [],
            islandReserveThickness: 40,
            islandCompactThickness: 38,
            islandOuterGap: 4,
            islandShowSatellites: false
        };
    }
    function check(condition, message) {
        if (!condition)
            throw new Error(message);
    }
    function advance() {
        caseIndex++;
        if (caseIndex < cases.length) {
            applyCase();
            capture.restart();
            return;
        }
        console.log("FIXTURE_PASS");
        Qt.quit();
    }
    IpcHandler {
        target: "probe"
        function next() {
            root.advance();
        }
    }
    FloatingWindow {
        visible: Quickshell.env("DMS_FIXTURE_CAPTURE") === "1"
        title: "reservation probe"
        color: "#162128"
        implicitWidth: 400
        implicitHeight: 300
    }
    function applyCase() {
        const scenario = cases[caseIndex];
        SettingsData.frameEnabled = scenario.mode !== "off";
        SettingsData.frameMode = scenario.mode === "off" ? "separate" : scenario.mode;
        SettingsData.barConfigs = scenario.configs;
        Qt.callLater(() => {
            FrameTransitionState.acknowledge(FrameTransitionState.revision);
            FrameTransitionState.syncEffective();
            NiriService._layoutAppliedRevision = NiriService._frameTransitionRevision;
        });
    }
    Item {
        Repeater {
            model: ScriptModel {
                values: SettingsData.barConfigs
                objectProp: "id"
            }
            delegate: DankBar {
                required property var modelData
                barConfig: modelData
            }
        }
    }
    DankIsland {
        id: islands
    }
    Frame {}
    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.frameScreenPreferences = ["all"];
        const next = [];
        for (const mode of ["off", "separate", "connected"])
            for (let edge = 0; edge < 4; edge++)
                for (let count = 1; count <= 4; count++)
                    next.push({
                        mode,
                        edge,
                        configs: ["z", "a", "m", "b"].slice(0, count).map((id, index) => config(id, edge, index % 2 === 1))
                    });
        next.push({
            mode: "off",
            edge: 0,
            configs: [config("top", 0, false), config("bottom", 1, true), config("left", 2, false), config("right", 3, true)]
        });
        for (const mode of ["off", "separate", "connected"])
            for (let edge = 0; edge < 4; edge++)
                for (const allIslands of [false, true])
                    next.push({
                        mode,
                        edge,
                        expand: allIslands,
                        configs: ["outer", "inner"].map(id => config(id, edge, allIslands))
                    });
        for (let edge = 0; edge < 4; edge++) {
            const outer = Object.assign(config("hidden", edge, false), {
                autoHide: true,
                gothCornersEnabled: true
            });
            const floating = Object.assign(config("floating", edge, true), {
                islandFloating: true,
                islandShowSatellites: true
            });
            const fixed = config("fixed", edge, false);
            next.push({
                mode: "off",
                edge,
                expand: true,
                configs: [outer, floating, fixed]
            });
            next.push({
                mode: "off",
                edge,
                configs: [fixed, floating, outer]
            });
            next.push({
                mode: "connected",
                edge,
                configs: [Object.assign(config("overlay", edge, false), {
                        useOverlayLayer: true
                    }), config("island", edge, true), config("frame", (edge + 2) % 4, false)]
            });
        }
        for (const mode of ["off", "separate", "connected"]) {
            for (let edge = 0; edge < 4; edge++)
                next.push({
                    mode,
                    edge,
                    configs: [config("single-island", edge, true)]
                });
            next.push({
                mode,
                edge: 0,
                configs: [0, 1, 2, 3].map(edge => config("bar-" + edge, edge, false))
            });
        }
        cases = Quickshell.env("DMS_FIXTURE_CORNERS") === "1" ? next.slice(73) : next;
        caseIndex = 0;
        applyCase();
    }
    Timer {
        id: capture
        interval: 600
        repeat: true
        running: true
        onTriggered: {
            try {
                const screen = Quickshell.screens[0];
                const layout = ShellLayout.forScreen(screen);
                const scenario = root.cases[root.caseIndex];
                const hosted = Object.values(BarWidgetService.frameHostedBars[screen.name] ?? {});
                const bars = Object.values(BarWidgetService.dankBarItems).reduce((result, bar) => result.concat(bar.barVariants.instances || []), []);
                const islandHosts = bars.filter(bar => bar.barConfig?.island === true);
                const snapshot = {
                    mode: scenario.mode,
                    edge: scenario.edge,
                    count: scenario.configs.length,
                    caseIndex: root.caseIndex,
                    manual: layout.manualPlacement,
                    screen: {
                        width: screen.width,
                        height: screen.height,
                        scale: CompositorService.getScreenScale(screen)
                    },
                    reservations: Object.keys(layout.edges).reduce((result, edge) => {
                        result[edge] = layout.edges[edge].reservation;
                        return result;
                    }, {}),
                    instances: layout.instances,
                    bars: bars.map(bar => ({
                                id: bar.barConfig.id,
                                width: bar.width,
                                height: bar.height,
                                exclusiveZone: bar.exclusiveZone,
                                margins: {
                                    top: bar.margins.top,
                                    bottom: bar.margins.bottom,
                                    left: bar.margins.left,
                                    right: bar.margins.right
                                }
                            })),
                    hosted: hosted.map(bar => ({
                                id: bar.barConfig.id,
                                x: bar.parent.x,
                                y: bar.parent.y,
                                width: bar.width,
                                height: bar.height
                            })),
                    islands: islandHosts.map(host => ({
                                id: host.barConfig.id,
                                width: host.width,
                                height: host.height,
                                exclusiveZone: host.exclusiveZone
                            }))
                };
                console.log("LAYOUT_SNAPSHOT", JSON.stringify(snapshot));
                if (!root.captureBaseline) {
                    root.check(layout.instances.length === scenario.configs.length, "every assigned config once");
                    root.check(bars.length + hosted.length === scenario.configs.length, "every assigned host once");
                    root.check(islands.hosts().filter(host => host.islandController).length === islandHosts.length, "every island window reaches the island router");
                    for (const instance of layout.instances) {
                        root.check(instance.rowOffset >= 0 && instance.rowThickness > 0, "valid row geometry");
                        const prior = layout.instances.filter(other => other.edge === instance.edge && other.configOrder < instance.configOrder);
                        root.check(Math.abs(instance.rowOffset - layout.instances.find(other => other.edge === instance.edge).rowOffset - prior.reduce((sum, other) => sum + other.rowThickness, 0)) < 1, "config order row placement");
                    }
                }
                if (scenario.expand && !scenario.expanded) {
                    scenario.expanded = true;
                    root.rowsBeforeExpansion = JSON.stringify(layout.instances);
                    for (const host of islandHosts)
                        islands.openActivity("home", screen, "", host.barConfig.id);
                    for (const config of scenario.configs.filter(config => config.autoHide))
                        SettingsData.setBarIpcReveal(config.id, true);
                    return;
                }
                if (scenario.expand)
                    root.check(JSON.stringify(layout.instances) === root.rowsBeforeExpansion, "expansion and reveal retain row geometry");
                if (Quickshell.env("DMS_FIXTURE_CAPTURE") === "1") {
                    stop();
                    console.log("CAPTURE_READY");
                    return;
                }
                root.advance();
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
                stop();
                Qt.quit();
            }
        }
    }
}
