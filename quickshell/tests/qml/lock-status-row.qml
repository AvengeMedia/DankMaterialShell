import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Lock
import qs.Modules.Greetd
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    Component {
        id: lockContent
        LockScreenContent {}
    }
    Component {
        id: greeterContent
        GreeterContent {}
    }
    TestCase {
        id: input
        when: false
        name: "lock-status-row"
    }

    Item {
        width: 1200
        height: 100

        LockStatusRow {
            id: full
            showMediaPlayer: true
        }
        LockStatusRow {
            id: quiet
            showMediaPlayer: false
            y: 50
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

    function find(item, predicate) {
        if (predicate(item))
            return item;
        for (const child of item.children ?? []) {
            const found = find(child, predicate);
            if (found)
                return found;
        }
        return null;
    }

    function dividers(row) {
        return row.children.filter(c => c.visible && c.width === Theme.dividerWidth && c.height === Theme.iconSize).length;
    }

    function groups(row) {
        return row.children.filter(c => c.visible && !(c.width === Theme.dividerWidth && c.height === Theme.iconSize)).length;
    }

    function checkDividers(row, label) {
        root.check(dividers(row) === Math.max(groups(row) - 1, 0), label + ": dividers " + dividers(row) + " for groups " + groups(row));
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            try {
                root.check(lockContent.status === Component.Ready, "LockScreenContent compiles: " + lockContent.errorString());
                root.check(greeterContent.status === Component.Ready, "GreeterContent compiles: " + greeterContent.errorString());

                for (let i = 0; i < 60 && !MprisController.activePlayer; i++)
                    input.wait(50);
                root.check(!!MprisController.activePlayer, "fixture player is active");
                input.wait(50);

                const quietLoader = root.find(quiet, c => c.hasOwnProperty("sourceComponent") && c.hasOwnProperty("active"));
                root.check(quietLoader && !quietLoader.active && quietLoader.item === null, "media group stays unloaded when showMediaPlayer is off");
                const fullLoader = root.find(full, c => c.hasOwnProperty("sourceComponent") && c.hasOwnProperty("active"));
                root.check(fullLoader.active && fullLoader.item && fullLoader.visible, "media group loads with an active player");
                root.check(root.find(fullLoader.item, c => c.elide === Text.ElideRight).text !== "", "media title renders");
                root.checkDividers(full, "media only");
                root.checkDividers(quiet, "nothing visible");
                root.check(quiet.implicitWidth === 0, "empty row takes no width");

                WeatherService.weather = {
                    available: true,
                    temp: 21,
                    tempF: 70,
                    wCode: 0
                };
                input.wait(20);
                const temperature = root.find(full, c => c.text !== undefined && String(c.text).endsWith("°"));
                root.check(temperature && temperature.text === "21°", "weather shows celsius: " + (temperature ? temperature.text : "none"));
                full.useFahrenheit = true;
                root.check(temperature.text === "70°", "weather follows useFahrenheit");
                root.checkDividers(full, "media and weather");
                root.check(dividers(full) === 1, "one divider between media and weather");
                full.showWeather = false;
                input.wait(20);
                root.checkDividers(full, "weather hidden");
                root.check(dividers(full) === 0, "no divider when only media is visible");
                root.checkDividers(quiet, "weather only");

                const keyboardArea = root.find(full.children[0], c => c.hasOwnProperty("cursorShape") && c.hasOwnProperty("hoverEnabled"));
                root.check(keyboardArea.enabled, "keyboard layout is clickable by default");
                full.interactive = false;
                root.check(!keyboardArea.enabled && keyboardArea.cursorShape === Qt.ArrowCursor, "interactive off disables the keyboard layout click");

                console.log("FIXTURE_PASS lock status row: compile, media loader gating, divider rule, weather units, interactive");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
