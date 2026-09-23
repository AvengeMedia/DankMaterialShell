import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.Modules.DankIsland
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var hosts: []
    property bool hostsChecked: false

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
                { id: "dot", enabled: true, visible: true, dot: true, position: 0 },
                { id: "vertical", enabled: true, visible: true, island: true, islandFloating: true, islandPlacement: "free", position: 2, islandSatellitePosition: "island", leftWidgets: ["clock"], rightWidgets: ["clock"] }
            ];
            root.hosts = SettingsData.barConfigs.map(config => hostComponent.createObject(root, { barId: config.id, screen: Quickshell.screens[0] }));
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
                        root.check(Math.abs(surface.currentVisualX + surface.currentVisualWidth / 2 - host.anchorX) <= 1, "visible X follows the anchor");
                        root.check(Math.abs(surface.currentVisualY + surface.currentVisualHeight / 2 - host.anchorY) <= 1, "visible Y follows the anchor");
                        root.check(Math.abs(body.x + host.surfaceX) < 1 && Math.abs(body.y + host.surfaceY) < 1, "window translation preserves screen coordinates");
                        root.check(host.implicitWidth <= Math.ceil(surface.currentVisualWidth) + 1, "moving buffer stays bounded to the face");
                    }
                    host.islandController.requestActivity("controlcenter", true, false);
                    surface.surfaceMotion.settle();
                    root.check(host.implicitWidth < host.screen.width && host.implicitHeight < host.screen.height, "expanded buffer is bounded to the sheet");
                    root.check(surface.currentScreenX >= 0 && surface.currentScreenY >= 0, "sheet stays on screen");
                    host.islandController.requestCollapse();
                    surface.surfaceMotion.settle();
                    root.check(!surface.motionRunning, "idle motion stops");
                }
                root.hostsChecked = true;
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
                Qt.quit();
            }
        }
    }

    Item {
        Repeater {
            id: bars
            model: root.hostsChecked ? SettingsData.barConfigs : []
            delegate: DankBar {
                required property var modelData
                barConfig: modelData
            }
        }
    }

    Timer {
        interval: 0
        readonly property var band: bars.count === 2 ? bars.itemAt(1).barVariants.instances[0] ?? null : null
        running: !!band && band.height === band.screen.height && band.width < band.height
        onTriggered: {
            try {
                root.check(bars.itemAt(0).barVariants.instances.length === 0, "a dot has no satellite window");
                const band = bars.itemAt(1).barVariants.instances[0];
                root.check(bars.itemAt(1).barVariants.instances.length === 1 && !band.islandHost, "a free island keeps one satellite window without a pill");
                root.check(band.exclusiveZone <= 0, "the satellite window reserves nothing");
                const leading = band.leadingSectionRect;
                const trailing = band.trailingSectionRect;
                root.check(leading.y + leading.h <= trailing.y, "near island keeps left before right");
                root.check(Math.abs((leading.y + trailing.y + trailing.h) / 2 - band.height / 2) <= 2, "near island gathers at the edge centre");
                console.log("FIXTURE_PASS");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
