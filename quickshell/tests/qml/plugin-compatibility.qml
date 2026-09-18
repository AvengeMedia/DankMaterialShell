import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DankCommon.Common as DC

ShellRoot {
    id: root
    property var objects: []
    Item {
        id: host
    }
    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        try {
            const paths = ["ExampleEmojiPlugin/EmojiWidget", "ExampleCompositePlugin/CompositeBarWidget", "ExampleCompositePlugin/CompositeDesktopWidget", "ExampleCompositePlugin/CompositeDaemon", "ExampleDesktopClock/DesktopClock", "LauncherExample/LauncherExampleLauncher", "ExampleWithVariants/VariantWidget", "AttachedPanelExample/AttachedPanelExample"];
            for (const path of paths) {
                const component = Qt.createComponent("PLUGINS/" + path + ".qml");
                if (component.status !== Component.Ready)
                    throw new Error(component.errorString());
                const item = component.createObject(host, {
                    pluginService: PluginService
                });
                if (!item)
                    throw new Error("create " + path + ": " + component.errorString());
                if (path.includes("LauncherExample") && item.getItems("Test Item 1").length !== 1)
                    throw new Error("launcher filtering");
                objects.push(item);
            }
        } catch (error) {
            console.error("FIXTURE_FAIL", error.message);
            Qt.quit();
        }
    }
    Timer {
        running: true
        interval: 900
        onTriggered: {
            for (const item of root.objects)
                item.destroy();
            console.log("FIXTURE_PASS", root.objects.length, "unchanged plugin components");
            Qt.quit();
        }
    }
}
