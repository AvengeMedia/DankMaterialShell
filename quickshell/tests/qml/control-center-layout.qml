import QtQuick
import Quickshell
import qs.Common
import qs.Modules.ControlCenter.Components
import qs.Modules.ControlCenter.Widgets
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property int scenario: 0
    property var before: null

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    FloatingWindow {
        visible: true
        implicitWidth: 600
        implicitHeight: 240

        Item {
            id: content
            anchors.fill: parent
            visible: false

            HeaderPane {
                id: header
                width: 518
                live: false
                LayoutMirroring.enabled: root.scenario >= 2
            }

            CcTile {
                id: tile
                y: 100
                width: 255
                title: "Output"
                subtitle: root.scenario % 2 === 0 ? "Selected device" : ""
                iconName: "volume_up"
                live: false
                LayoutMirroring.enabled: root.scenario >= 2
            }
        }
    }

    function labels(item) {
        const result = [];
        for (const child of item.children) {
            if (typeof child.text === "string" && child.text !== "")
                result.push(child);
            result.push(...labels(child));
        }
        return result;
    }

    function geometry(item) {
        return labels(item).map(label => {
            const position = label.mapToItem(item, 0, 0);
            return {
                x: position.x,
                y: position.y,
                width: label.width,
                height: label.height
            };
        });
    }

    function check(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function begin() {
        content.visible = false;
        Qt.callLater(() => {
            root.before = {
                tile: geometry(tile),
                header: geometry(header)
            };
            content.visible = true;
            verify.restart();
        });
    }

    Timer {
        interval: 500
        running: true
        onTriggered: root.begin()
    }

    Timer {
        id: verify
        interval: 80
        onTriggered: {
            try {
                const after = {
                    tile: root.geometry(tile),
                    header: root.geometry(header)
                };
                for (const name of ["tile", "header"]) {
                    root.check(after[name].length > 0, name + " has labels");
                    root.check(JSON.stringify(root.before[name]) === JSON.stringify(after[name]), name + " label geometry changed on opening in scenario " + root.scenario);
                }
                root.scenario++;
                if (root.scenario < 4) {
                    root.begin();
                    return;
                }
                console.log("FIXTURE_PASS control center label layout");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
