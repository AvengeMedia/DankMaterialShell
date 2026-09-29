import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.Modules.DankIsland
import qs.DankCommon.Common as DC

// An auto-hidden or manually hidden bar hosting the island shows itself for island-bound events (an activity, a level
// change) and hides again once the face is gone.
ShellRoot {
    id: root

    readonly property var screen: Quickshell.screens[0]
    readonly property string barId: "main"

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
            SettingsData.reduceMotion = true;
            SettingsData.frameEnabled = false;
            SettingsData.barConfigs = [{ id: root.barId, enabled: true, visible: true, autoHide: true, autoHideDelay: 400, position: 0, screenPreferences: ["all"], leftWidgets: ["clock"], centerWidgets: [{ id: "island", enabled: true }], rightWidgets: ["clock"] }];
        }
    }

    Timer {
        id: steps

        property int index: 0
        property int waited: 0
        readonly property var body: IslandHostRegistry.hostFor(root.screen.name, root.barId)
        readonly property var window: body?.hostWindow ?? null

        interval: 25
        repeat: true
        running: !!body && !!body.islandController

        function finish(message) {
            if (message)
                console.error("FIXTURE_FAIL", message);
            else
                console.log("FIXTURE_PASS");
            stop();
            Qt.quit();
        }

        function next() {
            index++;
            waited = 0;
        }

        onTriggered: {
            if (++waited > 240) {
                finish("timed out at step " + index);
                return;
            }
            const controller = body.islandController;
            try {
                switch (index) {
                case 0:
                    if (body.motionRunning || window.barRevealed)
                        return;
                    controller.requestControlCenter("", false);
                    next();
                    return;
                case 1:
                    if (!controller.expanded || body.motionRunning)
                        return;
                    root.check(window.barRevealed, "an activity request reveals the auto-hidden bar");
                    root.check(window.exclusiveZone === -1, "an auto-hidden bar reserves nothing while revealed for the island");
                    controller.requestCollapse();
                    next();
                    return;
                case 2:
                    if (controller.expanded || body.motionRunning)
                        return;
                    root.check(window.barRevealed, "the bar is still held right after collapse");
                    next();
                    return;
                case 3:
                    if (window.barRevealed)
                        return;
                    controller.requestSystemActivity("volume");
                    next();
                    return;
                case 4:
                    if (!controller.transientActive || body.motionRunning)
                        return;
                    root.check(window.barRevealed, "a level change reveals the bar for its compact face");
                    controller.finishTransient();
                    next();
                    return;
                case 5:
                    if (controller.transientActive || window.barRevealed)
                        return;
                    SettingsData.updateBarConfig(root.barId, { visible: false, autoHide: false });
                    next();
                    return;
                case 6:
                    if ((SettingsData.getBarConfig(root.barId)?.visible ?? true) || window.barRevealed || body.motionRunning)
                        return;
                    root.check(SettingsData.activeIslandConfigsForScreen(root.screen).length === 0, "a hidden bar's island swallows no popups or OSDs");
                    controller.requestControlCenter("", false);
                    next();
                    return;
                case 7:
                    if (!controller.expanded || body.motionRunning)
                        return;
                    root.check(window.barRevealed, "a manually hidden bar shows itself for the island");
                    root.check(window.exclusiveZone === -1, "a hidden bar reserves nothing while revealed for the island");
                    controller.requestCollapse();
                    next();
                    return;
                case 8:
                    if (controller.expanded || body.motionRunning || window.barRevealed)
                        return;
                    finish("");
                    return;
                }
            } catch (error) {
                finish(error.message);
            }
        }
    }
}
