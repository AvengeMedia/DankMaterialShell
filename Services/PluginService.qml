pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property var availablePlugins: ({})
    property var loadedPlugins: ({})
    property var pluginWidgetComponents: ({})
    property string pluginDirectory: {
        var configDir = StandardPaths.writableLocation(StandardPaths.ConfigLocation)
        var configDirStr = configDir.toString()
        if (configDirStr.startsWith("file://")) {
            configDirStr = configDirStr.substring(7)
        }
        return configDirStr + "/DankMaterialShell/plugins"
    }

    signal pluginLoaded(string pluginId)
    signal pluginUnloaded(string pluginId)
    signal pluginLoadFailed(string pluginId, string error)

    Component.onCompleted: {
        Qt.callLater(initializePlugins)
    }

    function initializePlugins() {
        scanPlugins()
    }

    property var lsProcess: Process {
        id: dirScanner

        stdout: StdioCollector {
            onStreamFinished: {
                var output = text.trim()
                if (output) {
                    var directories = output.split('\n')
                    for (var i = 0; i < directories.length; i++) {
                        var dir = directories[i].trim()
                        if (dir) {
                            var manifestPath = pluginDirectory + "/" + dir + "/plugin.json"
                            console.log("PluginService: Found plugin directory:", dir, "checking manifest at:", manifestPath)
                            loadPluginManifest(manifestPath)
                        }
                    }
                } else {
                    console.log("PluginService: No directories found in plugin directory")
                }
            }
        }

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                console.error("PluginService: Failed to scan plugin directory, exit code:", exitCode)
            }
        }
    }

    function scanPlugins() {
        lsProcess.command = ["find", pluginDirectory, "-maxdepth", "1", "-type", "d", "-not", "-path", pluginDirectory, "-exec", "basename", "{}", ";"]
        lsProcess.running = true
    }

    property var manifestReaders: ({})

    function loadPluginManifest(manifestPath) {
        console.log("PluginService: Loading manifest:", manifestPath)

        // Create a unique key for this manifest reader
        var readerId = "reader_" + Date.now() + "_" + Math.random()

        var catProcess = Qt.createComponent("data:text/plain,import Quickshell.Io; Process { stdout: StdioCollector { } }")
        if (catProcess.status === Component.Ready) {
            var process = catProcess.createObject(root)
            process.command = ["cat", manifestPath]
            process.stdout.streamFinished.connect(function() {
                try {
                    console.log("PluginService: DEBUGGING parsing manifest, text length:", process.stdout.text.length)
                    var manifest = JSON.parse(process.stdout.text.trim())
                    console.log("PluginService: Successfully parsed manifest for plugin:", manifest.id)
                    processManifest(manifest, manifestPath)
                } catch (e) {
                    console.error("PluginService: Failed to parse manifest", manifestPath, ":", e.message)
                }
                process.destroy()
                delete manifestReaders[readerId]
            })
            process.exited.connect(function(exitCode) {
                if (exitCode !== 0) {
                    console.error("PluginService: Failed to read manifest file:", manifestPath, "exit code:", exitCode)
                    process.destroy()
                    delete manifestReaders[readerId]
                }
            })
            manifestReaders[readerId] = process
            process.running = true
        } else {
            console.error("PluginService: Failed to create manifest reader process")
        }
    }

    function processManifest(manifest, manifestPath) {
        registerPlugin(manifest, manifestPath)

        // Auto-load plugin if it's enabled in settings (default to enabled)
        var enabled = SettingsData.getPluginSetting(manifest.id, "enabled", true)
        if (enabled) {
            loadPlugin(manifest.id)
        }
    }

    function registerPlugin(manifest, manifestPath) {
        console.log("PluginService: registerPlugin called with", manifest.id)
        if (!manifest.id || !manifest.name || !manifest.component) {
            console.error("PluginService: Invalid manifest, missing required fields:", manifestPath)
            return
        }

        var pluginDir = manifestPath.substring(0, manifestPath.lastIndexOf('/'))

        // Clean up relative paths by removing './' prefix
        var componentFile = manifest.component
        if (componentFile.startsWith('./')) {
            componentFile = componentFile.substring(2)
        }

        var settingsFile = manifest.settings
        if (settingsFile && settingsFile.startsWith('./')) {
            settingsFile = settingsFile.substring(2)
        }

        var pluginInfo = {}
        for (var key in manifest) {
            pluginInfo[key] = manifest[key]
        }
        pluginInfo.manifestPath = manifestPath
        pluginInfo.pluginDirectory = pluginDir
        pluginInfo.componentPath = pluginDir + '/' + componentFile
        pluginInfo.settingsPath = settingsFile ? pluginDir + '/' + settingsFile : null
        pluginInfo.loaded = false

        availablePlugins[manifest.id] = pluginInfo
        console.log("PluginService: Registered plugin:", manifest.id, "-", manifest.name)
        console.log("PluginService: Component path:", pluginInfo.componentPath)
    }

    function loadPlugin(pluginId) {
        console.log("PluginService: loadPlugin called for", pluginId)
        var plugin = availablePlugins[pluginId]
        if (!plugin) {
            console.error("PluginService: Plugin not found:", pluginId)
            pluginLoadFailed(pluginId, "Plugin not found")
            return false
        }

        if (plugin.loaded) {
            console.log("PluginService: Plugin already loaded:", pluginId)
            return true
        }

        try {
            // Create the widget component
            var componentUrl = "file://" + plugin.componentPath
            console.log("PluginService: Loading component from:", componentUrl)

            var component = Qt.createComponent(componentUrl)
            if (component.status === Component.Error) {
                console.error("PluginService: Failed to create component for plugin:", pluginId, "Error:", component.errorString())
                pluginLoadFailed(pluginId, component.errorString())
                return false
            }

            pluginWidgetComponents[pluginId] = component
            plugin.loaded = true
            loadedPlugins[pluginId] = plugin

            console.log("PluginService: Successfully loaded plugin:", pluginId)
            pluginLoaded(pluginId)
            return true

        } catch (error) {
            console.error("PluginService: Error loading plugin:", pluginId, "Error:", error.message)
            pluginLoadFailed(pluginId, error.message)
            return false
        }
    }

    function unloadPlugin(pluginId) {
        var plugin = loadedPlugins[pluginId]
        if (!plugin) {
            console.warn("PluginService: Plugin not loaded:", pluginId)
            return false
        }

        try {
            // Remove from component map
            delete pluginWidgetComponents[pluginId]

            // Mark as unloaded
            plugin.loaded = false
            delete loadedPlugins[pluginId]

            console.log("PluginService: Successfully unloaded plugin:", pluginId)
            pluginUnloaded(pluginId)
            return true

        } catch (error) {
            console.error("PluginService: Error unloading plugin:", pluginId, "Error:", error.message)
            return false
        }
    }

    function getWidgetComponents() {
        return pluginWidgetComponents
    }

    function getAvailablePlugins() {
        var result = []
        for (var key in availablePlugins) {
            result.push(availablePlugins[key])
        }
        return result
    }

    function getLoadedPlugins() {
        var result = []
        for (var key in loadedPlugins) {
            result.push(loadedPlugins[key])
        }
        return result
    }

    function isPluginLoaded(pluginId) {
        return loadedPlugins[pluginId] !== undefined
    }

    function enablePlugin(pluginId) {
        console.log("PluginService: Enabling plugin:", pluginId)
        SettingsData.setPluginSetting(pluginId, "enabled", true)
        return loadPlugin(pluginId)
    }

    function disablePlugin(pluginId) {
        console.log("PluginService: Disabling plugin:", pluginId)
        SettingsData.setPluginSetting(pluginId, "enabled", false)
        return unloadPlugin(pluginId)
    }

    function reloadPlugin(pluginId) {
        if (isPluginLoaded(pluginId)) {
            unloadPlugin(pluginId)
        }
        return loadPlugin(pluginId)
    }

    function savePluginData(pluginId, key, value) {
        console.log("PluginService: Saving plugin data:", pluginId, key, JSON.stringify(value))
        SettingsData.setPluginSetting(pluginId, key, value)
        console.log("PluginService: Data saved successfully")
        return true
    }

    function loadPluginData(pluginId, key, defaultValue) {
        console.log("PluginService: Loading plugin data:", pluginId, key)
        var value = SettingsData.getPluginSetting(pluginId, key, defaultValue)
        console.log("PluginService: Loaded key:", key, "value:", JSON.stringify(value))
        return value
    }

    function createPluginDirectory() {
        console.log("PluginService: Creating plugin directory:", pluginDirectory)
        var mkdirProcess = Qt.createComponent("data:text/plain,import Quickshell.Io; Process { }")
        if (mkdirProcess.status === Component.Ready) {
            var process = mkdirProcess.createObject(root)
            process.command = ["mkdir", "-p", pluginDirectory]
            process.exited.connect(function(exitCode) {
                if (exitCode === 0) {
                    console.log("PluginService: Successfully created plugin directory")
                } else {
                    console.error("PluginService: Failed to create plugin directory, exit code:", exitCode)
                }
                process.destroy()
            })
            process.running = true
            return true
        } else {
            console.error("PluginService: Failed to create mkdir process")
            return false
        }
    }
}
