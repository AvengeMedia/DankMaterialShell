pragma Singleton
pragma ComponentBehavior

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
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

    property var _realOutputs: ({})

    property bool inOverview: false

    property int currentKeyboardLayoutIndex: 0
    property var keyboardLayoutNames: []

    property string configValidationOutput: ""
    property bool hasInitialConnection: false
    property bool suppressConfigToast: true
    property bool suppressNextConfigToast: false
    property bool matugenSuppression: false
    property bool configGenerationPending: false

    readonly property string screenshotsDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.PicturesLocation)) + "/Screenshots"
    property string pendingScreenshotPath: ""

    signal windowUrgentChanged
    signal configReloaded

    function setWorkspaces(newMap) {
        root.workspaces = newMap;
        allWorkspaces = Object.values(newMap).sort((a, b) => a.idx - b.idx);
    }

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

    property int _lastGapValue: -1

    Connections {
        target: SettingsData
        function onBarConfigsChanged() {
            const newGaps = Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4));
            if (newGaps === root._lastGapValue)
                return;
            root._lastGapValue = newGaps;
            generateNiriLayoutConfig();
        }
    }

    Process {
        id: validateProcess
        command: ["niri", "validate"]
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                const lines = text.split('\n');
                const trimmedLines = lines.map(line => line.replace(/\s+$/, '')).filter(line => line.length > 0);
                configValidationOutput = trimmedLines.join('\n').trim();
                if (hasInitialConnection) {
                    ToastService.showError("niri: failed to load config", configValidationOutput, "", "niri-config");
                }
            }
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                configValidationOutput = "";
            }
        }
    }

    Process {
        id: writeConfigProcess
        property string configContent: ""
        property string configPath: ""

        onExited: exitCode => {
            if (exitCode === 0) {
                console.info("NiriService: Generated layout config at", configPath);
                return;
            }
            console.warn("NiriService: Failed to write layout config, exit code:", exitCode);
        }
    }

    Process {
        id: writeAlttabProcess
        property string alttabContent: ""
        property string alttabPath: ""

        onExited: exitCode => {
            if (exitCode === 0) {
                console.info("NiriService: Generated alttab config at", alttabPath);
                return;
            }
            console.warn("NiriService: Failed to write alttab config, exit code:", exitCode);
        }
    }

    Process {
        id: writeBlurruleProcess
        property string blurrulePath: ""

        onExited: exitCode => {
            if (exitCode === 0) {
                console.info("NiriService: Generated wpblur config at", blurrulePath);
                return;
            }
            console.warn("NiriService: Failed to write wpblur config, exit code:", exitCode);
        }
    }

    DankSocket {
        id: eventStreamSocket
        path: root.socketPath
        connected: CompositorService.isNiri

        onConnectionStateChanged: {
            if (connected) {
                send('"EventStream"');
                fetchOutputs();
            }
        }

        parser: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line);
                    handleNiriEvent(event);
                } catch (e) {
                    console.warn("NiriService: Failed to parse event:", line, e);
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
        if (!CompositorService.isNiri)
            return;
        Proc.runCommand("niri-fetch-outputs", ["niri", "msg", "-j", "outputs"], (output, exitCode) => {
            if (exitCode !== 0) {
                console.warn("NiriService: Failed to fetch outputs, exit code:", exitCode);
                return;
            }
            try {
                const outputsData = JSON.parse(output);
                outputs = outputsData;
                console.info("NiriService: Loaded", Object.keys(outputsData).length, "outputs");
                updateDisplayScales();
                if (windows.length > 0) {
                    windows = sortWindowsByLayout(windows);
                }
            } catch (e) {
                console.warn("NiriService: Failed to parse outputs:", e);
            }
        });
    }

    function updateDisplayScales() {
        if (!outputs || Object.keys(outputs).length === 0)
            return;
        const scales = {};
        for (const outputName in outputs) {
            const output = outputs[outputName];
            if (output.logical && output.logical.scale !== undefined) {
                scales[outputName] = output.logical.scale;
            }
        }

        displayScales = scales;
    }

    function sortWindowsByLayout(windowList) {
        const enriched = windowList.map(w => {
            const ws = workspaces[w.workspace_id];
            if (!ws) {
                return {
                    "window": w,
                    "outputX": 999999,
                    "outputY": 999999,
                    "wsIdx": 999999,
                    "col": 999999,
                    "row": 999999
                };
            }

            const outputInfo = outputs[ws.output];
            const outputX = (outputInfo && outputInfo.logical) ? outputInfo.logical.x : 999999;
            const outputY = (outputInfo && outputInfo.logical) ? outputInfo.logical.y : 999999;

            const pos = w.layout?.pos_in_scrolling_layout;
            const col = (pos && pos.length >= 2) ? pos[0] : 999999;
            const row = (pos && pos.length >= 2) ? pos[1] : 999999;

            return {
                "window": w,
                "outputX": outputX,
                "outputY": outputY,
                "wsIdx": ws.idx,
                "col": col,
                "row": row
            };
        });

        enriched.sort((a, b) => {
            if (a.outputX !== b.outputX)
                return a.outputX - b.outputX;
            if (a.outputY !== b.outputY)
                return a.outputY - b.outputY;
            if (a.wsIdx !== b.wsIdx)
                return a.wsIdx - b.wsIdx;
            if (a.col !== b.col)
                return a.col - b.col;
            if (a.row !== b.row)
                return a.row - b.row;
            return a.window.id - b.window.id;
        });

        return enriched.map(e => e.window);
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
        case 'WindowFocusChanged':
            handleWindowFocusChanged(event.WindowFocusChanged);
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
        case 'WorkspaceUrgencyChanged':
            handleWorkspaceUrgencyChanged(event.WorkspaceUrgencyChanged);
            break;
        case 'WindowUrgencyChanged':
            handleWindowUrgencyChanged(event.WindowUrgencyChanged);
            break;
        case 'ScreenshotCaptured':
            handleScreenshotCaptured(event.ScreenshotCaptured);
            break;
        }
    }

    function handleWorkspacesChanged(data) {
        const newWorkspaces = {};

        for (const ws of data.workspaces) {
            const oldWs = root.workspaces[ws.id];
            newWorkspaces[ws.id] = ws;
            if (oldWs && oldWs.active_window_id !== undefined) {
                newWorkspaces[ws.id].active_window_id = oldWs.active_window_id;
            }
        }

        setWorkspaces(newWorkspaces);

        focusedWorkspaceIndex = allWorkspaces.findIndex(w => w.is_focused);
        if (focusedWorkspaceIndex >= 0) {
            const focusedWs = allWorkspaces[focusedWorkspaceIndex];
            focusedWorkspaceId = focusedWs.id;
            currentOutput = focusedWs.output || "";
        } else {
            focusedWorkspaceIndex = 0;
            focusedWorkspaceId = "";
        }

        updateCurrentOutputWorkspaces();
    }

    function handleWorkspaceActivated(data) {
        const ws = root.workspaces[data.id];
        if (!ws) {
            return;
        }
        const output = ws.output;

        const updatedWorkspaces = {};

        for (const id in root.workspaces) {
            const workspace = root.workspaces[id];
            const got_activated = workspace.id === data.id;

            const updatedWs = {};
            for (let prop in workspace) {
                updatedWs[prop] = workspace[prop];
            }

            if (workspace.output === output) {
                updatedWs.is_active = got_activated;
            }

            if (data.focused) {
                updatedWs.is_focused = got_activated;
            }

            updatedWorkspaces[id] = updatedWs;
        }

        setWorkspaces(updatedWorkspaces);

        focusedWorkspaceId = data.id;
        focusedWorkspaceIndex = allWorkspaces.findIndex(w => w.id === data.id);

        if (focusedWorkspaceIndex >= 0) {
            currentOutput = allWorkspaces[focusedWorkspaceIndex].output || "";
        }

        updateCurrentOutputWorkspaces();
    }

    function handleWindowFocusChanged(data) {
        const focusedWindowId = data.id;

        let focusedWindow = null;
        const updatedWindows = [];

        for (var i = 0; i < windows.length; i++) {
            const w = windows[i];
            const updatedWindow = {};

            for (let prop in w) {
                updatedWindow[prop] = w[prop];
            }

            updatedWindow.is_focused = (w.id === focusedWindowId);
            if (updatedWindow.is_focused) {
                focusedWindow = updatedWindow;
            }

            updatedWindows.push(updatedWindow);
        }

        windows = updatedWindows;

        if (focusedWindow) {
            const ws = root.workspaces[focusedWindow.workspace_id];
            if (ws && ws.active_window_id !== focusedWindowId) {
                const updatedWs = {};
                for (let prop in ws) {
                    updatedWs[prop] = ws[prop];
                }
                updatedWs.active_window_id = focusedWindowId;

                const updatedWorkspaces = {};
                for (const id in root.workspaces) {
                    updatedWorkspaces[id] = id === focusedWindow.workspace_id ? updatedWs : root.workspaces[id];
                }
                setWorkspaces(updatedWorkspaces);
            }
        }
    }

    function handleWorkspaceActiveWindowChanged(data) {
        const ws = root.workspaces[data.workspace_id];
        if (ws) {
            const updatedWs = {};
            for (let prop in ws) {
                updatedWs[prop] = ws[prop];
            }
            updatedWs.active_window_id = data.active_window_id;

            const updatedWorkspaces = {};
            for (const id in root.workspaces) {
                updatedWorkspaces[id] = id === data.workspace_id ? updatedWs : root.workspaces[id];
            }
            setWorkspaces(updatedWorkspaces);
        }

        const updatedWindows = [];

        for (var i = 0; i < windows.length; i++) {
            const w = windows[i];
            const updatedWindow = {};

            for (let prop in w) {
                updatedWindow[prop] = w[prop];
            }

            if (data.active_window_id !== null && data.active_window_id !== undefined) {
                updatedWindow.is_focused = (w.id == data.active_window_id);
            } else {
                updatedWindow.is_focused = w.workspace_id == data.workspace_id ? false : w.is_focused;
            }

            updatedWindows.push(updatedWindow);
        }

        windows = updatedWindows;
    }

    function handleWindowsChanged(data) {
        windows = sortWindowsByLayout(data.windows);
    }

    function handleWindowClosed(data) {
        windows = windows.filter(w => w.id !== data.id);
    }

    function handleWindowOpenedOrChanged(data) {
        if (!data.window)
            return;
        const window = data.window;
        const existingIndex = windows.findIndex(w => w.id === window.id);

        if (existingIndex >= 0) {
            const updatedWindows = [...windows];
            updatedWindows[existingIndex] = window;
            windows = sortWindowsByLayout(updatedWindows);
        } else {
            windows = sortWindowsByLayout([...windows, window]);
        }
    }

    function handleWindowLayoutsChanged(data) {
        if (!data.changes)
            return;
        const updatedWindows = [...windows];
        let hasChanges = false;

        for (const change of data.changes) {
            const windowId = change[0];
            const layoutData = change[1];

            const windowIndex = updatedWindows.findIndex(w => w.id === windowId);
            if (windowIndex < 0)
                continue;
            const updatedWindow = {};
            for (var prop in updatedWindows[windowIndex]) {
                updatedWindow[prop] = updatedWindows[windowIndex][prop];
            }
            updatedWindow.layout = layoutData;
            updatedWindows[windowIndex] = updatedWindow;
            hasChanges = true;
        }

        if (!hasChanges)
            return;
        windows = sortWindowsByLayout(updatedWindows);
    }

    function handleOutputsChanged(data) {
        if (!data.outputs)
            return;
        outputs = data.outputs;
        updateDisplayScales();
        windows = sortWindowsByLayout(windows);
    }

    function handleOverviewChanged(data) {
        inOverview = data.is_open;
    }

    function handleConfigLoaded(data) {
        if (data.failed) {
            validateProcess.running = true;
            return;
        }

        configValidationOutput = "";
        ToastService.dismissCategory("niri-config");
        fetchOutputs();
        configReloaded();

        if (hasInitialConnection && !suppressConfigToast && !suppressNextConfigToast && !matugenSuppression) {
            ToastService.showInfo("niri: config reloaded", "", "", "niri-config");
        } else if (suppressNextConfigToast) {
            suppressNextConfigToast = false;
            suppressResetTimer.stop();
        }

        if (!hasInitialConnection) {
            hasInitialConnection = true;
            suppressToastTimer.start();
        }
    }

    function handleKeyboardLayoutsChanged(data) {
        keyboardLayoutNames = data.keyboard_layouts.names;
        currentKeyboardLayoutIndex = data.keyboard_layouts.current_idx;
    }

    function handleKeyboardLayoutSwitched(data) {
        currentKeyboardLayoutIndex = data.idx;
    }

    function handleWorkspaceUrgencyChanged(data) {
        const ws = root.workspaces[data.id];
        if (!ws)
            return;
        const updatedWs = {};
        for (let prop in ws) {
            updatedWs[prop] = ws[prop];
        }
        updatedWs.is_urgent = data.urgent;

        const updatedWorkspaces = {};
        for (const id in root.workspaces) {
            updatedWorkspaces[id] = id === data.id ? updatedWs : root.workspaces[id];
        }
        setWorkspaces(updatedWorkspaces);

        windowUrgentChanged();
    }

    function handleWindowUrgencyChanged(data) {
        const windowIndex = windows.findIndex(w => w.id === data.id);
        if (windowIndex < 0)
            return;
        const updatedWindows = [...windows];
        const updatedWindow = {};
        for (let prop in updatedWindows[windowIndex]) {
            updatedWindow[prop] = updatedWindows[windowIndex][prop];
        }
        updatedWindow.is_urgent = data.urgent;
        updatedWindows[windowIndex] = updatedWindow;
        windows = updatedWindows;

        windowUrgentChanged();
    }

    function handleScreenshotCaptured(data) {
        if (!data.path)
            return;
        if (pendingScreenshotPath && data.path === pendingScreenshotPath) {
            const editor = Quickshell.env("DMS_SCREENSHOT_EDITOR");
            const command = editor === "satty" ? ["satty", "-f", data.path] : ["swappy", "-f", data.path];
            Quickshell.execDetached({
                "command": command
            });
            pendingScreenshotPath = "";
        }
    }

    function updateCurrentOutputWorkspaces() {
        if (!currentOutput) {
            currentOutputWorkspaces = allWorkspaces;
            return;
        }

        const outputWs = allWorkspaces.filter(w => w.output === currentOutput);
        currentOutputWorkspaces = outputWs;
    }

    function send(request) {
        if (!CompositorService.isNiri || !requestSocket.connected)
            return false;
        requestSocket.send(request);
        return true;
    }

    function doScreenTransition() {
        return send({
            "Action": {
                "DoScreenTransition": {
                    "delay_ms": 0
                }
            }
        });
    }

    function toggleOverview() {
        return send({
            "Action": {
                "ToggleOverview": {}
            }
        });
    }

    function moveColumnLeft() {
        return send({
            "Action": {
                "FocusColumnLeft": {}
            }
        });
    }

    function moveColumnRight() {
        return send({
            "Action": {
                "FocusColumnRight": {}
            }
        });
    }

    function moveWorkspaceDown() {
        return send({
            "Action": {
                "FocusWorkspaceDown": {}
            }
        });
    }

    function moveWorkspaceUp() {
        return send({
            "Action": {
                "FocusWorkspaceUp": {}
            }
        });
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
        });
    }

    function focusWindow(windowId) {
        return send({
            "Action": {
                "FocusWindow": {
                    "id": windowId
                }
            }
        });
    }

    function powerOffMonitors() {
        return send({
            "Action": {
                "PowerOffMonitors": {}
            }
        });
    }

    function powerOnMonitors() {
        return send({
            "Action": {
                "PowerOnMonitors": {}
            }
        });
    }

    function cycleKeyboardLayout() {
        return send({
            "Action": {
                "SwitchLayout": {
                    "layout": "Next"
                }
            }
        });
    }

    function quit() {
        return send({
            "Action": {
                "Quit": {
                    "skip_confirmation": true
                }
            }
        });
    }

    function screenshot() {
        pendingScreenshotPath = "";
        const timestamp = Date.now();
        const path = `${screenshotsDir}/dms-screenshot-${timestamp}.png`;
        pendingScreenshotPath = path;

        return send({
            "Action": {
                "Screenshot": {
                    "show_pointer": true,
                    "path": path
                }
            }
        });
    }

    function screenshotScreen() {
        pendingScreenshotPath = "";
        const timestamp = Date.now();
        const path = `${screenshotsDir}/dms-screenshot-${timestamp}.png`;
        pendingScreenshotPath = path;

        return send({
            "Action": {
                "ScreenshotScreen": {
                    "write_to_disk": true,
                    "show_pointer": true,
                    "path": path
                }
            }
        });
    }

    function screenshotWindow() {
        pendingScreenshotPath = "";
        const timestamp = Date.now();
        const path = `${screenshotsDir}/dms-screenshot-${timestamp}.png`;
        pendingScreenshotPath = path;

        return send({
            "Action": {
                "ScreenshotWindow": {
                    "write_to_disk": true,
                    "show_pointer": true,
                    "path": path
                }
            }
        });
    }

    function getCurrentOutputWorkspaceNumbers() {
        return currentOutputWorkspaces.map(w => w.idx + 1);
    }

    function getCurrentWorkspaceNumber() {
        if (focusedWorkspaceIndex >= 0 && focusedWorkspaceIndex < allWorkspaces.length) {
            return allWorkspaces[focusedWorkspaceIndex].idx + 1;
        }
        return 1;
    }

    function getCurrentKeyboardLayoutName() {
        if (currentKeyboardLayoutIndex >= 0 && currentKeyboardLayoutIndex < keyboardLayoutNames.length) {
            return keyboardLayoutNames[currentKeyboardLayoutIndex];
        }
        return "";
    }

    function suppressNextToast() {
        matugenSuppression = true;
        suppressResetTimer.restart();
    }

    function findNiriWindow(toplevel) {
        if (!toplevel.appId)
            return null;

        for (var j = 0; j < windows.length; j++) {
            const niriWindow = windows[j];
            if (niriWindow.app_id === toplevel.appId) {
                if (!niriWindow.title || niriWindow.title === toplevel.title) {
                    return {
                        "niriIndex": j,
                        "niriWindow": niriWindow
                    };
                }
            }
        }
        return null;
    }

    function sortToplevels(toplevels) {
        if (!toplevels || toplevels.length === 0 || !CompositorService.isNiri || windows.length === 0) {
            return [...toplevels];
        }

        const usedToplevels = new Set();
        const enrichedToplevels = [];

        for (const niriWindow of sortWindowsByLayout(windows)) {
            let bestMatch = null;
            let bestScore = -1;

            for (const toplevel of toplevels) {
                if (usedToplevels.has(toplevel))
                    continue;
                if (toplevel.appId === niriWindow.app_id) {
                    let score = 1;

                    if (niriWindow.title && toplevel.title) {
                        if (toplevel.title === niriWindow.title) {
                            score = 3;
                        } else if (toplevel.title.includes(niriWindow.title) || niriWindow.title.includes(toplevel.title)) {
                            score = 2;
                        }
                    }

                    if (score > bestScore) {
                        bestScore = score;
                        bestMatch = toplevel;
                        if (score === 3)
                            break;
                    }
                }
            }

            if (!bestMatch)
                continue;
            usedToplevels.add(bestMatch);

            const workspace = workspaces[niriWindow.workspace_id];
            const isFocused = niriWindow.is_focused ?? (workspace && workspace.active_window_id === niriWindow.id) ?? false;

            const enrichedToplevel = {
                "appId": bestMatch.appId,
                "title": bestMatch.title,
                "activated": isFocused,
                "niriWindowId": niriWindow.id,
                "niriWorkspaceId": niriWindow.workspace_id,
                "activate": function () {
                    return NiriService.focusWindow(niriWindow.id);
                },
                "close": function () {
                    if (bestMatch.close) {
                        return bestMatch.close();
                    }
                    return false;
                }
            };

            for (let prop in bestMatch) {
                if (!(prop in enrichedToplevel)) {
                    enrichedToplevel[prop] = bestMatch[prop];
                }
            }

            enrichedToplevels.push(enrichedToplevel);
        }

        for (const toplevel of toplevels) {
            if (!usedToplevels.has(toplevel)) {
                enrichedToplevels.push(toplevel);
            }
        }

        return enrichedToplevels;
    }

    function filterCurrentWorkspace(toplevels, screenName) {
        let currentWorkspaceId = null;

        for (var i = 0; i < allWorkspaces.length; i++) {
            const ws = allWorkspaces[i];
            if (ws.output === screenName && ws.is_active) {
                currentWorkspaceId = ws.id;
                break;
            }
        }

        if (currentWorkspaceId === null)
            return toplevels;

        const workspaceWindows = windows.filter(niriWindow => niriWindow.workspace_id === currentWorkspaceId);
        const usedToplevels = new Set();
        const result = [];

        for (const niriWindow of workspaceWindows) {
            let bestMatch = null;
            let bestScore = -1;

            for (const toplevel of toplevels) {
                if (usedToplevels.has(toplevel))
                    continue;
                if (toplevel.appId === niriWindow.app_id) {
                    let score = 1;

                    if (niriWindow.title && toplevel.title) {
                        if (toplevel.title === niriWindow.title) {
                            score = 3;
                        } else if (toplevel.title.includes(niriWindow.title) || niriWindow.title.includes(toplevel.title)) {
                            score = 2;
                        }
                    }

                    if (score > bestScore) {
                        bestScore = score;
                        bestMatch = toplevel;
                        if (score === 3)
                            break;
                    }
                }
            }

            if (!bestMatch)
                continue;
            usedToplevels.add(bestMatch);

            const workspace = workspaces[niriWindow.workspace_id];
            const isFocused = niriWindow.is_focused ?? (workspace && workspace.active_window_id === niriWindow.id) ?? false;

            const enrichedToplevel = {
                "appId": bestMatch.appId,
                "title": bestMatch.title,
                "activated": isFocused,
                "niriWindowId": niriWindow.id,
                "niriWorkspaceId": niriWindow.workspace_id,
                "activate": function () {
                    return NiriService.focusWindow(niriWindow.id);
                },
                "close": function () {
                    if (bestMatch.close) {
                        return bestMatch.close();
                    }
                    return false;
                }
            };

            for (let prop in bestMatch) {
                if (!(prop in enrichedToplevel)) {
                    enrichedToplevel[prop] = bestMatch[prop];
                }
            }

            result.push(enrichedToplevel);
        }

        return result;
    }

    function generateNiriLayoutConfig() {
        if (!CompositorService.isNiri || configGenerationPending)
            return;
        suppressNextToast();
        configGenerationPending = true;
        configGenerationDebounce.restart();
    }

    function doGenerateNiriLayoutConfig() {
        console.log("NiriService: Generating layout config...");

        const defaultRadius = typeof SettingsData !== "undefined" ? SettingsData.cornerRadius : 12;
        const defaultGaps = typeof SettingsData !== "undefined" ? Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4)) : 4;

        const cornerRadius = (typeof SettingsData !== "undefined" && SettingsData.niriLayoutRadiusOverride >= 0) ? SettingsData.niriLayoutRadiusOverride : defaultRadius;
        const gaps = (typeof SettingsData !== "undefined" && SettingsData.niriLayoutGapsOverride >= 0) ? SettingsData.niriLayoutGapsOverride : defaultGaps;

        const dmsWarning = `// ! DO NOT EDIT !
        // ! AUTO-GENERATED BY DMS !
        // ! CHANGES WILL BE OVERWRITTEN !
        // ! PLACE YOUR CUSTOM CONFIGURATION ELSEWHERE !

        `;

        const configContent = dmsWarning + `layout {
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
        }`;

        const alttabContent = dmsWarning + `recent-windows {
        highlight {
        corner-radius ${cornerRadius}
        }
        }`;

        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        const niriDmsDir = configDir + "/niri/dms";
        const configPath = niriDmsDir + "/layout.kdl";
        const alttabPath = niriDmsDir + "/alttab.kdl";

        writeConfigProcess.configContent = configContent;
        writeConfigProcess.configPath = configPath;
        writeConfigProcess.command = ["sh", "-c", `mkdir -p "${niriDmsDir}" && cat > "${configPath}" << 'EOF'\n${configContent}\nEOF`];
        writeConfigProcess.running = true;

        writeAlttabProcess.alttabContent = alttabContent;
        writeAlttabProcess.alttabPath = alttabPath;
        writeAlttabProcess.command = ["sh", "-c", `mkdir -p "${niriDmsDir}" && cat > "${alttabPath}" << 'EOF'\n${alttabContent}\nEOF`];
        writeAlttabProcess.running = true;

        configGenerationPending = false;
    }

    function generateNiriBlurrule() {
        console.log("NiriService: Generating wpblur config...");

        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        const niriDmsDir = configDir + "/niri/dms";
        const blurrulePath = niriDmsDir + "/wpblur.kdl";
        const sourceBlurrulePath = Paths.strip(Qt.resolvedUrl("niri-wpblur.kdl"));

        writeBlurruleProcess.blurrulePath = blurrulePath;
        writeBlurruleProcess.command = ["sh", "-c", `mkdir -p "${niriDmsDir}" && cp --no-preserve=mode "${sourceBlurrulePath}" "${blurrulePath}"`];
        writeBlurruleProcess.running = true;
    }

    function updateOutputPosition(outputName, x, y) {
        if (!outputs || !outputs[outputName])
            return;
        const updatedOutputs = {};
        for (const name in outputs) {
            const output = outputs[name];
            if (name === outputName && output.logical) {
                updatedOutputs[name] = JSON.parse(JSON.stringify(output));
                updatedOutputs[name].logical.x = x;
                updatedOutputs[name].logical.y = y;
            } else {
                updatedOutputs[name] = output;
            }
        }
        outputs = updatedOutputs;
    }

    function applyOutputConfig(outputName, config, callback) {
        if (!CompositorService.isNiri || !outputName) {
            if (callback)
                callback(false, "Invalid config");
            return;
        }

        const commands = [];

        if (config.position !== undefined) {
            commands.push(`niri msg output "${outputName}" position ${config.position.x} ${config.position.y}`);
        }

        if (config.mode !== undefined) {
            commands.push(`niri msg output "${outputName}" mode ${config.mode}`);
        }

        if (config.vrr !== undefined) {
            commands.push(`niri msg output "${outputName}" vrr ${config.vrr ? "on" : "off"}`);
        }

        if (config.scale !== undefined) {
            commands.push(`niri msg output "${outputName}" scale ${config.scale}`);
        }

        if (config.transform !== undefined) {
            commands.push(`niri msg output "${outputName}" transform "${config.transform}"`);
        }

        if (commands.length === 0) {
            if (callback)
                callback(true, "No changes");
            return;
        }

        const fullCommand = commands.join(" && ");
        Proc.runCommand("niri-output-config", ["sh", "-c", fullCommand], (output, exitCode) => {
            if (exitCode !== 0) {
                console.warn("NiriService: Failed to apply output config:", output);
                if (callback)
                    callback(false, output);
                return;
            }
            console.info("NiriService: Applied output config for", outputName);
            fetchOutputs();
            if (callback)
                callback(true, "Success");
        });
    }

    function getOutputIdentifier(output, outputName) {
        if (SettingsData.displayNameMode === "model" && output.make && output.model) {
            const serial = output.serial || "Unknown";
            return output.make + " " + output.model + " " + serial;
        }
        return outputName;
    }

    function generateOutputsConfig(outputsData) {
        const data = outputsData || outputs;
        if (!data || Object.keys(data).length === 0)
            return;
        let kdlContent = `// Auto-generated by DMS - do not edit manually\n\n`;

        for (const outputName in data) {
            const output = data[outputName];
            const identifier = getOutputIdentifier(output, outputName);
            const niriSettings = SettingsData.getNiriOutputSettings(identifier);

            kdlContent += `output "${identifier}" {\n`;

            if (niriSettings.disabled) {
                kdlContent += `    off\n}\n\n`;
                continue;
            }

            if (output.current_mode !== undefined && output.modes && output.modes[output.current_mode]) {
                const mode = output.modes[output.current_mode];
                kdlContent += `    mode "${mode.width}x${mode.height}@${(mode.refresh_rate / 1000).toFixed(3)}"\n`;
            }

            if (output.logical) {
                kdlContent += `    scale ${output.logical.scale ?? 1.0}\n`;

                if (output.logical.transform && output.logical.transform !== "Normal") {
                    const transformMap = {
                        "Normal": "normal",
                        "90": "90",
                        "180": "180",
                        "270": "270",
                        "Flipped": "flipped",
                        "Flipped90": "flipped-90",
                        "Flipped180": "flipped-180",
                        "Flipped270": "flipped-270"
                    };
                    kdlContent += `    transform "${transformMap[output.logical.transform] || "normal"}"\n`;
                }

                if (output.logical.x !== undefined && output.logical.y !== undefined) {
                    kdlContent += `    position x=${output.logical.x} y=${output.logical.y}\n`;
                }
            }

            if (output.vrr_enabled) {
                const vrrOnDemand = niriSettings.vrrOnDemand ?? false;
                kdlContent += vrrOnDemand ? `    variable-refresh-rate on-demand=true\n` : `    variable-refresh-rate\n`;
            }

            if (niriSettings.focusAtStartup) {
                kdlContent += `    focus-at-startup\n`;
            }

            if (niriSettings.backdropColor) {
                kdlContent += `    backdrop-color "${niriSettings.backdropColor}"\n`;
            }

            kdlContent += generateHotCornersBlock(niriSettings);
            kdlContent += generateLayoutBlock(niriSettings);

            kdlContent += `}\n\n`;
        }

        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        const niriDmsDir = configDir + "/niri/dms";
        const outputsPath = niriDmsDir + "/outputs.kdl";

        Proc.runCommand("niri-write-outputs", ["sh", "-c", `mkdir -p "${niriDmsDir}" && cat > "${outputsPath}" << 'EOF'\n${kdlContent}EOF`], (output, exitCode) => {
            if (exitCode !== 0) {
                console.warn("NiriService: Failed to write outputs config:", output);
                return;
            }
            console.info("NiriService: Generated outputs config at", outputsPath);
        });
    }

    function generateHotCornersBlock(niriSettings) {
        if (!niriSettings.hotCorners)
            return "";
        const hc = niriSettings.hotCorners;
        if (hc.off)
            return `    hot-corners {\n        off\n    }\n`;
        const corners = hc.corners || [];
        if (corners.length === 0)
            return "";
        let block = `    hot-corners {\n`;
        for (const corner of corners) {
            block += `        ${corner}\n`;
        }
        block += `    }\n`;
        return block;
    }

    function generateLayoutBlock(niriSettings) {
        if (!niriSettings.layout)
            return "";
        const layout = niriSettings.layout;
        const hasSettings = layout.gaps !== undefined || layout.defaultColumnWidth || layout.presetColumnWidths || layout.alwaysCenterSingleColumn !== undefined;
        if (!hasSettings)
            return "";
        let block = `    layout {\n`;
        if (layout.gaps !== undefined)
            block += `        gaps ${layout.gaps}\n`;
        if (layout.defaultColumnWidth?.type === "proportion") {
            const val = layout.defaultColumnWidth.value;
            const formatted = Number.isInteger(val) ? val.toFixed(1) : val.toString();
            block += `        default-column-width { proportion ${formatted}; }\n`;
        }
        if (layout.presetColumnWidths && layout.presetColumnWidths.length > 0) {
            block += `        preset-column-widths {\n`;
            for (const preset of layout.presetColumnWidths) {
                if (preset.type === "proportion") {
                    const val = preset.value;
                    const formatted = Number.isInteger(val) ? val.toFixed(1) : val.toString();
                    block += `            proportion ${formatted}\n`;
                }
            }
            block += `        }\n`;
        }
        if (layout.alwaysCenterSingleColumn !== undefined)
            block += layout.alwaysCenterSingleColumn ? `        always-center-single-column\n` : `        always-center-single-column false\n`;
        block += `    }\n`;
        return block;
    }

    IpcHandler {
        function screenshot(): string {
            if (!CompositorService.isNiri) {
                return "NIRI_NOT_AVAILABLE";
            }
            if (NiriService.screenshot()) {
                return "SCREENSHOT_SUCCESS";
            }
            return "SCREENSHOT_FAILED";
        }

        function screenshotScreen(): string {
            if (!CompositorService.isNiri) {
                return "NIRI_NOT_AVAILABLE";
            }
            if (NiriService.screenshotScreen()) {
                return "SCREENSHOT_SCREEN_SUCCESS";
            }
            return "SCREENSHOT_SCREEN_FAILED";
        }

        function screenshotWindow(): string {
            if (!CompositorService.isNiri) {
                return "NIRI_NOT_AVAILABLE";
            }
            if (NiriService.screenshotWindow()) {
                return "SCREENSHOT_WINDOW_SUCCESS";
            }
            return "SCREENSHOT_WINDOW_FAILED";
        }

        target: "niri"
    }
}
