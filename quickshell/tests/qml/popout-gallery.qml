import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.ProcessList
import qs.Modules.Notifications.Center
import qs.Modules.DankBar.Popouts
import qs.Modules.DankBar.Widgets
import qs.Modules.ControlCenter
import qs.Modules.DankDash
import qs.Modals.Clipboard
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    readonly property string shotDir: Quickshell.env("DMS_FIXTURE_SHOTS")
    property var cases: [
        {
            name: "process-list",
            component: processList
        },
        {
            name: "notification-center",
            component: notificationCenter
        },
        {
            name: "battery",
            component: battery
        },
        {
            name: "system-update",
            component: systemUpdate
        },
        {
            name: "vpn",
            component: vpn
        },
        {
            name: "dwl-layout",
            component: dwlLayout
        },
        {
            name: "color-picker",
            component: colorPicker
        },
        {
            name: "clipboard",
            component: clipboard
        },
        {
            name: "focused-window",
            component: focusedWindow
        },
        {
            name: "power-menu",
            component: powerMenu
        },
        {
            name: "duration",
            component: duration
        },
        {
            name: "control-center",
            component: controlCenter,
            openFocus: "ControlCenterContent",
            key: Qt.Key_Tab,
            ringsAfterKey: 1
        },
        {
            name: "dash",
            component: dash,
            openFocus: "CalendarOverviewCard",
            key: Qt.Key_Right,
            modifiers: Qt.AltModifier,
            ringsAfterKey: 0
        }
    ]
    property int caseIndex: -1
    property var current: null
    property bool failed: false

    Component {
        id: processList
        ProcessListPopout {}
    }
    Component {
        id: notificationCenter
        NotificationCenterPopout {}
    }
    Component {
        id: battery
        BatteryPopout {}
    }
    Component {
        id: systemUpdate
        SystemUpdatePopout {}
    }
    Component {
        id: vpn
        VpnPopout {}
    }
    Component {
        id: dwlLayout
        DWLLayoutPopout {}
    }
    Component {
        id: colorPicker
        ColorPickerPopout {}
    }
    Component {
        id: clipboard
        ClipboardHistoryPopout {}
    }
    Component {
        id: focusedWindow
        FocusedWindowContextMenu {
            currentWindow: ({
                    appId: "org.kde.dolphin",
                    title: "Home",
                    pid: 4242
                })
        }
    }
    Component {
        id: powerMenu
        PowerMenuPopout {}
    }
    Component {
        id: duration
        DurationPopout {}
    }
    Component {
        id: controlCenter
        ControlCenterPopout {}
    }
    Component {
        id: dash
        DankDashPopout {}
    }

    function typeName(item) {
        return String(item).split("(")[0].replace(/_QMLTYPE_\d+/, "").replace(/_QML_\d+/, "");
    }

    function paddingOf(item, depth) {
        if (!item || depth > 6)
            return null;
        for (const child of item.children || []) {
            const type = typeName(child);
            if ((type.endsWith("Column") || type.endsWith("ColumnLayout") || type.endsWith("Flickable") || type === "QQuickItem") && (child.anchors?.margins > 0 || child.x > 0))
                return {
                    type: type,
                    margins: child.anchors?.margins ?? 0,
                    x: child.x,
                    y: child.y,
                    spacing: child.spacing ?? null
                };
            const found = paddingOf(child, depth + 1);
            if (found)
                return found;
        }
        return null;
    }

    function visibleRings(item, depth) {
        if (!item || depth > 14)
            return 0;
        let count = typeName(item) === "FocusRing" && item.visible ? 1 : 0;
        for (const child of item.children || [])
            count += visibleRings(child, depth + 1);
        return count;
    }

    function focusName(content) {
        return typeName(content.Window.window?.activeFocusItem);
    }

    function headerOf(item, depth) {
        if (!item || depth > 8)
            return null;
        for (const child of item.children || []) {
            if (typeName(child) === "DankWindowHeader")
                return {
                    shared: true,
                    height: child.height,
                    title: child.title
                };
            const found = headerOf(child, depth + 1);
            if (found)
                return found;
        }
        return null;
    }

    function advance() {
        if (root.current) {
            root.current.close();
            root.current.destroy();
            root.current = null;
        }
        caseIndex++;
        if (caseIndex >= cases.length) {
            console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
            Qt.quit();
            return;
        }
        const popout = cases[caseIndex].component.createObject(root);
        if (!popout) {
            console.log("FIXTURE_FAIL could not create " + cases[caseIndex].name);
            root.failed = true;
            Qt.callLater(advance);
            return;
        }
        root.current = popout;
        popout.screen = Quickshell.screens[0];
        popout.triggerX = 640;
        popout.triggerY = 0;
        popout.triggerWidth = 40;
        popout.open();
        settle.restart();
    }

    TestCase {
        id: input
        when: false
        name: "popout-gallery"
    }

    Process {
        id: shot
        onExited: root.advance()
    }

    function finishCase() {
        if (!root.shotDir) {
            Qt.callLater(root.advance);
            return;
        }
        shot.command = ["niri", "msg", "action", "screenshot-screen", "--show-pointer", "false", "--path", root.shotDir + "/" + root.cases[root.caseIndex].name + ".png"];
        shot.running = true;
    }

    Timer {
        id: afterKey
        interval: 400
        onTriggered: {
            const name = root.cases[root.caseIndex].name;
            const content = root.current.contentLoader?.item ?? null;
            const entry = root.cases[root.caseIndex];
            const rings = visibleRings(content, 0);
            const focus = focusName(content);
            console.log("PARITY " + JSON.stringify({
                name: name,
                afterKey: true,
                rings: rings,
                focus: focus
            }));
            if (rings !== entry.ringsAfterKey || focus === entry.openFocus) {
                console.log("FIXTURE_FAIL " + name + " after keyboard navigation focus=" + focus + " rings=" + rings);
                root.failed = true;
            }
            root.finishCase();
        }
    }

    Timer {
        id: settle
        interval: 1500
        onTriggered: {
            const popout = root.current;
            const content = popout.contentLoader?.item ?? null;
            if (!content) {
                console.log("FIXTURE_FAIL " + root.cases[root.caseIndex].name + " has no content item");
                root.failed = true;
            }
            const entry = root.cases[root.caseIndex];
            const rings = visibleRings(content, 0);
            console.log("PARITY " + JSON.stringify({
                name: entry.name,
                visible: popout.shouldBeVisible,
                width: popout.popupWidth,
                height: popout.popupHeight,
                padding: content ? paddingOf(content, 0) : null,
                header: content ? headerOf(content, 0) : null,
                rings: rings,
                focus: content ? focusName(content) : null
            }));
            if (rings > 0 || (entry.openFocus !== undefined && content && focusName(content) !== entry.openFocus)) {
                console.log("FIXTURE_FAIL " + entry.name + " on open focus=" + (content ? focusName(content) : null) + " rings=" + rings);
                root.failed = true;
            }
            if (entry.key === undefined || !content) {
                root.finishCase();
                return;
            }
            input.keyClick(entry.key, entry.modifiers ?? Qt.NoModifier);
            afterKey.restart();
        }
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
        Qt.callLater(advance);
    }
}
