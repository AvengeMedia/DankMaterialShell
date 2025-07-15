import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../Common/fuzzysort.js" as Fuzzy
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property list<DesktopEntry> applications: []
    property var applicationsByName: ({})
    property var applicationsByExec: ({})
    property bool ready: false
    
    property var preppedApps: []
    
    
    Component.onCompleted: {
        loadApplications()
    }
    
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            console.log("AppSearchService: DesktopEntries applicationsChanged signal received")
            console.log("AppSearchService: Current applications count before reload:", applications.length)
            loadApplications()
        }
    }
    
    
    function loadApplications() {
        Qt.callLater(function() {
            var allApps = Array.from(DesktopEntries.applications.values)
            
            applications = allApps
                .filter(app => !app.noDisplay)
                .sort((a, b) => a.name.localeCompare(b.name))
            
            var byName = {}
            var byExec = {}
            
            for (var i = 0; i < applications.length; i++) {
                var app = applications[i]
                byName[app.name.toLowerCase()] = app
                
                var execProp = app.execString || ""
                var cleanExec = execProp ? execProp.replace(/%[fFuU]/g, "").trim() : ""
                if (cleanExec) {
                    byExec[cleanExec] = app
                }
            }
            
            applicationsByName = byName
            applicationsByExec = byExec
            
            preppedApps = applications.map(app => ({
                name: Fuzzy.prepare(app.name || ""),
                comment: Fuzzy.prepare(app.comment || ""),
                entry: app
            }))
            
            ready = true
            
            console.log("AppSearchService: Loaded", applications.length, "applications")
            console.log("AppSearchService: Prepared", preppedApps.length, "apps for fuzzy search")
            console.log("AppSearchService: Ready status:", ready)
        })
    }
    
    function searchApplications(query) {
        if (!query || query.length === 0) {
            return applications
        }
        
        if (!ready || preppedApps.length === 0) {
            return []
        }
        
        var results = Fuzzy.go(query, preppedApps, {
            all: false,
            keys: ["name", "comment"],
            scoreFn: r => {
                var nameScore = r[0] ? r[0].score : 0
                var commentScore = r[1] ? r[1].score : 0
                return nameScore > 0 ? nameScore * 0.9 + commentScore * 0.1 : commentScore * 0.5
            },
            limit: 50
        })
        
        return results.map(r => r.obj.entry)
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
        
        if (typeof app.execute === "function") {
            app.execute()
            return true
        }
        
        console.warn("AppSearchService: Cannot launch app, no execute method")
        return false
    }
}