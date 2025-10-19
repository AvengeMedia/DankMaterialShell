pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../Common/fzf.js" as Fzf
import qs.Common

Singleton {
    id: root

    property var applications: DesktopEntries.applications.values.filter(app => !app.noDisplay && !app.runInTerminal)



    function searchApplications(query) {
        if (!query || query.length === 0) {
            return applications
        }
        if (applications.length === 0)
            return []

        const queryLower = query.toLowerCase().trim()
        const scoredApps = []
        const usageRanking = AppUsageHistoryData.appUsageRanking || {}

        for (const app of applications) {
            const name = (app.name || "").toLowerCase()
            const genericName = (app.genericName || "").toLowerCase()
            const comment = (app.comment || "").toLowerCase()
            const keywords = app.keywords ? app.keywords.map(k => k.toLowerCase()) : []

            let score = 0
            let matched = false

            const nameWords = name.trim().split(/\s+/).filter(w => w.length > 0)
            const containsAsWord = nameWords.includes(queryLower)
            const startsWithAsWord = nameWords.some(word => word.startsWith(queryLower))

            if (name === queryLower) {
                score = 10000
                matched = true
            } else if (containsAsWord) {
                score = 9500 + (100 - Math.min(name.length, 100))
                matched = true
            } else if (name.startsWith(queryLower)) {
                score = 9000 + (100 - Math.min(name.length, 100))
                matched = true
            } else if (startsWithAsWord) {
                score = 8500 + (100 - Math.min(name.length, 100))
                matched = true
            } else if (name.includes(queryLower)) {
                score = 8000 + (100 - Math.min(name.length, 100))
                matched = true
            } else if (keywords.length > 0) {
                for (const keyword of keywords) {
                    if (keyword === queryLower) {
                        score = 6000
                        matched = true
                        break
                    } else if (keyword.startsWith(queryLower)) {
                        score = 5500
                        matched = true
                        break
                    } else if (keyword.includes(queryLower)) {
                        score = 5000
                        matched = true
                        break
                    }
                }
            }
            if (!matched && genericName.includes(queryLower)) {
                if (genericName === queryLower) {
                    score = 9000
                } else if (genericName.startsWith(queryLower)) {
                    score = 8500
                } else {
                    const genericWords = genericName.trim().split(/\s+/).filter(w => w.length > 0)
                    if (genericWords.includes(queryLower)) {
                        score = 8000
                    } else if (genericWords.some(word => word.startsWith(queryLower))) {
                        score = 7500
                    } else {
                        score = 7000
                    }
                }
                matched = true
            } else if (!matched && comment.includes(queryLower)) {
                score = 3000
                matched = true
            } else if (!matched) {
                const nameFinder = new Fzf.Finder([app], {
                                                      "selector": a => a.name || "",
                                                      "casing": "case-insensitive",
                                                      "fuzzy": "v2"
                                                  })
                const fuzzyResults = nameFinder.find(query)
                if (fuzzyResults.length > 0 && fuzzyResults[0].score > 0) {
                    score = Math.min(fuzzyResults[0].score, 2000)
                    matched = true
                }
            }

            if (matched) {
                const appId = app.id || (app.execString || app.exec || "")
                const idVariants = [
                    appId,
                    appId.replace(".desktop", ""),
                    app.id,
                    app.id ? app.id.replace(".desktop", "") : null
                ].filter(id => id)

                let usageData = null
                for (const variant of idVariants) {
                    if (usageRanking[variant]) {
                        usageData = usageRanking[variant]
                        break
                    }
                }

                if (usageData) {
                    const usageCount = usageData.usageCount || 0
                    const lastUsed = usageData.lastUsed || 0
                    const now = Date.now()
                    const daysSinceUsed = (now - lastUsed) / (1000 * 60 * 60 * 24)

                    let usageBonus = 0
                    usageBonus += Math.min(usageCount * 100, 2000)

                    if (daysSinceUsed < 1) {
                        usageBonus += 1500
                    } else if (daysSinceUsed < 7) {
                        usageBonus += 1000
                    } else if (daysSinceUsed < 30) {
                        usageBonus += 500
                    }

                    score += usageBonus
                }

                scoredApps.push({
                                    "app": app,
                                    "score": score
                                })
            }
        }

        scoredApps.sort((a, b) => b.score - a.score)
        return scoredApps.slice(0, 50).map(item => item.app)
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
        if (typeof PluginService === "undefined") return null

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
        if (typeof PluginService === "undefined") return []

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

        const component = PluginService.pluginLauncherComponents[pluginId]
        if (!component) return []

        try {
            const instance = component.createObject(root, {
                "pluginService": PluginService
            })

            if (instance && typeof instance.getItems === "function") {
                const items = instance.getItems(query || "")
                instance.destroy()
                return items || []
            }

            if (instance) {
                instance.destroy()
            }
        } catch (e) {
            console.warn("AppSearchService: Error getting items from plugin", pluginId, ":", e)
        }

        return []
    }

    function executePluginItem(item, pluginId) {
        if (typeof PluginService === "undefined") return false

        const component = PluginService.pluginLauncherComponents[pluginId]
        if (!component) return false

        try {
            const instance = component.createObject(root, {
                "pluginService": PluginService
            })

            if (instance && typeof instance.executeItem === "function") {
                instance.executeItem(item)
                instance.destroy()
                return true
            }

            if (instance) {
                instance.destroy()
            }
        } catch (e) {
            console.warn("AppSearchService: Error executing item from plugin", pluginId, ":", e)
        }

        return false
    }

    function searchPluginItems(query) {
        if (typeof PluginService === "undefined") return []

        let allItems = []
        const launchers = PluginService.getLauncherPlugins()

        for (const pluginId in launchers) {
            const items = getPluginItemsForPlugin(pluginId, query)
            allItems = allItems.concat(items)
        }

        return allItems
    }
}
