import QtQuick
import QtTest
import "../../Modules/DankBar/Widgets/KeyboardLayoutLabels.js" as KeyboardLayoutLabels

TestCase {
    name: "KeyboardLayoutLabels"

    readonly property var validVariants: ["US", "UK", "GB", "AZERTY", "QWERTY", "Dvorak", "Colemak", "Mac", "Intl", "International"]

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
        const label = KeyboardLayoutLabels.displayLabel("English (US)", true, false, validVariants, {});
        compare(KeyboardLayoutLabels.displayLabel("English (US)", true, false, validVariants, {
            [label]: "en"
        }), "en");
    }

    function test_overrideAppliesToUppercaseCodeOnlyLabel() {
        const label = KeyboardLayoutLabels.displayLabel("Armenian", true, false, validVariants, {});
        compare(KeyboardLayoutLabels.displayLabel("Armenian", true, false, validVariants, {
            [label]: "am"
        }), "am");
    }

    function test_verticalLabelOverrideIsKeyedIndependentlyFromHorizontal() {
        const label = KeyboardLayoutLabels.verticalLabel("am-phonetic-alt", {});
        compare(KeyboardLayoutLabels.verticalLabel("am-phonetic-alt", {
            [label]: "hy"
        }), "hy");
    }
}
