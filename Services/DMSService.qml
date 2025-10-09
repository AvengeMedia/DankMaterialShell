pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool dmsAvailable: false
    property var capabilities: []
    property var availablePlugins: []
    property var installedPlugins: []
    property bool isConnected: false
    property bool isConnecting: false

    readonly property string socketPath: Quickshell.env("DMS_SOCKET")

    property var pendingRequests: ({})
    property int requestIdCounter: 0

    signal pluginsListReceived(var plugins)
    signal installedPluginsReceived(var plugins)
    signal searchResultsReceived(var plugins)
    signal operationSuccess(string message)
    signal operationError(string error)
    signal connectionStateChanged()

    Component.onCompleted: {
        if (socketPath && socketPath.length > 0) {
            testProcess.running = true
        }
    }

    Process {
        id: testProcess
        command: ["test", "-S", root.socketPath]

        onExited: exitCode => {
            if (exitCode === 0) {
                root.dmsAvailable = true
                connectSocket()
            } else {
                root.dmsAvailable = false
            }
        }
    }

    function connectSocket() {
        if (!dmsAvailable || isConnected || isConnecting) {
            return
        }

        isConnecting = true
        socket.connected = true
    }

    DankSocket {
        id: socket
        path: root.socketPath
        connected: false

        onConnectionStateChanged: {
            if (connected) {
                root.isConnected = true
                root.isConnecting = false
                root.connectionStateChanged()
            } else {
                root.isConnected = false
                root.isConnecting = false
                root.connectionStateChanged()
            }
        }

        parser: SplitParser {
            onRead: line => {
                if (!line || line.length === 0) {
                    return
                }

                try {
                    const response = JSON.parse(line)

                    if (response.capabilities) {
                        root.capabilities = response.capabilities
                        return
                    }

                    handleResponse(response)
                } catch (e) {
                    console.warn("DMSService: Failed to parse response:", line, e)
                }
            }
        }
    }

    function sendRequest(method, params, callback) {
        if (!isConnected) {
            if (callback) {
                callback({
                             "error": "not connected to DMS socket"
                         })
            }
            return
        }

        requestIdCounter++
        const id = Date.now() + requestIdCounter
        const request = {
            "id": id,
            "method": method
        }

        if (params) {
            request.params = params
        }

        if (callback) {
            pendingRequests[id] = callback
        }

        socket.send(request)
    }

    property var networkUpdateCallback: null

    function handleResponse(response) {
        if (response.id === undefined && response.result) {
            if (response.result.type === "state_changed" && response.result.data) {
                if (networkUpdateCallback) {
                    networkUpdateCallback(response.result.data)
                }
            }
            return
        }

        const callback = pendingRequests[response.id]

        if (callback) {
            delete pendingRequests[response.id]
            callback(response)
        }
    }

    function ping(callback) {
        sendRequest("ping", null, callback)
    }

    function listPlugins(callback) {
        sendRequest("plugins.list", null, response => {
                        if (response.result) {
                            availablePlugins = response.result
                            pluginsListReceived(response.result)
                        }
                        if (callback) {
                            callback(response)
                        }
                    })
    }

    function listInstalled(callback) {
        sendRequest("plugins.listInstalled", null, response => {
                        if (response.result) {
                            installedPlugins = response.result
                            installedPluginsReceived(response.result)
                        }
                        if (callback) {
                            callback(response)
                        }
                    })
    }

    function search(query, category, compositor, capability, callback) {
        const params = {
            "query": query
        }
        if (category) {
            params.category = category
        }
        if (compositor) {
            params.compositor = compositor
        }
        if (capability) {
            params.capability = capability
        }

        sendRequest("plugins.search", params, response => {
                        if (response.result) {
                            searchResultsReceived(response.result)
                        }
                        if (callback) {
                            callback(response)
                        }
                    })
    }

    function install(pluginName, callback) {
        sendRequest("plugins.install", {
                        "name": pluginName
                    }, response => {
                        if (callback) {
                            callback(response)
                        }
                        if (!response.error) {
                            listInstalled()
                        }
                    })
    }

    function uninstall(pluginName, callback) {
        sendRequest("plugins.uninstall", {
                        "name": pluginName
                    }, response => {
                        if (callback) {
                            callback(response)
                        }
                        if (!response.error) {
                            listInstalled()
                        }
                    })
    }

    function update(pluginName, callback) {
        sendRequest("plugins.update", {
                        "name": pluginName
                    }, response => {
                        if (callback) {
                            callback(response)
                        }
                        if (!response.error) {
                            listInstalled()
                        }
                    })
    }
}
