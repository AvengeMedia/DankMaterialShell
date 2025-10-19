import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string searchQuery: ""
    property string selectedCategory: I18n.tr("All")
    property string viewMode: "list" // "list" or "grid"
    property int selectedIndex: 0
    property int maxResults: 50
    property int gridColumns: 4
    property bool debounceSearch: true
    property int debounceInterval: 50
    property bool keyboardNavigationActive: false
    property bool suppressUpdatesWhileLaunching: false
    property var categories: {
        const allCategories = AppSearchService.getAllCategories().filter(cat => cat !== "Education" && cat !== "Science")
        const result = [I18n.tr("All")]
        return result.concat(allCategories.filter(cat => cat !== I18n.tr("All")))
    }
    readonly property var categoryIcons: categories.map(category => AppSearchService.getCategoryIcon(category))
    property var appUsageRanking: AppUsageHistoryData.appUsageRanking || {}
    property alias model: filteredModel
    property var _watchApplications: AppSearchService.applications
    property var _uniqueApps: []
    property bool _isTriggered: false
    property string _triggeredCategory: ""
    property bool _updatingFromTrigger: false

    signal appLaunched(var app)
    signal categorySelected(string category)
    signal viewModeSelected(string mode)

    function updateCategories() {
        const allCategories = AppSearchService.getAllCategories().filter(cat => cat !== "Education" && cat !== "Science")
        const result = [I18n.tr("All")]
        categories = result.concat(allCategories.filter(cat => cat !== I18n.tr("All")))
    }

    Connections {
        target: PluginService
        function onPluginLoaded() { updateCategories() }
        function onPluginUnloaded() { updateCategories() }
        function onPluginListUpdated() { updateCategories() }
    }

    Connections {
        target: SettingsData
        function onSortAppsAlphabeticallyChanged() {
            updateFilteredModel()
        }
    }



    function updateFilteredModel() {
        if (suppressUpdatesWhileLaunching) {
            suppressUpdatesWhileLaunching = false
            return
        }
        filteredModel.clear()
        selectedIndex = 0
        keyboardNavigationActive = false

        const triggerResult = checkPluginTriggers(searchQuery)
        if (triggerResult.triggered) {
            console.log("AppLauncher: Plugin trigger detected:", triggerResult.trigger, "for plugin:", triggerResult.pluginId)
        }

        let apps = []
        const allCategory = I18n.tr("All")
        const emptyTriggerPlugins = typeof PluginService !== "undefined" ? PluginService.getPluginsWithEmptyTrigger() : []

        if (triggerResult.triggered) {
            _isTriggered = true
            _triggeredCategory = triggerResult.pluginCategory
            _updatingFromTrigger = true
            selectedCategory = triggerResult.pluginCategory
            _updatingFromTrigger = false
            apps = AppSearchService.getPluginItems(triggerResult.pluginCategory, triggerResult.query)
        } else {
            if (_isTriggered) {
                _updatingFromTrigger = true
                selectedCategory = allCategory
                _updatingFromTrigger = false
                _isTriggered = false
                _triggeredCategory = ""
            }
            if (searchQuery.length === 0) {
                if (selectedCategory === allCategory) {
                    let emptyTriggerItems = []
                    emptyTriggerPlugins.forEach(pluginId => {
                        const plugin = PluginService.getLauncherPlugin(pluginId)
                        const pluginCategory = plugin.name || pluginId
                        const items = AppSearchService.getPluginItems(pluginCategory, "")
                        emptyTriggerItems = emptyTriggerItems.concat(items)
                    })
                    apps = AppSearchService.applications.concat(emptyTriggerItems)
                } else {
                    apps = AppSearchService.getAppsInCategory(selectedCategory).slice(0, maxResults)
                }
            } else {
                if (selectedCategory === allCategory) {
                    apps = AppSearchService.searchApplications(searchQuery)

                    let emptyTriggerItems = []
                    emptyTriggerPlugins.forEach(pluginId => {
                        const plugin = PluginService.getLauncherPlugin(pluginId)
                        const pluginCategory = plugin.name || pluginId
                        const items = AppSearchService.getPluginItems(pluginCategory, searchQuery)
                        emptyTriggerItems = emptyTriggerItems.concat(items)
                    })
                    apps = apps.concat(emptyTriggerItems)
                } else {
                    const categoryApps = AppSearchService.getAppsInCategory(selectedCategory)
                    if (categoryApps.length > 0) {
                        const allSearchResults = AppSearchService.searchApplications(searchQuery)
                        const categoryNames = new Set(categoryApps.map(app => app.name))
                        apps = allSearchResults.filter(searchApp => categoryNames.has(searchApp.name)).slice(0, maxResults)
                    } else {
                        apps = []
                    }
                }
            }
        }

        if (searchQuery.length === 0) {
            if (SettingsData.sortAppsAlphabetically) {
                apps = apps.sort((a, b) => {
                                     return (a.name || "").localeCompare(b.name || "")
                                 })
            } else {
                apps = apps.sort((a, b) => {
                                     const aId = a.id || a.execString || a.exec || ""
                                     const bId = b.id || b.execString || b.exec || ""
                                     const aUsage = appUsageRanking[aId] ? appUsageRanking[aId].usageCount : 0
                                     const bUsage = appUsageRanking[bId] ? appUsageRanking[bId].usageCount : 0
                                     if (aUsage !== bUsage) {
                                         return bUsage - aUsage
                                     }
                                     return (a.name || "").localeCompare(b.name || "")
                                 })
            }
        }

        const seenNames = new Set()
        const uniqueApps = []
        apps.forEach(app => {
                         if (app) {
                             const itemKey = app.name + "|" + (app.execString || app.exec || app.action || "")
                             if (seenNames.has(itemKey)) {
                                 return
                             }
                             seenNames.add(itemKey)
                             uniqueApps.push(app)

                             const isPluginItem = app.action !== undefined
                             filteredModel.append({
                                                      "name": app.name || "",
                                                      "exec": app.execString || app.exec || app.action || "",
                                                      "icon": app.icon || "application-x-executable",
                                                      "comment": app.comment || "",
                                                      "categories": app.categories || [],
                                                      "isPlugin": isPluginItem,
                                                      "appIndex": uniqueApps.length - 1
                                                  })
                         }
                     })

        root._uniqueApps = uniqueApps
    }

    function selectNext() {
        if (filteredModel.count === 0) {
            return
        }
        keyboardNavigationActive = true
        selectedIndex = viewMode === "grid" ? Math.min(selectedIndex + gridColumns, filteredModel.count - 1) : Math.min(selectedIndex + 1, filteredModel.count - 1)
    }

    function selectPrevious() {
        if (filteredModel.count === 0) {
            return
        }
        keyboardNavigationActive = true
        selectedIndex = viewMode === "grid" ? Math.max(selectedIndex - gridColumns, 0) : Math.max(selectedIndex - 1, 0)
    }

    function selectNextInRow() {
        if (filteredModel.count === 0 || viewMode !== "grid") {
            return
        }
        keyboardNavigationActive = true
        selectedIndex = Math.min(selectedIndex + 1, filteredModel.count - 1)
    }

    function selectPreviousInRow() {
        if (filteredModel.count === 0 || viewMode !== "grid") {
            return
        }
        keyboardNavigationActive = true
        selectedIndex = Math.max(selectedIndex - 1, 0)
    }

    function launchSelected() {
        if (filteredModel.count === 0 || selectedIndex < 0 || selectedIndex >= filteredModel.count) {
            return
        }
        const selectedApp = filteredModel.get(selectedIndex)
        launchApp(selectedApp)
    }

    function launchApp(appData) {
        if (!appData || typeof appData.appIndex === "undefined" || appData.appIndex < 0 || appData.appIndex >= _uniqueApps.length) {
            return
        }
        suppressUpdatesWhileLaunching = true

        const actualApp = _uniqueApps[appData.appIndex]

        if (appData.isPlugin) {
            const pluginId = getPluginIdForItem(actualApp)
            if (pluginId) {
                AppSearchService.executePluginItem(actualApp, pluginId)
                appLaunched(appData)
                return
            }
        } else {
            SessionService.launchDesktopEntry(actualApp)
            appLaunched(appData)
            AppUsageHistoryData.addAppUsage(actualApp)
        }
    }

    function setCategory(category) {
        selectedCategory = category
        categorySelected(category)
    }

    function setViewMode(mode) {
        viewMode = mode
        viewModeSelected(mode)
    }

    onSearchQueryChanged: {
        if (debounceSearch) {
            searchDebounceTimer.restart()
        } else {
            updateFilteredModel()
        }
    }
    onSelectedCategoryChanged: {
        if (_updatingFromTrigger) {
            return
        }
        updateFilteredModel()
    }
    onAppUsageRankingChanged: updateFilteredModel()
    on_WatchApplicationsChanged: updateFilteredModel()
    Component.onCompleted: {
        updateFilteredModel()
    }

    ListModel {
        id: filteredModel
    }

    Timer {
        id: searchDebounceTimer

        interval: root.debounceInterval
        repeat: false
        onTriggered: updateFilteredModel()
    }

    // Plugin trigger system functions
    function checkPluginTriggers(query) {
        if (!query || typeof PluginService === "undefined") {
            return { triggered: false, pluginCategory: "", query: "" }
        }

        const triggers = PluginService.getAllPluginTriggers()

        for (const trigger in triggers) {
            if (query.startsWith(trigger)) {
                const pluginId = triggers[trigger]
                const plugin = PluginService.getLauncherPlugin(pluginId)

                if (plugin) {
                    const remainingQuery = query.substring(trigger.length).trim()
                    const result = {
                        triggered: true,
                        pluginId: pluginId,
                        pluginCategory: plugin.name || pluginId,
                        query: remainingQuery,
                        trigger: trigger
                    }
                    return result
                }
            }
        }

        return { triggered: false, pluginCategory: "", query: "" }
    }

    function getPluginIdForItem(item) {
        if (!item || !item.categories || typeof PluginService === "undefined") {
            return null
        }

        const launchers = PluginService.getLauncherPlugins()
        for (const pluginId in launchers) {
            const plugin = launchers[pluginId]
            const pluginCategory = plugin.name || pluginId

            let hasCategory = false
            if (Array.isArray(item.categories)) {
                hasCategory = item.categories.includes(pluginCategory)
            } else if (item.categories && typeof item.categories.count !== "undefined") {
                for (let i = 0; i < item.categories.count; i++) {
                    if (item.categories.get(i) === pluginCategory) {
                        hasCategory = true
                        break
                    }
                }
            }

            if (hasCategory) {
                return pluginId
            }
        }
        return null
    }
}
