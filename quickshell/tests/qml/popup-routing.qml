import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankBar
import qs.Modules.Plugins
import qs.DankCommon.Common as DC

ShellRoot {
    id: root
    property var firstPopout: null
    property var replacement: null
    function check(condition, message) {
        if (!condition)
            throw new Error(message);
    }
    function target(barId, occurrenceId) {
        return {
            screenName: Quickshell.screens[0].name,
            barId,
            section: "left",
            occurrenceId
        };
    }
    Component {
        id: plugin
        PluginComponent {
            horizontalBarPill: Component {
                Rectangle {
                    width: 28
                    height: 28
                    color: Theme.primary
                }
            }
            verticalBarPill: horizontalBarPill
            popoutWidth: 180
            popoutHeight: 120
            popoutContent: Component {
                Rectangle {
                    implicitWidth: 140
                    implicitHeight: 80
                    color: Theme.primaryContainer
                }
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
        Loader {
            id: dashLoader
            active: false
            sourceComponent: DankPopout {
                property var triggerScreen: null
                property string requestedTab: ""
                function requestTab(tab) {
                    requestedTab = tab;
                }
                popupWidth: 180
                popupHeight: 120
                content: Component {
                    Rectangle {
                        implicitWidth: 140
                        implicitHeight: 80
                        color: Theme.primaryContainer
                    }
                }
            }
        }
    }
    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        PluginService.availablePlugins = {
            fixture: {
                id: "fixture"
            }
        };
        PluginService.pluginWidgetComponents = {
            fixture: plugin
        };
        PopoutService.dankDashPopoutLoader = dashLoader;
        SettingsData.barConfigs = ["z", "a"].map(id => ({
                    id,
                    enabled: true,
                    visible: true,
                    position: 0,
                    spacing: 4,
                    innerPadding: 4,
                    leftWidgets: ["fixture", "clock"],
                    centerWidgets: [],
                    rightWidgets: []
                }));
    }
    Timer {
        interval: 500
        running: true
        repeat: true
        property int step: 0
        onTriggered: {
            try {
                const screen = Quickshell.screens[0];
                const active = PopoutManager.currentPopoutsByScreen[screen.name];
                switch (step++) {
                case 0:
                    BarWidgetService.triggerWidgetPopout("fixture", root.target("z", "fixture_0"));
                    break;
                case 1:
                    root.check(active?.shouldBeVisible && active.sourceRegistration.context.barId === "z", "first plugin popup origin");
                    root.firstPopout = active;
                    BarWidgetService.triggerWidgetPopout("fixture", root.target("a", "fixture_0"));
                    break;
                case 2:
                    root.check(active?.shouldBeVisible && active !== root.firstPopout && !root.firstPopout.shouldBeVisible, "plugin popup concurrency");
                    root.check(active.sourceRegistration.context.barId === "a" && active.triggerY >= ShellLayout.forConfig(screen, "a").rowOffset, "second plugin row anchor");
                    BarWidgetService.triggerWidgetPopout("fixture", root.target("a", "fixture_0"));
                    break;
                case 3:
                    root.check(!active?.shouldBeVisible, "same plugin toggles closed");
                    BarWidgetService.triggerWidgetPopout("clock", root.target("z", "clock_1"));
                    break;
                case 4:
                    root.check(active?.shouldBeVisible && active.sourceRegistration.context.barId === "z" && active.requestedTab === "overview", "built-in factory popup origin");
                    BarWidgetService.triggerWidgetPopout("clock", root.target("a", "clock_1"));
                    break;
                case 5:
                    root.check(active?.shouldBeVisible && active.sourceRegistration.context.barId === "a", "shared built-in popup retargets exactly");
                    root.firstPopout = active;
                    const old = active.sourceRegistration;
                    root.replacement = BarWidgetService.registerWidget(old.widgetId, old.screenName, old.item, old.instanceId, old.context);
                    break;
                case 6:
                    root.check(!root.firstPopout.shouldBeVisible, "stale popup registration closes");
                    BarWidgetService.releaseWidget(root.replacement);
                    SettingsData.barConfigs = [];
                    break;
                case 7:
                    root.check(!PopoutManager.currentPopoutsByScreen[screen.name]?.shouldBeVisible, "popup teardown clears manager");
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
