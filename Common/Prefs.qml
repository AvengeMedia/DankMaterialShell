pragma Singleton
import QtQuick
import Qt.labs.settings
import Quickshell

Singleton {
    id: root
    
    property alias themeIndex: settings.themeIndex
    property alias themeIsDynamic: settings.themeIsDynamic
    
    Settings {
        id: settings
        category: "theme"
        
        // 0-9 = built-in static themes, 10 = Auto (dynamic)
        property int themeIndex: 0
        property bool themeIsDynamic: false
    }
    
    // Apply theme when component is ready
    Component.onCompleted: {
        console.log("Prefs Component.onCompleted - themeIndex:", settings.themeIndex, "isDynamic:", settings.themeIsDynamic)
        Qt.callLater(applyStoredTheme)
    }
    
    function applyStoredTheme() {
        console.log("Applying stored theme:", settings.themeIndex, settings.themeIsDynamic)
        
        // Make sure Theme is available
        if (typeof Theme !== "undefined") {
            Theme.switchTheme(settings.themeIndex, settings.themeIsDynamic, false)  // Don't save during startup
        } else {
            // Try again in a moment
            Qt.callLater(() => {
                if (typeof Theme !== "undefined") {
                    Theme.switchTheme(settings.themeIndex, settings.themeIsDynamic, false)  // Don't save during startup
                }
            })
        }
    }
    
    function setTheme(index, isDynamic) {
        console.log("Prefs setTheme called - themeIndex:", index, "isDynamic:", isDynamic)
        settings.themeIndex = index
        settings.themeIsDynamic = isDynamic
        console.log("Prefs saved - themeIndex:", settings.themeIndex, "isDynamic:", settings.themeIsDynamic)
    }
}