import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Settings
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

    property var fakeStore: QtObject {
        function value(key) {
            return undefined;
        }
        function get(key) {
            return undefined;
        }
        function set(key, value) {
        }
    }

    Component {
        id: cardComponent
        WorkspaceAppearanceCard {
            store: root.fakeStore
        }
    }

    Item {
        id: stage
        width: 800
        height: 800
    }

    Timer {
        interval: 1200
        running: true
        onTriggered: {
            Quickshell.watchFiles = false;
            DC.Style.theme = Theme;
            DC.Style.settings = SettingsData;
            DC.I18n.backend = I18n;
            const card = cardComponent.createObject(stage, {
                width: 700
            });
            if (!card) {
                console.error("FIXTURE_FAIL card did not instantiate: " + cardComponent.errorString());
                Qt.quit();
                return;
            }
            const lists = {};
            for (const name of ["focusedColorOptions", "occupiedColorOptions", "unfocusedColorOptions", "urgentColorOptions", "borderColorOptions"])
                lists[name] = card[name];
            console.log("PARITY " + JSON.stringify(lists));
            for (const name in lists) {
                check(lists[name].length > 0, name + " non-empty");
                check(lists[name].every(entry => entry.value && entry.label), name + " entries carry value and label");
                check(new Set(lists[name].map(entry => entry.value)).size === lists[name].length, name + " values unique");
            }
            const has = (list, value) => list.some(entry => entry.value === value);
            check(has(lists.occupiedColorOptions, "sec"), "occupied keeps the legacy sec value");
            check(!has(lists.borderColorOptions, "default") && has(lists.borderColorOptions, "custom"), "border list has custom but no default");
            root.finish();
            Qt.quit();
        }
    }
}
