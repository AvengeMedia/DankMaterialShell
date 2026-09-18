import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Widgets
import qs.DankCommon.Common as DC

ShellRoot {
    Component.onCompleted: {
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    FloatingWindow {
        visible: true
        implicitWidth: 400
        implicitHeight: 300

        Item {
            id: scene
            anchors.fill: parent

            DankFlickable {
                id: flick
                x: 20
                y: 20
                width: 300
                height: 200
                contentWidth: width
                contentHeight: column.height

                Column {
                    id: column
                    width: parent.width

                    DankSlider {
                        id: slider
                        width: parent.width
                        value: 50
                    }

                    Item {
                        id: filler
                        width: 1
                        height: 0
                    }
                }
            }
        }

        TestCase {
            id: tester
            when: false

            function check(condition, label) {
                if (!condition)
                    throw new Error(label);
                console.log("PASS " + label);
            }

            function wheelOnSlider() {
                const point = slider.mapToItem(scene, slider.width / 2, slider.height / 2);
                mouseWheel(scene, point.x, point.y, 0, 120);
                wait(50);
            }

            function run() {
                wait(300);
                wheelOnSlider();
                check(slider.value === 51, "wheel steps a slider whose container does not scroll");
                filler.height = 1000;
                wait(50);
                wheelOnSlider();
                check(slider.value === 51, "wheel leaves a slider alone once the container scrolls");
                console.log("FIXTURE_PASS slider wheel");
                Qt.quit();
            }
        }

        Timer {
            interval: 800
            running: true
            onTriggered: {
                try {
                    tester.run();
                } catch (error) {
                    console.error("FIXTURE_FAIL " + error.message);
                    Qt.quit();
                }
            }
        }
    }
}
