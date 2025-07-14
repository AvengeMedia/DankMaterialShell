import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property bool niriAvailable: false
    property string focusedAppId: ""
    property string focusedAppName: ""
    property string focusedWindowTitle: ""
    property int focusedWindowId: -1
    
    Component.onCompleted: {
        // Use the availability from NiriWorkspaceService to avoid duplicate checks
        root.niriAvailable = NiriWorkspaceService.niriAvailable
        
        // Connect to workspace service events
        NiriWorkspaceService.onNiriAvailableChanged.connect(() => {
            root.niriAvailable = NiriWorkspaceService.niriAvailable
            if (root.niriAvailable) {
                loadInitialFocusedWindow()
            }
        })
        
        if (root.niriAvailable) {
            loadInitialFocusedWindow()
        }
    }
    
    // Listen to window focus changes from NiriWorkspaceService
    Connections {
        target: NiriWorkspaceService
        function onFocusedWindowIdChanged() {
            root.focusedWindowId = parseInt(NiriWorkspaceService.focusedWindowId) || -1
            updateFocusedWindowData()
        }
        function onFocusedWindowTitleChanged() {
            root.focusedWindowTitle = NiriWorkspaceService.focusedWindowTitle
        }
    }
    
    // Process to get focused window info
    Process {
        id: focusedWindowQuery
        command: ["niri", "msg", "--json", "focused-window"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    try {
                        const windowData = JSON.parse(text.trim())
                        root.focusedAppId = windowData.app_id || ""
                        root.focusedWindowTitle = windowData.title || ""
                        root.focusedAppName = getDisplayName(windowData.app_id || "")
                        root.focusedWindowId = parseInt(windowData.id) || -1
                    } catch (e) {
                        console.warn("FocusedWindowService: Failed to parse focused window data:", e)
                        clearFocusedWindow()
                    }
                } else {
                    clearFocusedWindow()
                }
            }
        }
    }
    
    function loadInitialFocusedWindow() {
        if (root.niriAvailable) {
            focusedWindowQuery.running = true
        }
    }
    
    function updateFocusedWindowData() {
        if (root.niriAvailable && root.focusedWindowId !== -1) {
            focusedWindowQuery.running = true
        } else {
            clearFocusedWindow()
        }
    }
    
    function clearFocusedWindow() {
        root.focusedAppId = ""
        root.focusedAppName = ""
        root.focusedWindowTitle = ""
    }
    
    // Convert app_id to a more user-friendly display name
    function getDisplayName(appId) {
        if (!appId) return ""
        
        // Common app_id to display name mappings
        const appNames = {
            "com.mitchellh.ghostty": "Ghostty",
            "org.mozilla.firefox": "Firefox",
            "org.gnome.Nautilus": "Files",
            "org.gnome.TextEditor": "Text Editor",
            "com.google.Chrome": "Chrome",
            "org.telegram.desktop": "Telegram",
            "com.spotify.Client": "Spotify",
            "org.kde.konsole": "Konsole",
            "org.gnome.Terminal": "Terminal",
            "code": "VS Code",
            "code-oss": "VS Code",
            "org.mozilla.Thunderbird": "Thunderbird",
            "org.libreoffice.LibreOffice": "LibreOffice",
            "org.gimp.GIMP": "GIMP",
            "org.blender.Blender": "Blender",
            "discord": "Discord",
            "slack": "Slack",
            "zoom": "Zoom"
        }
        
        // Return mapped name or clean up the app_id
        if (appNames[appId]) {
            return appNames[appId]
        }
        
        // Try to extract a clean name from the app_id
        // Remove common prefixes and make first letter uppercase
        let cleanName = appId
            .replace(/^(org\.|com\.|net\.|io\.)/, '')
            .replace(/\./g, ' ')
            .split(' ')
            .map(word => word.charAt(0).toUpperCase() + word.slice(1))
            .join(' ')
        
        return cleanName
    }
}