import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Settings
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var tab: null
    readonly property int pageHeight: 1800

    Component {
        id: tabComponent
        PrinterTab {}
    }

    PanelWindow {
        color: "transparent"
        implicitWidth: 900
        implicitHeight: 1800
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

    function collect(item, out) {
        if (!item.visible)
            return out;
        switch (typeName(item)) {
        case "DankIcon":
            out.icons.push(item.name);
            return out;
        case "StyledText":
            out.texts.push(item.text);
            break;
        case "DankToggle":
            out.toggles.push(item.checked);
            break;
        case "DankDropdown":
            out.dropdowns.push(item.currentValue);
            break;
        }
        if (out.contentHeight < 0 && item.contentHeight !== undefined && item.contentItem !== undefined) {
            out.contentHeight = Math.round(item.contentHeight);
            const column = item.contentItem.children[0];
            out.sections = Array.from(column?.children ?? []).filter(child => child.visible && child.height > 0).map(child => Math.round(child.height));
        }
        for (const child of item.children || [])
            collect(child, out);
        return out;
    }

    property var states: []

    function snapshot() {
        const layout = collect(root.tab, {
            texts: [],
            icons: [],
            toggles: [],
            dropdowns: [],
            contentHeight: -1
        });
        layout.implicitHeight = Math.round(root.tab.implicitHeight);
        return layout;
    }

    property bool failed: false

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function has(name, state, texts) {
        for (const text of texts)
            check(state.texts.includes(text), name + " missing text '" + text + "'");
    }

    function lacks(name, state, texts) {
        for (const text of texts)
            check(!state.texts.includes(text), name + " still shows '" + text + "'");
    }

    function finish() {
        console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
        Qt.quit();
    }

    function verify(states) {
        check(states.length === 2, "printer captured two states, got " + states.length);
        const [discover, manual] = states;
        has("printer discover", discover, ["CUPS Print Server", "Available", "Printers", "Total jobs", "Add printer", "Discover devices", "Add by address", "Select device...", "Select driver...", "Create printer", "2 printers", "office-laser", "Idle", "2 jobs", "HP LaserJet Pro", "Room 2", "[12] Pending", "[13] Completed", "garage-inkjet", "Stopped", "Paused", "Resume", "Accept jobs", "Classes", "1 class", "all-printers"]);
        check(discover.texts.filter(text => text === "2").length === 2, "printer and job counts both read 2");
        check(JSON.stringify(discover.dropdowns) === JSON.stringify(["Select device...", "Select driver..."]), "discover mode shows device and driver pickers, got " + JSON.stringify(discover.dropdowns));
        has("printer manual", manual, ["Host", "Port", "Protocol", "ipp", "Printer reachable", "HP LaserJet Pro", "Test connection", "Create printer"]);
        lacks("printer manual", manual, ["Select device..."]);
        check(manual.dropdowns[0] === "ipp", "manual entry defaults to ipp, got " + JSON.stringify(manual.dropdowns));
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        property int step: 0
        onTriggered: {
            if (step++ === 0) {
                Quickshell.watchFiles = false;
                DC.Style.theme = Theme;
                DC.Style.settings = SettingsData;
                DC.I18n.backend = I18n;
                CupsService.cupsAvailable = true;
                CupsService.updatePrinters([
                    {
                        name: "office-laser",
                        state: "idle",
                        stateReason: "none",
                        location: "Room 2",
                        makeModel: "HP LaserJet Pro",
                        accepting: true
                    },
                    {
                        name: "garage-inkjet",
                        state: "stopped",
                        stateReason: "paused",
                        accepting: false
                    }
                ]);
                const printers = Object.assign({}, CupsService.printers);
                printers["office-laser"].jobs = [
                    {
                        id: 12,
                        state: "pending",
                        size: 20480,
                        timeCreated: "2026-09-12T10:00:00"
                    },
                    {
                        id: 13,
                        state: "completed",
                        size: 1024,
                        timeCreated: "2026-09-12T09:00:00"
                    }
                ];
                CupsService.printers = printers;
                CupsService.expandedPrinter = "garage-inkjet";
                CupsService.printerClasses = [
                    {
                        name: "all-printers",
                        members: ["office-laser", "garage-inkjet"]
                    }
                ];
                root.tab = tabComponent.createObject(stage, {
                    width: stage.width,
                    height: root.pageHeight
                });
                if (!root.tab) {
                    console.error("FIXTURE_FAIL " + tabComponent.errorString());
                    Qt.quit();
                    return;
                }
                root.tab.showAddPrinter = true;
                return;
            }
            root.states.push(root.snapshot());
            if (step === 2) {
                root.tab.manualEntryMode = true;
                root.tab.manualHost = "10.0.0.5";
                root.tab.testConnectionResult = {
                    success: true,
                    data: {
                        reachable: true,
                        makeModel: "HP LaserJet Pro"
                    }
                };
                return;
            }
            stop();
            root.verify(root.states);
            root.finish();
        }
    }
}
