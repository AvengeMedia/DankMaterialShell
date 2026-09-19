import QtQuick
import QtTest
import "../Modules/DankBar/Widgets/KeyboardLayoutLabels.js" as KeyboardLayoutLabels

TestCase {
    name: "KeyboardLayoutLabels"

    readonly property var validVariants: ["US", "UK", "GB", "AZERTY", "QWERTY", "Dvorak", "Colemak", "Mac", "Intl", "International"]

    // Hyprland compact mode passes the raw "kb_layout-kb_variant" string straight through
    // (codesOnly), which is what makes labels like "am-phonetic-alt" unreadable.
    function test_overrideReplacesRawHyprlandCompactLabel() {
        compare(KeyboardLayoutLabels.displayLabel("am-phonetic-alt", true, true, validVariants, {
            "am-phonetic-alt": "am"
        }), "am");
    }

    function test_noOverrideKeepsExistingBehaviorUnchanged() {
        compare(KeyboardLayoutLabels.displayLabel("am-phonetic-alt", true, true, validVariants, {}), "am-phonetic-alt");
        compare(KeyboardLayoutLabels.displayLabel("am-phonetic-alt", true, true, validVariants, undefined), "am-phonetic-alt");
    }

    function test_overrideKeyIsTheComputedLabelNotTheRawInput() {
        // Niri/Sway/Aqueous feed full XKB descriptions through the compact shortening logic;
        // the override map is keyed by what that logic would otherwise display ("en-US"), not
        // the original description ("English (US)").
        compare(KeyboardLayoutLabels.displayLabel("English (US)", true, false, validVariants, {}), "en-US");
        compare(KeyboardLayoutLabels.displayLabel("English (US)", true, false, validVariants, {
            "en-US": "en"
        }), "en");
    }

    function test_overrideAppliesToUppercaseCodeOnlyLabel() {
        compare(KeyboardLayoutLabels.displayLabel("Armenian", true, false, validVariants, {}), "HY");
        compare(KeyboardLayoutLabels.displayLabel("Armenian", true, false, validVariants, {
            "HY": "am"
        }), "am");
    }

    function test_verticalLabelOverrideIsKeyedIndependentlyFromHorizontal() {
        compare(KeyboardLayoutLabels.verticalLabel("am-phonetic-alt", {}), "AM");
        compare(KeyboardLayoutLabels.verticalLabel("am-phonetic-alt", {
            "AM": "hy"
        }), "hy");
    }
}
