import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.Modules.Dock
import qs.Modules.Plugins
import qs.DankCommon.Common as DC
import "Common/settings/DockConfig.js" as DockConfig

ShellRoot {
    id: root
    property bool animate: false
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
            attachedContent: Component {
                Rectangle {
                    implicitWidth: 320
                    implicitHeight: 280
                    color: Theme.surfaceContainer
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
    }
    Dock {}
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
        SettingsData.barConfigs = ["a", "b"].map(id => ({
                    id,
                    enabled: true,
                    visible: true,
                    position: 0,
                    spacing: 4,
                    innerPadding: 4,
                    leftWidgets: [],
                    centerWidgets: ["clock"],
                    rightWidgets: []
                }));
        const config = DockConfig.create("dock", "dock");
        config.enabled = true;
        config.widgetExpansion = "inline";
        config.widgets.push({
            id: "fixture",
            widgetId: "fixture"
        });
        SettingsData.dockConfigs = [config];
        SessionData.setDockPins("dock", ["browser", "editor", "terminal", "files"]);
    }
    Timer {
        interval: 1500
        running: true
        onTriggered: console.log("RESOURCE_READY")
    }
    Timer {
        interval: 700
        running: root.animate
        repeat: true
        onTriggered: {
            const widget = BarWidgetService.getWidget("fixture", Quickshell.screens[0].name);
            if (!widget) {
                console.log("FIXTURE_FAIL fixture widget missing during animation");
                return;
            }
            widget.triggerPopout();
        }
    }
    IpcHandler {
        target: "probe"
        function play(): void {
            root.animate = true;
        }
        function stop(): void {
            root.animate = false;
            const widget = BarWidgetService.getWidget("fixture", Quickshell.screens[0].name);
            if (!widget) {
                console.log("FIXTURE_FAIL fixture widget missing at stop");
                return;
            }
            widget.closePopout();
        }
        function done(): void {
            console.log("FIXTURE_PASS");
            Qt.quit();
        }
    }
}
