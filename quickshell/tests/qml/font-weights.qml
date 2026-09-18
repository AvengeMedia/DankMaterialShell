import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
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

    function probeWidth(weight, axes) {
        const probe = probeComponent.createObject(stage);
        probe.font.weight = weight;
        if (axes)
            probe.font.variableAxes = axes;
        const width = probe.implicitWidth;
        probe.destroy();
        return width;
    }

    Item {
        id: stage
        width: 1200
        height: 200
    }

    Component {
        id: probeComponent

        StyledText {
            text: "The quick brown fox jumps over the lazy dog"
            font.pixelSize: 40
            wrapMode: Text.NoWrap
            elide: Text.ElideNone
        }
    }

    Timer {
        interval: 25
        running: true
        repeat: true
        property int waited: 0
        onTriggered: {
            if (probeWidth(Font.Thin) >= probeWidth(Font.Black) && ++waited < 80)
                return;
            stop();
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

            const widths = [Font.Light, Font.Normal, Font.Medium, Font.Bold].map(weight => probeWidth(weight));
            console.log("WIDTHS " + JSON.stringify(widths));
            check(widths.every((width, index) => index === 0 || width > widths[index - 1]), "bundled sans renders each weight heavier than the last");

            const axisWidth = probeWidth(Font.Normal, {
                "wght": 750
            });
            check(axisWidth > widths[1], "Normal weight still resolves to the variable face so wght axes apply");

            SettingsData.fontWeight = Font.Bold;
            const display = probeComponent.createObject(stage, {
                "fontToken": "display"
            });
            check(display.fontInfo.family === DC.Fonts.display, `display text resolves to the bundled display face, got ${display.fontInfo.family}`);
            check(display.font.weight === Font.Normal, "display text ignores the UI weight setting");
            check(display.implicitWidth !== probeWidth(Font.Normal), "display face differs from the UI face");
            display.fontToken = DC.Fonts.notable;
            check(display.fontInfo.family === DC.Fonts.notable && display.font.weight === Font.Normal, `a bundled family token resolves to that face, got ${display.fontInfo.family}`);
            display.destroy();
            SettingsData.fontWeight = Font.Normal;

            root.finish();
            Qt.quit();
        }
    }
}
