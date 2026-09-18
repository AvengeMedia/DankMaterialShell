import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar.Widgets
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

    property var barConfig: ({
            widgetPadding: 12,
            fontScale: 1,
            iconScale: 1,
            spacing: 4
        })
    property var axes: [
        {
            isVertical: false,
            edge: "top"
        },
        {
            isVertical: false,
            edge: "bottom"
        },
        {
            isVertical: true,
            edge: "left"
        },
        {
            isVertical: true,
            edge: "right"
        }
    ]
    property var cases: [
        {
            name: "clipboard",
            component: clipboard
        },
        {
            name: "notepad",
            component: notepad
        }
    ]
    property var loadOnly: [
        {
            name: "idle",
            component: idle
        },
        {
            name: "notifications",
            component: notifications
        },
        {
            name: "vpn",
            component: vpn
        },
        {
            name: "focused",
            component: focused
        },
        {
            name: "disk",
            component: disk
        }
    ]
    property var phases: ["closed", "open", "closed-again"]
    property var instances: []
    property int phase: 0

    Component {
        id: clipboard
        ClipboardButton {}
    }
    Component {
        id: notepad
        NotepadButton {}
    }
    Component {
        id: idle
        IdleInhibitor {}
    }
    Component {
        id: notifications
        NotificationCenterButton {}
    }
    Component {
        id: vpn
        Vpn {}
    }
    Component {
        id: focused
        FocusedApp {}
    }
    Component {
        id: disk
        DiskUsage {}
    }

    PanelWindow {
        id: stageWindow
        color: "transparent"
        implicitWidth: 1200
        implicitHeight: 700
        anchors {
            top: true
            left: true
        }

        Item {
            id: stage
            anchors.fill: parent
        }
    }

    function typeName(item) {
        return String(item).split("(")[0].replace(/_QMLTYPE_\d+/, "").replace(/_QML_\d+/, "");
    }

    function dump(item, origin) {
        const pos = item.mapToItem(origin, 0, 0);
        const entry = {
            type: typeName(item),
            x: Math.round(pos.x * 100) / 100,
            y: Math.round(pos.y * 100) / 100,
            w: item.width,
            h: item.height,
            opacity: Math.round(item.opacity * 100) / 100
        };
        if (typeof item.text === "string" && item.font !== undefined) {
            entry.text = item.text;
            entry.px = item.font.pixelSize;
        }
        if (item.color !== undefined)
            entry.color = String(item.color);
        if (item.radius !== undefined)
            entry.radius = item.radius;
        if (item.border !== undefined && item.border.width !== undefined)
            entry.border = [item.border.width, String(item.border.color)];
        entry.children = (item.children || []).filter(child => child.visible).map(child => dump(child, origin));
        return entry;
    }

    function menuOf(item) {
        for (let i = 0; i < item.data.length; i++) {
            const object = item.data[i];
            if (object && object.contextWindow && typeof object.hide === "function")
                return object;
        }
        return null;
    }

    function menuWindow(item) {
        return menuOf(item)?.contextWindow ?? null;
    }

    function snapshot() {
        const phaseName = root.phases[root.phase];
        for (const instance of root.instances) {
            const item = instance.item;
            const menu = menuWindow(item);
            check(item !== null && isFinite(item.minTooltipY), phaseName + " " + instance.name + " " + instance.edge + " loaded");
            if (typeof item.openContextMenu === "function") {
                check(menu !== null || phaseName === "closed", phaseName + " " + instance.name + " has a menu window");
                check((menu?.visible ?? false) === (phaseName === "open"), phaseName + " " + instance.name + " " + instance.edge + " menu visibility");
                if (phaseName === "open")
                    check(menu.screen?.name === stageWindow.screen?.name, phaseName + " " + instance.name + " menu on the widget screen");
            }
            const record = {
                phase: root.phases[root.phase],
                name: instance.name,
                edge: instance.edge,
                minTooltipY: item.minTooltipY,
                w: item.width,
                h: item.height,
                tree: dump(item.visualContent, item.visualContent),
                menuVisible: menu ? menu.visible : null,
                menuScreen: menu?.screen?.name ?? null,
                menu: menu && menu.visible ? dump(menu.contentItem, menu.contentItem) : null
            };
            console.log("PARITY " + JSON.stringify(record));
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        const created = [];
        let y = 0;
        for (const axis of root.axes) {
            for (const testCase of root.cases) {
                const item = testCase.component.createObject(stage, {
                    axis: axis,
                    barThickness: 48,
                    widgetThickness: 30,
                    barSpacing: 4,
                    barConfig: root.barConfig,
                    parentScreen: stageWindow.screen,
                    x: 300,
                    y: 80 + y
                });
                y += 60;
                created.push({
                    name: testCase.name,
                    edge: axis.edge,
                    item: item
                });
            }
        }
        for (const axis of root.axes) {
            for (const testCase of root.loadOnly) {
                const item = testCase.component.createObject(stage, {
                    axis: axis,
                    barThickness: 48,
                    widgetThickness: 30,
                    barSpacing: 4,
                    barConfig: root.barConfig,
                    parentScreen: stageWindow.screen,
                    x: 700,
                    y: 80 + y
                });
                y += 60;
                created.push({
                    name: testCase.name,
                    edge: axis.edge,
                    item: item
                });
            }
        }
        root.instances = created;
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            root.snapshot();
            root.phase++;
            if (root.phase >= root.phases.length) {
                root.finish();
                stop();
                Qt.quit();
                return;
            }
            for (const instance of root.instances) {
                if (typeof instance.item.openContextMenu !== "function")
                    continue;
                if (root.phases[root.phase] === "open")
                    instance.item.openContextMenu();
                else
                    root.menuOf(instance.item).hide();
            }
        }
    }
}
