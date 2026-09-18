import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.Modules.DankIsland
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property int step: 0
    property bool failed: false

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function controller() {
        return islands.hosts()[0]?.body?.islandController ?? null;
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

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.frameEnabled = false;
        SettingsData.launcherStyle = "island";
        SettingsData.rememberLastQuery = false;
        SettingsData.barConfigs = [
            {
                id: "island",
                enabled: true,
                visible: true,
                position: 0,
                island: true,
                spacing: 4,
                innerPadding: 4,
                leftWidgets: [],
                centerWidgets: [],
                rightWidgets: [],
                islandShowSatellites: false
            }
        ];
    }

    Timer {
        interval: 25
        running: true
        repeat: true
        property int waited: 0

        property string waitingFor: "the island host"

        function advance(label) {
            root.step++;
            waited = 0;
            waitingFor = label;
        }

        onTriggered: {
            const c = root.controller();
            if (++waited > 120) {
                console.log("FIXTURE_FAIL timed out waiting for " + waitingFor);
                stop();
                Qt.quit();
                return;
            }
            switch (root.step) {
            case 0:
                if (!c)
                    return;
                c.requestLauncher("", "", false);
                advance("cold open to expand and focus the search field");
                return;
            case 1:
                if (!c.expanded || !c.launcherInputFocused)
                    return;
                root.check(c.activeActivity === "launcher", "cold open expands the launcher");
                c.requestCollapse();
                advance("collapse to drop search focus");
                return;
            case 2:
                if (c.launcherInputFocused)
                    return;
                c.requestLauncher("", "", false);
                advance("warm reopen to focus the search field");
                return;
            case 3:
                if (!c.launcherInputFocused)
                    return;
                c.requestControlCenter("", false);
                advance("control center to take over and release launcher focus");
                return;
            case 4:
                if (c.activeActivity !== "controlcenter" || c.launcherInputFocused)
                    return;
                c.requestLauncher("", "", false);
                advance("launcher to refocus after an activity switch");
                return;
            case 5:
                if (!c.launcherInputFocused)
                    return;
                c.requestCollapse();
                console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
                stop();
                Qt.quit();
                return;
            }
        }
    }
}
