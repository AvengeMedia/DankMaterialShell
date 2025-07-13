import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property string configDir: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/DankMaterialShell"
    property string recentAppsFile: configDir + "/recentApps.json"
    property int maxRecentApps: 10
    property var recentApps: []
    
    // Create config directory on startup
    Process {
        id: mkdirProcess
        command: ["mkdir", "-p", root.configDir]
        running: true
        onExited: {
            loadRecentApps()
        }
    }
    
    FileView {
        id: recentAppsFileView
        path: root.recentAppsFile
        
        onTextChanged: {
            if (text && text.length > 0) {
                try {
                    var data = JSON.parse(text)
                    if (Array.isArray(data)) {
                        root.recentApps = data
                    }
                } catch (e) {
                    console.log("PreferencesService: Invalid recent apps format")
                    root.recentApps = []
                }
            }
        }
    }
    
    function loadRecentApps() {
        // FileView will automatically load and trigger onTextChanged
        if (!recentAppsFileView.text || recentAppsFileView.text.length === 0) {
            recentApps = []
        }
    }
    
    function saveRecentApps() {
        var jsonData = JSON.stringify(recentApps, null, 2)
        var process = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["sh", "-c", "echo \'' + jsonData.replace(/'/g, "'\"'\"'") + '\' > \'' + root.recentAppsFile + '\'"]
                running: true
                onExited: {
                    if (exitCode !== 0) {
                        console.warn("Failed to save recent apps:", exitCode)
                    }
                    destroy()
                }
            }
        ', root)
    }
    
    function addRecentApp(app) {
        if (!app) return
        
        var execProp = app.execString || ""
        if (!execProp) return
        
        // Create a minimal app object to store
        var appData = {
            name: app.name,
            exec: execProp,
            icon: app.icon || "application-x-executable",
            comment: app.comment || ""
        }
        
        // Remove existing entry if present
        recentApps = recentApps.filter(a => a.exec !== execProp)
        
        // Add to front
        recentApps.unshift(appData)
        
        // Limit size
        if (recentApps.length > maxRecentApps) {
            recentApps = recentApps.slice(0, maxRecentApps)
        }
        
        saveRecentApps()
    }
    
    function getRecentApps() {
        return recentApps
    }
    
    function clearRecentApps() {
        recentApps = []
        saveRecentApps()
    }
}