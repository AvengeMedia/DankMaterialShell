import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.Modules.DankIsland
import qs.DankCommon.Common as DC

ShellRoot {
    id: root
    property int fallbackCalls: 0
    readonly property var hosts: islands.hosts()

    TestCase { id: input; when: false }
    QtObject {
        id: cachedLauncher
        function show() { root.fallbackCalls++; }
        function hide() {}
        function toggle() { root.fallbackCalls++; }
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
    DankIsland { id: islands }

    function check(value, label) {
        if (!value)
            throw new Error(label);
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
            SettingsData.frameEnabled = false;
            SettingsData.reduceMotion = true;
            SettingsData.launcherStyle = "island";
            SettingsData.barConfigs = [
                { id: "edge", island: true, enabled: true, visible: true, position: 0 },
                { id: "dot", dot: true, enabled: true, visible: true, position: 0 },
                { id: "floating", island: true, enabled: true, visible: true, position: 2,
                    islandFloating: true, islandPlacement: "free", islandSharedRouting: "last-used" }
            ];
            PopoutService.dankLauncherV2Modal = cachedLauncher;
        }
    }
    // requestActivity defers activation until the launcher visuals load, so each step polls.
    Timer {
        id: steps

        property int index: 0
        property int waited: 0
        readonly property var order: ["dot", "floating", "dot"]
        readonly property var screen: Quickshell.screens[0]
        readonly property var body: IslandHostRegistry.hostFor(screen.name, order[Math.min(index, order.length - 1)])

        interval: 25
        repeat: true
        running: root.hosts.length === 3 && root.hosts.every(host => host.islandController && (!host.free || (host.width === host.implicitWidth && host.height === host.implicitHeight && host.width > 0)))

        function finish(message) {
            if (message)
                console.error("FIXTURE_FAIL", message);
            else
                console.log("FIXTURE_PASS");
            stop();
            Qt.quit();
        }

        function launcherOpen(controller) {
            return controller.expanded && controller.activeActivity === "launcher";
        }

        onTriggered: {
            if (++waited > 120) {
                finish("timed out at step " + index);
                return;
            }
            const controller = body.islandController;
            try {
                if (index < order.length) {
                    const surface = body.surface;
                    const barId = order[index];
                    if (!controller.expanded && !launcherOpen(controller) && SettingsData.lastUsedBarByScreen[screen.name] !== barId) {
                        input.mouseMove(surface, surface.currentVisualX + surface.currentVisualWidth / 2, surface.currentVisualY + surface.currentVisualHeight / 2, 0);
                        input.mouseClick(surface, surface.currentVisualX + surface.currentVisualWidth / 2, surface.currentVisualY + surface.currentVisualHeight / 2, Qt.LeftButton, Qt.NoModifier, 0);
                        root.check(SettingsData.lastUsedBarByScreen[screen.name] === barId, "click must select " + barId);
                        PopoutService.openDankLauncherV2();
                        root.check(root.fallbackCalls === 0, "cached launcher must not intercept shared shortcuts");
                        return;
                    }
                    if (!launcherOpen(controller))
                        return;
                    PopoutService.toggleDankLauncherV2();
                    root.check(!controller.expanded, "second shortcut collapses the selected launcher in " + barId);
                    SettingsData.lastUsedBarByScreen = {};
                    index++;
                    waited = 0;
                    return;
                }
                if (index === order.length) {
                    SettingsData.frameEnabled = true;
                    input.mouseClick(body.surface, body.surface.currentVisualX + body.surface.currentVisualWidth / 2, body.surface.currentVisualY + body.surface.currentVisualHeight / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    PopoutService.openDankLauncherV2();
                    root.check(root.fallbackCalls === 0, "frame mode does not steal shared shortcuts");
                    index++;
                    waited = 0;
                    return;
                }
                if (!launcherOpen(controller))
                    return;
                PopoutService.closeDankLauncherV2();
                root.check(!controller.expanded, "close collapses the selected dot launcher");
                finish("");
            } catch (error) {
                finish(error.message);
            }
        }
    }
}
