import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Settings
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

    property var pickers: []
    property int step: 0
    property var events: []
    property string expectedDesktop: ""

    Component {
        id: barPicker
        WidgetSelectionPopup {
            onWidgetSelected: (widgetId, targetSection) => root.events.push("bar:" + widgetId + ":" + targetSection)
        }
    }
    Component {
        id: desktopPicker
        DesktopWidgetBrowser {
            onWidgetAdded: widgetType => root.events.push("desktop:" + widgetType)
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
            h: item.height
        };
        if (typeof item.text === "string" && item.font !== undefined) {
            entry.text = item.text;
            entry.px = item.font.pixelSize;
        }
        if (item.color !== undefined)
            entry.color = String(item.color);
        if (item.border !== undefined && item.border.width !== undefined)
            entry.border = [item.border.width, String(item.border.color)];
        entry.children = (item.children || []).filter(child => child.visible).map(child => dump(child, origin));
        return entry;
    }

    function snapshot(label) {
        for (const picker of root.pickers) {
            const win = picker.item;
            console.log("PARITY " + JSON.stringify({
                label: label,
                name: picker.name,
                visible: win.visible,
                title: win.title,
                objectName: win.objectName,
                filtered: (win.filteredWidgets || []).map(w => w.id),
                selectedIndex: win.selectedIndex,
                nav: win.keyboardNavigationActive,
                tree: dump(win.contentItem, win.contentItem)
            }));
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        const bar = barPicker.createObject(root);
        const desktop = desktopPicker.createObject(root);
        root.pickers = [
            {
                name: "bar",
                item: bar
            },
            {
                name: "desktop",
                item: desktop
            }
        ];
    }

    Timer {
        interval: 1200
        running: true
        repeat: true
        onTriggered: {
            const bar = root.pickers[0].item;
            const desktop = root.pickers[1].item;
            switch (root.step++) {
            case 0:
                bar.targetSection = "center";
                bar.widgets = [
                    {
                        id: "clock",
                        text: "Clock",
                        description: "Time and date",
                        icon: "schedule"
                    },
                    {
                        id: "cpuUsage",
                        text: "CPU usage",
                        description: "Processor load",
                        icon: "memory"
                    },
                    {
                        id: "battery",
                        text: "Battery",
                        description: "Charge level",
                        icon: "battery_full"
                    }
                ];
                bar.show();
                desktop.show();
                return;
            case 1:
                root.snapshot("open");
                check(bar.visible && desktop.visible, "both pickers visible after show");
                check(JSON.stringify(bar.filteredWidgets.map(w => w.id)) === JSON.stringify(["clock", "cpuUsage", "battery"]), "bar picker lists the injected widgets");
                check(desktop.filteredWidgets.length > 0 && desktop.filteredWidgets.every(w => w.id && w.name), "desktop picker lists registry widgets");
                bar.searchQuery = "cpu";
                bar.updateFilteredWidgets();
                desktop.searchQuery = "clock";
                desktop.updateFilteredWidgets();
                return;
            case 2:
                root.snapshot("searched");
                check(JSON.stringify(bar.filteredWidgets.map(w => w.id)) === JSON.stringify(["cpuUsage"]), "bar search narrows to cpuUsage");
                check(desktop.filteredWidgets.length > 0 && desktop.filteredWidgets.every(w => (w.name + w.id + (w.description || "")).toLowerCase().includes("clock")), "desktop search narrows to clock widgets");
                root.expectedDesktop = desktop.filteredWidgets[0]?.id ?? "";
                bar.selectNext();
                desktop.selectNext();
                desktop.selectNext();
                return;
            case 3:
                root.snapshot("navigated");
                check(bar.selectedIndex === 0 && bar.keyboardNavigationActive, "bar keyboard selection on first result");
                check(desktop.selectedIndex === 0 && desktop.keyboardNavigationActive, "desktop keyboard selection clamps to the single result");
                bar.selectWidget();
                desktop.selectWidget();
                return;
            case 4:
                root.snapshot("chosen");
                check(!bar.visible && !desktop.visible, "both pickers hidden after choosing");
                check(JSON.stringify(root.events) === JSON.stringify(["bar:cpuUsage:center", "desktop:" + root.expectedDesktop]), "chosen events " + JSON.stringify(root.events));
                console.log("PARITY_EVENTS " + JSON.stringify(root.events));
                root.finish();
                stop();
                Qt.quit();
            }
        }
    }
}
