import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modals.DankLauncherV2
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var launcher: null
    property bool failed: false
    property int step: 0
    property var created: []

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label + " created=" + JSON.stringify(root.created));
    }

    function shows(pluginId) {
        return root.launcher.spotlightContent.controller.flatModel.some(entry => entry.item?.pluginId === pluginId);
    }

    function stallState() {
        const content = root.launcher?.spotlightContent;
        const controller = content?.controller;
        return JSON.stringify({
            open: root.launcher?.spotlightOpen,
            contentVisible: root.launcher?.contentVisible,
            content: !!content,
            searchMode: controller?.searchMode,
            isSearching: controller?.isSearching,
            pluginPhasePending: controller?._pluginPhasePending,
            rows: controller?.flatModel?.length,
            cacheValid: AppSearchService.isCacheValid(),
            launchers: Object.keys(PluginService.getLauncherPlugins()),
            emptyTrigger: PluginService.getPluginsWithEmptyTrigger(),
            pluginSettings: SettingsData.pluginSettings,
            visibility: SettingsData.launcherPluginVisibility
        });
    }

    component FixtureLauncher: QtObject {
        property var pluginService: null
        required property string pluginId

        Component.onCompleted: root.created = root.created.concat([pluginId])

        function getItems(query) {
            return [
                {
                    name: pluginId
                }
            ];
        }
    }

    Component {
        id: allowedLauncher
        FixtureLauncher {
            pluginId: "allowed"
        }
    }

    Component {
        id: triggerLauncher
        FixtureLauncher {
            pluginId: "triggered"
        }
    }

    Component {
        id: modalComp
        DankLauncherV2Modal {}
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.launcherStyle = "standalone";
        SettingsData.rememberLastQuery = false;
        SettingsData.rememberLastMode = false;
        root.launcher = modalComp.createObject(root);
    }

    Timer {
        interval: 0
        running: SettingsData._hasLoaded && SessionData._hasLoaded
        onTriggered: {
            PluginService.availablePlugins = {
                allowed: {
                    id: "allowed",
                    name: "Allowed",
                    loaded: true
                },
                triggered: {
                    id: "triggered",
                    name: "Triggered",
                    trigger: "z",
                    loaded: true
                }
            };
            SettingsData.setPluginSetting("allowed", "noTrigger", true);
            SettingsData.setPluginAllowWithoutTrigger("triggered", false);
            PluginService.pluginLauncherComponents = {
                allowed: allowedLauncher,
                triggered: triggerLauncher
            };
            steps.start();
        }
    }

    Timer {
        id: steps
        interval: 25
        repeat: true
        property int waited: 0
        onTriggered: {
            if (++waited > 400) {
                check(false, "timed out in step " + root.step + " state=" + root.stallState());
                stop();
                Qt.quit();
                return;
            }
            switch (root.step) {
            case 0:
                root.launcher.show();
                waited = 0;
                root.step++;
                return;
            case 1:
                if (root.created.length === 0)
                    return;
                check(JSON.stringify(root.created) === '["allowed"]', "empty query creates only the plugin allowed without a trigger");
                root.launcher.spotlightContent.searchField.text = "z";
                waited = 0;
                root.step++;
                return;
            case 2:
                if (!root.shows("triggered"))
                    return;
                check(root.shows("triggered"), "typing the trigger creates the plugin and shows its items");
                console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
                stop();
                Qt.quit();
            }
        }
    }
}
