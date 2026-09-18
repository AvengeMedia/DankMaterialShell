import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Settings
import qs.Modules.Settings.DesktopWidgetSettings as DWS
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    readonly property var instance: SettingsData.desktopWidgetInstances.find(i => i.id === "inst1") ?? null

    Component {
        id: cardComponent
        DesktopWidgetInstanceCard {}
    }
    Component {
        id: groupSectionComponent
        DesktopWidgetGroupSection {}
    }
    TestCase {
        id: input
        when: false
        name: "desktop-widget-settings"
    }

    Item {
        width: 600
        height: 3000

        DWS.ClockSettings {
            id: clock
            instanceId: "inst1"
            instanceData: root.instance
        }
        DWS.SystemMonitorSettings {
            id: sysmon
            y: 800
            instanceId: "inst1"
            instanceData: root.instance
        }
        DWS.PluginDesktopWidgetSettings {
            id: plugin
            y: 2000
            instanceId: "inst1"
            instanceData: root.instance
            widgetType: "somePlugin"
        }
        DWS.PluginDesktopWidgetSettings {
            id: pluginOwn
            y: 2500
            instanceId: "inst1"
            instanceData: root.instance
            widgetType: "somePlugin"
            widgetDef: ({
                    settingsComponent: "ClockSettings.qml"
                })
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.set("desktopWidgetInstances", [
            {
                id: "inst1",
                widgetType: "desktopClock",
                config: {
                    graphInterval: 600,
                    showTopProcesses: true,
                    topProcessCount: 10
                }
            }
        ]);
        SessionData.updateDesktopWidgetInstancePosition("inst1", "DP-1", {
            x: 10,
            y: 20,
            width: 300,
            height: 200
        });
        SessionData.updateDesktopWidgetInstancePosition("inst1", "_synced", {
            x: 0.1,
            y: 0.2,
            width: 300,
            height: 200
        });
    }

    function check(value, message) {
        if (!value)
            throw new Error(message);
    }

    function find(item, predicate) {
        if (predicate(item))
            return item;
        for (const child of item.children ?? []) {
            const found = find(child, predicate);
            if (found)
                return found;
        }
        return null;
    }

    function rowVisible(host, label) {
        for (const child of host.children) {
            if (child === host.children[0])
                continue;
            if (find(child, c => c.text === label))
                return child.visible;
        }
        return false;
    }

    function press(host, label) {
        const button = find(host, c => c.text === label && typeof c.clicked !== "undefined");
        root.check(button !== null, "button " + label + " exists");
        button.clicked();
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            try {
                root.check(cardComponent.status === Component.Ready, "DesktopWidgetInstanceCard compiles: " + cardComponent.errorString());
                root.check(groupSectionComponent.status === Component.Ready, "DesktopWidgetGroupSection compiles: " + groupSectionComponent.errorString());
                root.check(root.instance !== null, "fixture instance exists");

                clock.updateConfig("showDate", false);
                root.check(root.instance.config.showDate === false, "updateConfig writes into the instance config");
                root.check(root.instance.config.graphInterval === 600, "updateConfig merges instead of replacing");

                root.check(root.rowVisible(clock, "Opacity") && root.rowVisible(clock, "Reset Position"), "clock shows appearance and placement rows");
                root.check(root.rowVisible(sysmon, "Opacity") && root.rowVisible(sysmon, "Reset Size"), "system monitor shows appearance and placement rows");
                root.check(!root.rowVisible(plugin, "Opacity") && root.rowVisible(plugin, "Reset Position"), "plugin without own settings hides appearance, keeps placement");
                input.wait(100);
                root.check(!root.rowVisible(pluginOwn, "Opacity") && !root.rowVisible(pluginOwn, "Reset Position"), "plugin with own settings hides the shared tail");
                root.check(root.find(pluginOwn, c => c.text === "Clock style") !== null, "plugin settings component loads");

                root.check(root.find(sysmon, c => c.text === "Graph time range").currentIndex === 2, "graph interval maps to its button index");
                root.check(root.find(sysmon, c => c.text === "Process count").currentIndex === 2, "process count maps to its button index");
                const sortRow = root.find(sysmon, c => c.text === "Sort by");
                sortRow.selectionChanged(1, true);
                root.check(root.instance.config.topProcessSortBy === "memory", "sort selection writes memory");
                sortRow.selectionChanged(0, false);
                root.check(root.instance.config.topProcessSortBy === "memory", "deselection is ignored");

                root.press(clock, "Reset Position");
                let stored = SessionData.desktopWidgetInstancePositions.inst1;
                root.check(stored["DP-1"].x === undefined && stored["DP-1"].y === undefined && stored["DP-1"].width === 300, "reset position clears x/y and keeps size");
                root.check(stored["_synced"].x === undefined && stored["_synced"].width === 300, "reset position also clears the synced entry");
                root.press(clock, "Reset Size");
                stored = SessionData.desktopWidgetInstancePositions.inst1;
                root.check(stored["DP-1"].width === undefined && stored["DP-1"].height === undefined, "reset size clears width/height");
                SessionData.resetDesktopWidgetInstanceGeometry("missing", ["x"]);
                root.check(SessionData.desktopWidgetInstancePositions.missing === undefined, "reset on an unknown instance is a no-op");

                console.log("FIXTURE_PASS desktop widget settings: compile, shared tail gating, button group mapping, geometry reset");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
