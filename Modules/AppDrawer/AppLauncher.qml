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
    readonly property var categories: {
        const allCategories = AppSearchService.getAllCategories().filter(cat => cat !== "Education" && cat !== "Science")
        const result = [I18n.tr("All")]
        return result.concat(allCategories.filter(cat => cat !== I18n.tr("All")))
    }
    readonly property var categoryIcons: categories.map(category => AppSearchService.getCategoryIcon(category))
    property var appUsageRanking: AppUsageHistoryData.appUsageRanking || {}
    property alias model: filteredModel
    property var _watchApplications: AppSearchService.applications

    signal appLaunched(var app)
    signal categorySelected(string category)
    signal viewModeSelected(string mode)

    function updateFilteredModel() {
        if (suppressUpdatesWhileLaunching) {
            suppressUpdatesWhileLaunching = false
            return
        }
        filteredModel.clear()
        selectedIndex = 0
        keyboardNavigationActive = false

        let apps = []
        const allCategory = I18n.tr("All")
        if (searchQuery.length === 0) {
            apps = selectedCategory === allCategory ? AppSearchService.getAppsInCategory(allCategory) : AppSearchService.getAppsInCategory(selectedCategory).slice(0, maxResults)
        } else {
            if (selectedCategory === allCategory) {
                apps = AppSearchService.searchApplications(searchQuery)
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

        if (searchQuery.length === 0) {
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

        apps.forEach(app => {
                         if (app) {
                             filteredModel.append({
                                                      "name": app.name || "",
                                                      "exec": app.execString || "",
                                                      "icon": app.icon || "application-x-executable",
                                                      "comment": app.comment || "",
                                                      "categories": app.categories || [],
                                                      "desktopEntry": app
                                                  })
                         }
                     })
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
        if (!appData) {
            return
        }
        suppressUpdatesWhileLaunching = true
        SessionService.launchDesktopEntry(appData.desktopEntry)
        appLaunched(appData)
        AppUsageHistoryData.addAppUsage(appData.desktopEntry)
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
    onSelectedCategoryChanged: updateFilteredModel()
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
}
