import QtQuick
import Quickshell
import qs.Common
import "DankCommon/Common/Contrast.js" as Contrast

ShellRoot {
    id: root

    property bool failed: false

    readonly property var gruvbox: ({
            "primary": "#8ec07c",
            "primaryText": "#282828",
            "primaryContainer": "#427b58",
            "secondary": "#83a598",
            "surface": "#282828",
            "surfaceText": "#ebdbb2",
            "surfaceVariant": "#3c3836",
            "surfaceVariantText": "#d5c4a1",
            "surfaceTint": "#8ec07c",
            "background": "#1d2021",
            "backgroundText": "#ebdbb2",
            "outline": "#665c54",
            "surfaceContainer": "#32302f",
            "surfaceContainerHigh": "#3c3836",
            "error": "#fb4934",
            "accents": {
                "blue": "#fb4934"
            }
        })

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function readable(pair) {
        return pair && Contrast.ratio(pair.onContainer, pair.container) >= 4.5;
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            Theme.isLightMode = false;
            Theme.currentTheme = "purple";
            for (const slot of ["red", "orange", "yellow", "green", "teal", "blue", "purple", "pink"])
                check(readable(Theme.accent(slot)), "stock dark " + slot + " glyph readable");
            const stockBlue = Theme.accent("blue").container;
            Theme.isLightMode = true;
            check(readable(Theme.accent("blue")), "stock light blue glyph readable");
            check(Theme.accent("blue").container !== stockBlue, "fill follows the mode");
            check(Theme.accent("nope") === null, "unknown slot is null");

            Theme.isLightMode = false;
            Theme.customThemeData = gruvbox;
            Theme.currentTheme = "custom";
            const overridden = Theme.accent("blue").container;
            check(overridden.r > overridden.b, "custom accents override the slot hue");
            check(readable(Theme.accent("blue")), "overridden slot glyph readable");
            check(readable(Theme.accent("green")), "derived slot glyph readable under custom theme");
            console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
            Qt.quit();
        }
    }
}
