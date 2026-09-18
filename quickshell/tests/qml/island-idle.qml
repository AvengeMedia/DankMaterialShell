import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.Modules.DankIsland
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

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
        interval: 1500
        running: true
        repeat: true
        property int step: 0
        onTriggered: {
            const host = islands.hosts()[0];
            switch (step++) {
            case 0:
                if (!host) {
                    console.error("FIXTURE_FAIL no island host");
                    Qt.quit();
                }
                console.log("COMPACT_IDLE_BEGIN");
                break;
            case 3:
                console.log("COMPACT_IDLE_END");
                host.islandController.requestActivity("home", true, false);
                break;
            case 4:
                if (!host.islandController.expanded) {
                    console.error("FIXTURE_FAIL island did not expand");
                    Qt.quit();
                }
                console.log("EXPANDED_IDLE_BEGIN");
                break;
            case 7:
                console.log("EXPANDED_IDLE_END");
                host.islandController.requestCollapse();
                break;
            case 9:
                if (host.islandController.expanded) {
                    console.error("FIXTURE_FAIL island did not collapse");
                    Qt.quit();
                }
                console.log("FIXTURE_PASS");
                stop();
                Qt.quit();
            }
        }
    }
}
