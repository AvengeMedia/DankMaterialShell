import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankIsland
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var hosts: []

    Component {
        id: hostComponent
        IslandFreeHostWindow {}
    }

    function check(condition, message) {
        if (!condition)
            throw new Error(message);
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
            SettingsData.barConfigs = [
                {
                    id: "dot",
                    enabled: true,
                    visible: true,
                    dot: true,
                    position: 0
                },
                {
                    id: "vertical",
                    enabled: true,
                    visible: true,
                    island: true,
                    islandFloating: true,
                    islandPlacement: "free",
                    position: 2
                }
            ];
            root.hosts = SettingsData.barConfigs.map(config => hostComponent.createObject(root, {
                    barId: config.id,
                    screen: Quickshell.screens[0]
                }));
        }
    }

    Timer {
        interval: 0
        running: root.hosts.length === 2 && root.hosts.every(host => host.width > 0 && host.height > 0)
        onTriggered: {
            try {
                for (const host of root.hosts) {
                    const body = IslandHostRegistry.hostFor(host.screen.name, host.barId);
                    const surface = body.surface;
                    root.check(host.width < host.screen.width / 2 && host.height < host.screen.height / 2, "compact window must not allocate a fullscreen buffer");
                    for (const point of [[host.screen.width * 0.8, host.screen.height * 0.7], [0, 0]]) {
                        host.moveTo(point[0], point[1]);
                        surface.surfaceMotion.settle();
                        root.check(host.implicitWidth <= Math.ceil(surface.currentVisualWidth) + 1, "moving buffer stays bounded to the face");
                    }
                    host.islandController.requestActivity("controlcenter", true, false);
                    surface.surfaceMotion.settle();
                    root.check(host.implicitWidth < host.screen.width && host.implicitHeight < host.screen.height, "expanded buffer is bounded to the sheet");
                }
                console.log("FIXTURE_PASS");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
