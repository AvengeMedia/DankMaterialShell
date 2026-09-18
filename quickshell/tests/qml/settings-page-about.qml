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
        AboutTab {}
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
        const page = states[0];
        has("about", page, ["Version", "1.6.0", "API", "v7", "Status", "Connected", "Capabilities", "network", "clipboard", "Show welcome", "System check"]);
        check(page.contentHeight > 0, "about has scrollable content");
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
                DMSService.cliVersion = "1.6.0";
                DMSService.apiVersion = 7;
                DMSService.capabilities = ["network", "clipboard"];
                DMSService.isConnected = true;
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
            stop();
            root.verify([collect(root.tab, {
                    texts: [],
                    icons: [],
                    toggles: [],
                    dropdowns: [],
                    contentHeight: -1
                })]);
            root.finish();
        }
    }
}
