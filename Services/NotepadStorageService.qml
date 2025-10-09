pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string baseDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/DankMaterialShell")
    readonly property string filesDir: baseDir + "/notepad-files"
    readonly property string metadataPath: baseDir + "/notepad-session.json"

    property var tabs: []
    property int currentTabIndex: 0
    property var tabsBeingCreated: ({})

    FileView {
        id: metadataFile
        path: root.metadataPath
        blockWrites: true
        atomicWrites: true

        onLoaded: {
            try {
                var data = JSON.parse(text())
                root.tabs = data.tabs || []
                root.currentTabIndex = data.currentTabIndex || 0
                validateTabs()
            } catch(e) {
                console.warn("Failed to parse notepad metadata:", e)
                createDefaultTab()
            }
        }

        onLoadFailed: {
            createDefaultTab()
        }
    }


    function loadMetadata() {
        metadataFile.path = ""
        metadataFile.path = root.metadataPath
    }

    function createDefaultTab() {
        var id = Date.now()
        var filePath = "notepad-files/untitled-" + id + ".txt"
        var fullPath = baseDir + "/" + filePath

        var newTabsBeingCreated = Object.assign({}, tabsBeingCreated)
        newTabsBeingCreated[id] = true
        tabsBeingCreated = newTabsBeingCreated

        createEmptyFile(fullPath, function() {
            root.tabs = [{
                id: id,
                title: I18n.tr("Untitled"),
                filePath: filePath,
                isTemporary: true,
                lastModified: new Date().toISOString(),
                cursorPosition: 0,
                scrollPosition: 0
            }]
            root.currentTabIndex = 0

            var updatedTabsBeingCreated = Object.assign({}, tabsBeingCreated)
            delete updatedTabsBeingCreated[id]
            tabsBeingCreated = updatedTabsBeingCreated
            saveMetadata()
        })
    }

    function saveMetadata() {
        var metadata = {
            version: 1,
            currentTabIndex: currentTabIndex,
            tabs: tabs
        }
        metadataFile.setText(JSON.stringify(metadata, null, 2))
    }

    function loadTabContent(tabIndex, callback) {
        if (tabIndex < 0 || tabIndex >= tabs.length) {
            callback("")
            return
        }

        var tab = tabs[tabIndex]
        var fullPath = tab.isTemporary
                        ? baseDir + "/" + tab.filePath
                        : tab.filePath

        if (tabsBeingCreated[tab.id]) {
            Qt.callLater(() => {
                loadTabContent(tabIndex, callback)
            })
            return
        }
        var loader = tabFileLoaderComponent.createObject(root, {
            path: fullPath,
            callback: callback
        })
    }

    function saveTabContent(tabIndex, content) {
        if (tabIndex < 0 || tabIndex >= tabs.length) return

        var tab = tabs[tabIndex]
        var fullPath = tab.isTemporary
                        ? baseDir + "/" + tab.filePath
                        : tab.filePath

        var saver = tabFileSaverComponent.createObject(root, {
            path: fullPath,
            content: content,
            tabIndex: tabIndex
        })
    }

    function createNewTab() {
        var id = Date.now()
        var filePath = "notepad-files/untitled-" + id + ".txt"
        var fullPath = baseDir + "/" + filePath

        var newTab = {
            id: id,
            title: I18n.tr("Untitled"),
            filePath: filePath,
            isTemporary: true,
            lastModified: new Date().toISOString(),
            cursorPosition: 0,
            scrollPosition: 0
        }

        var newTabsBeingCreated = Object.assign({}, tabsBeingCreated)
        newTabsBeingCreated[id] = true
        tabsBeingCreated = newTabsBeingCreated
        createEmptyFile(fullPath, function() {
            var newTabs = tabs.slice()
            newTabs.push(newTab)
            tabs = newTabs
            currentTabIndex = tabs.length - 1

            var updatedTabsBeingCreated = Object.assign({}, tabsBeingCreated)
            delete updatedTabsBeingCreated[id]
            tabsBeingCreated = updatedTabsBeingCreated
            saveMetadata()
        })

        return newTab
    }

    function closeTab(tabIndex) {
        if (tabIndex < 0 || tabIndex >= tabs.length) return

        var newTabs = tabs.slice()

        if (newTabs.length <= 1) {
            var id = Date.now()
            var filePath = "notepad-files/untitled-" + id + ".txt"

            var newTabsBeingCreated = Object.assign({}, tabsBeingCreated)
            newTabsBeingCreated[id] = true
            tabsBeingCreated = newTabsBeingCreated
            createEmptyFile(baseDir + "/" + filePath, function() {
                newTabs[0] = {
                    id: id,
                    title: I18n.tr("Untitled"),
                    filePath: filePath,
                    isTemporary: true,
                    lastModified: new Date().toISOString(),
                    cursorPosition: 0,
                    scrollPosition: 0
                }
                currentTabIndex = 0
                tabs = newTabs

                var updatedTabsBeingCreated = Object.assign({}, tabsBeingCreated)
                delete updatedTabsBeingCreated[id]
                tabsBeingCreated = updatedTabsBeingCreated
                saveMetadata()
            })
            return
        } else {
            var tabToDelete = newTabs[tabIndex]
            if (tabToDelete && tabToDelete.isTemporary) {
                deleteFile(baseDir + "/" + tabToDelete.filePath)
            }

            newTabs.splice(tabIndex, 1)
            if (currentTabIndex >= newTabs.length) {
                currentTabIndex = newTabs.length - 1
            } else if (currentTabIndex > tabIndex) {
                currentTabIndex -= 1
            }
        }

        tabs = newTabs
        saveMetadata()

    }

    function switchToTab(tabIndex) {
        if (tabIndex < 0 || tabIndex >= tabs.length) return

        currentTabIndex = tabIndex
        saveMetadata()
    }

    function saveTabAs(tabIndex, userPath) {
        if (tabIndex < 0 || tabIndex >= tabs.length) return

        var tab = tabs[tabIndex]
        var fileName = userPath.split('/').pop()

        if (tab.isTemporary) {
            var tempPath = baseDir + "/" + tab.filePath
            copyFile(tempPath, userPath)
            deleteFile(tempPath)
        }

        var newTabs = tabs.slice()
        newTabs[tabIndex] = Object.assign({}, tab, {
            title: fileName,
            filePath: userPath,
            isTemporary: false,
            lastModified: new Date().toISOString()
        })
        tabs = newTabs
        saveMetadata()

    }

    function updateTabMetadata(tabIndex, properties) {
        if (tabIndex < 0 || tabIndex >= tabs.length) return

        var newTabs = tabs.slice()
        var updatedTab = Object.assign({}, newTabs[tabIndex], properties)
        updatedTab.lastModified = new Date().toISOString()
        newTabs[tabIndex] = updatedTab
        tabs = newTabs
        saveMetadata()

    }

    function validateTabs() {
        var validTabs = []
        for (var i = 0; i < tabs.length; i++) {
            var tab = tabs[i]
            validTabs.push(tab)
        }
        tabs = validTabs

        if (tabs.length === 0) {
            createDefaultTab()
        }
    }

    Component {
        id: tabFileLoaderComponent
        FileView {
            property var callback
            blockLoading: true
            preload: true

            onLoaded: {
                callback(text())
                destroy()
            }

            onLoadFailed: {
                callback("")
                destroy()
            }
        }
    }

    Component {
        id: tabFileSaverComponent
        FileView {
            property string content
            property int tabIndex
            property var creationCallback

            blockWrites: false
            atomicWrites: true

            Component.onCompleted: setText(content)

            onSaved: {
                if (tabIndex >= 0) {
                    updateTabMetadata(tabIndex, {})
                }
                if (creationCallback) {
                    creationCallback()
                }
                destroy()
            }

            onSaveFailed: {
                console.error("Failed to save tab content")
                if (creationCallback) {
                    creationCallback()
                }
                destroy()
            }
        }
    }

    function createEmptyFile(path, callback) {
        var cleanPath = path.toString()

        if (!cleanPath.startsWith("/")) {
            cleanPath = baseDir + "/" + cleanPath
        }

        var creator = fileCreatorComponent.createObject(root, {
            filePath: cleanPath,
            creationCallback: callback
        })
    }

    function copyFile(source, destination) {
        copyProcess.source = source
        copyProcess.destination = destination
        copyProcess.running = true
    }

    function deleteFile(path) {
        deleteProcess.filePath = path
        deleteProcess.running = true
    }

    Component {
        id: fileCreatorComponent
        QtObject {
            property string filePath
            property var creationCallback

            Component.onCompleted: {
                var touchProcess = touchProcessComponent.createObject(this, {
                    filePath: filePath,
                    callback: creationCallback
                })
            }
        }
    }

    Component {
        id: touchProcessComponent
        Process {
            property string filePath
            property var callback
            command: ["touch", filePath]

            Component.onCompleted: running = true

            onExited: (exitCode) => {
                if (callback) callback()
                destroy()
            }
        }
    }

    Process {
        id: copyProcess
        property string source
        property string destination
        command: ["cp", source, destination]
    }

    Process {
        id: deleteProcess
        property string filePath
        command: ["rm", "-f", filePath]
    }
}