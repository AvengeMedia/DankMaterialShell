import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.Modules.Plugins
import qs.Modules.SurfaceWidgets
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var oldRegistration: null
    property var oldItem: null
    property var replacement: null
    property var oldKey: ""
    property int calls: 0
    property var lastAnchor: null

    function check(condition, label) {
        if (!condition)
            throw new Error(label);
    }
    function target(barId, section, occurrenceId) {
        return {
            screenName: Quickshell.screens[0].name,
            barId,
            section,
            occurrenceId,
            kind: "bar"
        };
    }
    function config(id, position, autoHide) {
        return {
            id,
            enabled: true,
            visible: true,
            position,
            autoHide,
            spacing: 4,
            innerPadding: 4,
            leftWidgets: ["clock", "clock", "fixture", "fixture"],
            centerWidgets: ["clock", "fixture"],
            rightWidgets: ["clock", "fixture"]
        };
    }
    Component {
        id: plugin
        PluginComponent {
            horizontalBarPill: Component {
                Rectangle {
                    width: 32
                    height: 28
                }
            }
            verticalBarPill: Component {
                Rectangle {
                    width: 28
                    height: 32
                }
            }
            pillClickAction: (x, y, width, section, screen) => {
                root.calls++;
                root.lastAnchor = {
                    x,
                    y,
                    width,
                    section,
                    screen: screen.name
                };
            }
        }
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
    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }
    Timer {
        interval: 0
        running: SettingsData._hasLoaded && SessionData._hasLoaded
        onTriggered: {
            PluginService.availablePlugins = {
                fixture: {
                    id: "fixture"
                }
            };
            PluginService.pluginWidgetComponents = {
                fixture: plugin
            };
            SettingsData.barConfigs = [config("z", 0, false), config("a", 1, true)];
            checks.start();
        }
    }

    Timer {
        id: checks
        interval: 25
        repeat: true
        property int step: 0
        property int waited: 0
        property string waitingFor: ""

        function advance() {
            step++;
            waited = 0;
            waitingFor = "";
        }

        onTriggered: {
            try {
                const screen = Quickshell.screens[0];
                const entries = Object.values(BarWidgetService.widgetRegistry);
                if (++waited > 120)
                    throw new Error("timed out in step " + step + (waitingFor ? " waiting for " + waitingFor : ""));
                switch (step) {
                case 0:
                    if (entries.length < 16)
                        return;
                    root.check(entries.length === 16, "all built-in/plugin duplicates registered");
                    root.check(BarWidgetService.getWidget("clock", screen.name) === BarWidgetService.getWidgetInstance("clock", root.target("z", "left", "clock_0")), "legacy config/section order");
                    for (const entry of entries.filter(entry => entry.widgetId === "fixture")) {
                        entry.item.triggerPopout();
                        root.check(root.lastAnchor.section === entry.context.section && root.lastAnchor.screen === screen.name, "plugin action origin");
                        const expected = entry.context.surface.popupAnchor(entry.item, entry.context.section);
                        root.check(Math.abs(root.lastAnchor.y - expected.trigger.y) < 1, "plugin action edge");
                    }
                    root.check(root.calls === 8, "every duplicate plugin action");
                    root.check(!BarWidgetService.triggerWidgetPopout("fixture", root.target("missing", "left", "fixture_2")), "explicit bar miss");
                    root.check(BarWidgetService.triggerWidgetPopout("fixture", root.target("a", "left", "fixture_2")), "hidden bar routing");
                    root.check(BarWidgetService.getBarWindowForScreen(screen.name, "a").barRevealed, "originating hidden bar reveals");
                    root.oldRegistration = BarWidgetService.resolveWidget("clock", root.target("z", "left", "clock_0"));
                    root.oldItem = root.oldRegistration.item;
                    root.oldKey = root.oldRegistration.key;
                    root.replacement = BarWidgetService.registerWidget("clock", screen.name, root.oldItem, root.oldRegistration.instanceId, root.oldRegistration.context);
                    BarWidgetService.releaseWidget(root.oldRegistration);
                    root.check(BarWidgetService.widgetRegistry[root.oldKey] === root.replacement, "same-object stale token cannot release replacement");
                    SettingsData.barConfigs = SettingsData.barConfigs.map(config => config.id !== "z" ? config : Object.assign({}, config, {
                            leftWidgets: ["fixture", "clock", "fixture", "clock"]
                        }));
                    advance();
                    break;
                case 1:
                    waitingFor = "the reorder to register clock_3 and release clock_0";
                    if (!BarWidgetService.getWidgetInstance("clock", root.target("z", "left", "clock_3")))
                        return;
                    if (BarWidgetService.getWidgetInstance("clock", root.target("z", "left", "clock_0")))
                        return;
                    BarWidgetService.releaseWidget(root.replacement);
                    root.check(BarWidgetService.getWidgetInstance("clock", root.target("z", "left", "clock_1")) !== null, "stale teardown preserves reordered sibling");
                    const legacy = BarWidgetService.registerWidget("legacy", screen.name, root);
                    root.check(BarWidgetService.getWidget("legacy", screen.name) === root, "three-argument plugin registration");
                    BarWidgetService.unregisterWidget("legacy", screen.name, root);
                    root.check(!BarWidgetService.hasWidget("legacy"), "legacy owner release");
                    SettingsData.barConfigs = [root.config("a", 2, false)];
                    advance();
                    break;
                case 2:
                    if (entries.length === 0 || entries.some(entry => entry.context.barId !== "a"))
                        return;
                    root.check(!BarWidgetService.getWidgetInstance("fixture", root.target("z", "left", "fixture_0")), "deleted bar is ineligible");
                    root.check(Object.values(BarWidgetService.widgetRegistry).every(entry => entry.context.barId === "a"), "deleted hosts release registrations");
                    for (const entry of Object.values(BarWidgetService.widgetRegistry).filter(entry => entry.widgetId === "fixture")) {
                        entry.item.triggerPopout();
                        root.check(root.lastAnchor.x > 0 && root.lastAnchor.x < screen.width / 2, "vertical plugin origin");
                    }
                    SettingsData.barConfigs = [];
                    advance();
                    break;
                case 3:
                    if (entries.length !== 0)
                        return;
                    root.check(Object.keys(BarWidgetService.widgetRegistry).length === 0, "all hosts released");
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
