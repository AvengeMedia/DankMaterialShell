import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Dock
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property bool failed: false

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function finish() {
        console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
    }

    property var buttons: []
    property int step: 0

    Component {
        id: appButton
        DockAppButton {}
    }
    Component {
        id: launcherButton
        DockLauncherButton {}
    }

    PanelWindow {
        color: "transparent"
        implicitWidth: 800
        implicitHeight: 400
        anchors {
            top: true
            left: true
        }

        Item {
            id: stage
            anchors.fill: parent
        }
    }

    function snapshot(label) {
        for (const button of root.buttons) {
            const offset = Math.round(button.item.hoverAnimOffset * 1000) / 1000;
            const position = Number(button.name.split("-")[1]);
            const direction = position === SettingsData.Position.Top || position === SettingsData.Position.Left ? 1 : -1;
            switch (label) {
            case "hovered":
                check(offset * direction > 0, label + " " + button.name + " settled offset " + offset);
                break;
            default:
                check(offset === 0, label + " " + button.name + " offset back to 0, got " + offset);
            }
            console.log("PARITY " + JSON.stringify({
                label: label,
                name: button.name,
                hovered: button.item.isHovered,
                offset: offset
            }));
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        const created = [];
        let x = 20;
        for (const position of [SettingsData.Position.Top, SettingsData.Position.Bottom, SettingsData.Position.Left, SettingsData.Position.Right]) {
            for (const [name, component] of [["app", appButton], ["launcher", launcherButton]]) {
                const item = component.createObject(stage, {
                    options: {
                        position: position,
                        compact: true
                    },
                    actualIconSize: 40,
                    width: 48,
                    height: 48,
                    x: x,
                    y: 100
                });
                x += 60;
                created.push({
                    name: name + "-" + position,
                    item: item
                });
            }
        }
        root.buttons = created;
    }

    Timer {
        interval: 700
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                root.snapshot("idle");
                for (const button of root.buttons)
                    button.item.isHovered = true;
                return;
            case 1:
                root.snapshot("hovered");
                for (const button of root.buttons)
                    button.item.isHovered = false;
                return;
            case 2:
                root.snapshot("left");
                SettingsData.animationDuration = 0;
                for (const button of root.buttons)
                    button.item.isHovered = true;
                return;
            case 3:
                root.snapshot("hovered-motion-off");
                root.finish();
                stop();
                Qt.quit();
            }
        }
    }
}
