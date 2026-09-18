import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.DankDash
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var popout: null
    property bool failed: false
    property int step: 0

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function typeName(item) {
        return String(item).split("(")[0].replace(/_QMLTYPE_\d+/, "").replace(/_QML_\d+/, "");
    }

    function findBy(item, pred, depth) {
        if (!item || depth > 30)
            return null;
        if (pred(item))
            return item;
        for (const child of item.children || []) {
            const found = findBy(child, pred, depth + 1);
            if (found)
                return found;
        }
        return null;
    }

    function content() {
        return root.popout.contentLoader?.item ?? null;
    }

    function grid() {
        return findBy(content(), item => typeName(item) === "DashCardGrid", 0);
    }

    function list() {
        return findBy(content(), item => typeName(item) === "KeyboardNavigatedNotificationList", 0);
    }

    function focusName() {
        return typeName(content().Window.window?.activeFocusItem);
    }

    function state(label) {
        const l = list();
        const c = l?.keyboardController ?? null;
        const s = {
            label: label,
            focus: focusName(),
            notifications: NotificationService.notifications.length,
            listKeyboardActive: l?.keyboardActive ?? null,
            focusAllowed: l?.focusAllowed ?? null,
            navActive: c?.keyboardNavigationActive ?? null,
            selected: c?.selectedFlatIndex ?? null,
            contentY: l ? Math.round(l.contentY) : null
        };
        console.log("PARITY " + JSON.stringify(s));
        return s;
    }

    TestCase {
        id: input
        when: false
        name: "dash-notifications-keys"
    }

    Component {
        id: dashComp
        DankDashPopout {}
    }

    Process {
        id: notify
        command: ["sh", "-c", "for i in 1 2 3 4; do notify-send -a app$i \"Note $i\" \"Body of note $i\" || echo \"notify-send $i exit $?\"; done; echo bus=$DBUS_SESSION_BUS_ADDRESS"]
        stdout: StdioCollector {
            onStreamFinished: console.log("NOTIFY stdout: " + text.trim())
        }
        stderr: StdioCollector {
            onStreamFinished: console.log("NOTIFY stderr: " + text.trim())
        }
        onExited: (code, status) => console.log("NOTIFY exit " + code)
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
        root.popout = dashComp.createObject(root);
        root.popout.screen = Quickshell.screens[0];
        root.popout.triggerX = 640;
        root.popout.triggerY = 0;
        root.popout.triggerWidth = 40;
    }

    Timer {
        interval: 1200
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                return;
            case 1:
                notify.running = true;
                return;
            case 2:
                if (NotificationService.notifications.length < 3)
                    notify.running = true;
                root.popout.requestTab("overview");
                root.popout.dashVisible = true;
                return;
            case 3:
                {
                    const s = root.state("open");
                    check(s.notifications >= 3, "notifications arrived: " + s.notifications);
                    const g = root.grid();
                    const slot = g?.slotFor("notifications") ?? null;
                    check(!!g && !!slot, "overview grid and notifications slot present");
                    if (!slot)
                        return;
                    g.focusSlot(slot, Qt.TabFocusReason);
                    return;
                }
            case 4:
                {
                    const s = root.state("card-focused");
                    check(s.focus === "NotificationsTab", "card focus lands on NotificationsTab, got " + s.focus);
                    input.keyClick(Qt.Key_Down);
                    return;
                }
            case 5:
                {
                    const s = root.state("after-down-1");
                    check(s.navActive === true && s.listKeyboardActive === true && s.focusAllowed === true, "first Down starts keyboard navigation");
                    check(s.selected === 0, "first Down selects the first notification");
                    input.keyClick(Qt.Key_Down);
                    return;
                }
            case 6:
                {
                    const s = root.state("after-down-2");
                    check(s.selected === 1, "second Down selects the second notification, got " + s.selected);
                    check(s.focus === "NotificationsTab", "focus stays on NotificationsTab, got " + s.focus);
                    root.popout.requestTab("notifications");
                    return;
                }
            case 7:
                {
                    const s = root.state("tab-open");
                    check(root.popout.activeTabId === "notifications", "notifications tab active");
                    input.keyClick(Qt.Key_Down);
                    return;
                }
            case 8:
                {
                    const s = root.state("tab-down-1");
                    input.keyClick(Qt.Key_Down);
                    return;
                }
            case 9:
                {
                    const s = root.state("tab-down-2");
                    input.keyClick(Qt.Key_Down);
                    return;
                }
            case 10:
                {
                    const s = root.state("tab-down-3");
                    check(s.navActive === true && s.listKeyboardActive === true && s.focusAllowed === true, "tab: keyboard navigation active after Down presses");
                    check(s.selected >= 1, "tab: selection advanced, got " + s.selected);
                    check(s.focus === "NotificationsTab", "tab: focus on NotificationsTab, got " + s.focus);
                    root.popout.dashVisible = false;
                    return;
                }
            case 11:
                console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
                stop();
                Qt.quit();
            }
        }
    }
}
