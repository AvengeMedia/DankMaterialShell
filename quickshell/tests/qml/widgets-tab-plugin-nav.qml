import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Settings
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property bool failed: false
    property var tab: null

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function findPluginRow(item) {
        if (item.modelData?.pluginId && typeof item.clicked === "function")
            return item;
        for (const child of item.children || []) {
            const found = findPluginRow(child);
            if (found)
                return found;
        }
        return null;
    }

    QtObject {
        id: modalStub

        property var navigated: []

        function navigateTo(pageId) {
            navigated = navigated.concat([pageId]);
            return true;
        }
    }

    Component {
        id: tabComponent
        WidgetsTab {}
    }

    PanelWindow {
        color: "transparent"
        implicitWidth: 900
        implicitHeight: 1600
        anchors {
            top: true
            left: true
        }

        Item {
            id: stage
            anchors.fill: parent
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        property int step: 0
        onTriggered: {
            if (step++ === 0) {
                Quickshell.watchFiles = false;
                DC.Style.theme = Theme;
                DC.Style.settings = SettingsData;
                DC.I18n.backend = I18n;
                SettingsData.barConfigs = [
                    {
                        "id": "default",
                        "enabled": true,
                        "position": SettingsData.Position.Top,
                        "leftWidgets": ["plugin_fixture"],
                        "centerWidgets": [],
                        "rightWidgets": []
                    }
                ];
                root.tab = tabComponent.createObject(stage, {
                    width: 860,
                    height: 1500,
                    parentModal: modalStub,
                    baseWidgetDefinitions: [
                        {
                            "id": "plugin_fixture",
                            "pluginId": "fixture",
                            "text": "Fixture Plugin",
                            "description": "",
                            "icon": "extension",
                            "enabled": true
                        }
                    ]
                });
                if (!root.tab) {
                    console.error("FIXTURE_FAIL " + tabComponent.errorString());
                    Qt.quit();
                    return;
                }
                return;
            }
            const row = findPluginRow(root.tab);
            check(!!row, "plugin widget row is rendered");
            row?.clicked();
            check(JSON.stringify(modalStub.navigated) === JSON.stringify([SettingsTabs.pluginPrefix + "fixture"]), "plugin row pushes the plugin page onto the modal history, got " + JSON.stringify(modalStub.navigated));
            console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
            stop();
            Qt.quit();
        }
    }
}
