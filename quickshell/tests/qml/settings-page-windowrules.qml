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
        WindowRulesTab {}
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
        check(states.length === 2, "window rules captured two states, got " + states.length);
        const [collapsed, expanded] = states;
        has("window rules", collapsed, ["Window rules", "Create rule for:", "Select a window...", "First Time Setup", "Rules (1)", "Float pavucontrol", "pavucontrol", "Float", "Opacity: 0.9", "User window rules (2)", "firefox (+1 more)", "firefox · title: Picture-in-Picture (+1 more)", "config.kdl", "Width: 50%", "Steam", "steam"]);
        lacks("window rules collapsed", collapsed, ["Match (2)", "Actions"]);
        has("window rules expanded", expanded, ["Match (2)", "• App ID: firefox   ·   Title: Picture-in-Picture", "• Floating: Yes", "Actions", "Float: Yes   ·   Width: 50%", "Source: niri/config.kdl"]);
        check(expanded.sections[3] > collapsed.sections[3], "expanding an external rule grows its section");
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
            if (step === 2) {
                root.tab.activeWindows = [
                    {
                        appId: "kitty",
                        title: "zsh"
                    }
                ];
                root.tab.windowRules = [
                    {
                        id: "r1",
                        name: "Float pavucontrol",
                        enabled: true,
                        source: "niri/dms/windowrules.kdl",
                        matchCriteria: {
                            appId: "pavucontrol"
                        },
                        actions: {
                            openFloating: true,
                            opacity: 0.9
                        }
                    }
                ];
                root.tab.externalRules = [
                    {
                        id: "e1",
                        name: "",
                        source: "niri/config.kdl",
                        matchCriteria: {
                            appId: "firefox",
                            title: "Picture-in-Picture"
                        },
                        matches: [
                            {
                                appId: "firefox",
                                title: "Picture-in-Picture"
                            },
                            {
                                isFloating: true
                            }
                        ],
                        actions: {
                            openFloating: true,
                            defaultColumnWidth: "50%"
                        }
                    },
                    {
                        id: "e2",
                        name: "Steam",
                        source: "niri/config.kdl",
                        matchCriteria: {
                            appId: "steam"
                        },
                        actions: {}
                    }
                ];
                return;
            }
            root.states.push(root.snapshot());
            if (step === 3) {
                root.tab.expandedExternalId = "e1";
                return;
            }
            stop();
            root.verify(root.states);
            root.finish();
        }
    }
}
