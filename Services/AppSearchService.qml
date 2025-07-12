import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property list<DesktopEntry> applications: []
    property var applicationsByName: ({})
    property var applicationsByExec: ({})
    property bool ready: false
    property int refreshInterval: 10000
    
    Timer {
        id: refreshTimer
        interval: root.refreshInterval
        repeat: true
        running: true
        onTriggered: root.refreshApplications()
    }
    
    Component.onCompleted: {
        loadApplications()
    }
    
    function refreshApplications() {
        loadApplications()
    }
    
    function loadApplications() {
        var allApps = Array.from(DesktopEntries.applications.values)
        
        // Debug: Check what properties are available
        if (allApps.length > 0) {
            var firstApp = allApps[0]
            if (firstApp.exec !== undefined) console.log("  exec:", firstApp.exec)
            if (firstApp.execString !== undefined) console.log("  execString:", firstApp.execString)
            if (firstApp.executable !== undefined) console.log("  executable:", firstApp.executable)
            if (firstApp.command !== undefined) console.log("  command:", firstApp.command)
        }
        
        applications = allApps
            .filter(app => !app.noDisplay)
            .sort((a, b) => a.name.localeCompare(b.name))
        
        // Build lookup maps
        var byName = {}
        var byExec = {}
        
        for (var i = 0; i < applications.length; i++) {
            var app = applications[i]
            byName[app.name.toLowerCase()] = app
            
            // Clean exec string for lookup
            var execProp = app.execString || ""
            var cleanExec = execProp ? execProp.replace(/%[fFuU]/g, "").trim() : ""
            if (cleanExec) {
                byExec[cleanExec] = app
            }
        }
        
        applicationsByName = byName
        applicationsByExec = byExec
        ready = true
        
        console.log("AppSearchService: Loaded", applications.length, "applications")
    }
    
    function searchApplications(query) {
        if (!query || query.length === 0) {
            return applications
        }
        
        var lowerQuery = query.toLowerCase()
        var results = []
        
        for (var i = 0; i < applications.length; i++) {
            var app = applications[i]
            var score = 0
            
            // Check name
            var nameLower = app.name.toLowerCase()
            if (nameLower === lowerQuery) {
                score = 1000
            } else if (nameLower.startsWith(lowerQuery)) {
                score = 500
            } else if (nameLower.includes(lowerQuery)) {
                score = 100
            }
            
            // Check comment/description
            if (app.comment) {
                var commentLower = app.comment.toLowerCase()
                if (commentLower.includes(lowerQuery)) {
                    score += 50
                }
            }
            
            // Check generic name
            if (app.genericName) {
                var genericLower = app.genericName.toLowerCase()
                if (genericLower.includes(lowerQuery)) {
                    score += 25
                }
            }
            
            // Check keywords
            if (app.keywords && app.keywords.length > 0) {
                for (var j = 0; j < app.keywords.length; j++) {
                    if (app.keywords[j].toLowerCase().includes(lowerQuery)) {
                        score += 10
                        break
                    }
                }
            }
            
            if (score > 0) {
                results.push({
                    app: app,
                    score: score
                })
            }
        }
        
        // Sort by score descending
        results.sort((a, b) => b.score - a.score)
        
        // Return just the apps
        return results.map(r => r.app)
    }
    
    function getAppByName(name) {
        return applicationsByName[name.toLowerCase()] || null
    }
    
    function getAppByExec(exec) {
        var cleanExec = exec.replace(/%[fFuU]/g, "").trim()
        return applicationsByExec[cleanExec] || null
    }
    
    function getCategoriesForApp(app) {
        if (!app || !app.categories) return []
        
        var categoryMap = {
            "AudioVideo": "Media",
            "Audio": "Media",
            "Video": "Media",
            "Development": "Development",
            "TextEditor": "Development",
            "IDE": "Development",
            "Education": "Education",
            "Game": "Games",
            "Graphics": "Graphics",
            "Photography": "Graphics",
            "Network": "Internet",
            "WebBrowser": "Internet",
            "Email": "Internet",
            "Office": "Office",
            "WordProcessor": "Office",
            "Spreadsheet": "Office",
            "Presentation": "Office",
            "Science": "Science",
            "Settings": "Settings",
            "System": "System",
            "Utility": "Utilities",
            "Accessories": "Utilities",
            "FileManager": "Utilities",
            "TerminalEmulator": "Utilities"
        }
        
        var mappedCategories = new Set()
        
        for (var i = 0; i < app.categories.length; i++) {
            var cat = app.categories[i]
            if (categoryMap[cat]) {
                mappedCategories.add(categoryMap[cat])
            }
        }
        
        return Array.from(mappedCategories)
    }
    
    function getAllCategories() {
        var categories = new Set(["All"])
        
        for (var i = 0; i < applications.length; i++) {
            var appCategories = getCategoriesForApp(applications[i])
            appCategories.forEach(cat => categories.add(cat))
        }
        
        return Array.from(categories).sort()
    }
    
    function getAppsInCategory(category) {
        if (category === "All") {
            return applications
        }
        
        return applications.filter(app => {
            var appCategories = getCategoriesForApp(app)
            return appCategories.includes(category)
        })
    }
    
    function launchApp(app) {
        if (!app) {
            console.warn("AppSearchService: Cannot launch app, app is null")
            return false
        }
        
        // DesktopEntry objects have an execute() method
        if (typeof app.execute === "function") {
            app.execute()
            return true
        }
        
        console.warn("AppSearchService: Cannot launch app, no execute method")
        return false
    }
}