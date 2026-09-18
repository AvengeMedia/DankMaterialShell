import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Settings
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property bool failed: false
    property int step: 0
    property var theme: null
    property var plugin: null

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function finish() {
        console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
    }

    function typeName(item) {
        return String(item).split("(")[0].replace(/_QMLTYPE_\d+/, "").replace(/_QML_\d+/, "");
    }

    function collect(item, origin, out) {
        const kids = (item.children || []).filter(child => child.visible && child.width > 0 && child.height > 0);
        const paints = item.color !== undefined || (typeof item.text === "string" && item.font !== undefined) || item.source !== undefined;
        if (paints || kids.length === 0) {
            const pos = item.mapToItem(origin, 0, 0);
            const entry = {
                type: typeName(item),
                x: Math.round(pos.x * 100) / 100,
                y: Math.round(pos.y * 100) / 100,
                w: Math.round(item.width * 100) / 100,
                h: Math.round(item.height * 100) / 100
            };
            if (typeof item.text === "string" && item.font !== undefined) {
                entry.text = item.text;
                entry.px = item.font.pixelSize;
            }
            if (item.color !== undefined)
                entry.color = String(item.color);
            if (item.border !== undefined && item.border.width !== undefined)
                entry.border = [item.border.width, String(item.border.color)];
            if (item.opacity !== 1)
                entry.opacity = Math.round(item.opacity * 100) / 100;
            out.push(entry);
        }
        for (const child of kids)
            collect(child, origin, out);
    }

    function state(win) {
        return {
            visible: win.visible,
            title: win.title,
            objectName: win.objectName,
            query: win.searchQuery,
            selectedIndex: win.selectedIndex,
            nav: win.keyboardNavigationActive,
            loading: win.isLoading,
            detail: win.detailPluginId ?? null,
            hasFocus: win.activeFocusItem ? typeName(win.activeFocusItem) : ""
        };
    }

    function snapshot(label) {
        for (const pair of [["theme", root.theme], ["plugin", root.plugin]]) {
            const win = pair[1];
            const nodes = [];
            collect(win.contentItem, win.contentItem, nodes);
            console.log("PARITY " + JSON.stringify({
                label: label,
                name: pair[0],
                state: state(win),
                nodes: nodes
            }));
        }
    }

    Component {
        id: themeComp
        ThemeBrowser {}
    }
    Component {
        id: pluginComp
        PluginBrowser {}
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        root.theme = themeComp.createObject(root);
        root.plugin = pluginComp.createObject(root);
    }

    readonly property var themes: [
        {
            id: "nord",
            name: "Nord",
            description: "Arctic palette",
            author: "arctic",
            installed: true,
            sourceDir: "nord"
        },
        {
            id: "dracula",
            name: "Dracula",
            description: "Dark purple",
            author: "count",
            installed: false,
            variants: {
                type: "single",
                default: "purple",
                options: [
                    {
                        id: "purple"
                    },
                    {
                        id: "blue"
                    }
                ]
            }
        },
        {
            id: "breeze",
            name: "Breeze",
            description: "Blue KDE",
            author: "kde",
            installed: false,
            wcag: {
                dark: {
                    breakdown: [
                        {
                            level: "AAA"
                        }
                    ]
                }
            }
        }
    ]
    readonly property var plugins: [
        {
            id: "cpuGraph",
            name: "CPU graph",
            description: "Processor history",
            author: "ann",
            category: "system",
            firstParty: true,
            capabilities: ["widget"],
            installed: false,
            upvotes: 12,
            status: ["reviewed"],
            version: "1.2",
            similar: ["ramGraph"]
        },
        {
            id: "ramGraph",
            name: "RAM graph",
            description: "Memory history",
            author: "bob",
            category: "system",
            firstParty: true,
            capabilities: ["widget"],
            installed: true,
            upvotes: 4,
            status: []
        },
        {
            id: "weatherTile",
            name: "Weather tile",
            description: "Forecast card",
            author: "cara",
            category: "weather",
            firstParty: true,
            capabilities: ["desktop"],
            installed: false,
            upvotes: 7,
            status: ["reviewed"]
        }
    ]

    Timer {
        interval: 1200
        running: true
        repeat: true
        onTriggered: {
            const theme = root.theme;
            const plugin = root.plugin;
            switch (root.step++) {
            case 0:
                theme.show();
                plugin.show();
                return;
            case 1:
                SessionData.setPluginBrowserHideInstalled(false);
                SessionData.setPluginBrowserInstalledFirst(false);
                SessionData.setPluginBrowserSortMode("default");
                SessionData.setShowThirdPartyPlugins(true);
                theme.isLoading = false;
                theme.loadError = "";
                theme.allThemes = root.themes;
                theme.updateFilteredThemes();
                plugin.isLoading = false;
                plugin.loadError = "";
                plugin.allPlugins = root.plugins;
                plugin.updateFilteredPlugins();
                return;
            case 2:
                root.snapshot("open");
                check(theme.visible && plugin.visible, "both browsers visible");
                check(JSON.stringify(theme.filteredThemes.map(t => t.id)) === JSON.stringify(["nord", "dracula", "breeze"]), "theme list " + JSON.stringify(theme.filteredThemes.map(t => t.id)));
                check(JSON.stringify(plugin.filteredPlugins.map(p => p.id)) === JSON.stringify(["cpuGraph", "weatherTile", "ramGraph"]), "plugin list sorted by votes " + JSON.stringify(plugin.filteredPlugins.map(p => p.id)));
                theme.searchQuery = "b";
                theme.updateFilteredThemes();
                plugin.searchQuery = "graph";
                plugin.updateFilteredPlugins();
                return;
            case 3:
                root.snapshot("searched");
                check(JSON.stringify(theme.filteredThemes.map(t => t.id)) === JSON.stringify(["breeze"]), "theme search narrows to breeze");
                check(JSON.stringify(plugin.filteredPlugins.map(p => p.id)) === JSON.stringify(["cpuGraph", "ramGraph"]), "plugin search narrows to graphs");
                theme.selectNext();
                plugin.selectNext();
                plugin.selectStep(1);
                return;
            case 4:
                root.snapshot("navigated");
                check(theme.selectedIndex === 0 && theme.keyboardNavigationActive, "theme selection on first card");
                check(plugin.selectedIndex === 1 && plugin.keyboardNavigationActive, "plugin selection stepped to second card");
                theme.operationMessage = "Installed: Nord";
                plugin.operationMessage = "Installing: CPU graph";
                plugin.operationPending = true;
                plugin.openPluginDetail(plugin.filteredPlugins[1]);
                return;
            case 5:
                root.snapshot("status-detail");
                check(plugin.detailPluginId === "ramGraph", "plugin detail opened");
                plugin.closePluginDetail();
                theme.hide();
                plugin.hide();
                return;
            case 6:
                root.snapshot("hidden");
                check(!theme.visible && !plugin.visible, "both browsers hidden");
                check(theme.searchQuery === "" && plugin.searchQuery === "" && plugin.detailPluginId === "", "state reset on hide");
                root.finish();
                stop();
                Qt.quit();
            }
        }
    }
}
