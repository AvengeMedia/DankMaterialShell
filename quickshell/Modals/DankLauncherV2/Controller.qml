pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "Scorer.js" as Scorer
import "ControllerUtils.js" as Utils
import "NavigationHelpers.js" as Nav
import "ItemTransformers.js" as Transform

Item {
    id: root

    property string searchQuery: ""
    property string searchMode: "all"
    property string previousSearchMode: "all"
    property bool autoSwitchedToFiles: false
    property bool isFileSearching: false
    property var sections: []
    property var flatModel: []
    property int selectedFlatIndex: 0
    property var selectedItem: null
    property bool isSearching: false
    property string activePluginId: ""
    property var collapsedSections: ({})
    property bool keyboardNavigationActive: false
    property bool mouseHasMoved: false
    property real lastGlobalMouseX: -1
    property real lastGlobalMouseY: -1
    property var sectionViewModes: ({})
    property var pluginViewPreferences: ({})
    property int gridColumns: SettingsData.appLauncherGridColumns
    property int viewModeVersion: 0
    property string viewModeContext: "spotlight"

    signal itemExecuted
    signal searchCompleted
    signal modeChanged(string mode)
    signal viewModeChanged(string sectionId, string mode)
    signal searchQueryRequested(string query)

    Connections {
        target: SettingsData
        function onSortAppsAlphabeticallyChanged() {
            AppSearchService.invalidateLauncherCache();
        }
    }

    Connections {
        target: PluginService
        function onRequestLauncherUpdate(pluginId) {
            if (activePluginId === pluginId) {
                if (activePluginCategories.length <= 1)
                    loadPluginCategories(pluginId);
                performSearch();
                return;
            }
            if (searchQuery)
                performSearch();
        }
    }

    Process {
        id: wtypeProcess
        command: ["wtype", "-M", "ctrl", "-P", "v", "-p", "v", "-m", "ctrl"]
        running: false
    }

    Process {
        id: copyProcess
        running: false
        onExited: pasteTimer.start()
    }

    Timer {
        id: pasteTimer
        interval: 200
        repeat: false
        onTriggered: wtypeProcess.running = true
    }

    function pasteSelected() {
        if (!selectedItem)
            return;
        if (!SessionService.wtypeAvailable) {
            ToastService.showError("wtype not available - install wtype for paste support");
            return;
        }

        const pluginId = selectedItem.pluginId;
        if (!pluginId)
            return;
        const pasteArgs = AppSearchService.getPluginPasteArgs(pluginId, selectedItem.data);
        if (!pasteArgs)
            return;
        copyProcess.command = pasteArgs;
        copyProcess.running = true;
        itemExecuted();
    }

    readonly property var sectionDefinitions: [
        {
            id: "calculator",
            title: I18n.tr("Calculator"),
            icon: "calculate",
            priority: 0,
            defaultViewMode: "list"
        },
        {
            id: "favorites",
            title: I18n.tr("Pinned"),
            icon: "push_pin",
            priority: 1,
            defaultViewMode: "list"
        },
        {
            id: "apps",
            title: I18n.tr("Applications"),
            icon: "apps",
            priority: 2,
            defaultViewMode: "list"
        },
        {
            id: "browse_plugins",
            title: I18n.tr("Browse"),
            icon: "category",
            priority: 2.5,
            defaultViewMode: "grid"
        },
        {
            id: "files",
            title: I18n.tr("Files"),
            icon: "folder",
            priority: 4,
            defaultViewMode: "list"
        },
        {
            id: "fallback",
            title: I18n.tr("Commands"),
            icon: "terminal",
            priority: 5,
            defaultViewMode: "list"
        }
    ]

    property string pluginFilter: ""
    property string activePluginName: ""
    property var activePluginCategories: []
    property string activePluginCategory: ""

    function getSectionViewMode(sectionId) {
        if (sectionId === "browse_plugins")
            return "list";
        if (pluginViewPreferences[sectionId]?.enforced)
            return pluginViewPreferences[sectionId].mode;
        if (sectionViewModes[sectionId])
            return sectionViewModes[sectionId];

        var savedModes = viewModeContext === "appDrawer" ? (SettingsData.appDrawerSectionViewModes || {}) : (SettingsData.spotlightSectionViewModes || {});
        if (savedModes[sectionId])
            return savedModes[sectionId];

        for (var i = 0; i < sectionDefinitions.length; i++) {
            if (sectionDefinitions[i].id === sectionId)
                return sectionDefinitions[i].defaultViewMode || "list";
        }

        if (pluginViewPreferences[sectionId]?.mode)
            return pluginViewPreferences[sectionId].mode;

        return "list";
    }

    function setSectionViewMode(sectionId, mode) {
        if (sectionId === "browse_plugins")
            return;
        if (pluginViewPreferences[sectionId]?.enforced)
            return;
        sectionViewModes = Object.assign({}, sectionViewModes, {
            [sectionId]: mode
        });
        viewModeVersion++;
        if (viewModeContext === "appDrawer") {
            var savedModes = Object.assign({}, SettingsData.appDrawerSectionViewModes || {}, {
                [sectionId]: mode
            });
            SettingsData.appDrawerSectionViewModes = savedModes;
        } else {
            var savedModes = Object.assign({}, SettingsData.spotlightSectionViewModes || {}, {
                [sectionId]: mode
            });
            SettingsData.spotlightSectionViewModes = savedModes;
        }
        viewModeChanged(sectionId, mode);
    }

    function canChangeSectionViewMode(sectionId) {
        if (sectionId === "browse_plugins")
            return false;
        return !pluginViewPreferences[sectionId]?.enforced;
    }

    function canCollapseSection(sectionId) {
        return searchMode === "all";
    }

    function setPluginViewPreference(pluginId, mode, enforced) {
        var prefs = pluginViewPreferences;
        prefs[pluginId] = {
            mode: mode,
            enforced: enforced || false
        };
        pluginViewPreferences = prefs;
    }

    function applyActivePluginViewPreference(pluginId, isBuiltIn) {
        var sectionId = "plugin_" + pluginId;
        var pref = null;
        if (isBuiltIn) {
            var builtIn = AppSearchService.builtInPlugins[pluginId];
            if (builtIn && builtIn.viewMode) {
                pref = {
                    mode: builtIn.viewMode,
                    enforced: builtIn.viewModeEnforced === true
                };
            }
        } else {
            pref = PluginService.getPluginViewPreference(pluginId);
        }

        if (pref && pref.mode) {
            setPluginViewPreference(sectionId, pref.mode, pref.enforced);
        } else {
            var prefs = pluginViewPreferences;
            delete prefs[sectionId];
            pluginViewPreferences = prefs;
        }
    }

    function clearActivePluginViewPreference() {
        var prefs = {};
        for (var key in pluginViewPreferences) {
            if (!key.startsWith("plugin_")) {
                prefs[key] = pluginViewPreferences[key];
            }
        }
        pluginViewPreferences = prefs;
    }

    property int _searchVersion: 0

    Timer {
        id: searchDebounce
        interval: searchMode === "all" && searchQuery.length > 0 ? 90 : 60
        onTriggered: root.performSearch()
    }

    Timer {
        id: fileSearchDebounce
        interval: 200
        onTriggered: root.performFileSearch()
    }

    function getOrTransformApp(app) {
        return AppSearchService.getOrTransformApp(app, transformApp);
    }

    function setSearchQuery(query) {
        _searchVersion++;
        searchQuery = query;
        searchDebounce.restart();

        if (searchMode !== "plugins" && (searchMode === "files" || query.startsWith("/")) && query.length > 0) {
            fileSearchDebounce.restart();
        }
    }

    function setMode(mode, isAutoSwitch) {
        if (searchMode === mode)
            return;
        if (isAutoSwitch) {
            previousSearchMode = searchMode;
            autoSwitchedToFiles = true;
        } else {
            autoSwitchedToFiles = false;
        }
        searchMode = mode;
        modeChanged(mode);
        performSearch();
        if (mode === "files") {
            fileSearchDebounce.restart();
        }
    }

    function restorePreviousMode() {
        if (!autoSwitchedToFiles)
            return;
        autoSwitchedToFiles = false;
        searchMode = previousSearchMode;
        modeChanged(previousSearchMode);
        performSearch();
    }

    function cycleMode() {
        var modes = ["all", "apps", "files", "plugins"];
        var currentIndex = modes.indexOf(searchMode);
        var nextIndex = (currentIndex + 1) % modes.length;
        setMode(modes[nextIndex]);
    }

    function reset() {
        searchQuery = "";
        searchMode = "all";
        previousSearchMode = "all";
        autoSwitchedToFiles = false;
        isFileSearching = false;
        sections = [];
        flatModel = [];
        selectedFlatIndex = 0;
        selectedItem = null;
        isSearching = false;
        activePluginId = "";
        activePluginName = "";
        activePluginCategories = [];
        activePluginCategory = "";
        pluginFilter = "";
        collapsedSections = {};
        mouseHasMoved = false;
        lastGlobalMouseX = -1;
        lastGlobalMouseY = -1;
    }

    function handleMousePositionChanged(globalPos) {
        if (lastGlobalMouseX >= 0 && lastGlobalMouseY >= 0) {
            const dx = Math.abs(globalPos.x - lastGlobalMouseX);
            const dy = Math.abs(globalPos.y - lastGlobalMouseY);
            if (dx > 0.5 || dy > 0.5) {
                keyboardNavigationActive = false;
                mouseHasMoved = true;
            }
        }
        lastGlobalMouseX = globalPos.x;
        lastGlobalMouseY = globalPos.y;
    }

    function loadPluginCategories(pluginId) {
        if (!pluginId) {
            if (activePluginCategories.length > 0) {
                activePluginCategories = [];
                activePluginCategory = "";
            }
            return;
        }

        const categories = AppSearchService.getPluginLauncherCategories(pluginId);
        if (categories.length === activePluginCategories.length) {
            let same = true;
            for (let i = 0; i < categories.length; i++) {
                if (categories[i].id !== activePluginCategories[i]?.id) {
                    same = false;
                    break;
                }
            }
            if (same)
                return;
        }
        activePluginCategories = categories;
        activePluginCategory = "";
        AppSearchService.setPluginLauncherCategory(pluginId, "");
    }

    function setActivePluginCategory(categoryId) {
        if (activePluginCategory === categoryId)
            return;
        activePluginCategory = categoryId;
        AppSearchService.setPluginLauncherCategory(activePluginId, categoryId);
        performSearch();
    }

    function clearPluginFilter() {
        if (pluginFilter) {
            pluginFilter = "";
            performSearch();
            return true;
        }
        return false;
    }

    function preserveSelectionAfterUpdate() {
        var previousSelectedId = selectedItem?.id || "";
        return function (newFlatModel) {
            if (!previousSelectedId)
                return getFirstItemIndex();
            for (var i = 0; i < newFlatModel.length; i++) {
                if (!newFlatModel[i].isHeader && newFlatModel[i].item?.id === previousSelectedId)
                    return i;
            }
            return getFirstItemIndex();
        };
    }

    function performSearch() {
        var currentVersion = _searchVersion;
        isSearching = true;
        var restoreSelection = preserveSelectionAfterUpdate();

        var cachedSections = AppSearchService.getCachedDefaultSections();
        if (cachedSections && !searchQuery && searchMode === "all" && !pluginFilter) {
            activePluginId = "";
            activePluginName = "";
            activePluginCategories = [];
            activePluginCategory = "";
            clearActivePluginViewPreference();
            sections = cachedSections.map(function (s) {
                var copy = Object.assign({}, s, {
                    items: s.items ? s.items.slice() : []
                });
                if (collapsedSections[s.id] !== undefined)
                    copy.collapsed = collapsedSections[s.id];
                return copy;
            });
            flatModel = Scorer.flattenSections(sections);
            selectedFlatIndex = restoreSelection(flatModel);
            updateSelectedItem();
            isSearching = false;
            searchCompleted();
            return;
        }

        var allItems = [];

        var triggerMatch = detectTrigger(searchQuery);
        if (triggerMatch.pluginId) {
            var pluginChanged = activePluginId !== triggerMatch.pluginId;
            activePluginId = triggerMatch.pluginId;
            activePluginName = getPluginName(triggerMatch.pluginId, triggerMatch.isBuiltIn);
            applyActivePluginViewPreference(triggerMatch.pluginId, triggerMatch.isBuiltIn);

            if (pluginChanged && !triggerMatch.isBuiltIn)
                loadPluginCategories(triggerMatch.pluginId);

            var pluginItems = getPluginItems(triggerMatch.pluginId, triggerMatch.query);
            allItems = allItems.concat(pluginItems);

            if (triggerMatch.isBuiltIn) {
                var builtInItems = AppSearchService.getBuiltInLauncherItems(triggerMatch.pluginId, triggerMatch.query);
                for (var j = 0; j < builtInItems.length; j++) {
                    allItems.push(transformBuiltInLauncherItem(builtInItems[j], triggerMatch.pluginId));
                }
            }

            var dynamicDefs = buildDynamicSectionDefs(allItems);
            var scoredItems = Scorer.scoreItems(allItems, triggerMatch.query, getFrecencyForItem);
            var sortAlpha = !triggerMatch.query && SettingsData.sortAppsAlphabetically;
            sections = Scorer.groupBySection(scoredItems, dynamicDefs, sortAlpha, 500);

            for (var sid in collapsedSections) {
                for (var i = 0; i < sections.length; i++) {
                    if (sections[i].id === sid) {
                        sections[i].collapsed = collapsedSections[sid];
                    }
                }
            }

            flatModel = Scorer.flattenSections(sections);
            selectedFlatIndex = restoreSelection(flatModel);
            updateSelectedItem();

            isSearching = false;
            searchCompleted();
            return;
        }

        activePluginId = "";
        activePluginName = "";
        activePluginCategories = [];
        activePluginCategory = "";
        clearActivePluginViewPreference();

        if (searchMode === "files") {
            var fileQuery = searchQuery.startsWith("/") ? searchQuery.substring(1).trim() : searchQuery.trim();
            isFileSearching = fileQuery.length >= 2 && DSearchService.dsearchAvailable;
            sections = [];
            flatModel = [];
            selectedFlatIndex = 0;
            selectedItem = null;
            isSearching = false;
            searchCompleted();
            return;
        }

        if (searchMode === "apps") {
            var cachedSections = AppSearchService.getCachedDefaultSections();
            if (cachedSections && !searchQuery) {
                var appSectionIds = ["favorites", "apps"];
                sections = cachedSections.filter(function (s) {
                    return appSectionIds.indexOf(s.id) !== -1;
                }).map(function (s) {
                    var copy = Object.assign({}, s, {
                        items: s.items ? s.items.slice() : []
                    });
                    if (collapsedSections[s.id] !== undefined)
                        copy.collapsed = collapsedSections[s.id];
                    return copy;
                });
                flatModel = Scorer.flattenSections(sections);
                selectedFlatIndex = restoreSelection(flatModel);
                updateSelectedItem();
                isSearching = false;
                searchCompleted();
                return;
            }

            var apps = searchApps(searchQuery);
            for (var i = 0; i < apps.length; i++) {
                allItems.push(apps[i]);
            }

            var scoredItems = Scorer.scoreItems(allItems, searchQuery, getFrecencyForItem);
            var sortAlpha = !searchQuery && SettingsData.sortAppsAlphabetically;
            sections = Scorer.groupBySection(scoredItems, sectionDefinitions, sortAlpha, searchQuery ? 50 : 500);

            for (var sid in collapsedSections) {
                for (var i = 0; i < sections.length; i++) {
                    if (sections[i].id === sid) {
                        sections[i].collapsed = collapsedSections[sid];
                    }
                }
            }

            flatModel = Scorer.flattenSections(sections);
            selectedFlatIndex = restoreSelection(flatModel);
            updateSelectedItem();

            isSearching = false;
            searchCompleted();
            return;
        }

        if (searchMode === "plugins") {
            if (!searchQuery && !pluginFilter) {
                var browseItems = getPluginBrowseItems();
                allItems = allItems.concat(browseItems);
            } else if (pluginFilter) {
                var isBuiltInFilter = !!AppSearchService.builtInPlugins[pluginFilter];
                applyActivePluginViewPreference(pluginFilter, isBuiltInFilter);

                var filterItems = getPluginItems(pluginFilter, searchQuery);
                allItems = allItems.concat(filterItems);

                var builtInItems = AppSearchService.getBuiltInLauncherItems(pluginFilter, searchQuery);
                for (var j = 0; j < builtInItems.length; j++) {
                    allItems.push(transformBuiltInLauncherItem(builtInItems[j], pluginFilter));
                }
            } else {
                var emptyTriggerPlugins = getEmptyTriggerPlugins();
                for (var i = 0; i < emptyTriggerPlugins.length; i++) {
                    var pluginId = emptyTriggerPlugins[i];
                    var pItems = getPluginItems(pluginId, searchQuery);
                    allItems = allItems.concat(pItems);
                }

                var builtInLauncherPlugins = getBuiltInEmptyTriggerLaunchers();
                for (var i = 0; i < builtInLauncherPlugins.length; i++) {
                    var pluginId = builtInLauncherPlugins[i];
                    var blItems = AppSearchService.getBuiltInLauncherItems(pluginId, searchQuery);
                    for (var j = 0; j < blItems.length; j++) {
                        allItems.push(transformBuiltInLauncherItem(blItems[j], pluginId));
                    }
                }
            }

            var dynamicDefs = buildDynamicSectionDefs(allItems);
            var scoredItems = Scorer.scoreItems(allItems, searchQuery, getFrecencyForItem);
            var sortAlpha = !searchQuery && SettingsData.sortAppsAlphabetically;
            sections = Scorer.groupBySection(scoredItems, dynamicDefs, sortAlpha, 500);

            for (var sid in collapsedSections) {
                for (var i = 0; i < sections.length; i++) {
                    if (sections[i].id === sid) {
                        sections[i].collapsed = collapsedSections[sid];
                    }
                }
            }

            flatModel = Scorer.flattenSections(sections);
            selectedFlatIndex = restoreSelection(flatModel);
            updateSelectedItem();

            isSearching = false;
            searchCompleted();
            return;
        }

        var calculatorResult = evaluateCalculator(searchQuery);
        if (calculatorResult) {
            allItems.push(calculatorResult);
        }

        var apps = searchApps(searchQuery);
        allItems = allItems.concat(apps);

        if (searchMode === "all") {
            var includePlugins = !searchQuery || searchQuery.length >= 2;
            if (searchQuery && includePlugins) {
                var allPluginsOrdered = getAllVisiblePluginsOrdered();
                var maxPerPlugin = 10;
                for (var i = 0; i < allPluginsOrdered.length; i++) {
                    var plugin = allPluginsOrdered[i];
                    if (plugin.isBuiltIn) {
                        var blItems = AppSearchService.getBuiltInLauncherItems(plugin.id, searchQuery);
                        var blLimit = Math.min(blItems.length, maxPerPlugin);
                        for (var j = 0; j < blLimit; j++)
                            allItems.push(transformBuiltInLauncherItem(blItems[j], plugin.id));
                    } else {
                        var pItems = getPluginItems(plugin.id, searchQuery);
                        if (pItems.length > maxPerPlugin)
                            pItems = pItems.slice(0, maxPerPlugin);
                        allItems = allItems.concat(pItems);
                    }
                }
            } else if (!searchQuery) {
                var emptyTriggerOrdered = getEmptyTriggerPluginsOrdered();
                for (var i = 0; i < emptyTriggerOrdered.length; i++) {
                    var plugin = emptyTriggerOrdered[i];
                    if (plugin.isBuiltIn) {
                        var blItems = AppSearchService.getBuiltInLauncherItems(plugin.id, searchQuery);
                        for (var j = 0; j < blItems.length; j++)
                            allItems.push(transformBuiltInLauncherItem(blItems[j], plugin.id));
                    } else {
                        var pItems = getPluginItems(plugin.id, searchQuery);
                        allItems = allItems.concat(pItems);
                    }
                }

                var browseItems = getPluginBrowseItems();
                allItems = allItems.concat(browseItems);
            }
        }

        var dynamicDefs = buildDynamicSectionDefs(allItems);

        if (currentVersion !== _searchVersion) {
            isSearching = false;
            return;
        }

        var scoredItems = Scorer.scoreItems(allItems, searchQuery, getFrecencyForItem);
        var sortAlpha = !searchQuery && SettingsData.sortAppsAlphabetically;
        var newSections = Scorer.groupBySection(scoredItems, dynamicDefs, sortAlpha, searchQuery ? 50 : 500);

        if (currentVersion !== _searchVersion) {
            isSearching = false;
            return;
        }

        for (var i = 0; i < newSections.length; i++) {
            var sid = newSections[i].id;
            if (collapsedSections[sid] !== undefined) {
                newSections[i].collapsed = collapsedSections[sid];
            }
        }

        sections = newSections;
        flatModel = Scorer.flattenSections(sections);

        if (!AppSearchService.isCacheValid() && !searchQuery && searchMode === "all" && !pluginFilter) {
            AppSearchService.setCachedDefaultSections(sections, flatModel);
        }

        selectedFlatIndex = restoreSelection(flatModel);
        updateSelectedItem();

        isSearching = false;
        searchCompleted();
    }

    function performFileSearch() {
        if (!DSearchService.dsearchAvailable)
            return;
        var fileQuery = "";
        if (searchQuery.startsWith("/")) {
            fileQuery = searchQuery.substring(1).trim();
        } else if (searchMode === "files") {
            fileQuery = searchQuery.trim();
        } else {
            return;
        }

        if (fileQuery.length < 2) {
            isFileSearching = false;
            return;
        }

        isFileSearching = true;
        var params = {
            limit: 20,
            fuzzy: true,
            sort: "score",
            desc: true
        };

        DSearchService.search(fileQuery, params, function (response) {
            isFileSearching = false;
            if (response.error)
                return;
            var fileItems = [];
            var hits = response.result?.hits || [];

            for (var i = 0; i < hits.length; i++) {
                var hit = hits[i];
                fileItems.push(transformFileResult({
                    path: hit.id || "",
                    score: hit.score || 0
                }));
            }

            var fileSection = {
                id: "files",
                title: I18n.tr("Files"),
                icon: "folder",
                priority: 4,
                items: fileItems,
                collapsed: collapsedSections["files"] || false
            };

            var newSections;
            if (searchMode === "files") {
                newSections = fileItems.length > 0 ? [fileSection] : [];
            } else {
                var existingNonFile = sections.filter(function (s) {
                    return s.id !== "files";
                });
                if (fileItems.length > 0) {
                    newSections = existingNonFile.concat([fileSection]);
                } else {
                    newSections = existingNonFile;
                }
            }
            newSections.sort(function (a, b) {
                return a.priority - b.priority;
            });
            sections = newSections;

            flatModel = Scorer.flattenSections(sections);
            if (selectedFlatIndex >= flatModel.length) {
                selectedFlatIndex = getFirstItemIndex();
            }
            updateSelectedItem();
        });
    }

    function searchApps(query) {
        var apps = AppSearchService.searchApplications(query);
        var items = [];

        for (var i = 0; i < apps.length; i++) {
            items.push(getOrTransformApp(apps[i]));
        }

        var coreApps = AppSearchService.getCoreApps(query);
        for (var i = 0; i < coreApps.length; i++) {
            items.push(transformCoreApp(coreApps[i]));
        }

        return items;
    }

    function transformApp(app) {
        var appId = app.id || app.execString || app.exec || "";
        var override = SessionData.getAppOverride(appId);
        return Transform.transformApp(app, override, [], I18n.tr("Launch"));
    }

    function transformCoreApp(app) {
        return Transform.transformCoreApp(app, I18n.tr("Open"));
    }

    function transformBuiltInLauncherItem(item, pluginId) {
        return Transform.transformBuiltInLauncherItem(item, pluginId, I18n.tr("Open"));
    }

    function transformFileResult(file) {
        return Transform.transformFileResult(file, I18n.tr("Open"), I18n.tr("Open folder"), I18n.tr("Copy path"));
    }

    function evaluateCalculator(query) {
        var calc = Utils.evaluateCalculator(query);
        if (!calc)
            return null;
        return Transform.createCalculatorItem(calc, query, I18n.tr("Copy"));
    }

    function detectTrigger(query) {
        if (!query || query.length === 0)
            return {
                pluginId: null,
                query: query
            };

        var pluginTriggers = PluginService.getAllPluginTriggers();
        for (var trigger in pluginTriggers) {
            if (trigger && query.startsWith(trigger)) {
                return {
                    pluginId: pluginTriggers[trigger],
                    query: query.substring(trigger.length).trim()
                };
            }
        }

        var builtInTriggers = AppSearchService.getBuiltInLauncherTriggers();
        for (var trigger in builtInTriggers) {
            if (trigger && query.startsWith(trigger)) {
                return {
                    pluginId: builtInTriggers[trigger],
                    query: query.substring(trigger.length).trim(),
                    isBuiltIn: true
                };
            }
        }

        return {
            pluginId: null,
            query: query
        };
    }

    function getEmptyTriggerPlugins() {
        var plugins = PluginService.getPluginsWithEmptyTrigger();
        var visible = plugins.filter(function (pluginId) {
            return SettingsData.getPluginAllowWithoutTrigger(pluginId);
        });
        return sortPluginIdsByOrder(visible);
    }

    function getAllLauncherPluginIds() {
        var launchers = PluginService.getLauncherPlugins();
        return Object.keys(launchers);
    }

    function getVisibleLauncherPluginIds() {
        var launchers = PluginService.getLauncherPlugins();
        var visible = Object.keys(launchers).filter(function (pluginId) {
            return SettingsData.getPluginAllowWithoutTrigger(pluginId);
        });
        return sortPluginIdsByOrder(visible);
    }

    function getAllBuiltInLauncherIds() {
        var launchers = AppSearchService.getBuiltInLauncherPlugins();
        return Object.keys(launchers);
    }

    function getVisibleBuiltInLauncherIds() {
        var launchers = AppSearchService.getBuiltInLauncherPlugins();
        var visible = Object.keys(launchers).filter(function (pluginId) {
            return SettingsData.getPluginAllowWithoutTrigger(pluginId);
        });
        return sortPluginIdsByOrder(visible);
    }

    function sortPluginIdsByOrder(pluginIds) {
        return Utils.sortPluginIdsByOrder(pluginIds, SettingsData.launcherPluginOrder || []);
    }

    function getAllVisiblePluginsOrdered() {
        var thirdPartyLaunchers = PluginService.getLauncherPlugins() || {};
        var builtInLaunchers = AppSearchService.getBuiltInLauncherPlugins() || {};
        var all = [];
        for (var id in thirdPartyLaunchers) {
            if (SettingsData.getPluginAllowWithoutTrigger(id))
                all.push({
                    id: id,
                    isBuiltIn: false
                });
        }
        for (var id in builtInLaunchers) {
            if (SettingsData.getPluginAllowWithoutTrigger(id))
                all.push({
                    id: id,
                    isBuiltIn: true
                });
        }
        return Utils.sortPluginsOrdered(all, SettingsData.launcherPluginOrder || []);
    }

    function getEmptyTriggerPluginsOrdered() {
        var thirdParty = PluginService.getPluginsWithEmptyTrigger() || [];
        var builtIn = AppSearchService.getBuiltInLauncherPluginsWithEmptyTrigger() || [];
        var all = [];
        for (var i = 0; i < thirdParty.length; i++) {
            var id = thirdParty[i];
            if (SettingsData.getPluginAllowWithoutTrigger(id))
                all.push({
                    id: id,
                    isBuiltIn: false
                });
        }
        for (var i = 0; i < builtIn.length; i++) {
            var id = builtIn[i];
            if (SettingsData.getPluginAllowWithoutTrigger(id))
                all.push({
                    id: id,
                    isBuiltIn: true
                });
        }
        return Utils.sortPluginsOrdered(all, SettingsData.launcherPluginOrder || []);
    }

    function getPluginBrowseItems() {
        var items = [];
        var browseLabel = I18n.tr("Browse");
        var triggerLabel = I18n.tr("Trigger: %1");
        var noTriggerLabel = I18n.tr("No trigger");

        var launchers = PluginService.getLauncherPlugins();
        for (var pluginId in launchers) {
            var trigger = PluginService.getPluginTrigger(pluginId);
            var isAllowed = SettingsData.getPluginAllowWithoutTrigger(pluginId);
            items.push(Transform.createPluginBrowseItem(pluginId, launchers[pluginId], trigger, false, isAllowed, browseLabel, triggerLabel, noTriggerLabel));
        }

        var builtInLaunchers = AppSearchService.getBuiltInLauncherPlugins();
        for (var pluginId in builtInLaunchers) {
            var trigger = AppSearchService.getBuiltInPluginTrigger(pluginId);
            var isAllowed = SettingsData.getPluginAllowWithoutTrigger(pluginId);
            items.push(Transform.createPluginBrowseItem(pluginId, builtInLaunchers[pluginId], trigger, true, isAllowed, browseLabel, triggerLabel, noTriggerLabel));
        }

        return items;
    }

    function getBuiltInEmptyTriggerLaunchers() {
        var plugins = AppSearchService.getBuiltInLauncherPluginsWithEmptyTrigger();
        var visible = plugins.filter(function (pluginId) {
            return SettingsData.getPluginAllowWithoutTrigger(pluginId);
        });
        return sortPluginIdsByOrder(visible);
    }

    function getPluginItems(pluginId, query) {
        var items = AppSearchService.getPluginItemsForPlugin(pluginId, query);
        var transformed = [];

        for (var i = 0; i < items.length; i++) {
            transformed.push(transformPluginItem(items[i], pluginId));
        }

        return transformed;
    }

    function getPluginName(pluginId, isBuiltIn) {
        if (isBuiltIn) {
            var plugin = AppSearchService.builtInPlugins[pluginId];
            return plugin ? plugin.name : pluginId;
        }
        var launchers = PluginService.getLauncherPlugins();
        if (launchers[pluginId]) {
            return launchers[pluginId].name || pluginId;
        }
        return pluginId;
    }

    function getPluginMetadata(pluginId) {
        var builtIn = AppSearchService.builtInPlugins[pluginId];
        if (builtIn) {
            return {
                name: builtIn.name || pluginId,
                icon: builtIn.cornerIcon || "extension"
            };
        }
        var launchers = PluginService.getLauncherPlugins();
        if (launchers[pluginId]) {
            var rawIcon = launchers[pluginId].icon || "extension";
            return {
                name: launchers[pluginId].name || pluginId,
                icon: Utils.stripIconPrefix(rawIcon)
            };
        }
        return {
            name: pluginId,
            icon: "extension"
        };
    }

    function buildDynamicSectionDefs(items) {
        var baseDefs = sectionDefinitions.slice();
        var pluginSections = {};
        var basePriority = 2.6;

        for (var i = 0; i < items.length; i++) {
            var section = items[i].section;
            if (!section || !section.startsWith("plugin_"))
                continue;
            if (pluginSections[section])
                continue;
            var pluginId = section.substring(7);
            var meta = getPluginMetadata(pluginId);
            var viewPref = getPluginViewPref(pluginId);

            pluginSections[section] = {
                id: section,
                title: meta.name,
                icon: meta.icon,
                priority: basePriority,
                defaultViewMode: viewPref.mode || "list"
            };

            if (viewPref.mode)
                setPluginViewPreference(section, viewPref.mode, viewPref.enforced);

            basePriority += 0.01;
        }

        for (var sectionId in pluginSections) {
            baseDefs.push(pluginSections[sectionId]);
        }

        baseDefs.sort(function (a, b) {
            return a.priority - b.priority;
        });
        return baseDefs;
    }

    function getPluginViewPref(pluginId) {
        var builtIn = AppSearchService.builtInPlugins[pluginId];
        if (builtIn && builtIn.viewMode) {
            return {
                mode: builtIn.viewMode,
                enforced: builtIn.viewModeEnforced === true
            };
        }

        var pref = PluginService.getPluginViewPreference(pluginId);
        if (pref && pref.mode) {
            return pref;
        }

        return {
            mode: "list",
            enforced: false
        };
    }

    function transformPluginItem(item, pluginId) {
        return Transform.transformPluginItem(item, pluginId, I18n.tr("Select"));
    }

    function getFrecencyForItem(item) {
        if (item.type !== "app")
            return null;

        var appId = item.id;
        var usageRanking = AppUsageHistoryData.appUsageRanking || {};

        var idVariants = [appId, appId.replace(".desktop", "")];
        var usageData = null;

        for (var i = 0; i < idVariants.length; i++) {
            if (usageRanking[idVariants[i]]) {
                usageData = usageRanking[idVariants[i]];
                break;
            }
        }

        return {
            usageCount: usageData?.usageCount || 0
        };
    }

    function getFirstItemIndex() {
        return Nav.getFirstItemIndex(flatModel);
    }

    function updateSelectedItem() {
        if (selectedFlatIndex >= 0 && selectedFlatIndex < flatModel.length) {
            var entry = flatModel[selectedFlatIndex];
            selectedItem = entry.isHeader ? null : entry.item;
        } else {
            selectedItem = null;
        }
    }

    function getCurrentSectionViewMode() {
        if (selectedFlatIndex < 0 || selectedFlatIndex >= flatModel.length)
            return "list";
        var entry = flatModel[selectedFlatIndex];
        if (!entry || entry.isHeader)
            return "list";
        return getSectionViewMode(entry.sectionId);
    }

    function getGridColumns(sectionId) {
        return Nav.getGridColumns(getSectionViewMode(sectionId), gridColumns);
    }

    function selectNext() {
        keyboardNavigationActive = true;
        var newIndex = Nav.calculateNextIndex(flatModel, selectedFlatIndex, null, null, gridColumns, getSectionViewMode);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectPrevious() {
        keyboardNavigationActive = true;
        var newIndex = Nav.calculatePrevIndex(flatModel, selectedFlatIndex, null, null, gridColumns, getSectionViewMode);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectRight() {
        keyboardNavigationActive = true;
        var newIndex = Nav.calculateRightIndex(flatModel, selectedFlatIndex, getSectionViewMode);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectLeft() {
        keyboardNavigationActive = true;
        var newIndex = Nav.calculateLeftIndex(flatModel, selectedFlatIndex, getSectionViewMode);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectNextSection() {
        keyboardNavigationActive = true;
        var newIndex = Nav.calculateNextSectionIndex(flatModel, selectedFlatIndex);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectPreviousSection() {
        keyboardNavigationActive = true;
        var newIndex = Nav.calculatePrevSectionIndex(flatModel, selectedFlatIndex);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectPageDown(visibleItems) {
        keyboardNavigationActive = true;
        var newIndex = Nav.calculatePageDownIndex(flatModel, selectedFlatIndex, visibleItems);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectPageUp(visibleItems) {
        keyboardNavigationActive = true;
        var newIndex = Nav.calculatePageUpIndex(flatModel, selectedFlatIndex, visibleItems);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectIndex(index) {
        keyboardNavigationActive = false;
        if (index >= 0 && index < flatModel.length && !flatModel[index].isHeader) {
            selectedFlatIndex = index;
            updateSelectedItem();
        }
    }

    function toggleSection(sectionId) {
        var newCollapsed = Object.assign({}, collapsedSections);
        var currentState = newCollapsed[sectionId];

        if (currentState === undefined) {
            for (var i = 0; i < sections.length; i++) {
                if (sections[i].id === sectionId) {
                    currentState = sections[i].collapsed || false;
                    break;
                }
            }
        }

        newCollapsed[sectionId] = !currentState;
        collapsedSections = newCollapsed;

        var newSections = sections.slice();
        for (var i = 0; i < newSections.length; i++) {
            if (newSections[i].id === sectionId) {
                newSections[i] = Object.assign({}, newSections[i], {
                    collapsed: newCollapsed[sectionId]
                });
            }
        }
        sections = newSections;

        flatModel = Scorer.flattenSections(sections);

        if (selectedFlatIndex >= flatModel.length) {
            selectedFlatIndex = getFirstItemIndex();
        }
        updateSelectedItem();
    }

    function executeSelected() {
        if (!selectedItem)
            return;
        executeItem(selectedItem);
    }

    function executeItem(item) {
        if (!item)
            return;
        if (item.type === "plugin_browse") {
            var browsePluginId = item.data?.pluginId;
            if (!browsePluginId)
                return;
            var browseTrigger = item.data.isBuiltIn ? AppSearchService.getBuiltInPluginTrigger(browsePluginId) : PluginService.getPluginTrigger(browsePluginId);

            if (browseTrigger && browseTrigger.length > 0) {
                searchQueryRequested(browseTrigger);
            } else {
                setMode("plugins");
                pluginFilter = browsePluginId;
                performSearch();
            }
            return;
        }

        switch (item.type) {
        case "app":
            if (item.isCore) {
                AppSearchService.executeCoreApp(item.data);
            } else if (item.data?.isAction) {
                launchAppAction(item.data);
            } else {
                launchApp(item.data);
            }
            break;
        case "plugin":
            if (item.isBuiltInLauncher) {
                AppSearchService.executeBuiltInLauncherItem(item.data);
            } else {
                AppSearchService.executePluginItem(item.data, item.pluginId);
            }
            break;
        case "file":
            openFile(item.data?.path);
            break;
        case "calculator":
            copyToClipboard(item.name);
            break;
        default:
            return;
        }

        itemExecuted();
    }

    function executeAction(item, action) {
        if (!item || !action)
            return;
        switch (action.action) {
        case "launch":
            executeItem(item);
            break;
        case "open":
            openFile(item.data.path);
            break;
        case "open_folder":
            openFolder(item.data.path);
            break;
        case "copy_path":
            copyToClipboard(item.data.path);
            break;
        case "copy":
            copyToClipboard(item.name);
            break;
        case "execute":
            executeItem(item);
            break;
        case "launch_dgpu":
            if (item.type === "app" && item.data) {
                launchAppWithNvidia(item.data);
            }
            break;
        case "toggle_all_visibility":
            if (item.type === "plugin_browse" && item.data?.pluginId) {
                var pluginId = item.data.pluginId;
                var currentState = SettingsData.getPluginAllowWithoutTrigger(pluginId);
                SettingsData.setPluginAllowWithoutTrigger(pluginId, !currentState);
                performSearch();
            }
            return;
        default:
            if (item.type === "app" && action.actionData) {
                launchAppAction({
                    parentApp: item.data,
                    actionData: action.actionData
                });
            }
        }

        itemExecuted();
    }

    function launchApp(app) {
        if (!app)
            return;
        SessionService.launchDesktopEntry(app);
        AppUsageHistoryData.addAppUsage(app);
    }

    function launchAppWithNvidia(app) {
        if (!app)
            return;
        SessionService.launchDesktopEntry(app, true);
        AppUsageHistoryData.addAppUsage(app);
    }

    function launchAppAction(actionItem) {
        if (!actionItem || !actionItem.parentApp || !actionItem.actionData)
            return;
        SessionService.launchDesktopAction(actionItem.parentApp, actionItem.actionData);
        AppUsageHistoryData.addAppUsage(actionItem.parentApp);
    }

    function openFile(path) {
        if (!path)
            return;
        Qt.openUrlExternally("file://" + path);
    }

    function openFolder(path) {
        if (!path)
            return;
        var folder = path.substring(0, path.lastIndexOf("/"));
        Qt.openUrlExternally("file://" + folder);
    }

    function copyToClipboard(text) {
        if (!text)
            return;
        Quickshell.execDetached(["dms", "cl", "copy", text]);
    }
}
