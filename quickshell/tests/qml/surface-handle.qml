import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.Common
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    TestCase {
        id: input
        when: false
        name: "surface-handle"
    }

    DankModal {
        id: modal
        modalWidth: 333
        modalHeight: 222
        content: Component {
            Item {}
        }
    }

    DankPopout {
        id: popout
        popupWidth: 250
        popupHeight: 150
        content: Component {
            Item {}
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.barConfigs = [
            {
                id: "bar",
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
        SettingsData.frameScreenPreferences = ["all"];
    }

    function check(value, message) {
        if (!value)
            throw new Error(message);
    }

    function connectFrame() {
        SettingsData.frameEnabled = true;
        SettingsData.frameMode = "connected";
        FrameTransitionState.acknowledge(FrameTransitionState.revision);
        FrameTransitionState.syncEffective();
        NiriService._layoutAppliedRevision = NiriService._frameTransitionRevision;
        input.wait(100);
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            try {
                const screen = Quickshell.screens[0];
                const standaloneWindow = modal.contentWindow;
                root.check(standaloneWindow && modal.alignedWidth === Theme.px(333, modal.dpr), "modal backend reads the consumer width");
                modal.modalWidth = 444;
                root.check(modal.alignedWidth === Theme.px(444, modal.dpr), "modal backend follows a later width change");
                modal.open();
                input.wait(50);
                root.check(modal.shouldBeVisible && standaloneWindow.visible, "dispatcher open reaches the backend");
                modal.close();
                input.wait(50);
                root.check(!modal.shouldBeVisible, "backend close flows back to the dispatcher");
                for (let i = 0; i < 60 && modal.isClosing; i++)
                    input.wait(50);
                root.check(!modal.isClosing, "modal finishes closing");

                popout.setTriggerPosition(100, 0, 40, "left", screen, 0, 44, 4, SettingsData.barConfigs[0], null);
                const standalonePopout = popout.contentWindow;
                root.check(standalonePopout && popout.alignedWidth === Theme.px(250, popout.dpr) && popout.screen === screen, "popout backend reads width and screen from the handle");

                root.connectFrame();
                root.check(FrameTransitionState.effectiveConnectedFrameModeActive, "fixture entered connected frame mode");
                modal.open();
                input.wait(100);
                root.check(modal.contentWindow && modal.contentWindow !== standaloneWindow && modal.shouldBeVisible, "modal opens on the connected backend after the mode switch");
                root.check(modal.alignedWidth === Theme.px(444, modal.dpr), "connected modal backend reads the same consumer width");
                modal.close();
                input.wait(50);
                root.check(popout.contentWindow && popout.contentWindow !== standalonePopout && popout.alignedWidth === Theme.px(250, popout.dpr), "connected popout backend reads the same consumer width");
                popout.popupWidth = 300;
                root.check(popout.alignedWidth === Theme.px(300, popout.dpr), "connected popout follows a later width change");

                console.log("FIXTURE_PASS surface handle: consumer properties reach both backends across a mode switch, visibility syncs both ways");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
