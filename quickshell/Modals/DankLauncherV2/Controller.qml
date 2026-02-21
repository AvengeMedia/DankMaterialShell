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
    property bool active: false
    property var _modeSectionsCache: ({})
    property bool _queryDrivenSearch: false
    property bool _diskCacheConsumed: false
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

    onActiveChanged: {
        if (!active) {
            sections = [];
            flatModel = [];
            selectedItem = null;
            _clearModeCache();
        }
    }

    Connections {
        target: SettingsData
        function onSortAppsAlphabeticallyChanged() {
            AppSearchService.invalidateLauncherCache();
            _clearModeCache();
        }
    }

    Connections {
        target: AppSearchService
        function onCacheVersionChanged() {
            if (!active)
                return;
            _clearModeCache();
            if (!searchQuery && searchMode === "all")
                performSearch();
        }
    }

    Connections {
        target: PluginService
        function onRequestLauncherUpdate(pluginId) {
            if (!active)
                return;
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

    property string fileSearchType: "all"
    property string fileSearchExt: ""
    property string fileSearchFolder: ""
    property string fileSearchSort: "score"

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
        var prefs = Object.assign({}, pluginViewPreferences);
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
            var prefs = Object.assign({}, pluginViewPreferences);
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
    property bool _pluginPhasePending: false
    property bool _pluginPhaseForceFirst: false
    property var _phase1Items: []

    Timer {
        id: searchDebounce
        interval: 60
        onTriggered: root.performSearch()
    }

    Timer {
        id: pluginPhaseTimer
        interval: 1
        onTriggered: root._performPluginPhase()
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
        _queryDrivenSearch = true;
        _pluginPhasePending = false;
        _phase1Items = [];
        pluginPhaseTimer.stop();
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
        fileSearchType = "all";
        fileSearchExt = "";
        fileSearchFolder = "";
        fileSearchSort = "score";
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
        _clearModeCache();
        _queryDrivenSearch = false;
        _pluginPhasePending = false;
        _pluginPhaseForceFirst = false;
        _phase1Items = [];
        pluginPhaseTimer.stop();
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

    function setFileSearchType(type) {
        if (fileSearchType === type)
            return;
        fileSearchType = type;
        performFileSearch();
    }

    function setFileSearchExt(ext) {
        if (fileSearchExt === ext)
            return;
        fileSearchExt = ext;
        performFileSearch();
    }

    function setFileSearchFolder(folder) {
        if (fileSearchFolder === folder)
            return;
        fileSearchFolder = folder;
        performFileSearch();
    }

    function setFileSearchSort(sort) {
        if (fileSearchSort === sort)
            return;
        fileSearchSort = sort;
        performFileSearch();
    }

    function clearPluginFilter() {
        if (pluginFilter) {
            pluginFilter = "";
            performSearch();
            return true;
        }
        return false;
    }

    function preserveSelectionAfterUpdate(forceFirst) {
        if (forceFirst)
            return function () {
                return getFirstItemIndex();
            };
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
        var shouldResetSelection = _queryDrivenSearch;
        _queryDrivenSearch = false;
        var restoreSelection = preserveSelectionAfterUpdate(shouldResetSelection);

        var cachedSections = AppSearchService.getCachedDefaultSections();
        if (!cachedSections && !_diskCacheConsumed && !searchQuery && searchMode === "all" && !pluginFilter) {
            _diskCacheConsumed = true;
            var diskSections = _loadDiskCache();
            if (diskSections) {
                activePluginId = "";
                activePluginName = "";
                activePluginCategories = [];
                activePluginCategory = "";
                clearActivePluginViewPreference();
                for (var i = 0; i < diskSections.length; i++) {
                    if (collapsedSections[diskSections[i].id] !== undefined)
                        diskSections[i].collapsed = collapsedSections[diskSections[i].id];
                }
                _applyHighlights(diskSections, "");
                flatModel = Scorer.flattenSections(diskSections);
                sections = diskSections;
                selectedFlatIndex = restoreSelection(flatModel);
                updateSelectedItem();
                isSearching = false;
                searchCompleted();
                return;
            }
        }

        if (cachedSections && !searchQuery && searchMode === "all" && !pluginFilter) {
            activePluginId = "";
            activePluginName = "";
            activePluginCategories = [];
            activePluginCategory = "";
            clearActivePluginViewPreference();
            var modeCache = _getCachedModeData("all");
            if (modeCache) {
                _applyHighlights(modeCache.sections, "");
                sections = modeCache.sections;
                flatModel = modeCache.flatModel;
            } else {
                var newSections = cachedSections.map(function (s) {
                    var copy = Object.assign({}, s, {
                        items: s.items ? s.items.slice() : []
                    });
                    if (collapsedSections[s.id] !== undefined)
                        copy.collapsed = collapsedSections[s.id];
                    return copy;
                });
                _applyHighlights(newSections, "");
                flatModel = Scorer.flattenSections(newSections);
                sections = newSections;
                _setCachedModeData("all", sections, flatModel);
            }
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
            for (var k = 0; k < pluginItems.length; k++)
                allItems.push(pluginItems[k]);

            if (triggerMatch.isBuiltIn) {
                var builtInItems = AppSearchService.getBuiltInLauncherItems(triggerMatch.pluginId, triggerMatch.query);
                for (var j = 0; j < builtInItems.length; j++) {
                    allItems.push(transformBuiltInLauncherItem(builtInItems[j], triggerMatch.pluginId));
                }
            }

            var dynamicDefs = buildDynamicSectionDefs(allItems);
            var scoredItems = Scorer.scoreItems(allItems, triggerMatch.query, getFrecencyForItem);
            var sortAlpha = !triggerMatch.query && SettingsData.sortAppsAlphabetically;
            var newSections = Scorer.groupBySection(scoredItems, dynamicDefs, sortAlpha, 500);

            for (var sid in collapsedSections) {
                for (var i = 0; i < newSections.length; i++) {
                    if (newSections[i].id === sid) {
                        newSections[i].collapsed = collapsedSections[sid];
                    }
                }
            }

            _applyHighlights(newSections, triggerMatch.query);
            flatModel = Scorer.flattenSections(newSections);
            sections = newSections;
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
                var modeCache = _getCachedModeData("apps");
                if (modeCache) {
                    _applyHighlights(modeCache.sections, "");
                    sections = modeCache.sections;
                    flatModel = modeCache.flatModel;
                } else {
                    var appSectionIds = ["favorites", "apps"];
                    var newSections = cachedSections.filter(function (s) {
                        return appSectionIds.indexOf(s.id) !== -1;
                    }).map(function (s) {
                        var copy = Object.assign({}, s, {
                            items: s.items ? s.items.slice() : []
                        });
                        if (collapsedSections[s.id] !== undefined)
                            copy.collapsed = collapsedSections[s.id];
                        return copy;
                    });
                    _applyHighlights(newSections, "");
                    flatModel = Scorer.flattenSections(newSections);
                    sections = newSections;
                    _setCachedModeData("apps", sections, flatModel);
                }
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
            var newSections = Scorer.groupBySection(scoredItems, sectionDefinitions, sortAlpha, searchQuery ? 50 : 500);

            for (var sid in collapsedSections) {
                for (var i = 0; i < newSections.length; i++) {
                    if (newSections[i].id === sid) {
                        newSections[i].collapsed = collapsedSections[sid];
                    }
                }
            }

            _applyHighlights(newSections, searchQuery);
            flatModel = Scorer.flattenSections(newSections);
            sections = newSections;
            selectedFlatIndex = restoreSelection(flatModel);
            updateSelectedItem();

            isSearching = false;
            searchCompleted();
            return;
        }

        if (searchMode === "plugins") {
            if (!searchQuery && !pluginFilter) {
                var browseItems = getPluginBrowseItems();
                for (var k = 0; k < browseItems.length; k++)
                    allItems.push(browseItems[k]);
            } else if (pluginFilter) {
                var isBuiltInFilter = !!AppSearchService.builtInPlugins[pluginFilter];
                applyActivePluginViewPreference(pluginFilter, isBuiltInFilter);

                var filterItems = getPluginItems(pluginFilter, searchQuery);
                for (var k = 0; k < filterItems.length; k++)
                    allItems.push(filterItems[k]);

                var builtInItems = AppSearchService.getBuiltInLauncherItems(pluginFilter, searchQuery);
                for (var j = 0; j < builtInItems.length; j++) {
                    allItems.push(transformBuiltInLauncherItem(builtInItems[j], pluginFilter));
                }
            } else {
                var emptyTriggerPlugins = getEmptyTriggerPlugins();
                for (var i = 0; i < emptyTriggerPlugins.length; i++) {
                    var pluginId = emptyTriggerPlugins[i];
                    var pItems = getPluginItems(pluginId, searchQuery);
                    for (var k = 0; k < pItems.length; k++)
                        allItems.push(pItems[k]);
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
            var newSections = Scorer.groupBySection(scoredItems, dynamicDefs, sortAlpha, 500);

            for (var sid in collapsedSections) {
                for (var i = 0; i < newSections.length; i++) {
                    if (newSections[i].id === sid) {
                        newSections[i].collapsed = collapsedSections[sid];
                    }
                }
            }

            _applyHighlights(newSections, searchQuery);
            flatModel = Scorer.flattenSections(newSections);
            sections = newSections;
            selectedFlatIndex = restoreSelection(flatModel);
            updateSelectedItem();

            isSearching = false;
            searchCompleted();
            return;
        }

        var apps = searchApps(searchQuery);
        for (var i = 0; i < apps.length; i++) {
            if (searchQuery)
                apps[i]._preScored = 11000 - i;
            allItems.push(apps[i]);
        }

        if (searchMode === "all") {
            if (searchQuery && searchQuery.length >= 2) {
                _pluginPhasePending = true;
                _phase1Items = allItems.slice();
                pluginPhaseTimer.restart();
                if (allItems.length === 0) {
                    _pluginPhaseForceFirst = shouldResetSelection;
                    isSearching = true;
                    searchCompleted();
                    return;
                }
                _pluginPhaseForceFirst = false;
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
                        for (var j = 0; j < pItems.length; j++)
                            allItems.push(pItems[j]);
                    }
                }

                var browseItems = getPluginBrowseItems();
                for (var i = 0; i < browseItems.length; i++)
                    allItems.push(browseItems[i]);
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

        _applyHighlights(newSections, searchQuery);
        flatModel = Scorer.flattenSections(newSections);
        sections = newSections;

        if (!AppSearchService.isCacheValid() && !searchQuery && searchMode === "all" && !pluginFilter) {
            AppSearchService.setCachedDefaultSections(sections, flatModel);
            _saveDiskCache(sections);
        }

        selectedFlatIndex = restoreSelection(flatModel);
        updateSelectedItem();

        isSearching = _pluginPhasePending;
        searchCompleted();
    }

    function _performPluginPhase() {
        _pluginPhasePending = false;
        if (!searchQuery || searchQuery.length < 2 || searchMode !== "all")
            return;

        var currentVersion = _searchVersion;
        var restoreSelection = preserveSelectionAfterUpdate(_pluginPhaseForceFirst);
        var allItems = _phase1Items;
        _phase1Items = [];

        var allPluginsOrdered = getAllVisiblePluginsOrdered();
        var maxPerPlugin = 10;
        for (var i = 0; i < allPluginsOrdered.length; i++) {
            if (currentVersion !== _searchVersion)
                return;
            var plugin = allPluginsOrdered[i];
            if (plugin.isBuiltIn) {
                var blItems = AppSearchService.getBuiltInLauncherItems(plugin.id, searchQuery);
                var blLimit = Math.min(blItems.length, maxPerPlugin);
                for (var j = 0; j < blLimit; j++) {
                    var item = transformBuiltInLauncherItem(blItems[j], plugin.id);
                    item._preScored = 900 - j;
                    allItems.push(item);
                }
            } else {
                var pItems = getPluginItems(plugin.id, searchQuery, maxPerPlugin);
                for (var j = 0; j < pItems.length; j++) {
                    pItems[j]._preScored = 900 - j;
                    allItems.push(pItems[j]);
                }
            }
        }

        if (currentVersion !== _searchVersion)
            return;

        var dynamicDefs = buildDynamicSectionDefs(allItems);
        var scoredItems = Scorer.scoreItems(allItems, searchQuery, getFrecencyForItem);
        var newSections = Scorer.groupBySection(scoredItems, dynamicDefs, false, 50);

        if (currentVersion !== _searchVersion)
            return;

        for (var i = 0; i < newSections.length; i++) {
            var sid = newSections[i].id;
            if (collapsedSections[sid] !== undefined)
                newSections[i].collapsed = collapsedSections[sid];
        }

        _applyHighlights(newSections, searchQuery);
        flatModel = Scorer.flattenSections(newSections);
        sections = newSections;
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
            sort: fileSearchSort || "score",
            desc: true
        };

        if (DSearchService.supportsTypeFilter) {
            params.type = (fileSearchType && fileSearchType !== "all") ? fileSearchType : "all";
        }
        if (fileSearchExt) {
            params.ext = fileSearchExt;
        }
        if (fileSearchFolder) {
            params.folder = fileSearchFolder;
        }

        DSearchService.search(fileQuery, params, function (response) {
            isFileSearching = false;
            if (response.error)
                return;
            var fileItems = [];
            var hits = response.result?.hits || [];

            for (var i = 0; i < hits.length; i++) {
                var hit = hits[i];
                var docTypes = hit.locations?.doc_type;
                var isDir = docTypes ? !!docTypes["dir"] : false;
                fileItems.push(transformFileResult({
                    path: hit.id || "",
                    score: hit.score || 0,
                    is_dir: isDir
                }));
            }

            var fileSections = [];
            var showType = fileSearchType || "all";

            if (showType === "all" && DSearchService.supportsTypeFilter) {
                var onlyFiles = [];
                var onlyDirs = [];
                for (var j = 0; j < fileItems.length; j++) {
                    if (fileItems[j].data?.is_dir)
                        onlyDirs.push(fileItems[j]);
                    else
                        onlyFiles.push(fileItems[j]);
                }
                if (onlyFiles.length > 0) {
                    fileSections.push({
                        id: "files",
                        title: I18n.tr("Files"),
                        icon: "insert_drive_file",
                        priority: 4,
                        items: onlyFiles,
                        collapsed: collapsedSections["files"] || false,
                        flatStartIndex: 0
                    });
                }
                if (onlyDirs.length > 0) {
                    fileSections.push({
                        id: "folders",
                        title: I18n.tr("Folders"),
                        icon: "folder",
                        priority: 4.1,
                        items: onlyDirs,
                        collapsed: collapsedSections["folders"] || false,
                        flatStartIndex: 0
                    });
                }
            } else {
                var filesIcon = showType === "dir" ? "folder" : showType === "file" ? "insert_drive_file" : "folder";
                var filesTitle = showType === "dir" ? I18n.tr("Folders") : I18n.tr("Files");
                if (fileItems.length > 0) {
                    fileSections.push({
                        id: "files",
                        title: filesTitle,
                        icon: filesIcon,
                        priority: 4,
                        items: fileItems,
                        collapsed: collapsedSections["files"] || false,
                        flatStartIndex: 0
                    });
                }
            }

            var newSections;
            if (searchMode === "files") {
                newSections = fileSections;
            } else {
                var existingNonFile = sections.filter(function (s) {
                    return s.id !== "files" && s.id !== "folders";
                });
                newSections = existingNonFile.concat(fileSections);
            }
            newSections.sort(function (a, b) {
                return a.priority - b.priority;
            });
            _applyHighlights(newSections, searchQuery);
            flatModel = Scorer.flattenSections(newSections);
            sections = newSections;
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
        return Transform.transformFileResult(file, I18n.tr("Open"), I18n.tr("Open folder"), I18n.tr("Copy path"), I18n.tr("Open in terminal"));
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

    function getPluginItems(pluginId, query, limit) {
        var items = AppSearchService.getPluginItemsForPlugin(pluginId, query);
        var count = limit > 0 && limit < items.length ? limit : items.length;
        var transformed = [];

        for (var i = 0; i < count; i++) {
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

    function _getCachedModeData(mode) {
        return _modeSectionsCache[mode] || null;
    }

    function _setCachedModeData(mode, sectionsData, flatModelData) {
        var cache = Object.assign({}, _modeSectionsCache);
        cache[mode] = {
            sections: sectionsData,
            flatModel: flatModelData
        };
        _modeSectionsCache = cache;
    }

    function _clearModeCache() {
        _modeSectionsCache = {};
    }

    function _saveDiskCache(sectionsData) {
        var serializable = [];
        for (var i = 0; i < sectionsData.length; i++) {
            var s = sectionsData[i];
            var items = [];
            var srcItems = s.items || [];
            for (var j = 0; j < srcItems.length; j++) {
                var it = srcItems[j];
                items.push({
                    id: it.id,
                    type: it.type,
                    name: it.name || "",
                    subtitle: it.subtitle || "",
                    icon: it.icon || "",
                    iconType: it.iconType || "image",
                    iconFull: it.iconFull || "",
                    section: it.section || "",
                    isCore: it.isCore || false,
                    isBuiltInLauncher: it.isBuiltInLauncher || false,
                    pluginId: it.pluginId || ""
                });
            }
            serializable.push({
                id: s.id,
                title: s.title || "",
                icon: s.icon || "",
                priority: s.priority || 0,
                items: items
            });
        }
        CacheData.saveLauncherCache(serializable);
    }

    function _actionsFromDesktopEntry(appId) {
        if (!appId)
            return [];
        var entry = DesktopEntries.heuristicLookup(appId);
        if (!entry || !entry.actions || entry.actions.length === 0)
            return [];
        var result = [];
        for (var i = 0; i < entry.actions.length; i++) {
            result.push({
                name: entry.actions[i].name,
                icon: "play_arrow",
                actionData: entry.actions[i]
            });
        }
        return result;
    }

    function _loadDiskCache() {
        var cached = CacheData.loadLauncherCache();
        if (!cached || !Array.isArray(cached) || cached.length === 0)
            return null;

        var sectionsData = [];
        for (var i = 0; i < cached.length; i++) {
            var s = cached[i];
            var items = [];
            var srcItems = s.items || [];
            for (var j = 0; j < srcItems.length; j++) {
                var it = srcItems[j];
                items.push({
                    id: it.id || "",
                    type: it.type || "app",
                    name: it.name || "",
                    subtitle: it.subtitle || "",
                    icon: it.icon || "",
                    iconType: it.iconType || "image",
                    iconFull: it.iconFull || "",
                    section: it.section || "",
                    isCore: it.isCore || false,
                    isBuiltInLauncher: it.isBuiltInLauncher || false,
                    pluginId: it.pluginId || "",
                    data: {
                        id: it.id
                    },
                    actions: _actionsFromDesktopEntry(it.id),
                    primaryAction: it.type === "app" && !it.isCore ? {
                        name: I18n.tr("Launch"),
                        icon: "open_in_new",
                        action: "launch"
                    } : null,
                    _diskCached: true,
                    _hName: "",
                    _hSub: "",
                    _hRich: false,
                    _preScored: undefined
                });
            }
            sectionsData.push({
                id: s.id || "",
                title: s.title || "",
                icon: s.icon || "",
                priority: s.priority || 0,
                items: items,
                collapsed: false,
                flatStartIndex: 0
            });
        }
        return sectionsData;
    }

    function updateSelectedItem() {
        if (selectedFlatIndex >= 0 && selectedFlatIndex < flatModel.length) {
            var entry = flatModel[selectedFlatIndex];
            selectedItem = entry.isHeader ? null : entry.item;
        } else {
            selectedItem = null;
        }
    }

    function _applyHighlights(sectionsData, query) {
        if (!query || query.length === 0) {
            for (var i = 0; i < sectionsData.length; i++) {
                var items = sectionsData[i].items;
                for (var j = 0; j < items.length; j++) {
                    var item = items[j];
                    item._hName = item.name || "";
                    item._hSub = item.subtitle || "";
                    item._hRich = false;
                }
            }
            return;
        }

        var highlightColor = Theme.primary;
        var nameColor = Theme.surfaceText;
        var subColor = Theme.surfaceVariantText;
        var lowerQuery = query.toLowerCase();

        for (var i = 0; i < sectionsData.length; i++) {
            var items = sectionsData[i].items;
            for (var j = 0; j < items.length; j++) {
                var item = items[j];
                item._hName = _highlightField(item.name || "", lowerQuery, query.length, nameColor, highlightColor);
                item._hSub = _highlightField(item.subtitle || "", lowerQuery, query.length, subColor, highlightColor);
                item._hRich = true;
            }
        }
    }

    function _highlightField(text, lowerQuery, queryLen, baseColor, highlightColor) {
        if (!text)
            return "";
        var idx = text.toLowerCase().indexOf(lowerQuery);
        if (idx === -1)
            return text;
        var before = text.substring(0, idx);
        var match = text.substring(idx, idx + queryLen);
        var after = text.substring(idx + queryLen);
        return '<span style="color:' + baseColor + '">' + before + '</span><span style="color:' + highlightColor + '; font-weight:600">' + match + '</span><span style="color:' + baseColor + '">' + after + '</span>';
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

    function _cancelPendingSelectionReset() {
        _queryDrivenSearch = false;
        _pluginPhaseForceFirst = false;
    }

    function selectNext() {
        keyboardNavigationActive = true;
        _cancelPendingSelectionReset();
        var newIndex = Nav.calculateNextIndex(flatModel, selectedFlatIndex, null, null, gridColumns, getSectionViewMode);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectPrevious() {
        keyboardNavigationActive = true;
        _cancelPendingSelectionReset();
        var newIndex = Nav.calculatePrevIndex(flatModel, selectedFlatIndex, null, null, gridColumns, getSectionViewMode);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectRight() {
        keyboardNavigationActive = true;
        _cancelPendingSelectionReset();
        var newIndex = Nav.calculateRightIndex(flatModel, selectedFlatIndex, getSectionViewMode);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectLeft() {
        keyboardNavigationActive = true;
        _cancelPendingSelectionReset();
        var newIndex = Nav.calculateLeftIndex(flatModel, selectedFlatIndex, getSectionViewMode);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectNextSection() {
        keyboardNavigationActive = true;
        _cancelPendingSelectionReset();
        var newIndex = Nav.calculateNextSectionIndex(flatModel, selectedFlatIndex);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectPreviousSection() {
        keyboardNavigationActive = true;
        _cancelPendingSelectionReset();
        var newIndex = Nav.calculatePrevSectionIndex(flatModel, selectedFlatIndex);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectPageDown(visibleItems) {
        keyboardNavigationActive = true;
        _cancelPendingSelectionReset();
        var newIndex = Nav.calculatePageDownIndex(flatModel, selectedFlatIndex, visibleItems);
        if (newIndex !== selectedFlatIndex) {
            selectedFlatIndex = newIndex;
            updateSelectedItem();
        }
    }

    function selectPageUp(visibleItems) {
        keyboardNavigationActive = true;
        _cancelPendingSelectionReset();
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
        _clearModeCache();
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
        flatModel = Scorer.flattenSections(newSections);
        sections = newSections;

        if (selectedFlatIndex >= flatModel.length) {
            selectedFlatIndex = getFirstItemIndex();
        }
        updateSelectedItem();
    }

    function executeSelected() {
        if (searchDebounce.running) {
            searchDebounce.stop();
            performSearch();
        }
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
        case "open_terminal":
            openTerminal(item.data.path);
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

    function _resolveDesktopEntry(app) {
        if (!app)
            return null;
        if (app.command)
            return app;
        var id = app.id || app.execString || app.exec || "";
        if (!id)
            return null;
        return DesktopEntries.heuristicLookup(id);
    }

    function launchApp(app) {
        var entry = _resolveDesktopEntry(app);
        if (!entry)
            return;
        SessionService.launchDesktopEntry(entry);
        AppUsageHistoryData.addAppUsage(entry);
    }

    function launchAppWithNvidia(app) {
        var entry = _resolveDesktopEntry(app);
        if (!entry)
            return;
        SessionService.launchDesktopEntry(entry, true);
        AppUsageHistoryData.addAppUsage(entry);
    }

    function launchAppAction(actionItem) {
        if (!actionItem || !actionItem.actionData)
            return;
        var entry = _resolveDesktopEntry(actionItem.parentApp);
        if (!entry)
            return;
        SessionService.launchDesktopAction(entry, actionItem.actionData);
        AppUsageHistoryData.addAppUsage(entry);
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

    function openTerminal(path) {
        if (!path)
            return;
        var terminal = Quickshell.env("TERMINAL") || "xterm";
        Quickshell.execDetached({
            command: [terminal],
            workingDirectory: path
        });
    }

    function copyToClipboard(text) {
        if (!text)
            return;
        Quickshell.execDetached(["dms", "cl", "copy", text]);
    }
}
