import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Widgets
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var values: []
    TestCase {
        id: input
        when: false
        name: "list-reuse-opacity"
    }

    function entries(prefix, count) {
        const list = [];
        for (let i = 0; i < count; i++)
            list.push({
                id: prefix + i,
                label: prefix + " " + i
            });
        return list;
    }

    PanelWindow {
        color: "transparent"
        implicitWidth: 400
        implicitHeight: 600
        anchors {
            top: true
            left: true
        }

        DankListView {
            id: list
            anchors.fill: parent
            reuseItems: true
            highlightSelection: true
            spacing: 4
            model: ScriptModel {
                values: root.values
                objectProp: "id"
            }
            delegate: DankListItem {
                required property int index
                required property var modelData
                width: list.width
                height: 48
                StyledText {
                    anchors.centerIn: parent
                    text: modelData.label
                }
            }
        }
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

    function ghosts(label) {
        const bad = [];
        for (let i = 0; i < list.count; i++) {
            const item = list.itemAtIndex(i);
            if (!item)
                continue;
            if (!item.visible || item.opacity < 0.99)
                bad.push(i + ":" + (item.visible ? "opacity " + item.opacity.toFixed(2) : "hidden"));
        }
        root.check(bad.length === 0, label + " leaves ghost rows " + bad.join(", "));
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            try {
                root.values = root.entries("a", 8);
                input.wait(600);
                root.ghosts("initial fill");

                root.values = [];
                root.values = root.entries("b", 8);
                input.wait(20);
                root.values = root.entries("c", 8);
                input.wait(600);
                root.ghosts("reset and refill during the add transition");

                root.values = [];
                input.wait(20);
                root.values = root.entries("d", 8);
                input.wait(30);
                list.forceLayout();
                list.positionViewAtBeginning();
                root.values = root.entries("d", 8);
                input.wait(600);
                root.ghosts("refill with forced layout and same ids");

                for (let round = 0; round < 6; round++) {
                    root.values = root.entries("r" + round, 6);
                    input.wait(round * 15);
                }
                input.wait(600);
                root.ghosts("rapid replacement rounds");

                root.values = root.entries("s", 40);
                input.wait(600);
                list.contentY = list.maximumContentY;
                input.wait(100);
                root.values = root.entries("t", 40);
                input.wait(30);
                list.contentY = 0;
                input.wait(100);
                list.contentY = list.maximumContentY / 2;
                input.wait(600);
                root.ghosts("churn while scrolled then jump");

                for (let round = 0; round < 8; round++) {
                    list.contentY = (round % 2) ? list.maximumContentY : 0;
                    root.values = root.entries("u" + round, 40 - round);
                    input.wait(40);
                }
                list.contentY = 0;
                input.wait(600);
                root.ghosts("alternating scroll and replace");

                list.reuseItems = false;
                for (let round = 0; round < 8; round++) {
                    list.contentY = (round % 2) ? list.maximumContentY : 0;
                    root.values = root.entries("v" + round, 40 - round);
                    input.wait(40);
                }
                list.contentY = 0;
                input.wait(600);
                root.ghosts("alternating scroll and replace without reuse");

                console.log("FIXTURE_PASS list reuse keeps every claimed row visible and opaque");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
