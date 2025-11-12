pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("SCROLLSOCK")

    property var workspaces: ({})
    property var allWorkspaces: []
    property int focusedWorkspaceNum: 1
    property var currentOutputWorkspaces: []
    property string currentOutput: ""
    property var outputs: []
    property string focusedWorkspaceName: ""
    property string currentMode: ""
    property string currentKeyboardLayout: ""
    property bool scrollerEnabled: false
    property string scrollDirection: "horizontal"
    property bool trailsEnabled: false
    property string trailsDirection: "forward"

    readonly property int IPC_COMMAND: 0
    readonly property int IPC_GET_WORKSPACES: 1
    readonly property int IPC_SUBSCRIBE: 2
    readonly property int IPC_GET_OUTPUTS: 3
    readonly property int IPC_GET_TREE: 4
    readonly property int IPC_GET_VERSION: 6
    readonly property int IPC_GET_INPUTS: 100

    readonly property int IPC_EVENT_WORKSPACE: 0x80000000
    readonly property int IPC_EVENT_OUTPUT: 0x80000001
    readonly property int IPC_EVENT_MODE: 0x80000002
    readonly property int IPC_EVENT_WINDOW: 0x80000003
    readonly property int IPC_EVENT_INPUT: 0x80000007
    readonly property int IPC_EVENT_SCROLLER: 0x80000014
    readonly property int IPC_EVENT_TRAILS: 0x80000015

    property bool hasInitialConnection: false
    property var _pendingResponses: []
    property int _messageId: 0

    function setWorkspaces(workspaceArray) {
        const newMap = {}
        for (const ws of workspaceArray) {
            newMap[ws.num] = ws
        }
        root.workspaces = newMap
        allWorkspaces = workspaceArray.sort((a, b) => a.num - b.num)
    }

    Component.onCompleted: {
        if (CompositorService.isScroll) {
            Qt.callLater(() => {
                fetchWorkspaces()
                fetchOutputs()
            })
        }
    }

    DankSocket {
        id: eventStreamSocket
        path: root.socketPath
        connected: CompositorService.isScroll

        onConnectionStateChanged: {
            if (connected) {
                subscribeToEvents()
                fetchWorkspaces()
                fetchOutputs()
            }
        }

        parser: DataStreamParser {
            id: eventParser

            property var buffer: new ArrayBuffer(0)
            property int bufferPos: 0

            onRead: data => {
                const newLength = buffer.byteLength - bufferPos + data.byteLength
                const newBuffer = new ArrayBuffer(newLength)
                const newView = new Uint8Array(newBuffer)

                if (bufferPos < buffer.byteLength) {
                    const oldView = new Uint8Array(buffer, bufferPos)
                    newView.set(oldView, 0)
                }

                const dataView = new Uint8Array(data)
                newView.set(dataView, buffer.byteLength - bufferPos)

                buffer = newBuffer
                bufferPos = 0

                processBuffer()
            }

            function processBuffer() {
                while (true) {
                    if (buffer.byteLength - bufferPos < 14) {
                        return
                    }

                    const view = new DataView(buffer, bufferPos)
                    const magic = String.fromCharCode(view.getUint8(0), view.getUint8(1), view.getUint8(2), view.getUint8(3), view.getUint8(4), view.getUint8(5))

                    if (magic !== "i3-ipc") {
                        console.warn("ScrollService: Invalid magic string, resetting buffer")
                        buffer = new ArrayBuffer(0)
                        bufferPos = 0
                        return
                    }

                    const payloadLength = view.getUint32(6, true)
                    const messageType = view.getUint32(10, true)

                    if (buffer.byteLength - bufferPos < 14 + payloadLength) {
                        return
                    }

                    const payloadBytes = new Uint8Array(buffer, bufferPos + 14, payloadLength)
                    const decoder = new TextDecoder("utf-8")
                    const payloadText = decoder.decode(payloadBytes)

                    bufferPos += 14 + payloadLength

                    try {
                        const payload = JSON.parse(payloadText)
                        handleScrollEvent(messageType, payload)
                    } catch (e) {
                        console.warn("ScrollService: Failed to parse payload:", e, payloadText)
                    }
                }
            }
        }
    }

    DankSocket {
        id: requestSocket
        path: root.socketPath
        connected: CompositorService.isScroll

        parser: DataStreamParser {
            id: requestParser

            property var buffer: new ArrayBuffer(0)
            property int bufferPos: 0

            onRead: data => {
                const newLength = buffer.byteLength - bufferPos + data.byteLength
                const newBuffer = new ArrayBuffer(newLength)
                const newView = new Uint8Array(newBuffer)

                if (bufferPos < buffer.byteLength) {
                    const oldView = new Uint8Array(buffer, bufferPos)
                    newView.set(oldView, 0)
                }

                const dataView = new Uint8Array(data)
                newView.set(dataView, buffer.byteLength - bufferPos)

                buffer = newBuffer
                bufferPos = 0

                processBuffer()
            }

            function processBuffer() {
                while (true) {
                    if (buffer.byteLength - bufferPos < 14) {
                        return
                    }

                    const view = new DataView(buffer, bufferPos)
                    const magic = String.fromCharCode(view.getUint8(0), view.getUint8(1), view.getUint8(2), view.getUint8(3), view.getUint8(4), view.getUint8(5))

                    if (magic !== "i3-ipc") {
                        console.warn("ScrollService: Invalid magic string in response, resetting buffer")
                        buffer = new ArrayBuffer(0)
                        bufferPos = 0
                        return
                    }

                    const payloadLength = view.getUint32(6, true)
                    const messageType = view.getUint32(10, true)

                    if (buffer.byteLength - bufferPos < 14 + payloadLength) {
                        return
                    }

                    const payloadBytes = new Uint8Array(buffer, bufferPos + 14, payloadLength)
                    const decoder = new TextDecoder("utf-8")
                    const payloadText = decoder.decode(payloadBytes)

                    bufferPos += 14 + payloadLength

                    try {
                        const payload = JSON.parse(payloadText)
                        handleScrollResponse(messageType, payload)
                    } catch (e) {
                        console.warn("ScrollService: Failed to parse response payload:", e, payloadText)
                    }
                }
            }
        }
    }

    function encodeMessage(messageType, payload) {
        const payloadStr = payload || ""
        const encoder = new TextEncoder()
        const payloadBytes = encoder.encode(payloadStr)
        const payloadLength = payloadBytes.byteLength

        const buffer = new ArrayBuffer(14 + payloadLength)
        const view = new DataView(buffer)

        view.setUint8(0, 105)
        view.setUint8(1, 51)
        view.setUint8(2, 45)
        view.setUint8(3, 105)
        view.setUint8(4, 112)
        view.setUint8(5, 99)

        view.setUint32(6, payloadLength, true)
        view.setUint32(10, messageType, true)

        const bufferView = new Uint8Array(buffer)
        bufferView.set(payloadBytes, 14)

        return buffer
    }

    function send(messageType, payload) {
        if (!CompositorService.isScroll || !requestSocket.connected) {
            return false
        }

        const message = encodeMessage(messageType, payload)
        requestSocket.write(message)
        requestSocket.flush()
        return true
    }

    function subscribeToEvents() {
        const events = JSON.stringify(["workspace", "output", "mode", "window", "input", "scroller", "trails"])
        send(IPC_SUBSCRIBE, events)
        hasInitialConnection = true
        console.info("ScrollService: Subscribed to events")
    }

    function fetchWorkspaces() {
        send(IPC_GET_WORKSPACES, "")
    }

    function fetchOutputs() {
        send(IPC_GET_OUTPUTS, "")
    }

    function handleScrollResponse(messageType, payload) {
        switch (messageType) {
        case IPC_GET_WORKSPACES:
            handleWorkspacesResponse(payload)
            break
        case IPC_GET_OUTPUTS:
            handleOutputsResponse(payload)
            break
        case IPC_SUBSCRIBE:
            console.info("ScrollService: Subscription confirmed")
            break
        }
    }

    function handleScrollEvent(messageType, payload) {
        switch (messageType) {
        case IPC_EVENT_WORKSPACE:
            handleWorkspaceEvent(payload)
            break
        case IPC_EVENT_OUTPUT:
            handleOutputEvent(payload)
            break
        case IPC_EVENT_MODE:
            handleModeEvent(payload)
            break
        case IPC_EVENT_WINDOW:
            handleWindowEvent(payload)
            break
        case IPC_EVENT_INPUT:
            handleInputEvent(payload)
            break
        case IPC_EVENT_SCROLLER:
            handleScrollerEvent(payload)
            break
        case IPC_EVENT_TRAILS:
            handleTrailsEvent(payload)
            break
        }
    }

    function handleWorkspacesResponse(payload) {
        if (!payload || !Array.isArray(payload)) {
            return
        }

        setWorkspaces(payload)

        const focused = payload.find(ws => ws.focused === true)
        if (focused) {
            focusedWorkspaceNum = focused.num
            focusedWorkspaceName = focused.name || String(focused.num)
            currentOutput = focused.output || ""
        }

        updateCurrentOutputWorkspaces()
    }

    function handleOutputsResponse(payload) {
        if (!payload || !Array.isArray(payload)) {
            return
        }

        outputs = payload
        console.info("ScrollService: Loaded", outputs.length, "outputs")
    }

    function handleWorkspaceEvent(payload) {
        if (!payload || !payload.change) {
            return
        }

        const change = payload.change

        if (change === "focus" || change === "init" || change === "empty" || change === "urgent") {
            fetchWorkspaces()
        }

        if (change === "focus" && payload.current) {
            focusedWorkspaceNum = payload.current.num
            focusedWorkspaceName = payload.current.name || String(payload.current.num)
            currentOutput = payload.current.output || ""
            updateCurrentOutputWorkspaces()
        }
    }

    function handleOutputEvent(payload) {
        if (!payload || !payload.change) {
            return
        }

        fetchOutputs()
        fetchWorkspaces()
    }

    function handleModeEvent(payload) {
        if (!payload || !payload.change) {
            return
        }

        currentMode = payload.change
    }

    function handleWindowEvent(payload) {
        if (!payload || !payload.change) {
            return
        }
    }

    function handleInputEvent(payload) {
        if (!payload || !payload.input) {
            return
        }

        const input = payload.input
        if (input.type === "keyboard" && input.xkb_active_layout_name) {
            currentKeyboardLayout = input.xkb_active_layout_name
        }
    }

    function handleScrollerEvent(payload) {
        if (!payload) {
            return
        }

        scrollerEnabled = payload.enabled ?? false
        scrollDirection = payload.direction || "horizontal"
    }

    function handleTrailsEvent(payload) {
        if (!payload) {
            return
        }

        trailsEnabled = payload.enabled ?? false
        trailsDirection = payload.direction || "forward"
    }

    function updateCurrentOutputWorkspaces() {
        if (!currentOutput) {
            currentOutputWorkspaces = allWorkspaces
            return
        }

        const outputWs = allWorkspaces.filter(w => w.output === currentOutput)
        currentOutputWorkspaces = outputWs
    }

    function switchToWorkspace(workspaceNum) {
        return send(IPC_COMMAND, `workspace number ${workspaceNum}`)
    }

    function getCurrentOutputWorkspaceNumbers() {
        return currentOutputWorkspaces.map(w => w.num)
    }

    function getCurrentWorkspaceNumber() {
        return focusedWorkspaceNum
    }

    function getCurrentKeyboardLayoutName() {
        return currentKeyboardLayout
    }
}
