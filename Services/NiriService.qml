pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common

Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET")

    property var workspaces: ({})
    property var allWorkspaces: []
    property int focusedWorkspaceIndex: 0
    property string focusedWorkspaceId: ""
    property var currentOutputWorkspaces: []
    property string currentOutput: ""

    property var outputs: ({})
    property var windows: []
    property var displayScales: ({})

    property bool inOverview: false

    property int currentKeyboardLayoutIndex: 0
    property var keyboardLayoutNames: []

    property string configValidationOutput: ""
    property bool hasInitialConnection: false
    property bool suppressConfigToast: true
    property bool suppressNextConfigToast: false
    property bool matugenSuppression: false
    property bool configGenerationPending: false

    signal windowUrgentChanged()

    Component.onCompleted: fetchOutputs()

    Timer {
        id: suppressToastTimer
        interval: 3000
        onTriggered: root.suppressConfigToast = false
    }

    Timer {
        id: suppressResetTimer
        interval: 2000
        onTriggered: root.matugenSuppression = false
    }

    Timer {
        id: configGenerationDebounce
        interval: 100
        onTriggered: root.doGenerateNiriLayoutConfig()
    }

    Process {
        id: outputsProcess
        command: ["niri", "msg", "-j", "outputs"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const outputsData = JSON.parse(text)
                    outputs = outputsData
                    console.log("NiriService: Loaded", Object.keys(outputsData).length, "outputs")
                    updateDisplayScales()
                    if (windows.length > 0) {
                        windows = sortWindowsByLayout(windows)
                    }
                } catch (e) {
                    console.warn("NiriService: Failed to parse outputs:", e)
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("NiriService: Failed to fetch outputs, exit code:", exitCode)
            }
        }
    }

    Process {
        id: validateProcess
        command: ["niri", "validate"]
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                const lines = text.split('\n')
                const trimmedLines = lines.map(line => line.replace(/\s+$/, '')).filter(line => line.length > 0)
                configValidationOutput = trimmedLines.join('\n').trim()
                if (hasInitialConnection) {
                    ToastService.showError("niri: failed to load config", configValidationOutput)
                }
            }
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                configValidationOutput = ""
            }
        }
    }

    Process {
        id: writeConfigProcess
        property string configContent: ""
        property string configPath: ""

        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("NiriService: Generated layout config at", configPath)
                return
            }
            console.warn("NiriService: Failed to write layout config, exit code:", exitCode)
        }
    }

    Process {
        id: writeBindsProcess
        property string bindsPath: ""

        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("NiriService: Generated binds config at", bindsPath)
                return
            }
            console.warn("NiriService: Failed to write binds config, exit code:", exitCode)
        }
    }

    DankSocket {
        id: eventStreamSocket
        path: root.socketPath
        connected: CompositorService.isNiri

        onConnectionStateChanged: {
            if (connected) {
                send('"EventStream"')
                fetchOutputs()
            }
        }

        parser: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line)
                    handleNiriEvent(event)
                } catch (e) {
                    console.warn("NiriService: Failed to parse event:", line, e)
                }
            }
        }
    }

    DankSocket {
        id: requestSocket
        path: root.socketPath
        connected: CompositorService.isNiri
    }

    function fetchOutputs() {
        if (!CompositorService.isNiri) return
        outputsProcess.running = true
    }

    function updateDisplayScales() {
        if (!outputs || Object.keys(outputs).length === 0) return

        const scales = {}
        for (const outputName in outputs) {
            const output = outputs[outputName]
            if (output.logical && output.logical.scale !== undefined) {
                scales[outputName] = output.logical.scale
            }
        }

        displayScales = scales
    }

    function sortWindowsByLayout(windowList) {
        return [...windowList].sort((a, b) => {
            const aWorkspace = workspaces[a.workspace_id]
            const bWorkspace = workspaces[b.workspace_id]

            if (aWorkspace && bWorkspace) {
                const aOutput = aWorkspace.output
                const bOutput = bWorkspace.output

                const aOutputInfo = outputs[aOutput]
                const bOutputInfo = outputs[bOutput]

                if (aOutputInfo && bOutputInfo && aOutputInfo.logical && bOutputInfo.logical) {
                    if (aOutputInfo.logical.x !== bOutputInfo.logical.x) {
                        return aOutputInfo.logical.x - bOutputInfo.logical.x
                    }
                    if (aOutputInfo.logical.y !== bOutputInfo.logical.y) {
                        return aOutputInfo.logical.y - bOutputInfo.logical.y
                    }
                }

                if (aOutput === bOutput && aWorkspace.idx !== bWorkspace.idx) {
                    return aWorkspace.idx - bWorkspace.idx
                }
            }

            if (a.workspace_id === b.workspace_id && a.layout && b.layout) {
                if (a.layout.pos_in_scrolling_layout && b.layout.pos_in_scrolling_layout) {
                    const aPos = a.layout.pos_in_scrolling_layout
                    const bPos = b.layout.pos_in_scrolling_layout

                    if (aPos.length > 1 && bPos.length > 1) {
                        if (aPos[0] !== bPos[0]) {
                            return aPos[0] - bPos[0]
                        }
                        if (aPos[1] !== bPos[1]) {
                            return aPos[1] - bPos[1]
                        }
                    }
                }
            }

            return a.id - b.id
        })
    }

    function handleNiriEvent(event) {
        const eventType = Object.keys(event)[0]

        switch (eventType) {
        case 'WorkspacesChanged':
            handleWorkspacesChanged(event.WorkspacesChanged)
            break
        case 'WorkspaceActivated':
            handleWorkspaceActivated(event.WorkspaceActivated)
            break
        case 'WorkspaceActiveWindowChanged':
            handleWorkspaceActiveWindowChanged(event.WorkspaceActiveWindowChanged)
            break
        case 'WindowsChanged':
            handleWindowsChanged(event.WindowsChanged)
            break
        case 'WindowClosed':
            handleWindowClosed(event.WindowClosed)
            break
        case 'WindowOpenedOrChanged':
            handleWindowOpenedOrChanged(event.WindowOpenedOrChanged)
            break
        case 'WindowLayoutsChanged':
            handleWindowLayoutsChanged(event.WindowLayoutsChanged)
            break
        case 'OutputsChanged':
            handleOutputsChanged(event.OutputsChanged)
            break
        case 'OverviewOpenedOrClosed':
            handleOverviewChanged(event.OverviewOpenedOrClosed)
            break
        case 'ConfigLoaded':
            handleConfigLoaded(event.ConfigLoaded)
            break
        case 'KeyboardLayoutsChanged':
            handleKeyboardLayoutsChanged(event.KeyboardLayoutsChanged)
            break
        case 'KeyboardLayoutSwitched':
            handleKeyboardLayoutSwitched(event.KeyboardLayoutSwitched)
            break
        case 'WorkspaceUrgencyChanged':
            handleWorkspaceUrgencyChanged(event.WorkspaceUrgencyChanged)
            break
        }
    }

    function handleWorkspacesChanged(data) {
        const workspaces = {}

        for (const ws of data.workspaces) {
            workspaces[ws.id] = ws
        }

        root.workspaces = workspaces
        allWorkspaces = [...data.workspaces].sort((a, b) => a.idx - b.idx)

        focusedWorkspaceIndex = allWorkspaces.findIndex(w => w.is_focused)
        if (focusedWorkspaceIndex >= 0) {
            const focusedWs = allWorkspaces[focusedWorkspaceIndex]
            focusedWorkspaceId = focusedWs.id
            currentOutput = focusedWs.output || ""
        } else {
            focusedWorkspaceIndex = 0
            focusedWorkspaceId = ""
        }

        updateCurrentOutputWorkspaces()
    }

    function handleWorkspaceActivated(data) {
        const ws = root.workspaces[data.id]
        if (!ws) {
            return
        }
        const output = ws.output

        for (const id in root.workspaces) {
            const workspace = root.workspaces[id]
            const got_activated = workspace.id === data.id

            if (workspace.output === output) {
                workspace.is_active = got_activated
            }

            if (data.focused) {
                workspace.is_focused = got_activated
            }
        }

        focusedWorkspaceId = data.id
        focusedWorkspaceIndex = allWorkspaces.findIndex(w => w.id === data.id)

        if (focusedWorkspaceIndex >= 0) {
            currentOutput = allWorkspaces[focusedWorkspaceIndex].output || ""
        }

        allWorkspaces = Object.values(root.workspaces).sort((a, b) => a.idx - b.idx)

        updateCurrentOutputWorkspaces()
        workspacesChanged()
    }

    function handleWorkspaceActiveWindowChanged(data) {
        const updatedWindows = []

        for (var i = 0; i < windows.length; i++) {
            const w = windows[i]
            const updatedWindow = {}

            for (let prop in w) {
                updatedWindow[prop] = w[prop]
            }

            if (data.active_window_id !== null && data.active_window_id !== undefined) {
                updatedWindow.is_focused = (w.id == data.active_window_id)
            } else {
                updatedWindow.is_focused = w.workspace_id == data.workspace_id ? false : w.is_focused
            }

            updatedWindows.push(updatedWindow)
        }

        windows = updatedWindows
    }

    function handleWindowsChanged(data) {
        windows = sortWindowsByLayout(data.windows)
    }

    function handleWindowClosed(data) {
        windows = windows.filter(w => w.id !== data.id)
    }

    function handleWindowOpenedOrChanged(data) {
        if (!data.window) return

        const window = data.window
        const existingIndex = windows.findIndex(w => w.id === window.id)

        if (existingIndex >= 0) {
            const updatedWindows = [...windows]
            updatedWindows[existingIndex] = window
            windows = sortWindowsByLayout(updatedWindows)
            return
        }

        windows = sortWindowsByLayout([...windows, window])
    }

    function handleWindowLayoutsChanged(data) {
        if (!data.changes) return

        const updatedWindows = [...windows]
        let hasChanges = false

        for (const change of data.changes) {
            const windowId = change[0]
            const layoutData = change[1]

            const windowIndex = updatedWindows.findIndex(w => w.id === windowId)
            if (windowIndex < 0) continue

            const updatedWindow = {}
            for (var prop in updatedWindows[windowIndex]) {
                updatedWindow[prop] = updatedWindows[windowIndex][prop]
            }
            updatedWindow.layout = layoutData
            updatedWindows[windowIndex] = updatedWindow
            hasChanges = true
        }

        if (!hasChanges) return

        windows = sortWindowsByLayout(updatedWindows)
        windowsChanged()
    }

    function handleOutputsChanged(data) {
        if (!data.outputs) return
        outputs = data.outputs
        updateDisplayScales()
        windows = sortWindowsByLayout(windows)
    }

    function handleOverviewChanged(data) {
        inOverview = data.is_open
    }

    function handleConfigLoaded(data) {
        if (data.failed) {
            validateProcess.running = true
        } else {
            configValidationOutput = ""
            if (ToastService.toastVisible && ToastService.currentLevel === ToastService.levelError && ToastService.currentMessage.startsWith("niri:")) {
                ToastService.hideToast()
            }
            fetchOutputs()
            if (hasInitialConnection && !suppressConfigToast && !suppressNextConfigToast && !matugenSuppression) {
                ToastService.showInfo("niri: config reloaded")
            } else if (suppressNextConfigToast) {
                suppressNextConfigToast = false
                suppressResetTimer.stop()
            }
        }

        if (!hasInitialConnection) {
            hasInitialConnection = true
            suppressToastTimer.start()
        }
    }

    function handleKeyboardLayoutsChanged(data) {
        keyboardLayoutNames = data.keyboard_layouts.names
        currentKeyboardLayoutIndex = data.keyboard_layouts.current_idx
    }

    function handleKeyboardLayoutSwitched(data) {
        currentKeyboardLayoutIndex = data.idx
    }

    function handleWorkspaceUrgencyChanged(data) {
        const ws = root.workspaces[data.id]
        if (!ws) return

        ws.is_urgent = data.urgent

        const idx = allWorkspaces.findIndex(w => w.id === data.id)
        if (idx >= 0) {
            allWorkspaces[idx].is_urgent = data.urgent
        }

        windowUrgentChanged()
    }

    function updateCurrentOutputWorkspaces() {
        if (!currentOutput) {
            currentOutputWorkspaces = allWorkspaces
            return
        }

        const outputWs = allWorkspaces.filter(w => w.output === currentOutput)
        currentOutputWorkspaces = outputWs
    }

    function send(request) {
        if (!CompositorService.isNiri || !requestSocket.connected) return false
        requestSocket.send(request)
        return true
    }

    function doScreenTransition() {
        return send({"Action": {"DoScreenTransition": {"delay_ms": 0}}})
    }

    function toggleOverview() {
        return send({"Action": {"ToggleOverview": {}}})
    }

    function switchToWorkspace(workspaceIndex) {
        return send({"Action": {"FocusWorkspace": {"reference": {"Index": workspaceIndex}}}})
    }

    function focusWindow(windowId) {
        return send({"Action": {"FocusWindow": {"id": windowId}}})
    }

    function powerOffMonitors() {
        return send({"Action": {"PowerOffMonitors": {}}})
    }

    function powerOnMonitors() {
        return send({"Action": {"PowerOnMonitors": {}}})
    }

    function cycleKeyboardLayout() {
        return send({"Action": {"SwitchLayout": {"layout": "Next"}}})
    }

    function quit() {
        return send({"Action": {"Quit": {"skip_confirmation": true}}})
    }

    function getCurrentOutputWorkspaceNumbers() {
        return currentOutputWorkspaces.map(w => w.idx + 1)
    }

    function getCurrentWorkspaceNumber() {
        if (focusedWorkspaceIndex >= 0 && focusedWorkspaceIndex < allWorkspaces.length) {
            return allWorkspaces[focusedWorkspaceIndex].idx + 1
        }
        return 1
    }

    function getCurrentKeyboardLayoutName() {
        if (currentKeyboardLayoutIndex >= 0 && currentKeyboardLayoutIndex < keyboardLayoutNames.length) {
            return keyboardLayoutNames[currentKeyboardLayoutIndex]
        }
        return ""
    }

    function suppressNextToast() {
        matugenSuppression = true
        suppressResetTimer.restart()
    }

    function findNiriWindow(toplevel) {
        if (!toplevel.appId) return null

        for (var j = 0; j < windows.length; j++) {
            const niriWindow = windows[j]
            if (niriWindow.app_id === toplevel.appId) {
                if (!niriWindow.title || niriWindow.title === toplevel.title) {
                    return {"niriIndex": j, "niriWindow": niriWindow}
                }
            }
        }
        return null
    }

    function sortToplevels(toplevels) {
        if (!toplevels || toplevels.length === 0 || !CompositorService.isNiri || windows.length === 0) {
            return [...toplevels]
        }

        const usedToplevels = new Set()
        const enrichedToplevels = []

        for (const niriWindow of sortWindowsByLayout(windows)) {
            let bestMatch = null

            for (const toplevel of toplevels) {
                if (usedToplevels.has(toplevel)) continue

                if (toplevel.appId === niriWindow.app_id) {
                    if (niriWindow.title && toplevel.title === niriWindow.title) {
                        bestMatch = toplevel
                        break
                    }
                    if (!niriWindow.title && !bestMatch) {
                        bestMatch = toplevel
                    }
                }
            }

            if (!bestMatch) continue

            usedToplevels.add(bestMatch)

            const enrichedToplevel = {
                appId: bestMatch.appId,
                title: bestMatch.title,
                activated: bestMatch.activated,
                niriWindowId: niriWindow.id,
                niriWorkspaceId: niriWindow.workspace_id,
                activate: function() {
                    return NiriService.focusWindow(niriWindow.id)
                },
                close: function() {
                    if (bestMatch.close) {
                        return bestMatch.close()
                    }
                    return false
                }
            }

            for (let prop in bestMatch) {
                if (!(prop in enrichedToplevel)) {
                    enrichedToplevel[prop] = bestMatch[prop]
                }
            }

            enrichedToplevels.push(enrichedToplevel)
        }

        for (const toplevel of toplevels) {
            if (!usedToplevels.has(toplevel)) {
                enrichedToplevels.push(toplevel)
            }
        }

        return enrichedToplevels
    }

    function filterCurrentWorkspace(toplevels, screenName) {
        let currentWorkspaceId = null

        for (var i = 0; i < allWorkspaces.length; i++) {
            const ws = allWorkspaces[i]
            if (ws.output === screenName && ws.is_active) {
                currentWorkspaceId = ws.id
                break
            }
        }

        if (currentWorkspaceId === null) return toplevels

        const workspaceWindows = windows.filter(niriWindow => niriWindow.workspace_id === currentWorkspaceId)
        const usedToplevels = new Set()
        const result = []

        for (const niriWindow of workspaceWindows) {
            let bestMatch = null

            for (const toplevel of toplevels) {
                if (usedToplevels.has(toplevel)) continue

                if (toplevel.appId === niriWindow.app_id) {
                    if (niriWindow.title && toplevel.title === niriWindow.title) {
                        bestMatch = toplevel
                        break
                    }
                    if (!niriWindow.title && !bestMatch) {
                        bestMatch = toplevel
                    }
                }
            }

            if (!bestMatch) continue

            usedToplevels.add(bestMatch)

            const enrichedToplevel = {
                appId: bestMatch.appId,
                title: bestMatch.title,
                activated: bestMatch.activated,
                niriWindowId: niriWindow.id,
                niriWorkspaceId: niriWindow.workspace_id,
                activate: function() {
                    return NiriService.focusWindow(niriWindow.id)
                },
                close: function() {
                    if (bestMatch.close) {
                        return bestMatch.close()
                    }
                    return false
                }
            }

            for (let prop in bestMatch) {
                if (!(prop in enrichedToplevel)) {
                    enrichedToplevel[prop] = bestMatch[prop]
                }
            }

            result.push(enrichedToplevel)
        }

        return result
    }

    function generateNiriLayoutConfig() {
        const niriSocket = Quickshell.env("NIRI_SOCKET")
        if (!niriSocket || niriSocket.length === 0) return
        if (configGenerationPending) return

        configGenerationPending = true
        configGenerationDebounce.restart()
    }

    function doGenerateNiriLayoutConfig() {
        console.log("NiriService: Generating layout config...")

        const cornerRadius = typeof SettingsData !== "undefined" ? SettingsData.cornerRadius : 12
        const gaps = typeof SettingsData !== "undefined" ? Math.max(4, SettingsData.dankBarSpacing) : 4

        const configContent = `layout {
    gaps ${gaps}

    border {
        width 2
    }

    focus-ring {
        width 2
    }
}

window-rule {
    geometry-corner-radius ${cornerRadius}
    clip-to-geometry true
    tiled-state true
    draw-border-with-background false
}`

        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
        const niriDmsDir = configDir + "/niri/dms"
        const configPath = niriDmsDir + "/layout.kdl"

        writeConfigProcess.configContent = configContent
        writeConfigProcess.configPath = configPath
        writeConfigProcess.command = ["sh", "-c", `mkdir -p "${niriDmsDir}" && cat > "${configPath}" << 'EOF'\n${configContent}\nEOF`]
        writeConfigProcess.running = true
        configGenerationPending = false
    }

    function generateNiriBinds() {
        console.log("NiriService: Generating binds config...")

        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
        const niriDmsDir = configDir + "/niri/dms"
        const bindsPath = niriDmsDir + "/binds.kdl"
        const sourceBindsPath = Paths.strip(Qt.resolvedUrl("niri-binds.kdl"))

        writeBindsProcess.bindsPath = bindsPath
        writeBindsProcess.command = ["sh", "-c", `mkdir -p "${niriDmsDir}" && cp "${sourceBindsPath}" "${bindsPath}"`]
        writeBindsProcess.running = true
    }
}