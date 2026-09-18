import QtQuick
import Quickshell
import qs.Common
import "DankCommon/Common/Contrast.js" as Contrast

ShellRoot {
    id: root

    property bool failed: false

    readonly property var nord: ({
            "primary": "#81a1c1",
            "primaryText": "#2e3440",
            "primaryContainer": "#88c0d0",
            "secondary": "#88c0d0",
            "surface": "#2e3440",
            "surfaceText": "#eceff4",
            "surfaceVariant": "#3b4252",
            "surfaceVariantText": "#d8dee9",
            "surfaceTint": "#81a1c1",
            "background": "#2e3440",
            "backgroundText": "#eceff4",
            "outline": "#4c566a",
            "surfaceContainer": "#3b4252",
            "surfaceContainerHigh": "#4c566a",
            "error": "#bf616a"
        })

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function readable(foreground, background, target) {
        return Contrast.ratio(foreground, background) >= target;
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            Theme.isLightMode = false;
            Theme.currentTheme = "purple";
            check(Theme.tonalPrimaryContainer, "stock container counts as tonal");
            check(Theme.selectedContainer === Theme.primaryContainer, "stock selection keeps primaryContainer");
            check(Theme.accentOnPrimaryContainer === Theme.primary, "stock icon boxes keep the primary accent");

            Theme.customThemeData = nord;
            Theme.currentTheme = "custom";
            check(!Theme.tonalPrimaryContainer, "accent-like container is not tonal");
            check(Theme.selectedContainer !== Theme.primaryContainer, "accent-like container is not used as selection fill");
            check(readable(Theme.onSelectedContainer, Theme.selectedContainer, 4.5), "selection text readable on tinted fill");
            check(readable(Theme.onPrimaryContainer, Theme.primaryContainer, 4.5), "derived onPrimaryContainer readable");
            check(readable(Theme.accentOnPrimaryContainer, Theme.primaryContainer, 3), "icon box glyph readable");
            check(readable(Theme.onSecondaryContainer, Theme.secondaryContainer, 4.5), "derived onSecondaryContainer readable");
            console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
            Qt.quit();
        }
    }
}
