pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    property var workspaces: ({})
    property var allWorkspaces: []
    property int focusedWorkspaceIndex: 0
    property string focusedWorkspaceId: ""
    property var currentOutputWorkspaces: []
    property string currentOutput: ""

    property var outputs: ({})

    property var windows: []

    property bool inOverview: false

    property int currentKeyboardLayoutIndex: 0
    property var keyboardLayoutNames: []

    property string configValidationOutput: ""
    property bool hasInitialConnection: false
    property bool suppressConfigToast: true

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET")

    Component.onCompleted: {
        fetchOutputs()
    }

    function fetchOutputs() {
        if (CompositorService.isNiri) {
            outputsProcess.running = true
        }
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

    Socket {
        id: eventStreamSocket
        path: root.socketPath
        connected: CompositorService.isNiri

        onConnectionStateChanged: {
            if (connected) {
                write('"EventStream"\n')
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

    Socket {
        id: requestSocket
        path: root.socketPath
        connected: CompositorService.isNiri
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
        const eventType = Object.keys(event)[0];
        
        switch (eventType) {
            case 'WorkspacesChanged':
                handleWorkspacesChanged(event.WorkspacesChanged);
                break;
            case 'WorkspaceActivated':
                handleWorkspaceActivated(event.WorkspaceActivated);
                break;
            case 'WorkspaceActiveWindowChanged':
                handleWorkspaceActiveWindowChanged(event.WorkspaceActiveWindowChanged);
                break;
            case 'WindowsChanged':
                handleWindowsChanged(event.WindowsChanged);
                break;
            case 'WindowClosed':
                handleWindowClosed(event.WindowClosed);
                break;
            case 'WindowOpenedOrChanged':
                handleWindowOpenedOrChanged(event.WindowOpenedOrChanged);
                break;
            case 'WindowLayoutsChanged':
                handleWindowLayoutsChanged(event.WindowLayoutsChanged);
                break;
            case 'OutputsChanged':
                handleOutputsChanged(event.OutputsChanged);
                break;
            case 'OverviewOpenedOrClosed':
                handleOverviewChanged(event.OverviewOpenedOrClosed);
                break;
            case 'ConfigLoaded':
                handleConfigLoaded(event.ConfigLoaded);
                break;
            case 'KeyboardLayoutsChanged':
                handleKeyboardLayoutsChanged(event.KeyboardLayoutsChanged);
                break;
            case 'KeyboardLayoutSwitched':
                handleKeyboardLayoutSwitched(event.KeyboardLayoutSwitched);
                break;
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
        if (data.active_window_id !== null && data.active_window_id !== undefined) {
            const updatedWindows = []
            for (var i = 0; i < windows.length; i++) {
                const w = windows[i]
                const updatedWindow = {}
                for (let prop in w) {
                    updatedWindow[prop] = w[prop]
                }
                updatedWindow.is_focused = (w.id == data.active_window_id)
                updatedWindows.push(updatedWindow)
            }
            windows = updatedWindows
        } else {
            const updatedWindows = []
            for (var i = 0; i < windows.length; i++) {
                const w = windows[i]
                const updatedWindow = {}
                for (let prop in w) {
                    updatedWindow[prop] = w[prop]
                }
                updatedWindow.is_focused = w.workspace_id == data.workspace_id ? false : w.is_focused
                updatedWindows.push(updatedWindow)
            }
            windows = updatedWindows
        }
    }

    function handleWindowsChanged(data) {
        windows = sortWindowsByLayout(data.windows)
    }

    function handleWindowClosed(data) {
        windows = windows.filter(w => w.id !== data.id)
    }

    function handleWindowOpenedOrChanged(data) {
        if (!data.window) {
            return
        }

        const window = data.window
        const existingIndex = windows.findIndex(w => w.id === window.id)

        if (existingIndex >= 0) {
            const updatedWindows = [...windows]
            updatedWindows[existingIndex] = window
            windows = sortWindowsByLayout(updatedWindows)
        } else {
            windows = sortWindowsByLayout([...windows, window])
        }
    }

    function handleWindowLayoutsChanged(data) {
        if (!data.changes) {
            return
        }

        const updatedWindows = [...windows]
        let hasChanges = false

        for (const change of data.changes) {
            const windowId = change[0]
            const layoutData = change[1]

            const windowIndex = updatedWindows.findIndex(w => w.id === windowId)
            if (windowIndex >= 0) {
                const updatedWindow = {}
                for (var prop in updatedWindows[windowIndex]) {
                    updatedWindow[prop] = updatedWindows[windowIndex][prop]
                }
                updatedWindow.layout = layoutData
                updatedWindows[windowIndex] = updatedWindow
                hasChanges = true
            }
        }

        if (hasChanges) {
            windows = sortWindowsByLayout(updatedWindows)
            windowsChanged()
        }
    }

    function handleOutputsChanged(data) {
        if (data.outputs) {
            outputs = data.outputs
            windows = sortWindowsByLayout(windows)
        }
    }

    function handleOverviewChanged(data) {
        inOverview = data.is_open
    }

    function handleConfigLoaded(data) {
        if (data.failed) {
            validateProcess.running = true
        } else {
            configValidationOutput = ""
            if (ToastService.toastVisible && ToastService.currentLevel === ToastService.levelError) {
                ToastService.hideToast()
            }
            if (hasInitialConnection && !suppressConfigToast) {
                ToastService.showInfo("niri: config reloaded")
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

    function updateCurrentOutputWorkspaces() {
        if (!currentOutput) {
            currentOutputWorkspaces = allWorkspaces
            return
        }

        const outputWs = allWorkspaces.filter(w => w.output === currentOutput)
        currentOutputWorkspaces = outputWs
    }

    function send(request) {
        if (!CompositorService.isNiri || !requestSocket.connected) {
            return false
        }
        requestSocket.write(JSON.stringify(request) + "\n")
        return true
    }

    function switchToWorkspace(workspaceIndex) {
        return send({
                        "Action": {
                            "FocusWorkspace": {
                                "reference": {
                                    "Index": workspaceIndex
                                }
                            }
                        }
                    })
    }

    function focusWindow(windowId) {
        return send({
                        "Action": {
                            "FocusWindow": {
                                "id": windowId
                            }
                        }
                    })
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

    function cycleKeyboardLayout() {
        return send({
                        "Action": {
                            "SwitchLayout": {
                                "layout": "Next"
                            }
                        }
                    })
    }

    function quit() {
        return send({
                        "Action": {
                            "Quit": {
                                "skip_confirmation": true
                            }
                        }
                    })
    }

    function findNiriWindow(toplevel) {
        if (!toplevel.appId) {
            return null
        }

        for (var j = 0; j < windows.length; j++) {
            const niriWindow = windows[j]
            if (niriWindow.app_id === toplevel.appId) {
                if (!niriWindow.title || niriWindow.title === toplevel.title) {
                    return {
                        "niriIndex": j,
                        "niriWindow": niriWindow
                    }
                }
            }
        }
        return null
    }

    function sortToplevels(toplevels) {
        if (!toplevels || toplevels.length === 0 || !CompositorService.isNiri || windows.length === 0) {
            return [...toplevels]
        }

        return [...toplevels].sort((a, b) => {
                                       const aNiri = findNiriWindow(a)
                                       const bNiri = findNiriWindow(b)

                                       if (!aNiri && !bNiri) {
                                           return 0
                                       }
                                       if (!aNiri) {
                                           return 1
                                       }
                                       if (!bNiri) {
                                           return -1
                                       }

                                       const aWindow = aNiri.niriWindow
                                       const bWindow = bNiri.niriWindow
                                       const aWorkspace = allWorkspaces.find(ws => ws.id === aWindow.workspace_id)
                                       const bWorkspace = allWorkspaces.find(ws => ws.id === bWindow.workspace_id)

                                       if (aWorkspace && bWorkspace) {
                                           if (aWorkspace.output !== bWorkspace.output) {
                                               return aWorkspace.output.localeCompare(bWorkspace.output)
                                           }

                                           if (aWorkspace.output === bWorkspace.output && aWorkspace.idx !== bWorkspace.idx) {
                                               return aWorkspace.idx - bWorkspace.idx
                                           }
                                       }

                                       if (aWindow.workspace_id === bWindow.workspace_id && aWindow.layout && bWindow.layout && aWindow.layout.pos_in_scrolling_layout && bWindow.layout.pos_in_scrolling_layout) {
                                           const aPos = aWindow.layout.pos_in_scrolling_layout
                                           const bPos = bWindow.layout.pos_in_scrolling_layout

                                           if (aPos.length > 1 && bPos.length > 1) {
                                               if (aPos[0] !== bPos[0]) {
                                                   return aPos[0] - bPos[0]
                                               }
                                               if (aPos[1] !== bPos[1]) {
                                                   return aPos[1] - bPos[1]
                                               }
                                           }
                                       }

                                       return aWindow.id - bWindow.id
                                   })
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

        if (currentWorkspaceId === null) {
            return toplevels
        }

        return toplevels.filter(toplevel => {
                                    const niriMatch = findNiriWindow(toplevel)
                                    return niriMatch && niriMatch.niriWindow.workspace_id === currentWorkspaceId
                                })
    }

    Timer {
        id: suppressToastTimer
        interval: 3000
        onTriggered: root.suppressConfigToast = false
    }
}
