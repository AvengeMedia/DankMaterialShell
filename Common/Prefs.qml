pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    
    property int themeIndex: 0
    property bool themeIsDynamic: false
    
    readonly property string configDir: Qt.resolvedUrl("file://" + Quickshell.env("HOME") + "/.config/DankMaterialDark")
    readonly property string configFile: configDir + "/settings.json"
    
    Component.onCompleted: {
        loadSettings()
        Qt.callLater(applyStoredTheme)
    }
    
    Process {
        id: mkdirProcess
        running: false
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("Config directory created successfully")
            }
            // Reload settings file after directory creation completes
            settingsFileView.reload()
        }
    }
    
    Process {
        id: writeProcess
        running: false
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("Settings saved successfully")
            } else {
                console.error("Failed to save settings, exit code:", exitCode)
            }
        }
    }
    
    FileView {
        id: settingsFileView
        path: "file://" + Quickshell.env("HOME") + "/.config/DankMaterialDark/settings.json"
        
        onLoaded: {
            console.log("Settings file loaded successfully")
            try {
                var content = settingsFileView.text()
                console.log("Settings file content:", content)
                if (content && content.trim()) {
                    var settings = JSON.parse(content)
                    themeIndex = settings.themeIndex !== undefined ? settings.themeIndex : 0
                    themeIsDynamic = settings.themeIsDynamic !== undefined ? settings.themeIsDynamic : false
                    console.log("Loaded settings - themeIndex:", themeIndex, "isDynamic:", themeIsDynamic)
                } else {
                    console.log("Settings file is empty")
                }
            } catch (e) {
                console.log("Could not parse settings, using defaults:", e)
            }
        }
        
        onLoadFailed: (error) => {
            console.log("Settings file not found, using defaults. Error:", error)
        }
    }
    
    function loadSettings() {
        mkdirProcess.command = ["mkdir", "-p", Quickshell.env("HOME") + "/.config/DankMaterialDark"]
        mkdirProcess.running = true        
    }
    
    function saveSettings() {
        var settings = {
            themeIndex: themeIndex,
            themeIsDynamic: themeIsDynamic
        }
        
        var content = JSON.stringify(settings, null, 2)
        
        writeProcess.command = ["sh", "-c", "echo '" + content + "' > '" + Quickshell.env("HOME") + "/.config/DankMaterialDark/settings.json'"]
        writeProcess.running = true
        console.log("Saving settings - themeIndex:", themeIndex, "isDynamic:", themeIsDynamic)
    }
    
    function applyStoredTheme() {
        console.log("Applying stored theme:", themeIndex, themeIsDynamic)
        
        if (typeof Theme !== "undefined") {
            Theme.switchTheme(themeIndex, themeIsDynamic, false)
        } else {
            Qt.callLater(() => {
                if (typeof Theme !== "undefined") {
                    Theme.switchTheme(themeIndex, themeIsDynamic, false)
                }
            })
        }
    }
    
    function setTheme(index, isDynamic) {
        console.log("Prefs setTheme called - themeIndex:", index, "isDynamic:", isDynamic)
        themeIndex = index
        themeIsDynamic = isDynamic
        saveSettings()
    }
}