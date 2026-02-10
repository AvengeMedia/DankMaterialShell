pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root

    property var applications: []
    property var _cachedCategories: null
    property var _cachedVisibleApps: null
    property var _hiddenAppsSet: new Set()

    property var _transformCache: ({})
    property var _cachedDefaultSections: []
    property var _cachedDefaultFlatModel: []
    property bool _defaultCacheValid: false
    property int cacheVersion: 0

    readonly property int maxResults: 10
    readonly property int frecencySampleSize: 10

    readonly property var timeBuckets: [
        {
            "maxDays": 4,
            "weight": 100
        },
        {
            "maxDays": 14,
            "weight": 70
        },
        {
            "maxDays": 31,
            "weight": 50
        },
        {
            "maxDays": 90,
            "weight": 30
        },
        {
            "maxDays": 99999,
            "weight": 10
        }
    ]

    function refreshApplications() {
        applications = DesktopEntries.applications.values;
        _cachedCategories = null;
        _cachedVisibleApps = null;
        invalidateLauncherCache();
    }

    function invalidateLauncherCache() {
        _transformCache = {};
        _defaultCacheValid = false;
        _cachedDefaultSections = [];
        _cachedDefaultFlatModel = [];
        cacheVersion++;
    }

    function getOrTransformApp(app, transformFn) {
        const id = app.id || app.execString || app.exec || "";
        if (!id)
            return transformFn(app);
        const cached = _transformCache[id];
        if (cached) {
            const currentIcon = app.icon || "";
            const cachedSourceIcon = cached._sourceIcon || "";
            if (currentIcon === cachedSourceIcon)
                return cached;
        }
        const transformed = transformFn(app);
        transformed._sourceIcon = app.icon || "";
        _transformCache[id] = transformed;
        return transformed;
    }

    function getCachedDefaultSections() {
        if (!_defaultCacheValid)
            return null;
        return _cachedDefaultSections;
    }

    function setCachedDefaultSections(sections, flatModel) {
        _cachedDefaultSections = sections.map(function (s) {
            return Object.assign({}, s, {
                items: s.items ? s.items.slice() : []
            });
        });
        _cachedDefaultFlatModel = flatModel.slice();
        _defaultCacheValid = true;
    }

    function isCacheValid() {
        return _defaultCacheValid;
    }

    function _rebuildHiddenSet() {
        _hiddenAppsSet = new Set(SessionData.hiddenApps || []);
        _cachedVisibleApps = null;
    }

    function isAppHidden(app) {
        if (!app)
            return false;
        const appId = app.id || app.execString || app.exec || "";
        return _hiddenAppsSet.has(appId);
    }

    function getVisibleApplications() {
        if (_cachedVisibleApps === null) {
            const seen = new Set();
            _cachedVisibleApps = applications.filter(app => {
                if (isAppHidden(app))
                    return false;
                const id = app.id;
                if (id && seen.has(id))
                    return false;
                if (id)
                    seen.add(id);
                return true;
            });
        }
        return _cachedVisibleApps.map(app => applyAppOverride(app));
    }

    Connections {
        target: SessionData
        function onHiddenAppsChanged() {
            root._rebuildHiddenSet();
            root.invalidateLauncherCache();
        }
        function onAppOverridesChanged() {
            root._cachedVisibleApps = null;
            root.invalidateLauncherCache();
        }
    }

    Connections {
        target: AppUsageHistoryData
        function onAppUsageRankingChanged() {
            root.invalidateLauncherCache();
        }
    }

    function applyAppOverride(app) {
        if (!app)
            return app;
        const appId = app.id || app.execString || app.exec || "";
        const override = SessionData.getAppOverride(appId);
        if (!override)
            return app;
        return Object.assign({}, app, {
            name: override.name || app.name,
            icon: override.icon || app.icon,
            comment: override.comment || app.comment,
            _override: override
        });
    }

    readonly property string dmsLogoPath: Qt.resolvedUrl("../assets/danklogo2.svg")

    readonly property var builtInPlugins: ({
            "dms_settings": {
                id: "dms_settings",
                name: I18n.tr("Settings", "settings window title"),
                icon: "svg+corner:" + dmsLogoPath + "|settings",
                cornerIcon: "settings",
                comment: "DMS",
                action: "ipc:settings",
                categories: ["Settings", "System"],
                defaultTrigger: "",
                isLauncher: false
            },
            "dms_notepad": {
                id: "dms_notepad",
                name: I18n.tr("Notepad", "Notepad"),
                icon: "svg+corner:" + dmsLogoPath + "|description",
                cornerIcon: "description",
                comment: "DMS",
                action: "ipc:notepad",
                categories: ["Office", "Utility"],
                defaultTrigger: "",
                isLauncher: false
            },
            "dms_sysmon": {
                id: "dms_sysmon",
                name: I18n.tr("System Monitor", "sysmon window title"),
                icon: "svg+corner:" + dmsLogoPath + "|monitor_heart",
                cornerIcon: "monitor_heart",
                comment: "DMS",
                action: "ipc:processlist",
                categories: ["System", "Monitor"],
                defaultTrigger: "",
                isLauncher: false
            },
            "dms_settings_search": {
                id: "dms_settings_search",
                name: I18n.tr("Settings", "settings window title"),
                cornerIcon: "search",
                comment: "DMS",
                defaultTrigger: "?",
                isLauncher: true
            }
        })

    function getBuiltInPluginTrigger(pluginId) {
        const plugin = builtInPlugins[pluginId];
        if (!plugin)
            return null;
        return SettingsData.getBuiltInPluginSetting(pluginId, "trigger", plugin.defaultTrigger);
    }

    readonly property var coreApps: {
        SettingsData.builtInPluginSettings;
        const apps = [];
        for (const pluginId in builtInPlugins) {
            if (!SettingsData.getBuiltInPluginSetting(pluginId, "enabled", true))
                continue;
            const plugin = builtInPlugins[pluginId];
            if (plugin.isLauncher)
                continue;
            apps.push({
                name: plugin.name,
                icon: plugin.icon,
                comment: plugin.comment,
                action: plugin.action,
                categories: plugin.categories,
                isCore: true,
                builtInPluginId: pluginId,
                cornerIcon: plugin.cornerIcon
            });
        }
        return apps;
    }

    function getBuiltInLauncherPlugins() {
        const result = {};
        for (const pluginId in builtInPlugins) {
            const plugin = builtInPlugins[pluginId];
            if (!plugin.isLauncher)
                continue;
            if (!SettingsData.getBuiltInPluginSetting(pluginId, "enabled", true))
                continue;
            result[pluginId] = plugin;
        }
        return result;
    }

    function getBuiltInLauncherTriggers() {
        const triggers = {};
        const launchers = getBuiltInLauncherPlugins();
        for (const pluginId in launchers) {
            const trigger = getBuiltInPluginTrigger(pluginId);
            if (trigger && trigger.trim() !== "")
                triggers[trigger] = pluginId;
        }
        return triggers;
    }

    function getBuiltInLauncherPluginsWithEmptyTrigger() {
        const result = [];
        const launchers = getBuiltInLauncherPlugins();
        for (const pluginId in launchers) {
            const trigger = getBuiltInPluginTrigger(pluginId);
            if (!trigger || trigger.trim() === "")
                result.push(pluginId);
        }
        return result;
    }

    function getBuiltInLauncherItems(pluginId, query) {
        if (pluginId !== "dms_settings_search")
            return [];

        SettingsSearchService.search(query);
        const results = SettingsSearchService.results;
        const items = [];
        for (let i = 0; i < results.length; i++) {
            const r = results[i];
            items.push({
                name: r.label,
                icon: "material:" + r.icon,
                comment: r.category,
                action: "settings_nav:" + r.tabIndex + ":" + r.section,
                categories: ["Settings"],
                isCore: true,
                isBuiltInLauncher: true,
                builtInPluginId: pluginId
            });
        }
        return items;
    }

    function executeBuiltInLauncherItem(item) {
        if (!item?.action)
            return false;

        const parts = item.action.split(":");
        if (parts[0] !== "settings_nav")
            return false;

        const tabIndex = parseInt(parts[1]);
        const section = parts.slice(2).join(":");
        SettingsSearchService.navigateToSection(section);
        PopoutService.openSettingsWithTabIndex(tabIndex);
        return true;
    }

    function getCoreApps(query) {
        if (!query || query.length === 0)
            return coreApps;
        const lowerQuery = query.toLowerCase();
        return coreApps.filter(app => app.name.toLowerCase().includes(lowerQuery) || app.comment.toLowerCase().includes(lowerQuery));
    }

    function executeCoreApp(app) {
        if (!app?.action)
            return false;

        const parts = app.action.split(":");
        if (parts[0] !== "ipc")
            return false;

        switch (parts[1]) {
        case "settings":
            PopoutService.focusOrToggleSettings();
            return true;
        case "notepad":
            PopoutService.toggleNotepad();
            return true;
        case "processlist":
            PopoutService.toggleProcessListModal();
            return true;
        }
        return false;
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.refreshApplications();
        }
    }

    Component.onCompleted: {
        _rebuildHiddenSet();
        refreshApplications();
    }

    function tokenize(text) {
        return text.toLowerCase().trim().split(/[\s\-_]+/).filter(w => w.length > 0);
    }

    function wordBoundaryMatch(text, query) {
        const textWords = tokenize(text);
        const queryWords = tokenize(query);

        if (queryWords.length === 0)
            return false;
        if (queryWords.length > textWords.length)
            return false;

        for (var i = 0; i <= textWords.length - queryWords.length; i++) {
            let allMatch = true;
            for (var j = 0; j < queryWords.length; j++) {
                if (!textWords[i + j].startsWith(queryWords[j])) {
                    allMatch = false;
                    break;
                }
            }
            if (allMatch)
                return true;
        }
        return false;
    }

    function levenshteinDistance(s1, s2) {
        const len1 = s1.length;
        const len2 = s2.length;
        const matrix = [];

        for (var i = 0; i <= len1; i++) {
            matrix[i] = [i];
        }
        for (var j = 0; j <= len2; j++) {
            matrix[0][j] = j;
        }

        for (var i = 1; i <= len1; i++) {
            for (var j = 1; j <= len2; j++) {
                const cost = s1[i - 1] === s2[j - 1] ? 0 : 1;
                matrix[i][j] = Math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost);
            }
        }
        return matrix[len1][len2];
    }

    function fuzzyMatchScore(text, query) {
        const queryLower = query.toLowerCase();
        const maxDistance = query.length <= 2 ? 0 : query.length === 3 ? 1 : query.length <= 6 ? 2 : 3;

        let bestScore = 0;

        const distance = levenshteinDistance(text.toLowerCase(), queryLower);
        if (distance <= maxDistance) {
            const maxLen = Math.max(text.length, query.length);
            bestScore = 1 - (distance / maxLen);
        }

        const words = tokenize(text);
        for (const word of words) {
            const wordDistance = levenshteinDistance(word, queryLower);
            if (wordDistance <= maxDistance) {
                const maxLen = Math.max(word.length, query.length);
                const score = 1 - (wordDistance / maxLen);
                bestScore = Math.max(bestScore, score);
            }
        }

        return bestScore;
    }

    function calculateFrecency(app) {
        const usageRanking = AppUsageHistoryData.appUsageRanking || {};
        const appId = app.id || (app.execString || app.exec || "");
        const idVariants = [appId, appId.replace(".desktop", ""), app.id, app.id ? app.id.replace(".desktop", "") : null].filter(id => id);

        let usageData = null;
        for (const variant of idVariants) {
            if (usageRanking[variant]) {
                usageData = usageRanking[variant];
                break;
            }
        }

        if (!usageData || !usageData.usageCount) {
            return {
                "frecency": 0,
                "daysSinceUsed": 999999
            };
        }

        const usageCount = usageData.usageCount || 0;
        const lastUsed = usageData.lastUsed || 0;
        const now = Date.now();
        const daysSinceUsed = (now - lastUsed) / (1000 * 60 * 60 * 24);

        let timeBucketWeight = 10;
        for (const bucket of timeBuckets) {
            if (daysSinceUsed <= bucket.maxDays) {
                timeBucketWeight = bucket.weight;
                break;
            }
        }

        const contextBonus = 100;
        const sampleSize = Math.min(usageCount, frecencySampleSize);
        const frecency = (timeBucketWeight * contextBonus * sampleSize) / 100;

        return {
            "frecency": frecency,
            "daysSinceUsed": daysSinceUsed
        };
    }

    function searchApplications(query) {
        if (!query || query.length === 0)
            return getVisibleApplications();
        if (applications.length === 0)
            return [];

        const queryLower = query.toLowerCase().trim();
        const scoredApps = [];
        const results = [];
        const visibleApps = getVisibleApplications();

        for (const app of visibleApps) {
            const name = (app.name || "").toLowerCase();
            const genericName = (app.genericName || "").toLowerCase();
            const comment = (app.comment || "").toLowerCase();
            const id = (app.id || "").toLowerCase();
            const keywords = app.keywords ? app.keywords.map(k => k.toLowerCase()) : [];

            let textScore = 0;
            let matchType = "none";

            if (name === queryLower) {
                textScore = 10000;
                matchType = "exact";
            } else if (name.startsWith(queryLower)) {
                textScore = 5000;
                matchType = "prefix";
            } else if (wordBoundaryMatch(name, queryLower)) {
                textScore = 1000;
                matchType = "word_boundary";
            } else if (name.includes(queryLower)) {
                textScore = 500;
                matchType = "substring";
            } else if (genericName && genericName.startsWith(queryLower)) {
                textScore = 800;
                matchType = "generic_prefix";
            } else if (genericName && genericName.includes(queryLower)) {
                textScore = 400;
                matchType = "generic";
            } else if (id && id.includes(queryLower)) {
                textScore = 350;
                matchType = "id";
            }

            if (matchType === "none" && keywords.length > 0) {
                for (const keyword of keywords) {
                    if (keyword.startsWith(queryLower)) {
                        textScore = 300;
                        matchType = "keyword_prefix";
                        break;
                    } else if (keyword.includes(queryLower)) {
                        textScore = 150;
                        matchType = "keyword";
                        break;
                    }
                }
            }

            if (matchType === "none" && comment && comment.includes(queryLower)) {
                textScore = 50;
                matchType = "comment";
            }

            if (matchType === "none") {
                const fuzzyScore = fuzzyMatchScore(name, queryLower);
                if (fuzzyScore > 0) {
                    textScore = fuzzyScore * 100;
                    matchType = "fuzzy";
                }
            }

            if (matchType !== "none") {
                const frecencyData = calculateFrecency(app);

                results.push({
                    "app": app,
                    "textScore": textScore,
                    "frecency": frecencyData.frecency,
                    "daysSinceUsed": frecencyData.daysSinceUsed,
                    "matchType": matchType
                });
            }
        }

        for (const result of results) {
            const frecencyBonus = result.frecency > 0 ? Math.min(result.frecency / 10, 2000) : 0;
            const recencyBonus = result.daysSinceUsed < 1 ? 1500 : result.daysSinceUsed < 7 ? 1000 : result.daysSinceUsed < 30 ? 500 : 0;

            const finalScore = result.textScore + frecencyBonus + recencyBonus;

            scoredApps.push({
                "app": result.app,
                "score": finalScore
            });
        }

        if (SessionData.searchAppActions) {
            const actionResults = searchAppActions(queryLower, visibleApps);
            for (const actionResult of actionResults) {
                scoredApps.push({
                    app: actionResult.app,
                    score: actionResult.score
                });
            }
        }

        scoredApps.sort((a, b) => b.score - a.score);
        return scoredApps.slice(0, maxResults).map(item => item.app);
    }

    function searchAppActions(query, apps) {
        const results = [];
        for (const app of apps) {
            if (!app.actions || app.actions.length === 0)
                continue;
            for (const action of app.actions) {
                const actionName = (action.name || "").toLowerCase();
                if (!actionName)
                    continue;

                let score = 0;
                if (actionName === query) {
                    score = 8000;
                } else if (actionName.startsWith(query)) {
                    score = 4000;
                } else if (actionName.includes(query)) {
                    score = 400;
                }

                if (score > 0) {
                    results.push({
                        app: {
                            name: action.name,
                            icon: action.icon || app.icon,
                            comment: app.name,
                            categories: app.categories || [],
                            isAction: true,
                            parentApp: app,
                            actionData: action
                        },
                        score: score
                    });
                }
            }
        }
        return results;
    }

    function getCategoriesForApp(app) {
        if (!app?.categories)
            return [];

        const categoryMap = {
            "AudioVideo": I18n.tr("Media"),
            "Audio": I18n.tr("Media"),
            "Video": I18n.tr("Media"),
            "Development": I18n.tr("Development"),
            "TextEditor": I18n.tr("Development"),
            "IDE": I18n.tr("Development"),
            "Education": I18n.tr("Education"),
            "Game": I18n.tr("Games"),
            "Graphics": I18n.tr("Graphics"),
            "Photography": I18n.tr("Graphics"),
            "Network": I18n.tr("Internet"),
            "WebBrowser": I18n.tr("Internet"),
            "Email": I18n.tr("Internet"),
            "Office": I18n.tr("Office"),
            "WordProcessor": I18n.tr("Office"),
            "Spreadsheet": I18n.tr("Office"),
            "Presentation": I18n.tr("Office"),
            "Science": I18n.tr("Science"),
            "Settings": I18n.tr("Settings"),
            "System": I18n.tr("System"),
            "Utility": I18n.tr("Utilities"),
            "Accessories": I18n.tr("Utilities"),
            "FileManager": I18n.tr("Utilities"),
            "TerminalEmulator": I18n.tr("Utilities")
        };

        const mappedCategories = new Set();

        for (const cat of app.categories) {
            if (categoryMap[cat])
                mappedCategories.add(categoryMap[cat]);
        }

        return Array.from(mappedCategories);
    }

    property var categoryIcons: ({
            "All": "apps",
            "Media": "music_video",
            "Development": "code",
            "Games": "sports_esports",
            "Graphics": "photo_library",
            "Internet": "web",
            "Office": "content_paste",
            "Settings": "settings",
            "System": "host",
            "Utilities": "build"
        })

    function getCategoryIcon(category) {
        // Check if it's a plugin category
        const pluginIcon = getPluginCategoryIcon(category);
        if (pluginIcon) {
            return pluginIcon;
        }
        return categoryIcons[category] || "folder";
    }

    function getAllCategories() {
        if (_cachedCategories)
            return _cachedCategories;

        const categories = new Set([I18n.tr("All")]);
        for (const app of applications) {
            const appCategories = getCategoriesForApp(app);
            appCategories.forEach(cat => categories.add(cat));
        }

        const pluginCategories = getPluginCategories();
        pluginCategories.forEach(cat => categories.add(cat));

        _cachedCategories = Array.from(categories).sort();
        return _cachedCategories;
    }

    function getAppsInCategory(category) {
        const visibleApps = getVisibleApplications();
        if (category === I18n.tr("All"))
            return visibleApps;

        const pluginItems = getPluginItems(category, "");
        if (pluginItems.length > 0)
            return pluginItems;

        return visibleApps.filter(app => {
            const appCategories = getCategoriesForApp(app);
            return appCategories.includes(category);
        });
    }

    // Plugin launcher support functions
    function getPluginCategories() {
        if (typeof PluginService === "undefined") {
            return [];
        }

        const categories = [];
        const launchers = PluginService.getLauncherPlugins();

        for (const pluginId in launchers) {
            const plugin = launchers[pluginId];
            const categoryName = plugin.name || pluginId;
            categories.push(categoryName);
        }

        return categories;
    }

    function getPluginCategoryIcon(category) {
        if (typeof PluginService === "undefined")
            return null;

        const launchers = PluginService.getLauncherPlugins();
        for (const pluginId in launchers) {
            const plugin = launchers[pluginId];
            if ((plugin.name || pluginId) === category) {
                return plugin.icon || "extension";
            }
        }
        return null;
    }

    function getAllPluginItems() {
        if (typeof PluginService === "undefined") {
            return [];
        }

        let allItems = [];
        const launchers = PluginService.getLauncherPlugins();

        for (const pluginId in launchers) {
            const categoryName = launchers[pluginId].name || pluginId;
            const items = getPluginItems(categoryName, "");
            allItems = allItems.concat(items);
        }

        return allItems;
    }

    function getPluginItems(category, query) {
        if (typeof PluginService === "undefined")
            return [];

        const launchers = PluginService.getLauncherPlugins();
        for (const pluginId in launchers) {
            const plugin = launchers[pluginId];
            if ((plugin.name || pluginId) === category) {
                return getPluginItemsForPlugin(pluginId, query);
            }
        }
        return [];
    }

    function getPluginItemsForPlugin(pluginId, query) {
        if (typeof PluginService === "undefined") {
            return [];
        }

        let instance = PluginService.pluginInstances[pluginId];
        let isPersistent = true;

        if (!instance) {
            const component = PluginService.pluginLauncherComponents[pluginId];
            if (!component)
                return [];

            try {
                instance = component.createObject(root, {
                    "pluginService": PluginService
                });
                isPersistent = false;
            } catch (e) {
                console.warn("AppSearchService: Error creating temporary plugin instance", pluginId, ":", e);
                return [];
            }
        }

        if (!instance)
            return [];

        try {
            if (typeof instance.getItems === "function") {
                const items = instance.getItems(query || "");
                if (!isPersistent)
                    instance.destroy();
                return items || [];
            }

            if (!isPersistent) {
                instance.destroy();
            }
        } catch (e) {
            console.warn("AppSearchService: Error getting items from plugin", pluginId, ":", e);
            if (!isPersistent)
                instance.destroy();
        }

        return [];
    }

    function executePluginItem(item, pluginId) {
        if (typeof PluginService === "undefined")
            return false;

        let instance = PluginService.pluginInstances[pluginId];
        let isPersistent = true;

        if (!instance) {
            const component = PluginService.pluginLauncherComponents[pluginId];
            if (!component)
                return false;

            try {
                instance = component.createObject(root, {
                    "pluginService": PluginService
                });
                isPersistent = false;
            } catch (e) {
                console.warn("AppSearchService: Error creating temporary plugin instance for execution", pluginId, ":", e);
                return false;
            }
        }

        if (!instance)
            return false;

        try {
            if (typeof instance.executeItem === "function") {
                instance.executeItem(item);
                if (!isPersistent)
                    instance.destroy();
                return true;
            }

            if (!isPersistent) {
                instance.destroy();
            }
        } catch (e) {
            console.warn("AppSearchService: Error executing item from plugin", pluginId, ":", e);
            if (!isPersistent)
                instance.destroy();
        }

        return false;
    }

    function getPluginPasteText(pluginId, item) {
        if (typeof PluginService === "undefined")
            return null;

        const instance = PluginService.pluginInstances[pluginId];
        if (!instance)
            return null;

        if (typeof instance.getPasteText === "function") {
            return instance.getPasteText(item);
        }

        return null;
    }

    function getPluginPasteArgs(pluginId, item) {
        if (typeof PluginService === "undefined")
            return null;

        const instance = PluginService.pluginInstances[pluginId];
        if (!instance)
            return null;

        if (typeof instance.getPasteArgs === "function")
            return instance.getPasteArgs(item);

        if (typeof instance.getPasteText === "function") {
            const text = instance.getPasteText(item);
            if (text)
                return ["dms", "cl", "copy", text];
        }

        return null;
    }

    function searchPluginItems(query) {
        if (typeof PluginService === "undefined")
            return [];

        let allItems = [];
        const launchers = PluginService.getLauncherPlugins();

        for (const pluginId in launchers) {
            const items = getPluginItemsForPlugin(pluginId, query);
            allItems = allItems.concat(items);
        }

        return allItems;
    }

    function getPluginLauncherCategories(pluginId) {
        if (typeof PluginService === "undefined")
            return [];

        const instance = PluginService.pluginInstances[pluginId];
        if (!instance)
            return [];

        if (typeof instance.getCategories !== "function")
            return [];

        try {
            return instance.getCategories() || [];
        } catch (e) {
            console.warn("AppSearchService: Error getting categories from plugin", pluginId, ":", e);
            return [];
        }
    }

    function setPluginLauncherCategory(pluginId, categoryId) {
        if (typeof PluginService === "undefined")
            return;

        const instance = PluginService.pluginInstances[pluginId];
        if (!instance)
            return;

        if (typeof instance.setCategory !== "function")
            return;

        try {
            instance.setCategory(categoryId);
        } catch (e) {
            console.warn("AppSearchService: Error setting category on plugin", pluginId, ":", e);
        }
    }

    function pluginHasCategories(pluginId) {
        if (typeof PluginService === "undefined")
            return false;

        const instance = PluginService.pluginInstances[pluginId];
        if (!instance)
            return false;

        return typeof instance.getCategories === "function";
    }
}
