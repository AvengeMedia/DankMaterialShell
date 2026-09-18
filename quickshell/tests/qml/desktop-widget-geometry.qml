import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Plugins
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    TestCase {
        id: input
        when: false
        name: "desktop-widget-geometry"
    }

    DesktopPluginWrapper {
        id: perScreen
        pluginId: "fixturePlugin"
        screen: Quickshell.screens[0]
        instanceId: "inst1"
        instanceData: ({
                id: "inst1",
                config: {}
            })
    }

    DesktopPluginWrapper {
        id: synced
        pluginId: "fixturePlugin"
        screen: Quickshell.screens[0]
        instanceId: "inst2"
        instanceData: ({
                id: "inst2",
                config: {
                    syncPositionAcrossScreens: true
                }
            })
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    function check(value, message) {
        if (!value)
            throw new Error(message);
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            try {
                const screen = Quickshell.screens[0];
                const key = SettingsData.getScreenDisplayName(screen);

                root.check(!perScreen.hasSavedPosition && !perScreen.hasSavedSize, "defaults before any save");
                root.check(perScreen.savedX === screen.width / 2 - perScreen.savedWidth / 2, "unsaved position centers on the screen");
                perScreen.savePosition(10, 20);
                perScreen.saveSize(300, 150);
                const stored = SessionData.desktopWidgetInstancePositions.inst1[key];
                root.check(stored.x === 10 && stored.y === 20 && stored.width === 300 && stored.height === 150, "per-screen instance stores raw geometry under the screen key");
                root.check(perScreen.hasSavedPosition && perScreen.savedX === 10 && perScreen.savedY === 20 && perScreen.savedWidth === 300 && perScreen.savedHeight === 150, "per-screen instance reads back what it saved");

                synced.savePosition(screen.width / 4, screen.height / 4);
                synced.saveSize(250, 125);
                const shared = SessionData.desktopWidgetInstancePositions.inst2._synced;
                root.check(shared.x === 0.25 && shared.y === 0.25 && shared.width === 250, "synced instance stores normalized coordinates and raw size");
                root.check(synced.savedX === screen.width / 4 && synced.savedY === screen.height / 4 && synced.savedWidth === 250 && synced.savedHeight === 125, "synced instance scales coordinates back to the screen");

                console.log("FIXTURE_PASS desktop widget geometry: per-screen and synced instance persistence round-trip");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
