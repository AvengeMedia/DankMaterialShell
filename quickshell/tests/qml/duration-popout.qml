import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar.Popouts
import qs.Modules.DankBar.Widgets
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    TestCase {
        id: input
        when: false
        name: "duration-popout"
    }
    DurationPopout {
        id: popout
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.barConfigs = [
            {
                id: "main",
                enabled: true,
                visible: true,
                position: 0,
                spacing: 4,
                innerPadding: 4,
                leftWidgets: [],
                centerWidgets: [],
                rightWidgets: []
            }
        ];
        SessionData.setDoNotDisturb(false);
    }

    function check(value, message) {
        if (!value)
            throw new Error(message);
    }

    function collect(item, predicate, out) {
        if (predicate(item))
            out.push(item);
        for (const child of item.children ?? [])
            collect(child, predicate, out);
        return out;
    }

    function rows() {
        return collect(popout.contentLoader.item, c => typeof c.firstInGroup === "boolean" && c.visible, []);
    }

    function statusShown() {
        return collect(popout.contentLoader.item, c => c.text === popout.presets.status && c.visible, []).length > 0;
    }

    function open(source) {
        popout.prepareForTrigger(source);
        popout.screen = Quickshell.screens[0];
        popout.triggerX = 640;
        popout.triggerY = 0;
        popout.triggerWidth = 40;
        popout.open();
        input.wait(300);
    }

    function settle() {
        for (let i = 0; i < 30 && (popout.shouldBeVisible || popout.isClosing); i++)
            input.wait(50);
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            try {
                root.open("dndDuration");
                root.check(popout.shouldBeVisible && popout.contentLoader.item, "popout opens");
                root.check(root.rows().length === 7, "seven presets and no turn-off row while off: " + root.rows().length);

                const before = Date.now();
                root.rows()[0].clicked();
                root.check(SessionData.doNotDisturb, "selecting a preset enables do not disturb");
                root.check(Math.abs(SessionData.doNotDisturbUntil - (before + 15 * 60000)) < 2000, "fifteen minute preset sets the deadline");
                root.settle();
                root.check(!popout.shouldBeVisible, "selecting a preset closes the popout");

                root.open("dndDuration");
                root.check(root.statusShown() && root.rows().length === 8, "while on, the turn-off row appears with the status");
                root.rows()[7].clicked();
                root.check(!SessionData.doNotDisturb, "turn off row disables do not disturb");
                root.settle();

                root.open("idleInhibit");
                root.check(popout.presets === IdleInhibitPresets && root.rows().length === 7, "same popout serves keep awake presets");
                popout.close();
                root.settle();

                console.log("FIXTURE_PASS duration popout: dnd presets, deadline, turn off, keep awake source");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
