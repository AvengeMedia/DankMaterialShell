pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root

    property var applications: DesktopEntries.applications.values.filter(app => !app.noDisplay && !app.runInTerminal)

    readonly property int maxResults: 10
    readonly property int frecencySampleSize: 10

    readonly property var timeBuckets: [{
            "maxDays": 4,
            "weight": 100
        }, {
            "maxDays": 14,
            "weight": 70
        }, {
            "maxDays": 31,
            "weight": 50
        }, {
            "maxDays": 90,
            "weight": 30
        }, {
            "maxDays": 99999,
            "weight": 10
        }]

    function tokenize(text) {
        return text.toLowerCase().trim().split(/[\s\-_]+/).filter(w => w.length > 0)
    }

    function wordBoundaryMatch(text, query) {
        const textWords = tokenize(text)
        const queryWords = tokenize(query)

        if (queryWords.length === 0)
            return false
        if (queryWords.length > textWords.length)
            return false

        for (var i = 0; i <= textWords.length - queryWords.length; i++) {
            let allMatch = true
            for (var j = 0; j < queryWords.length; j++) {
                if (!textWords[i + j].startsWith(queryWords[j])) {
                    allMatch = false
                    break
                }
            }
            if (allMatch)
                return true
        }
        return false
    }

    function levenshteinDistance(s1, s2) {
        const len1 = s1.length
        const len2 = s2.length
        const matrix = []

        for (var i = 0; i <= len1; i++) {
            matrix[i] = [i]
        }
        for (var j = 0; j <= len2; j++) {
            matrix[0][j] = j
        }

        for (var i = 1; i <= len1; i++) {
            for (var j = 1; j <= len2; j++) {
                const cost = s1[i - 1] === s2[j - 1] ? 0 : 1
                matrix[i][j] = Math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost)
            }
        }
        return matrix[len1][len2]
    }

    function fuzzyMatchScore(text, query) {
        const queryLower = query.toLowerCase()
        const maxDistance = query.length <= 2 ? 0 : query.length === 3 ? 1 : query.length <= 6 ? 2 : 3

        let bestScore = 0

        const distance = levenshteinDistance(text.toLowerCase(), queryLower)
        if (distance <= maxDistance) {
            const maxLen = Math.max(text.length, query.length)
            bestScore = 1 - (distance / maxLen)
        }

        const words = tokenize(text)
        for (const word of words) {
            const wordDistance = levenshteinDistance(word, queryLower)
            if (wordDistance <= maxDistance) {
                const maxLen = Math.max(word.length, query.length)
                const score = 1 - (wordDistance / maxLen)
                bestScore = Math.max(bestScore, score)
            }
        }

        return bestScore
    }

    function calculateFrecency(app) {
        const usageRanking = AppUsageHistoryData.appUsageRanking || {}
        const appId = app.id || (app.execString || app.exec || "")
        const idVariants = [appId, appId.replace(".desktop", ""), app.id, app.id ? app.id.replace(".desktop", "") : null].filter(id => id)

        let usageData = null
        for (const variant of idVariants) {
            if (usageRanking[variant]) {
                usageData = usageRanking[variant]
                break
            }
        }

        if (!usageData || !usageData.usageCount) {
            return {
                "frecency": 0,
                "daysSinceUsed": 999999
            }
        }

        const usageCount = usageData.usageCount || 0
        const lastUsed = usageData.lastUsed || 0
        const now = Date.now()
        const daysSinceUsed = (now - lastUsed) / (1000 * 60 * 60 * 24)

        let timeBucketWeight = 10
        for (const bucket of timeBuckets) {
            if (daysSinceUsed <= bucket.maxDays) {
                timeBucketWeight = bucket.weight
                break
            }
        }

        const contextBonus = 100
        const sampleSize = Math.min(usageCount, frecencySampleSize)
        const frecency = (timeBucketWeight * contextBonus * sampleSize) / 100

        return {
            "frecency": frecency,
            "daysSinceUsed": daysSinceUsed
        }
    }

    function searchApplications(query) {
        if (!query || query.length === 0) {
            return applications
        }
        if (applications.length === 0)
            return []

        const queryLower = query.toLowerCase().trim()
        const scoredApps = []
        const results = []

        for (const app of applications) {
            const name = (app.name || "").toLowerCase()
            const genericName = (app.genericName || "").toLowerCase()
            const comment = (app.comment || "").toLowerCase()
            const id = (app.id || "").toLowerCase()
            const keywords = app.keywords ? app.keywords.map(k => k.toLowerCase()) : []

            let textScore = 0
            let matchType = "none"

            if (name === queryLower) {
                textScore = 10000
                matchType = "exact"
            } else if (name.startsWith(queryLower)) {
                textScore = 5000
                matchType = "prefix"
            } else if (wordBoundaryMatch(name, queryLower)) {
                textScore = 1000
                matchType = "word_boundary"
            } else if (name.includes(queryLower)) {
                textScore = 500
                matchType = "substring"
            } else if (genericName && genericName.startsWith(queryLower)) {
                textScore = 800
                matchType = "generic_prefix"
            } else if (genericName && genericName.includes(queryLower)) {
                textScore = 400
                matchType = "generic"
            } else if (id && id.includes(queryLower)) {
                textScore = 350
                matchType = "id"
            }

            if (matchType === "none" && keywords.length > 0) {
                for (const keyword of keywords) {
                    if (keyword.startsWith(queryLower)) {
                        textScore = 300
                        matchType = "keyword_prefix"
                        break
                    } else if (keyword.includes(queryLower)) {
                        textScore = 150
                        matchType = "keyword"
                        break
                    }
                }
            }

            if (matchType === "none" && comment && comment.includes(queryLower)) {
                textScore = 50
                matchType = "comment"
            }

            if (matchType === "none") {
                const fuzzyScore = fuzzyMatchScore(name, queryLower)
                if (fuzzyScore > 0) {
                    textScore = fuzzyScore * 100
                    matchType = "fuzzy"
                }
            }

            if (matchType !== "none") {
                const frecencyData = calculateFrecency(app)

                results.push({
                                 "app": app,
                                 "textScore": textScore,
                                 "frecency": frecencyData.frecency,
                                 "daysSinceUsed": frecencyData.daysSinceUsed,
                                 "matchType": matchType
                             })
            }
        }

        for (const result of results) {
            const frecencyBonus = result.frecency > 0 ? Math.min(result.frecency / 10, 2000) : 0
            const recencyBonus = result.daysSinceUsed < 1 ? 1500 : result.daysSinceUsed < 7 ? 1000 : result.daysSinceUsed < 30 ? 500 : 0

            const finalScore = result.textScore + frecencyBonus + recencyBonus

            scoredApps.push({
                                "app": result.app,
                                "score": finalScore
                            })
        }

        scoredApps.sort((a, b) => b.score - a.score)
        return scoredApps.slice(0, maxResults).map(item => item.app)
    }

    function getCategoriesForApp(app) {
        if (!app?.categories)
            return []

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
        }

        const mappedCategories = new Set()

        for (const cat of app.categories) {
            if (categoryMap[cat])
                mappedCategories.add(categoryMap[cat])
        }

        return Array.from(mappedCategories)
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
        const pluginIcon = getPluginCategoryIcon(category)
        if (pluginIcon) {
            return pluginIcon
        }
        return categoryIcons[category] || "folder"
    }

    function getAllCategories() {
        const categories = new Set([I18n.tr("All")])

        for (const app of applications) {
            const appCategories = getCategoriesForApp(app)
            appCategories.forEach(cat => categories.add(cat))
        }

        // Add plugin categories
        const pluginCategories = getPluginCategories()
        pluginCategories.forEach(cat => categories.add(cat))

        const result = Array.from(categories).sort()
        return result
    }

    function getAppsInCategory(category) {
        if (category === I18n.tr("All")) {
            return applications
        }

        // Check if it's a plugin category
        const pluginItems = getPluginItems(category, "")
        if (pluginItems.length > 0) {
            return pluginItems
        }

        return applications.filter(app => {
                                       const appCategories = getCategoriesForApp(app)
                                       return appCategories.includes(category)
                                   })
    }

    // Plugin launcher support functions
    function getPluginCategories() {
        if (typeof PluginService === "undefined") {
            return []
        }

        const categories = []
        const launchers = PluginService.getLauncherPlugins()

        for (const pluginId in launchers) {
            const plugin = launchers[pluginId]
            const categoryName = plugin.name || pluginId
            categories.push(categoryName)
        }

        return categories
    }

    function getPluginCategoryIcon(category) {
        if (typeof PluginService === "undefined")
            return null

        const launchers = PluginService.getLauncherPlugins()
        for (const pluginId in launchers) {
            const plugin = launchers[pluginId]
            if ((plugin.name || pluginId) === category) {
                return plugin.icon || "extension"
            }
        }
        return null
    }

    function getAllPluginItems() {
        if (typeof PluginService === "undefined") {
            return []
        }

        let allItems = []
        const launchers = PluginService.getLauncherPlugins()

        for (const pluginId in launchers) {
            const categoryName = launchers[pluginId].name || pluginId
            const items = getPluginItems(categoryName, "")
            allItems = allItems.concat(items)
        }

        return allItems
    }

    function getPluginItems(category, query) {
        if (typeof PluginService === "undefined")
            return []

        const launchers = PluginService.getLauncherPlugins()
        for (const pluginId in launchers) {
            const plugin = launchers[pluginId]
            if ((plugin.name || pluginId) === category) {
                return getPluginItemsForPlugin(pluginId, query)
            }
        }
        return []
    }

    function getPluginItemsForPlugin(pluginId, query) {
        if (typeof PluginService === "undefined") {
            return []
        }

        let instance = PluginService.pluginInstances[pluginId]
        let isPersistent = true

        if (!instance) {
            const component = PluginService.pluginLauncherComponents[pluginId]
            if (!component)
                return []

            try {
                instance = component.createObject(root, {
                    "pluginService": PluginService
                })
                isPersistent = false
            } catch (e) {
                console.warn("AppSearchService: Error creating temporary plugin instance", pluginId, ":", e)
                return []
            }
        }

        if (!instance)
            return []

        try {
            if (typeof instance.getItems === "function") {
                const items = instance.getItems(query || "")
                if (!isPersistent)
                    instance.destroy()
                return items || []
            }

            if (!isPersistent) {
                instance.destroy()
            }
        } catch (e) {
            console.warn("AppSearchService: Error getting items from plugin", pluginId, ":", e)
            if (!isPersistent)
                instance.destroy()
        }

        return []
    }

    function executePluginItem(item, pluginId) {
        if (typeof PluginService === "undefined")
            return false

        let instance = PluginService.pluginInstances[pluginId]
        let isPersistent = true

        if (!instance) {
            const component = PluginService.pluginLauncherComponents[pluginId]
            if (!component)
                return false

            try {
                instance = component.createObject(root, {
                                                      "pluginService": PluginService
                                                  })
                isPersistent = false
            } catch (e) {
                console.warn("AppSearchService: Error creating temporary plugin instance for execution", pluginId, ":", e)
                return false
            }
        }

        if (!instance)
            return false

        try {
            if (typeof instance.executeItem === "function") {
                instance.executeItem(item)
                if (!isPersistent)
                    instance.destroy()
                return true
            }

            if (!isPersistent) {
                instance.destroy()
            }
        } catch (e) {
            console.warn("AppSearchService: Error executing item from plugin", pluginId, ":", e)
            if (!isPersistent)
                instance.destroy()
        }

        return false
    }

    function searchPluginItems(query) {
        if (typeof PluginService === "undefined")
            return []

        let allItems = []
        const launchers = PluginService.getLauncherPlugins()

        for (const pluginId in launchers) {
            const items = getPluginItemsForPlugin(pluginId, query)
            allItems = allItems.concat(items)
        }

        return allItems
    }
}
