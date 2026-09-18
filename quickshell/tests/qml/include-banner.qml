import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Settings.Widgets
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    readonly property var kinds: ["outputs", "layout", "windowrules", "input", "binds"]
    property var includes: ({})
    property var banners: ({})
    property bool failed: false

    Component {
        id: includeComponent
        ConfigInclude {
            autoCheck: false
        }
    }

    Component {
        id: bannerComponent
        IncludeSetupBanner {}
    }

    PanelWindow {
        color: "transparent"
        implicitWidth: 900
        implicitHeight: 900
        anchors {
            top: true
            left: true
        }

        Column {
            id: stage
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12
        }
    }

    function typeName(item) {
        return String(item).split("(")[0].replace(/_QMLTYPE_\d+/, "").replace(/_QML_\d+/, "");
    }

    function collect(item, out) {
        switch (typeName(item)) {
        case "StyledText":
            out.texts.push(item.text);
            break;
        case "DankButton":
            out.button = item;
            break;
        }
        for (const child of item.children || [])
            collect(child, out);
        return out;
    }

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function forceCompositor(name) {
        CompositorService.isNiri = name === "niri";
        CompositorService.isHyprland = name === "hyprland";
        CompositorService.isMango = name === "mango";
        CompositorService.compositor = name;
    }

    function status(included, readOnly) {
        return {
            "exists": included,
            "included": included,
            "configFormat": readOnly ? "hyprlang" : "",
            "readOnly": readOnly
        };
    }

    function verifySetupOnNiri(kind) {
        const include = includes[kind];
        const banner = banners[kind];
        include.status = status(false, false);
        include.checking = false;
        check(include.compositorSupported, kind + " supported on niri");
        check(include.fragmentLabel === "dms/" + kind, kind + " fragment label is dms/" + kind + ", got " + include.fragmentLabel);
        check(!include.included && !include.readOnly, kind + " default status is not included and not read-only");
        check(banner.visible, kind + " banner shows when not included");
        const shown = collect(banner, {
            texts: [],
            button: null
        });
        check(shown.texts.includes("First Time Setup"), kind + " banner missing 'First Time Setup', got " + JSON.stringify(shown.texts));
        check(shown.button && shown.button.visible && shown.button.enabled && shown.button.text === "Setup", kind + " banner shows an enabled Setup button");
        include.fixing = true;
        check(shown.button.text === "Setting up..." && !shown.button.enabled, kind + " button disables while fixing");
        include.fixing = false;
        include.checking = true;
        check(!banner.visible, kind + " banner hides while checking");
        include.checking = false;
        include.status = status(true, false);
        check(include.included, kind + " included after status update");
        check(!banner.visible, kind + " banner hides once included");
    }

    function verifyLegacyOnHyprland(kind) {
        const include = includes[kind];
        const banner = banners[kind];
        include.status = status(false, true);
        check(include.readOnly, kind + " read-only on hyprland conf mode");
        check(banner.visible, kind + " legacy banner shows");
        const shown = collect(banner, {
            texts: [],
            button: null
        });
        check(shown.texts.includes("Hyprland conf mode"), kind + " legacy banner missing 'Hyprland conf mode', got " + JSON.stringify(shown.texts));
        check(!shown.texts.includes("First Time Setup"), kind + " legacy banner still shows 'First Time Setup'");
        check(shown.button && !shown.button.visible, kind + " legacy banner hides the Setup button");
        include.status = status(true, true);
        check(banner.visible && include.readOnly, kind + " legacy banner stays while included but read-only");
    }

    function verifyInputOffNiri() {
        const include = includes["input"];
        forceCompositor("hyprland");
        check(!include.compositorSupported, "input unsupported on hyprland");
        forceCompositor("mango");
        check(!include.compositorSupported, "input unsupported on mango");
        forceCompositor("niri");
        check(include.compositorSupported, "input supported again on niri");
    }

    function finish() {
        console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
        Qt.quit();
    }

    Timer {
        interval: 800
        running: true
        repeat: true
        property int step: 0
        onTriggered: {
            if (step++ === 0) {
                Quickshell.watchFiles = false;
                DC.Style.theme = Theme;
                DC.Style.settings = SettingsData;
                DC.I18n.backend = I18n;
                root.forceCompositor("niri");
                const includes = {};
                const banners = {};
                for (const kind of root.kinds) {
                    includes[kind] = includeComponent.createObject(root, {
                        includeKind: kind
                    });
                    banners[kind] = bannerComponent.createObject(stage, {
                        include: includes[kind]
                    });
                    if (!includes[kind] || !banners[kind]) {
                        console.error("FIXTURE_FAIL " + kind + " " + includeComponent.errorString() + bannerComponent.errorString());
                        Qt.quit();
                        return;
                    }
                }
                root.includes = includes;
                root.banners = banners;
                return;
            }
            if (step === 2) {
                for (const kind of root.kinds)
                    root.verifySetupOnNiri(kind);
                root.forceCompositor("hyprland");
                return;
            }
            stop();
            for (const kind of root.kinds.filter(kind => kind !== "input"))
                root.verifyLegacyOnHyprland(kind);
            root.check(!root.includes["input"].compositorSupported, "input unsupported on hyprland");
            root.verifyInputOffNiri();
            root.finish();
        }
    }
}
