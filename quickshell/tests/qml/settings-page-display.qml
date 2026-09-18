import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Settings
import qs.Modules.Settings.DisplayConfig
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var tab: null
    readonly property int pageHeight: 1800

    Component {
        id: tabComponent
        DisplayConfigTab {}
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
        check(states.length === 3, "display captured three states, got " + states.length);
        const [idle, newProfile, editMonitors] = states;
        has("display idle", idle, ["First Time Setup", "Profiles", "Auto", "No profiles", "Arrangement", "Name format", "1 disconnected (hidden)"]);
        check(JSON.stringify(idle.toggles) === "[false,true]", "display idle toggles are auto off and snap on, got " + JSON.stringify(idle.toggles));
        has("display new profile", newProfile, ["Profile name", "Create", "Cancel"]);
        lacks("display new profile", newProfile, ["No profiles"]);
        has("display edit monitors", editMonitors, ["HDMI-A-1", "Disconnected", "Save", "Cancel"]);
        check(editMonitors.toggles.length === 3 && editMonitors.toggles[1] === false, "disconnected monitor row starts unchecked, got " + JSON.stringify(editMonitors.toggles));
        check(editMonitors.contentHeight > idle.contentHeight, "edit monitors dialog grows the page");
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
                WlrOutputService.wlrOutputAvailable = true;
                DisplayConfigState.allOutputs = {
                    "HDMI-A-1": {
                        name: "HDMI-A-1",
                        make: "Dell",
                        model: "U2720Q",
                        connected: false
                    }
                };
                root.tab = tabComponent.createObject(stage, {
                    width: stage.width,
                    height: root.pageHeight
                });
                if (!root.tab) {
                    console.error("FIXTURE_FAIL " + tabComponent.errorString());
                    Qt.quit();
                }
                return;
            }
            root.states.push(root.snapshot());
            if (step === 2) {
                root.tab.showNewProfileDialog = true;
                return;
            }
            if (step === 3) {
                root.tab.showNewProfileDialog = false;
                root.tab.editMonitorSelection = {};
                root.tab.showEditMonitorsDialog = true;
                return;
            }
            stop();
            root.verify(root.states);
            root.finish();
        }
    }
}
