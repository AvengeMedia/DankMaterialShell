import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.OSD
import qs.Modules.DankIsland
import qs.Modules.DankIsland.Activities
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var requested: []
    property var osd: null

    TestCase {
        id: input
        when: false
        name: "osd-level"
    }

    function findSlider(item) {
        if (item.handleWidth !== undefined && item.handleHeight !== undefined)
            return item;
        for (const child of item.children ?? []) {
            const found = findSlider(child);
            if (found)
                return found;
        }
        return null;
    }

    function check(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    Component {
        id: volumeComponent
        VolumeOSD {}
    }
    Component {
        id: micComponent
        MicVolumeOSD {}
    }
    Component {
        id: mediaComponent
        MediaVolumeOSD {}
    }
    Component {
        id: brightnessComponent
        BrightnessOSD {}
    }
    Component {
        id: sourceComponent
        IslandSystemSource {
            controller: null
        }
    }
    Component {
        id: homeComponent
        HomeCompact {
            controller: null
            systemModel: null
        }
    }
    Component {
        id: levelComponent
        LevelOSD {
            iconName: "volume_up"
            iconInteractive: true
            minimum: 10
            maximum: 60
            value: 35
            onLevelRequested: level => root.requested.push(level)
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    Timer {
        interval: 400
        running: true
        repeat: true
        property int step: 0
        onTriggered: {
            try {
                switch (step++) {
                case 0:
                    for (const component of [volumeComponent, micComponent, mediaComponent, brightnessComponent, sourceComponent, homeComponent, levelComponent])
                        root.check(component.status === Component.Ready, "compile " + component.errorString());
                    root.osd = levelComponent.createObject(root, {
                        modelData: Quickshell.screens[0]
                    });
                    SettingsData.osdPosition = SettingsData.Position.TopCenter;
                    SessionData.suppressOSD = false;
                    root.osd.show();
                    break;
                case 1:
                    root.check(root.osd.shouldBeVisible && !root.osd.isVerticalLayout, "horizontal osd shown");
                    root.check(root.osd.contentLoader.item.maximum === 60, "horizontal face carries the model range");
                    root.osd.requestLevel(42);
                    root.osd.available = false;
                    root.osd.requestLevel(50);
                    root.osd.available = true;
                    root.check(root.requested.length === 1 && root.requested[0] === 42, "unavailable osd rejects level requests");
                    SettingsData.osdPosition = SettingsData.Position.LeftCenter;
                    break;
                case 2:
                    root.check(root.osd.isVerticalLayout, "vertical layout follows osd position");
                    const face = root.findSlider(root.osd.contentLoader.item);
                    root.check(Math.abs(face.ratio - 0.5) < 0.01, "vertical face ratio uses the model range");
                    root.osd.value = 60;
                    root.check(Math.abs(face.ratio - 1) < 0.01, "vertical face follows value");
                    root.osd.value = 35;
                    for (let position = 0; position < 8; position++) {
                        SettingsData.osdPosition = position;
                        input.wait(50);
                        const row = root.osd.contentLoader.item;
                        const slider = root.findSlider(row);
                        root.check(slider.size === (root.osd.isVerticalLayout ? "m" : "s"), "osd slider size at position " + position);
                        root.check(slider.rotation === (root.osd.isVerticalLayout ? -90 : 0), "slider orientation at position " + position);
                        root.check(!slider.showStops, "OSD has no slider dots");
                        root.check(slider.height <= (row.vertical ? row.width : row.height), "handle fits across the OSD");
                        const track = slider.contentItem.children[1];
                        input.mouseClick(track, track.width - slider.handleWidth / 2, track.height / 2);
                        root.check(root.requested[root.requested.length - 1] === 60, "OSD pointer reaches maximum at position " + position);
                        input.mouseClick(track, slider.handleWidth / 2, track.height / 2);
                        root.check(root.requested[root.requested.length - 1] === 10, "OSD pointer reaches minimum at position " + position);
                    }
                    SettingsData.osdPosition = SettingsData.Position.TopCenter;
                    root.osd.hide();
                    console.log("FIXTURE_PASS");
                    stop();
                    Qt.quit();
                }
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
                stop();
                Qt.quit();
            }
        }
    }
}
