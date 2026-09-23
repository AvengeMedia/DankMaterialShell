import QtQuick
import Quickshell
import qs.Common
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

    function ladder(owner) {
        return [owner.fontWeight, owner.fontWeightMedium, owner.fontWeightBold];
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            Quickshell.watchFiles = false;
            DC.Style.theme = Theme;
            DC.Style.settings = SettingsData;

            for (const base of [Font.Thin, Font.Normal, Font.Bold, Font.Black]) {
                SettingsData.fontWeight = base;
                const weights = ladder(Theme);
                check(weights[0] === base, `Theme ladder starts at the setting, got ${JSON.stringify(weights)}`);
                check(weights.every((weight, index) => weight <= Font.Black && (index === 0 || weight >= weights[index - 1])), `Theme ladder rises and clamps at ${base}, got ${JSON.stringify(weights)}`);
                check(JSON.stringify(ladder(DC.Style)) === JSON.stringify(weights), `Style ladder differs from Theme at ${base}: ${JSON.stringify(ladder(DC.Style))}`);
            }
            SettingsData.fontWeight = Font.Normal;

            root.finish();
            Qt.quit();
        }
    }
}
