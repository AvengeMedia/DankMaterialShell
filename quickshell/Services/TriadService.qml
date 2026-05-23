pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("TriadService")

    readonly property string socketPath: {
        const explicitSocket = Quickshell.env("TRIAD_SOCKET")
        if (explicitSocket && explicitSocket.length > 0)
        return explicitSocket
        const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR")
        return runtimeDir && runtimeDir.length > 0 ? `${runtimeDir}/triad.sock` : ""
    }

    property var workspaces: ({})
    property var allWorkspaces: []
    property int focusedWorkspaceIndex: 1
    property var focusedWorkspaceId: null
    property var currentOutputWorkspaces: []
    property string currentOutput: ""

    property var outputs: ({})
    property var windows: []
    property var displayScales: ({})

    property bool inOverview: false
    property int currentKeyboardLayoutIndex: 0
    property var keyboardLayoutNames: []

    signal windowUrgentChanged

    DankSocket {
        id: eventStreamSocket
        path: root.socketPath
        connected: CompositorService.isTriad && root.socketPath.length > 0

        onConnectionStateChanged: {
            if (connected) {
                send({
                         "triad": {
                             "version": 1,
                             "request": "event-stream",
                             "events": ["state", "layout", "window"]
                         }
                     })
            }
        }

        parser: SplitParser {
            onRead: line => root.handleMessage(line)
        }
    }

    DankSocket {
        id: requestSocket
        path: root.socketPath
        connected: CompositorService.isTriad && root.socketPath.length > 0
    }

    function handleMessage(line) {
        if (!line || line.trim().length === 0)
            return
        try {
            const message = JSON.parse(line)
            const payload = message.triad
            if (!payload)
                return

            if (payload.type === "state" && payload.state) {
                applyState(payload.state)
                return
            }

            switch (payload.event) {
            case "state-changed":
                applyState(payload.state)
                break
            case "layout-state-changed":
                applyLayoutState(payload.state)
                break
            case "window-changed":
                mergeWindow(payload.window)
                break
            }
        } catch (e) {
            log.warn("Failed to parse Triad IPC message:", line, e)
        }
    }

    function send(request) {
        if (!CompositorService.isTriad || !requestSocket.connected)
            return false
        requestSocket.send(request)
        return true
    }

    function action(name, fields) {
        const payload = {
            "triad": {
                "version": 1,
                "request": "action",
                "action": name
            }
        }
        if (fields) {
            for (const key in fields) {
                payload.triad[key] = fields[key]
            }
        }
        return send(payload)
    }

    function switchToWorkspace(workspaceId) {
        const workspace = allWorkspaces.find(ws => ws.id === workspaceId || String(ws.id) === String(workspaceId))
        const idx = workspace?.idx ?? Number(workspaceId)
        if (idx > 0)
            return action("focus-workspace", {
                              "workspace_idx": idx
                          })
        return false
    }

    function focusWindow(windowId) {
        const id = Number(windowId)
        if (id > 0)
            return action("focus-window", {
                              "id": id
                          })
        return false
    }

    function toggleOverview() {
        return action("toggle-overview")
    }

    function moveColumnLeft() {
        return action("move-column-left")
    }

    function moveColumnRight() {
        return action("move-column-right")
    }

    function powerOffMonitors() {
        return action("power-off-monitors")
    }

    function powerOnMonitors() {
        return action("power-on-monitors")
    }

    function cycleKeyboardLayout() {
        return action("switch-keyboard-layout", {
                          "layout": "next"
                      })
    }

    function getCurrentKeyboardLayoutName() {
        if (!keyboardLayoutNames || keyboardLayoutNames.length === 0)
            return ""
        const idx = currentKeyboardLayoutIndex
        if (idx >= 0 && idx < keyboardLayoutNames.length)
            return keyboardLayoutNames[idx]
        return keyboardLayoutNames[0] || ""
    }

    function quit() {
        return action("exit-session")
    }

    function applyState(state) {
        if (!state)
            return
        applyOutputs(state.outputs || [])
        if (state.overview)
            inOverview = state.overview.is_open === true
        keyboardLayoutNames = state.keyboard_layouts || []
        currentKeyboardLayoutIndex = state.current_keyboard_layout_idx ?? 0
        applyWindows(state.windows || [])
        applyLayoutState(state.layout)
    }

    function applyOutputs(outputList) {
        const nextOutputs = {}
        const nextScales = {}
        for (const output of outputList || []) {
            if (!output?.name)
                continue
            nextOutputs[output.name] = output
            if (output.scale !== undefined && output.scale > 0)
                nextScales[output.name] = output.scale
        }
        outputs = nextOutputs
        displayScales = nextScales
    }

    function applyLayoutState(layout) {
        if (!layout)
            return
        focusedWorkspaceIndex = layout.active_workspace_idx || 1
        focusedWorkspaceId = layout.active_tag ?? null
        setWorkspaces(layout.workspaces || [])
    }

    function setWorkspaces(workspaceList) {
        const next = {}
        const mapped = []
        for (const workspace of workspaceList || []) {
            const normalized = normalizeWorkspace(workspace)
            if (!normalized)
                continue
            next[String(normalized.id)] = normalized
            mapped.push(normalized)
        }

        mapped.sort((a, b) => {
                        if (a.output !== b.output)
                        return a.output.localeCompare(b.output)
                        return a.idx - b.idx
                    })
        workspaces = next
        allWorkspaces = mapped
        updateCurrentOutput()
    }

    function normalizeWorkspace(workspace) {
        if (!workspace)
            return null
        const idx = Number(workspace.workspace_idx || 0)
        const id = workspace.tag_id ?? idx
        if (!id && idx <= 0)
            return null
        return {
            "id": id,
            "idx": idx,
            "name": workspace.name || "",
            "output": workspace.output || "",
            "is_active": workspace.is_output_visible === true,
            "is_focused": workspace.is_active === true,
            "is_urgent": workspace.is_urgent === true,
            "occupied": workspace.occupied === true,
            "active_window_id": workspace.focused_window_id ?? null,
            "layout": workspace.layout || "",
            "tag_id": id,
            "workspace_idx": idx
        }
    }

    function updateCurrentOutput() {
        let focused = allWorkspaces.find(ws => ws.is_focused)
        if (!focused)
            focused = allWorkspaces.find(ws => ws.is_active)
        if (!focused && allWorkspaces.length > 0)
            focused = allWorkspaces[0]
        currentOutput = focused?.output || ""
        currentOutputWorkspaces = currentOutput ? allWorkspaces.filter(ws => ws.output === currentOutput) : []
    }

    function applyWindows(windowList) {
        windows = sortWindows((windowList || []).map(normalizeWindow).filter(w => w !== null))
    }

    function mergeWindow(windowData) {
        const normalized = normalizeWindow(windowData)
        if (!normalized)
            return
        const next = windows.slice()
        const index = next.findIndex(win => win.id === normalized.id)
        if (index >= 0)
            next[index] = Object.assign({}, next[index], normalized)
        else
            next.push(normalized)
        windows = sortWindows(next)
    }

    function normalizeWindow(windowData) {
        if (!windowData || windowData.id === undefined || windowData.id === null)
            return null
        const id = Number(windowData.id)
        const appId = windowData.app_id || ""
        return {
            "id": id,
            "title": windowData.title || "",
            "app_id": appId,
            "appId": appId,
            "workspace_id": windowData.tag_id ?? null,
            "workspace_idx": windowData.workspace_idx ?? null,
            "output": windowData.output || "",
            "position": windowData.position || {},
            "is_focused": windowData.is_focused === true,
            "activated": windowData.is_focused === true,
            "is_floating": windowData.is_floating === true,
            "is_maximized": windowData.is_maximized === true,
            "is_fullscreen": windowData.is_fullscreen === true,
            "fullscreen": windowData.is_fullscreen === true,
            "floating_geometry": windowData.floating_geometry || null,
            "is_urgent": false
        }
    }

    function sortWindows(windowList) {
        return windowList.slice().sort((a, b) => {
                                           if (a.output !== b.output)
                                           return a.output.localeCompare(b.output)
                                           if ((a.workspace_idx || 0) !== (b.workspace_idx || 0))
                                           return (a.workspace_idx || 0) - (b.workspace_idx || 0)
                                           const aColumn = a.position?.column_idx ?? 0
                                           const bColumn = b.position?.column_idx ?? 0
                                           if (aColumn !== bColumn)
                                           return aColumn - bColumn
                                           const aWindow = a.position?.window_idx ?? 0
                                           const bWindow = b.position?.window_idx ?? 0
                                           if (aWindow !== bWindow)
                                           return aWindow - bWindow
                                           return String(a.title || "").localeCompare(String(b.title || ""))
                                       })
    }

    function getCurrentOutputWorkspaces() {
        return currentOutputWorkspaces
    }

    function getCurrentWorkspaceNumber() {
        return focusedWorkspaceIndex
    }

    function sortToplevels(toplevels) {
        return matchAndEnrichToplevels(Array.from(toplevels || []))
    }

    function filterCurrentWorkspace(toplevels, screenName) {
        if (!toplevels || toplevels.length === 0)
            return toplevels

        const workspace = screenName ? allWorkspaces.find(ws => ws.output === screenName && ws.is_active) : allWorkspaces.find(ws => ws.is_focused)
        const workspaceId = workspace?.id ?? focusedWorkspaceId
        if (workspaceId === undefined || workspaceId === null)
            return toplevels

        return matchAndEnrichToplevels(toplevels).filter(tl => tl?.triadWorkspaceId === workspaceId)
    }

    function filterCurrentDisplay(toplevels, screenName) {
        if (!toplevels || toplevels.length === 0 || !screenName)
            return toplevels
        return matchAndEnrichToplevels(toplevels).filter(tl => tl?.triadOutput === screenName)
    }

    function matchAndEnrichToplevels(toplevels) {
        const used = {}
        const enriched = []
        for (const toplevel of toplevels || []) {
            if (!toplevel)
                continue
            const win = findMatchingWindow(toplevel, used)
            if (win) {
                used[win.id] = true
                toplevel.triadWindowId = win.id
                toplevel.triadWorkspaceId = win.workspace_id
                toplevel.triadOutput = win.output
                toplevel.triadFocused = win.is_focused
                toplevel.triadFullscreen = win.is_fullscreen
                toplevel.triadMaximized = win.is_maximized
            }
            enriched.push(toplevel)
        }
        return enriched
    }

    function findMatchingWindow(toplevel, used) {
        const appId = toplevel.app_id || toplevel.appId || toplevel.class || toplevel.windowClass || ""
        const title = toplevel.title || ""
        let fallback = null
        for (const win of windows) {
            if (!win || used[win.id])
                continue
            if (appId && win.app_id && appId !== win.app_id)
                continue
            if (title && win.title && title === win.title)
                return win
            if (!fallback)
                fallback = win
        }
        return fallback
    }
}
