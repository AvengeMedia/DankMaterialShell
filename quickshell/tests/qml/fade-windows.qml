import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Lock
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property bool failed: false
    property int step: 0
    property var events: []

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function finish() {
        console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
    }

    function take() {
        const out = root.events;
        root.events = [];
        return JSON.stringify(out);
    }

    FadeToLockWindow {
        id: lockFade
        onFadeCompleted: root.events.push("lock:completed")
        onFadeCancelled: root.events.push("lock:cancelled")
    }

    FadeToDpmsWindow {
        id: dpmsFade
        onFadeCompleted: root.events.push("dpms:completed")
        onFadeCancelled: root.events.push("dpms:cancelled")
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.fadeToLockEnabled = true;
        SettingsData.fadeToDpmsEnabled = true;
        SettingsData.fadeToLockGracePeriod = 1;
        SettingsData.fadeToDpmsGracePeriod = 1;
        IdleService.isShellLocked = false;
        console.log("FADE colors lock=" + lockFade.contentItem.children[0].color + " dpms=" + dpmsFade.contentItem.children[0].color);
    }

    Timer {
        interval: 600
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                lockFade.startFade();
                dpmsFade.startFade();
                return;
            case 1:
                check(lockFade.active && lockFade.visible && dpmsFade.active && dpmsFade.visible, "both fades active after start");
                check(root.take() === "[]", "no completion before the grace period");
                lockFade.cancelFade();
                dpmsFade.cancelFade();
                return;
            case 2:
                check(!lockFade.active && !dpmsFade.active, "cancel mid-fade deactivates both");
                check(root.take() === JSON.stringify(["lock:cancelled", "dpms:cancelled"]), "cancel mid-fade emits cancelled once each");
                lockFade.startFade();
                dpmsFade.startFade();
                return;
            case 3:
            case 4:
                return;
            case 5:
                check(root.take() === JSON.stringify(["lock:completed", "dpms:completed"]), "both complete once after the grace period");
                check(lockFade.active && dpmsFade.active, "both stay up after completion");
                lockFade.cancelFade();
                dpmsFade.cancelFade();
                return;
            case 6:
                check(lockFade.active, "lock fade ignores cancel after completion");
                check(!dpmsFade.active, "dpms fade dismisses on cancel after completion");
                check(root.take() === JSON.stringify(["dpms:cancelled"]), "only dpms emits cancelled after completion");
                IdleService.isShellLocked = true;
                return;
            case 7:
                check(lockFade.active, "lock fade stays while the shell is locked");
                IdleService.isShellLocked = false;
                return;
            case 8:
                check(!lockFade.active, "lock fade dismisses on unlock after completion");
                check(root.take() === "[]", "unlock dismiss emits nothing");
                lockFade.startFade();
                dpmsFade.startFade();
                IdleService.isShellLocked = true;
                IdleService.isShellLocked = false;
                return;
            case 9:
                check(lockFade.active, "lock fade keeps running through an unlock before completion");
                check(!dpmsFade.active, "dpms fade dismisses on unlock before completion");
                check(root.take() === "[]", "unlock dismiss mid-fade emits nothing");
                lockFade.dismiss();
                SettingsData.fadeToLockEnabled = false;
                lockFade.startFade();
                check(!lockFade.active, "disabled lock fade does not start");
                root.finish();
                stop();
                Qt.quit();
            }
        }
    }
}
