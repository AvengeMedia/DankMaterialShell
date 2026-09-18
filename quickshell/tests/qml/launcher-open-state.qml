import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modals.DankLauncherV2
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    readonly property string style: Quickshell.env("DMS_FIXTURE_LAUNCHER_STYLE") || "standalone"
    property var launcher: null
    property bool failed: false
    property int step: 0

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function controller() {
        return root.launcher.spotlightContent.controller;
    }

    function state() {
        const c = controller();
        return {
            searchQuery: c.searchQuery,
            searchMode: c.searchMode,
            explicit: c.explicitQuerySession,
            previousSearchMode: c.previousSearchMode,
            autoSwitchedToFiles: c.autoSwitchedToFiles,
            isFileSearching: c.isFileSearching,
            fileSearchType: c.fileSearchType,
            fileSearchExt: c.fileSearchExt,
            fileSearchFolder: c.fileSearchFolder,
            fileSearchSort: c.fileSearchSort,
            pluginFilter: c.pluginFilter,
            activePluginId: c.activePluginId,
            activePluginName: c.activePluginName,
            activePluginCategories: c.activePluginCategories,
            activePluginCategory: c.activePluginCategory,
            appCategory: c.appCategory,
            collapsedSections: c.collapsedSections,
            selectedFlatIndex: c.selectedFlatIndex,
            historyIndex: c.historyIndex,
            results: c.flatModel.length,
            fieldText: root.launcher.spotlightContent.searchField.text
        };
    }

    function dirty() {
        const c = controller();
        c.appCategory = "Games";
        c.collapsedSections = {
            "apps": true
        };
        c.fileSearchExt = "png";
        c.fileSearchFolder = "/tmp";
        c.fileSearchSort = "name";
        c.pluginFilter = "abc";
        c.activePluginId = "p";
        c.activePluginName = "P";
        c.activePluginCategories = ["x"];
        c.activePluginCategory = "x";
        c.selectedFlatIndex = 3;
        c.historyIndex = 2;
        c.previousSearchMode = "files";
        c.autoSwitchedToFiles = true;
        c.isFileSearching = true;
        c.fileSearchType = "documents";
    }

    function expectClean(s, label) {
        check(s.appCategory === "", label + " appCategory cleared");
        check(Object.keys(s.collapsedSections).length === 0, label + " collapsedSections cleared");
        check(s.fileSearchExt === "" && s.fileSearchFolder === "" && s.fileSearchSort === "score", label + " file filters cleared");
        check(s.pluginFilter === "" && s.activePluginId === "" && s.activePluginName === "" && s.activePluginCategories.length === 0 && s.activePluginCategory === "", label + " plugin state cleared");
        check(s.historyIndex === -1, label + " history index reset");
        check(s.previousSearchMode === "all" && !s.autoSwitchedToFiles && !s.isFileSearching, label + " mode switch state cleared");
        check(s.fileSearchType === "images", label + " remembered file search type restored");
        check(s.searchMode === "apps", label + " remembered mode restored");
    }

    Component {
        id: modalComp
        DankLauncherV2Modal {}
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.launcherStyle = root.style;
        SettingsData.rememberLastQuery = false;
        SettingsData.rememberLastMode = true;
        SettingsData.dankLauncherV2UnloadOnClose = false;
        SessionData.launcherLastFileSearchType = "images";
        SessionData.launcherLastMode = "apps";
        root.launcher = modalComp.createObject(root);
    }

    Timer {
        interval: 900
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                return;
            case 1:
                root.launcher.show();
                return;
            case 2:
                console.log("STATE first-open " + JSON.stringify(root.state()));
                root.dirty();
                root.launcher.hide();
                return;
            case 3:
                root.launcher.show();
                return;
            case 4:
                {
                    const s = root.state();
                    console.log("STATE reopen " + JSON.stringify(s));
                    root.expectClean(s, "reopen");
                    check(!s.explicit && s.searchQuery === "" && s.fieldText === "", "reopen has no query");
                    check(s.results > 0 || root.launcher.spotlightContent.showResultsWithoutQuery === false, "reopen shows results without a query");
                    root.dirty();
                    root.launcher.hide();
                    return;
                }
            case 5:
                root.launcher.showWithQuery("te");
                return;
            case 6:
                {
                    const s = root.state();
                    console.log("STATE reopen-query " + JSON.stringify(s));
                    root.expectClean(s, "reopen-query");
                    check(s.explicit && s.searchQuery === "te" && s.fieldText === "te", "reopen-query carries the query");
                    check(s.results > 0, "reopen-query shows results");
                    root.launcher.hide();
                    return;
                }
            case 7:
                console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
                stop();
                Qt.quit();
            }
        }
    }
}
