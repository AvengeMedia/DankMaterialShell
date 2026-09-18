import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
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
            isVertical: true,
            edge: "left"
        }
    ]
    property var cases: [
        {
            name: "popup",
            section: "right",
            data: {
                trayAutoOverflow: true,
                trayMaxVisibleItems: 2
            }
        },
        {
            name: "popup-single",
            section: "right",
            data: {
                trayAutoOverflow: true,
                trayMaxVisibleItems: 2,
                trayPopupSingleLine: true
            }
        },
        {
            name: "popup-all",
            section: "right",
            data: {
                trayAutoOverflow: false
            }
        },
        {
            name: "inline-left",
            section: "left",
            data: {
                trayUseInlineExpansion: true,
                trayAutoOverflow: true,
                trayMaxVisibleItems: 2
            }
        },
        {
            name: "inline-right",
            section: "right",
            data: {
                trayUseInlineExpansion: true,
                trayAutoOverflow: true,
                trayMaxVisibleItems: 2
            }
        },
        {
            name: "inline-spaced",
            section: "left",
            data: {
                trayUseInlineExpansion: true,
                trayAutoOverflow: true,
                trayMaxVisibleItems: 1,
                trayIconSpacing: 8
            }
        }
    ]
    property var phases: ["closed", "open", "closed-again"]
    property var instances: []
    property int phase: 0

    Component {
        id: tray
        SystemTrayBar {}
    }

    PanelWindow {
        color: "transparent"
        implicitWidth: 1200
        implicitHeight: 800
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
            iw: item.implicitWidth,
            ih: item.implicitHeight,
            opacity: Math.round(item.opacity * 100) / 100,
            z: item.z
        };
        if (typeof item.text === "string" && item.font !== undefined) {
            entry.text = item.text;
            entry.px = item.font.pixelSize;
        }
        if (item.color !== undefined)
            entry.color = String(item.color);
        if (item.source !== undefined)
            entry.source = String(item.source);
        if (item.itemKey !== undefined)
            entry.key = item.itemKey;
        if (item.layer !== undefined && item.layer.enabled !== undefined)
            entry.layered = item.layer.enabled;
        entry.children = (item.children || []).filter(child => child.visible).map(child => dump(child, origin));
        return entry;
    }

    function popupContent(item) {
        for (let i = 0; i < item.data.length; i++) {
            const object = item.data[i];
            if (object && object.contentItem && object.anchors !== undefined && object.visible)
                return dump(object.contentItem, object.contentItem);
        }
        return null;
    }

    property var closedSizes: ({})
    property var carets: ({})

    function leaves(tree, out) {
        if (tree.text !== undefined)
            out.push(tree);
        for (const child of tree.children)
            leaves(child, out);
        return out;
    }

    function snapshot() {
        const phaseName = root.phases[root.phase];
        for (const instance of root.instances) {
            const item = instance.item;
            const popup = popupContent(item);
            const expectedHidden = {
                popup: 2,
                "popup-single": 2,
                "popup-all": 0,
                "inline-left": 2,
                "inline-right": 2,
                "inline-spaced": 3
            }[instance.name];
            check(item.hiddenBarItems.length === expectedHidden, phaseName + " " + instance.name + " hidden items " + item.hiddenBarItems.length);
            const caret = leaves(dump(item.visualContent, item.visualContent), []).find(leaf => leaf.text && leaf.text.startsWith("keyboard_arrow_"));
            check((caret !== undefined) === (expectedHidden > 0), phaseName + " " + instance.name + " overflow caret presence");
            check(item.menuOpen === (phaseName === "open"), phaseName + " " + instance.name + " menuOpen state");
            if (caret)
                root.carets[instance.name + instance.vertical + phaseName] = caret.text;
            if (caret && phaseName === "open")
                check(root.carets[instance.name + instance.vertical + "closed"] !== caret.text, phaseName + " " + instance.name + " caret flips when the menu opens");
            const size = instance.vertical ? item.visualHeight : item.visualWidth;
            const key = instance.name + instance.vertical;
            if (phaseName === "closed")
                root.closedSizes[key] = size;
            if (phaseName === "open" && instance.name.startsWith("inline"))
                check(size > root.closedSizes[key], phaseName + " " + instance.name + " inline expansion grows the bar widget");
            if (phaseName === "closed-again")
                check(size === root.closedSizes[key], phaseName + " " + instance.name + " size restored");
            const record = {
                phase: phaseName,
                name: instance.name,
                vertical: instance.vertical,
                visible: item.visible,
                trayCount: item.allTrayItems.length,
                hidden: item.hiddenBarItems.length,
                menuOpen: item.menuOpen,
                w: item.width,
                h: item.height,
                visualW: item.visualWidth,
                visualH: item.visualHeight,
                tree: dump(item.visualContent, item.visualContent),
                popup: popup
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
                const item = tray.createObject(stage, {
                    axis: axis,
                    barThickness: 48,
                    widgetThickness: 30,
                    barSpacing: 4,
                    barConfig: root.barConfig,
                    widgetData: testCase.data,
                    section: testCase.section,
                    y: y
                });
                y += 140;
                created.push({
                    name: testCase.name,
                    vertical: axis.isVertical,
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
        property int ticks: 0
        onTriggered: {
            ticks++;
            if (SystemTray.items.values.length < 4 && ticks < 12)
                return;
            check(SystemTray.items.values.length === 4, "four tray items registered, got " + SystemTray.items.values.length);
            root.snapshot();
            root.phase++;
            if (root.phase >= root.phases.length) {
                root.finish();
                stop();
                Qt.quit();
                return;
            }
            for (const instance of root.instances)
                instance.item.menuOpen = root.phases[root.phase] === "open";
        }
    }
}
