pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property var availablePlugins: ({})
    property var loadedPlugins: ({})
    property var pluginWidgetComponents: ({})
    property var pluginDaemonComponents: ({})
    property var pluginLauncherComponents: ({})
    property string pluginDirectory: {
        var configDir = StandardPaths.writableLocation(StandardPaths.ConfigLocation)
        var configDirStr = configDir.toString()
        if (configDirStr.startsWith("file://")) {
            configDirStr = configDirStr.substring(7)
        }
        return configDirStr + "/DankMaterialShell/plugins"
    }
    property string systemPluginDirectory: "/etc/xdg/quickshell/dms-plugins"

    property var knownManifests: ({})
    property var pathToPluginId: ({})
    property var pluginInstances: ({})
    property var globalVars: ({})

    signal pluginLoaded(string pluginId)
    signal pluginUnloaded(string pluginId)
    signal pluginLoadFailed(string pluginId, string error)
    signal pluginDataChanged(string pluginId)
    signal pluginListUpdated()
    signal globalVarChanged(string pluginId, string varName)

    Timer {
        id: resyncDebounce
        interval: 120
        repeat: false
        onTriggered: resyncAll()
    }

    Component.onCompleted: {
        userWatcher.folder = Paths.toFileUrl(root.pluginDirectory)
        systemWatcher.folder = Paths.toFileUrl(root.systemPluginDirectory)
        Qt.callLater(resyncAll)
    }

    FolderListModel {
        id: userWatcher
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        nameFilters: ["plugin.json"]

        onCountChanged: resyncDebounce.restart()
        onStatusChanged: if (status === FolderListModel.Ready) resyncDebounce.restart()
    }

    FolderListModel {
        id: systemWatcher
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        nameFilters: ["plugin.json"]

        onCountChanged: resyncDebounce.restart()
        onStatusChanged: if (status === FolderListModel.Ready) resyncDebounce.restart()
    }

    function snapshotModel(model, sourceTag) {
        const out = []
        const n = model.count
        const baseDir = sourceTag === "user" ? pluginDirectory : systemPluginDirectory
        for (let i = 0; i < n; i++) {
            let dirPath = model.get(i, "filePath")
            if (dirPath.startsWith("file://")) {
                dirPath = dirPath.substring(7)
            }
            if (!dirPath.startsWith(baseDir)) {
                continue
            }
            const manifestPath = dirPath + "/plugin.json"
            out.push({ path: manifestPath, source: sourceTag })
        }
        return out
    }

    function resyncAll() {
        const userList = snapshotModel(userWatcher, "user")
        const sysList  = snapshotModel(systemWatcher, "system")
        const seenPaths = {}

        function consider(entry) {
            const key = entry.path
            seenPaths[key] = true
            const prev = knownManifests[key]
            if (!prev) {
                loadPluginManifestFile(entry.path, entry.source, Date.now())
            }
        }
        for (let i=0;i<userList.length;i++) consider(userList[i])
        for (let i=0;i<sysList.length;i++)  consider(sysList[i])

        const removed = []
        for (const path in knownManifests) {
            if (!seenPaths[path]) removed.push(path)
        }
        if (removed.length) {
            removed.forEach(function(path) {
                const pid = pathToPluginId[path]
                if (pid) {
                    unregisterPluginByPath(path, pid)
                }
                delete knownManifests[path]
                delete pathToPluginId[path]
            })
            pluginListUpdated()
        }
    }

    function loadPluginManifestFile(manifestPathNoScheme, sourceTag, mtimeEpochMs) {
        const manifestId = "m_" + Math.random().toString(36).slice(2)
        const qml = `
            import QtQuick
            import Quickshell.Io
            FileView {
                id: fv
                property string absPath: ""
                onLoaded: {
                    try {
                        let raw = text()
                        if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1)
                        const manifest = JSON.parse(raw)
                        root._onManifestParsed(absPath, manifest, "${sourceTag}", ${mtimeEpochMs})
                    } catch (e) {
                        console.error("PluginService: bad manifest", absPath, e.message)
                        knownManifests[absPath] = { mtime: ${mtimeEpochMs}, source: "${sourceTag}", bad: true }
                    }
                    fv.destroy()
                }
                onLoadFailed: (err) => {
                    console.warn("PluginService: manifest load failed", absPath, err)
                    fv.destroy()
                }
            }
        `
        const loader = Qt.createQmlObject(qml, root, "mf_" + manifestId)
        loader.absPath = manifestPathNoScheme
        loader.path = manifestPathNoScheme
    }

    function _onManifestParsed(absPath, manifest, sourceTag, mtimeEpochMs) {
        if (!manifest || !manifest.id || !manifest.name || !manifest.component) {
            console.error("PluginService: invalid manifest fields:", absPath)
            knownManifests[absPath] = { mtime: mtimeEpochMs, source: sourceTag, bad: true }
            return
        }

        const dir = absPath.substring(0, absPath.lastIndexOf('/'))
        let comp = manifest.component
        if (comp.startsWith("./")) comp = comp.slice(2)
        let settings = manifest.settings
        if (settings && settings.startsWith("./")) settings = settings.slice(2)

        const info = {}
        for (const k in manifest) info[k] = manifest[k]

        let perms = manifest.permissions
        if (typeof perms === "string") {
            perms = perms.split(/\s*,\s*/)
        }
        if (!Array.isArray(perms)) {
            perms = []
        }
        info.permissions = perms.map(p => String(p).trim())

        info.manifestPath = absPath
        info.pluginDirectory = dir
        info.componentPath = dir + "/" + comp
        info.settingsPath  = settings ? (dir + "/" + settings) : null
        info.loaded = isPluginLoaded(manifest.id)
        info.type = manifest.type || "widget"
        info.source = sourceTag

        const existing = availablePlugins[manifest.id]
        const shouldReplace =
            (!existing) ||
            (existing && existing.source === "system" && sourceTag === "user")

        if (shouldReplace) {
            if (existing && existing.loaded && existing.source !== sourceTag) {
                unloadPlugin(manifest.id)
            }
            const newMap = Object.assign({}, availablePlugins)
            newMap[manifest.id] = info
            availablePlugins = newMap
            pathToPluginId[absPath] = manifest.id
            knownManifests[absPath] = { mtime: mtimeEpochMs, source: sourceTag }
            pluginListUpdated()
            const enabled = SettingsData.getPluginSetting(manifest.id, "enabled", false)
            if (enabled && !info.loaded) loadPlugin(manifest.id)
        } else {
            knownManifests[absPath] = { mtime: mtimeEpochMs, source: sourceTag, shadowedBy: existing.source }
            pathToPluginId[absPath] = manifest.id
        }
    }

    function unregisterPluginByPath(absPath, pluginId) {
        const current = availablePlugins[pluginId]
        if (current && current.manifestPath === absPath) {
            if (current.loaded) unloadPlugin(pluginId)
            const newMap = Object.assign({}, availablePlugins)
            delete newMap[pluginId]
            availablePlugins = newMap
        }
    }

    function loadPlugin(pluginId) {
        const plugin = availablePlugins[pluginId]
        if (!plugin) {
            console.error("PluginService: Plugin not found:", pluginId)
            pluginLoadFailed(pluginId, "Plugin not found")
            return false
        }

        if (plugin.loaded) {
            return true
        }

        const isDaemon = plugin.type === "daemon"
        const isLauncher = plugin.type === "launcher" || (plugin.capabilities && plugin.capabilities.includes("launcher"))
        const map = isDaemon ? pluginDaemonComponents : isLauncher ? pluginLauncherComponents : pluginWidgetComponents

        const prevInstance = pluginInstances[pluginId]
        if (prevInstance) {
            prevInstance.destroy()
            const newInstances = Object.assign({}, pluginInstances)
            delete newInstances[pluginId]
            pluginInstances = newInstances
        }

        try {
            const url = "file://" + plugin.componentPath
            const comp = Qt.createComponent(url, Component.PreferSynchronous)
            if (comp.status === Component.Error) {
                console.error("PluginService: component error", pluginId, comp.errorString())
                pluginLoadFailed(pluginId, comp.errorString())
                return false
            }

            if (isDaemon) {
                const instance = comp.createObject(root, { "pluginId": pluginId })
                if (!instance) {
                    console.error("PluginService: failed to instantiate daemon:", pluginId, comp.errorString())
                    pluginLoadFailed(pluginId, comp.errorString())
                    return false
                }
                const newInstances = Object.assign({}, pluginInstances)
                newInstances[pluginId] = instance
                pluginInstances = newInstances

                const newDaemons = Object.assign({}, pluginDaemonComponents)
                newDaemons[pluginId] = comp
                pluginDaemonComponents = newDaemons
            } else if (isLauncher) {
                const newLaunchers = Object.assign({}, pluginLauncherComponents)
                newLaunchers[pluginId] = comp
                pluginLauncherComponents = newLaunchers
            } else {
                const newComponents = Object.assign({}, pluginWidgetComponents)
                newComponents[pluginId] = comp
                pluginWidgetComponents = newComponents
            }

            plugin.loaded = true
            loadedPlugins[pluginId] = plugin

            pluginLoaded(pluginId)
            return true

        } catch (e) {
            console.error("PluginService: Error loading plugin:", pluginId, e.message)
            pluginLoadFailed(pluginId, e.message)
            return false
        }
    }

    function unloadPlugin(pluginId) {
        const plugin = loadedPlugins[pluginId]
        if (!plugin) {
            console.warn("PluginService: Plugin not loaded:", pluginId)
            return false
        }

        try {
            const isDaemon = plugin.type === "daemon"
            const isLauncher = plugin.type === "launcher" || (plugin.capabilities && plugin.capabilities.includes("launcher"))

            const instance = pluginInstances[pluginId]
            if (instance) {
                instance.destroy()
                const newInstances = Object.assign({}, pluginInstances)
                delete newInstances[pluginId]
                pluginInstances = newInstances
            }

            if (isDaemon && pluginDaemonComponents[pluginId]) {
                const newDaemons = Object.assign({}, pluginDaemonComponents)
                delete newDaemons[pluginId]
                pluginDaemonComponents = newDaemons
            } else if (isLauncher && pluginLauncherComponents[pluginId]) {
                const newLaunchers = Object.assign({}, pluginLauncherComponents)
                delete newLaunchers[pluginId]
                pluginLauncherComponents = newLaunchers
            } else if (pluginWidgetComponents[pluginId]) {
                const newComponents = Object.assign({}, pluginWidgetComponents)
                delete newComponents[pluginId]
                pluginWidgetComponents = newComponents
            }

            plugin.loaded = false
            delete loadedPlugins[pluginId]

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

    function getDaemonComponents() {
        return pluginDaemonComponents
    }

    function getAvailablePlugins() {
        const result = []
        for (const key in availablePlugins) {
            result.push(availablePlugins[key])
        }
        return result
    }

    function getPluginVariants(pluginId) {
        const plugin = availablePlugins[pluginId]
        if (!plugin) {
            return []
        }
        const variants = SettingsData.getPluginSetting(pluginId, "variants", [])
        return variants
    }

    function getAllPluginVariants() {
        const result = []
        for (const pluginId in availablePlugins) {
            const plugin = availablePlugins[pluginId]
            if (plugin.type !== "widget") {
                continue
            }
            const variants = getPluginVariants(pluginId)
            if (variants.length === 0) {
                result.push({
                    pluginId: pluginId,
                    variantId: null,
                    fullId: pluginId,
                    name: plugin.name,
                    icon: plugin.icon || "extension",
                    description: plugin.description || "Plugin widget",
                    loaded: plugin.loaded
                })
            } else {
                for (let i = 0; i < variants.length; i++) {
                    const variant = variants[i]
                    result.push({
                        pluginId: pluginId,
                        variantId: variant.id,
                        fullId: pluginId + ":" + variant.id,
                        name: plugin.name + " - " + variant.name,
                        icon: variant.icon || plugin.icon || "extension",
                        description: variant.description || plugin.description || "Plugin widget variant",
                        loaded: plugin.loaded
                    })
                }
            }
        }
        return result
    }

    function createPluginVariant(pluginId, variantName, variantConfig) {
        const variants = getPluginVariants(pluginId)
        const variantId = "variant_" + Date.now()
        const newVariant = Object.assign({}, variantConfig, {
            id: variantId,
            name: variantName
        })
        variants.push(newVariant)
        SettingsData.setPluginSetting(pluginId, "variants", variants)
        pluginDataChanged(pluginId)
        return variantId
    }

    function removePluginVariant(pluginId, variantId) {
        const variants = getPluginVariants(pluginId)
        const newVariants = variants.filter(function(v) { return v.id !== variantId })
        SettingsData.setPluginSetting(pluginId, "variants", newVariants)

        const fullId = pluginId + ":" + variantId
        removeWidgetFromDankBar(fullId)

        pluginDataChanged(pluginId)
    }

    function removeWidgetFromDankBar(widgetId) {
        function filterWidget(widget) {
            const id = typeof widget === "string" ? widget : widget.id
            return id !== widgetId
        }

        const leftWidgets = SettingsData.dankBarLeftWidgets
        const centerWidgets = SettingsData.dankBarCenterWidgets
        const rightWidgets = SettingsData.dankBarRightWidgets

        const newLeft = leftWidgets.filter(filterWidget)
        const newCenter = centerWidgets.filter(filterWidget)
        const newRight = rightWidgets.filter(filterWidget)

        if (newLeft.length !== leftWidgets.length) {
            SettingsData.setDankBarLeftWidgets(newLeft)
        }
        if (newCenter.length !== centerWidgets.length) {
            SettingsData.setDankBarCenterWidgets(newCenter)
        }
        if (newRight.length !== rightWidgets.length) {
            SettingsData.setDankBarRightWidgets(newRight)
        }
    }

    function updatePluginVariant(pluginId, variantId, variantConfig) {
        const variants = getPluginVariants(pluginId)
        for (let i = 0; i < variants.length; i++) {
            if (variants[i].id === variantId) {
                variants[i] = Object.assign({}, variants[i], variantConfig)
                break
            }
        }
        SettingsData.setPluginSetting(pluginId, "variants", variants)
        pluginDataChanged(pluginId)
    }

    function getPluginVariantData(pluginId, variantId) {
        const variants = getPluginVariants(pluginId)
        for (let i = 0; i < variants.length; i++) {
            if (variants[i].id === variantId) {
                return variants[i]
            }
        }
        return null
    }

    function getLoadedPlugins() {
        const result = []
        for (const key in loadedPlugins) {
            result.push(loadedPlugins[key])
        }
        return result
    }

    function isPluginLoaded(pluginId) {
        return loadedPlugins[pluginId] !== undefined
    }

    function enablePlugin(pluginId) {
        SettingsData.setPluginSetting(pluginId, "enabled", true)
        return loadPlugin(pluginId)
    }

    function disablePlugin(pluginId) {
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
        SettingsData.setPluginSetting(pluginId, key, value)
        pluginDataChanged(pluginId)
        return true
    }

    function loadPluginData(pluginId, key, defaultValue) {
        return SettingsData.getPluginSetting(pluginId, key, defaultValue)
    }

    function saveAllPluginSettings() {
        SettingsData.savePluginSettings()
    }

    function scanPlugins() {
        resyncDebounce.restart()
    }

    function createPluginDirectory() {
        const mkdirProcess = Qt.createComponent("data:text/plain,import Quickshell.Io; Process { }")
        if (mkdirProcess.status === Component.Ready) {
            const process = mkdirProcess.createObject(root)
            process.command = ["mkdir", "-p", pluginDirectory]
            process.exited.connect(function(exitCode) {
                if (exitCode !== 0) {
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

    // Launcher plugin helper functions
    function getLauncherPlugins() {
        const launchers = {}

        // Check plugins that have launcher components
        for (const pluginId in pluginLauncherComponents) {
            const plugin = availablePlugins[pluginId]
            if (plugin && plugin.loaded) {
                launchers[pluginId] = plugin
            }
        }
        return launchers
    }

    function getLauncherPlugin(pluginId) {
        const plugin = availablePlugins[pluginId]
        if (plugin && plugin.loaded && pluginLauncherComponents[pluginId]) {
            return plugin
        }
        return null
    }

    function getPluginTrigger(pluginId) {
        const plugin = getLauncherPlugin(pluginId)
        if (plugin) {
            const customTrigger = SettingsData.getPluginSetting(pluginId, "trigger", plugin.trigger || "!")
            return customTrigger
        }
        return null
    }

    function getAllPluginTriggers() {
        const triggers = {}
        const launchers = getLauncherPlugins()

        for (const pluginId in launchers) {
            const trigger = getPluginTrigger(pluginId)
            if (trigger && trigger.trim() !== "") {
                triggers[trigger] = pluginId
            }
        }
        return triggers
    }

    function getPluginsWithEmptyTrigger() {
        const plugins = []
        const launchers = getLauncherPlugins()

        for (const pluginId in launchers) {
            const trigger = getPluginTrigger(pluginId)
            if (!trigger || trigger.trim() === "") {
                plugins.push(pluginId)
            }
        }
        return plugins
    }

    function getGlobalVar(pluginId, varName, defaultValue) {
        if (globalVars[pluginId] && varName in globalVars[pluginId]) {
            return globalVars[pluginId][varName]
        }
        return defaultValue
    }

    function setGlobalVar(pluginId, varName, value) {
        const newGlobals = Object.assign({}, globalVars)
        if (!newGlobals[pluginId]) {
            newGlobals[pluginId] = {}
        }
        newGlobals[pluginId] = Object.assign({}, newGlobals[pluginId])
        newGlobals[pluginId][varName] = value
        globalVars = newGlobals
        globalVarChanged(pluginId, varName)
    }
}
