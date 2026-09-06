pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("AqueousService")
    property var state: ({})
    property string seatName: ""
    readonly property bool enabled: CompositorService.isAqueous
    readonly property bool available: enabled && state.available === true
    property var discoveredCapabilities: ({})
    property var watchProcess: null
    property var pendingProcesses: []
    property int lifecycle: 0
    property bool discovering: false
    property bool commandPending: false
    property int retryDelay: 500
    readonly property int maxBatchBytes: 4 * 1024 * 1024
    readonly property var capabilities: discoveredCapabilities
    readonly property string session: available ? state.batch.session : ""
    readonly property string sequence: available ? state.batch.sequence : ""
    readonly property var entities: available ? state.batch.upsert : []
    readonly property var outputs: entities.filter(e => e.kind === "output")
    readonly property var workspaces: entities.filter(e => e.kind === "workspace").map(w => Object.assign({}, w, {
            aqueousSession: session
        }))
    readonly property var windows: entities.filter(e => e.kind === "window")
    readonly property var seats: entities.filter(e => e.kind === "seat")
    readonly property var sessionState: entities.find(e => e.kind === "session") || ({})
    readonly property bool locked: sessionState.locked === true
    readonly property var seat: seatName ? seats.find(s => s.id === seatName) : (seats.length === 1 ? seats[0] : null)
    readonly property var keyboard: entities.find(e => e.kind === "keyboard" && e.id === seat?.keyboard)
    readonly property var keyboardLayouts: keyboard?.layouts || []
    readonly property string keyboardLayout: keyboardLayouts[keyboard?.index] || ""
    readonly property string focusedOutput: outputs.find(o => o.id === seat?.output)?.name || ""
    readonly property bool inOverview: !!sessionState.overview_output
    readonly property var focusedWindow: {
        const window = windows.find(w => w.id === seat?.window);
        return window ? windowFacade(window) : null;
    }
    readonly property var toplevels: windows.filter(w => taskbarEligible(w)).map(w => windowFacade(w))

    function taskbarEligible(window) {
        return !window.skip_taskbar && (window.visible || window.minimized || !workspaces.find(ws => ws.id === window.workspace)?.active);
    }

    function outputId(name) {
        return outputs.find(o => o.name === name)?.id || "";
    }

    function workspacesForOutput(name) {
        const id = outputId(name || focusedOutput);
        return workspaces.filter(w => w.output === id).sort((a, b) => a.number - b.number);
    }

    function byteLength(text) {
        return encodeURIComponent(text).replace(/%[0-9A-F]{2}/g, "x").length;
    }

    function parseJson(text) {
        if (byteLength(text) > maxBatchBytes + (text.endsWith("\n") ? 1 : 0))
            throw new Error("JSON exceeds 4 MiB");
        return JSON.parse(text);
    }

    function validateCapabilities(value) {
        if (!value || value.schema !== 1 || typeof value.session !== "string" || !/^[0-9a-f]{32}$/.test(value.session) || !Number.isInteger(value.max_batch_bytes) || value.max_batch_bytes <= 0 || value.max_batch_bytes > maxBatchBytes)
            throw new Error("unsupported: Aqueous shell capabilities");
        for (const name of ["state", "commands", "keyboard", "overview", "shortcut_inhibition"]) {
            if (typeof value[name] !== "boolean")
                throw new Error("unsupported: missing capability " + name);
        }
        if (!value.state)
            throw new Error("unsupported: shell state");
        return value;
    }

    function validateEntity(entity) {
        const fields = {
            output: "id:s name:s bounds:r usable_bounds:r scale:n transform:s active_workspace:? enabled:b powered:b",
            workspace: "id:s output:s name:s number:i active:b urgent:b",
            window: "id:s backend:s app_id:? class:? title:? workspace:? output:? geometry:r outer_geometry:r layout:s focused:b visible:b floating:b minimized:b maximized:b fullscreen:b skip_taskbar:b skip_switcher:b always_above:b always_below:b snapped:b fixed_position:b can_minimize:b can_maximize:b can_activate:b",
            seat: "id:s output:? window:? focus_kind:s keyboard:?",
            keyboard: "id:s seat:s layouts:a index:i",
            keyboard_device: "id:s name:? seat:s group:? virtual:b",
            session: "id:s locked:b default_seat:? overview_output:? overview_window:?"
        };
        if (!entity || !Object.prototype.hasOwnProperty.call(fields, entity.kind) || typeof entity.id !== "string" || !entity.id)
            throw new Error("invalid entity kind or ID");
        for (const field of fields[entity.kind].split(" ")) {
            const [name, type] = field.split(":");
            const value = entity[name];
            let valid = false;
            switch (type) {
            case "s":
                valid = typeof value === "string";
                break;
            case "?":
                valid = value === null || typeof value === "string";
                break;
            case "b":
                valid = typeof value === "boolean";
                break;
            case "i":
                valid = Number.isSafeInteger(value);
                break;
            case "n":
                valid = typeof value === "number" && Number.isFinite(value);
                break;
            case "a":
                valid = Array.isArray(value) && value.every(v => typeof v === "string");
                break;
            case "r":
                valid = value && ["x", "y", "width", "height"].every(k => Number.isSafeInteger(value[k]));
                break;
            }
            if (!valid)
                throw new Error("invalid " + entity.kind + "." + name);
        }
        if ((entity.kind === "session" && entity.id !== "session") || (entity.kind === "workspace" && entity.number < 1) || (entity.kind === "output" && entity.scale <= 0) || (entity.kind === "keyboard" && (entity.index < 0 || (entity.layouts.length && entity.index >= entity.layouts.length))) || (entity.kind === "window" && !["xdg", "xwayland"].includes(entity.backend)) || (entity.kind === "seat" && !["window", "shell_surface", "layer_surface", "override_redirect", "lock_surface", "none"].includes(entity.focus_kind)))
            throw new Error("invalid " + entity.kind);
    }

    function reduceBatch(previous, batch) {
        if (!batch || batch.schema !== 1 || typeof batch.session !== "string" || !/^[0-9a-f]{32}$/.test(batch.session) || typeof batch.sequence !== "string" || !/^[0-9]+$/.test(batch.sequence) || !Array.isArray(batch.upsert) || !Array.isArray(batch.removed))
            throw new Error("invalid shell batch envelope");
        if (batch.type !== "snapshot" && batch.type !== "delta")
            throw new Error("invalid shell batch type");
        if (batch.type === "snapshot" && (batch.base_sequence !== null || batch.removed.length))
            throw new Error("invalid snapshot baseline");
        if (batch.type === "delta" && (!previous || batch.session !== previous.session || batch.base_sequence !== previous.sequence || batch.sequence === previous.sequence))
            throw new Error("shell delta continuity mismatch");
        const model = Object.assign({}, batch.type === "delta" ? previous.model : {});
        const entityBytes = Object.assign({}, batch.type === "delta" ? previous.entityBytes : {});
        let modelBytes = batch.type === "delta" ? previous.modelBytes : 1;
        const seen = new Set();
        for (const entity of batch.upsert) {
            validateEntity(entity);
            const key = entity.kind + ":" + entity.id;
            if (seen.has(key))
                throw new Error("duplicate entity key");
            seen.add(key);
            // Include the separator; the required session makes the model nonempty.
            const size = byteLength(JSON.stringify(key) + ":" + JSON.stringify(entity)) + 1;
            modelBytes += size - (entityBytes[key] || 0);
            entityBytes[key] = size;
            model[key] = entity;
        }
        for (const key of batch.removed) {
            if (typeof key !== "string" || !/^(output|workspace|window|seat|keyboard|keyboard_device|session):.+$/.test(key) || seen.has(key))
                throw new Error("invalid or duplicate removal");
            seen.add(key);
            modelBytes -= entityBytes[key] || 0;
            delete entityBytes[key];
            delete model[key];
        }
        if (!model["session:session"])
            throw new Error("missing session entity");
        const references = {
            output: {
                active_workspace: "workspace"
            },
            workspace: {
                output: "output"
            },
            window: {
                output: "output",
                workspace: "workspace"
            },
            seat: {
                output: "output",
                window: "window",
                keyboard: "keyboard"
            },
            keyboard: {
                seat: "seat"
            },
            keyboard_device: {
                seat: "seat",
                group: "keyboard"
            },
            session: {
                default_seat: "seat",
                overview_output: "output",
                overview_window: "window"
            }
        };
        for (const entity of Object.values(model)) {
            for (const [field, kind] of Object.entries(references[entity.kind])) {
                if (entity[field] !== null && !model[kind + ":" + entity[field]])
                    throw new Error("dangling " + entity.kind + "." + field);
            }
        }
        if (modelBytes > maxBatchBytes)
            throw new Error("shell model exceeds size bound");
        return {
            session: batch.session,
            sequence: batch.sequence,
            model: model,
            entityBytes: entityBytes,
            modelBytes: modelBytes,
            upsert: Object.values(model)
        };
    }

    function acceptLine(line) {
        if (byteLength(line) > capabilities.max_batch_bytes)
            throw new Error("shell batch exceeds advertised limit");
        const batch = parseJson(line);
        if (batch.session !== capabilities.session)
            throw new Error("shell session changed after discovery");
        const next = reduceBatch(state.available ? state.batch : null, batch);
        state = {
            available: true,
            batch: next
        };
    }

    function commandArguments(action, fields) {
        const request = Object.assign({
            session: session,
            seat: seat?.id || ""
        }, fields || {});
        if (!available || request.session !== session)
            throw new Error("unavailable: stale session");
        if (locked)
            throw new Error("locked");
        const [kind, operation] = action.split(".");
        const capability = kind === "keyboard" ? "keyboard" : kind === "overview" ? "overview" : "commands";
        if (!capabilities[capability])
            throw new Error("unsupported: " + capability);
        for (const key of ["id", "seat", "group", "output", "workspace", "name"]) {
            if (request[key] !== undefined && (typeof request[key] !== "string" || byteLength(request[key]) > 1024))
                throw new Error("invalid: command string");
        }
        const target = entities.find(e => e.kind === kind && e.id === request.id);
        if ((kind === "window" || kind === "workspace") && !target)
            throw new Error("not_found");
        const selectedSeat = request.seat ? seats.find(s => s.id === request.seat) : (seats.length === 1 ? seats[0] : null);
        const output = outputs.find(o => o.id === request.output);
        let args;
        switch (action) {
        case "window.activate":
        case "workspace.activate":
            if (!selectedSeat)
                throw new Error(request.seat ? "not_found: seat" : "ambiguous_seat");
            if (kind === "window" && !target.can_activate)
                throw new Error("unavailable: window activation");
            args = [kind, operation, "--id", target.id, "--seat", selectedSeat.id];
            break;
        case "window.close":
            args = ["window", "close", "--id", target.id];
            break;
        case "window.minimized":
        case "window.maximized":
        case "window.fullscreen":
            if (typeof request.value !== "boolean")
                throw new Error("invalid: missing state");
            if (operation !== "fullscreen" && !target["can_" + operation.slice(0, -1)])
                throw new Error("unavailable: window state");
            args = ["window", "state", "--id", target.id, "--" + operation, String(request.value)];
            break;
        case "window.move":
            if (!!request.workspace === !!request.output)
                throw new Error("invalid: move destination");
            if (request.workspace && !workspaces.some(w => w.id === request.workspace))
                throw new Error("not_found: workspace");
            if (request.output && !output)
                throw new Error("not_found: output");
            args = ["window", "move", "--id", target.id, request.workspace ? "--workspace-id" : "--output", request.workspace || output.name];
            break;
        case "workspace.rename":
            if (typeof request.name !== "string" || /[\r\n]/.test(request.name))
                throw new Error("invalid: workspace name");
            args = ["workspace", "rename", "--id", target.id, "--name", request.name];
            break;
        case "keyboard.set":
        case "keyboard.next":
            {
                if (!selectedSeat)
                    throw new Error(request.seat ? "not_found: seat" : "ambiguous_seat");
                const group = entities.find(e => e.kind === "keyboard" && e.id === (request.group || selectedSeat.keyboard) && e.seat === selectedSeat.id);
                if (!group)
                    throw new Error("not_found: keyboard group");
                args = ["keyboard", operation, "--seat", selectedSeat.id, "--group", group.id];
                if (operation === "set") {
                    if (!Number.isInteger(request.index) || request.index < 0 || request.index >= group.layouts.length)
                        throw new Error("invalid: keyboard index");
                    args.push("--index", String(request.index));
                }
                break;
            }
        case "overview.show":
        case "overview.toggle":
        case "overview.hide":
            args = ["overview", operation];
            if (operation !== "hide") {
                if (!output)
                    throw new Error("not_found: output");
                args.push("--output", output.name);
            }
            break;
        case "session.exit":
            args = ["session", "exit"];
            break;
        default:
            throw new Error("unsupported: action");
        }
        return ["aqueousctl"].concat(args, ["--json"]);
    }

    function commandResult(action, result, error) {
        if (error)
            return error;
        const status = action === "window.close" || action === "session.exit" ? "accepted" : "applied";
        if (result?.ok !== true || result.status !== status || typeof result.sequence !== "string" || !/^[0-9]+$/.test(result.sequence))
            return result?.status || "missing command acknowledgement";
        return "";
    }

    function reportCommand(action, result, error, callback) {
        const failure = commandResult(action, result, error);
        if (failure) {
            log.warn("command failed:", action, failure);
            ToastService.showError(I18n.tr("Error"), failure);
        }
        if (callback)
            callback(!failure, failure || result.status);
    }

    function command(action, fields, callback) {
        let args;
        try {
            if (commandPending)
                throw new Error("busy");
            args = commandArguments(action, fields);
        } catch (e) {
            reportCommand(action, null, String(e), callback);
            return;
        }
        commandPending = true;
        runJson(args, null, (result, error) => {
            commandPending = false;
            reportCommand(action, result, error, callback);
        });
    }

    function runJson(args, input, callback) {
        if (!enabled) {
            callback(null, "unavailable");
            return;
        }
        if (input !== null && byteLength(input) > maxBatchBytes) {
            callback(null, "request exceeds 4 MiB");
            return;
        }
        const process = jsonProcessComponent.createObject(root, {
            command: args,
            input: input,
            callback: callback
        });
        pendingProcesses = pendingProcesses.concat([process]);
        process.running = true;
        process.deadline.start();
    }

    function startWatching() {
        if (!enabled || discovering || watchProcess)
            return;
        discovering = true;
        const attempt = lifecycle;
        runJson(["aqueousctl", "shell", "capabilities", "--json"], null, (result, error) => {
            if (attempt !== lifecycle)
                return;
            discovering = false;
            try {
                if (error)
                    throw new Error(error);
                discoveredCapabilities = validateCapabilities(result);
                watchProcess = watchComponent.createObject(root);
                watchProcess.running = true;
                watchProcess.deadline.start();
            } catch (e) {
                disconnected(String(e));
            }
        });
    }

    function disconnected(error) {
        state = {
            error: error
        };
        if (!enabled || retryTimer.running)
            return;
        retryTimer.interval = Math.floor(retryDelay * (0.8 + Math.random() * 0.2));
        retryDelay = Math.min(retryDelay * 2, 30000);
        retryTimer.start();
    }

    function stopWatching() {
        lifecycle++;
        retryTimer.stop();
        state = ({});
        discoveredCapabilities = ({});
        discovering = false;
        if (watchProcess)
            watchProcess.finish("unavailable");
        for (const process of pendingProcesses.slice())
            process.finish(null, "unavailable: backend changed or shell stopped");
        retryTimer.stop();
        commandPending = false;
        retryDelay = 500;
    }

    onEnabledChanged: {
        stopWatching();
        if (enabled)
            startWatching();
    }
    Component.onCompleted: startWatching()
    Component.onDestruction: stopWatching()

    function windowFacade(window) {
        const windowSession = session;
        const output = outputs.find(o => o.id === window.output);
        return {
            id: window.id,
            aqueousWindowId: window.id,
            aqueousKey: windowSession + ":window:" + window.id,
            aqueousSession: windowSession,
            aqueousWorkspaceId: window.workspace,
            aqueousOutputId: window.output,
            appId: window.app_id || window.class || "",
            title: window.title || "",
            activated: root.seat?.window === window.id,
            get fullscreen() {
                return window.fullscreen;
            },
            set fullscreen(value) {
                root.command("window.fullscreen", {
                    id: window.id,
                    session: windowSession,
                    value: value
                });
            },
            get maximized() {
                return window.maximized;
            },
            set maximized(value) {
                root.command("window.maximized", {
                    id: window.id,
                    session: windowSession,
                    value: value
                });
            },
            visible: window.visible,
            skipSwitcher: window.skip_switcher,
            canMinimize: window.can_minimize,
            canMaximize: window.can_maximize,
            canActivate: window.can_activate,
            screens: Quickshell.screens.filter(s => s.name === output?.name),
            get minimized() {
                return window.minimized;
            },
            set minimized(value) {
                root.command("window.minimized", {
                    id: window.id,
                    session: windowSession,
                    value: value
                });
            },
            activate: function () {
                root.command("window.activate", {
                    id: window.id,
                    session: windowSession
                });
            },
            close: function () {
                root.command("window.close", {
                    id: window.id,
                    session: windowSession
                });
            }
        };
    }

    function activateWorkspace(workspace) {
        if (!seat || !workspace)
            return;
        command("workspace.activate", {
            id: workspace.id,
            session: workspace.aqueousSession
        });
    }

    function cycleKeyboardLayout() {
        if (!seat || !keyboard || !capabilities.keyboard)
            return;
        command("keyboard.next", {
            group: keyboard.id
        });
    }

    function toggleOverview(screenName) {
        if (!capabilities.overview)
            return;
        command("overview.toggle", {
            output: outputId(screenName || focusedOutput)
        });
    }

    function quit() {
        command("session.exit");
    }

    IpcHandler {
        target: "aqueous"
        function status(): string {
            return JSON.stringify({
                available: root.available,
                session: root.session,
                sequence: root.sequence,
                focusedOutput: root.focusedOutput,
                outputs: root.outputs.length,
                windows: root.windows.length,
                workspaces: root.workspaces.length,
                keyboardLayout: root.keyboardLayout,
                overviewOutput: root.sessionState.overview_output || null,
                overviewWindow: root.sessionState.overview_window || null,
                error: root.state.error || ""
            });
        }
        function overview(action: string, output: string): string {
            if (!["show", "hide", "toggle"].includes(action))
                return "INVALID_ACTION";
            if (!root.available || root.locked || !root.capabilities.overview)
                return "UNAVAILABLE";
            root.command("overview." + action, {
                output: root.outputId(output || root.focusedOutput)
            });
            return "OVERVIEW_REQUESTED";
        }
        function selectSeat(name: string): string {
            if (name && !root.seats.some(s => s.id === name))
                return "SEAT_NOT_FOUND";
            root.seatName = name;
            return "SEAT_SELECTED";
        }
    }

    function overlapsDock(screenName, position, thickness, width, height) {
        const output = outputs.find(o => o.name === screenName);
        if (!output)
            return false;
        return windows.some(w => {
            if (w.output !== output.id || !w.visible || w.minimized)
                return false;
            const box = w.outer_geometry;
            const x = box.x - output.bounds.x;
            const y = box.y - output.bounds.y;
            if (position === SettingsData.Position.Top)
                return y < thickness && y + box.height > 0;
            if (position === SettingsData.Position.Left)
                return x < thickness && x + box.width > 0;
            if (position === SettingsData.Position.Right)
                return x < width && x + box.width > width - thickness;
            return y < height && y + box.height > height - thickness;
        });
    }

    Timer {
        id: retryTimer
        onTriggered: root.startWatching()
    }

    Component {
        id: watchComponent
        Process {
            id: watcher
            command: ["aqueousctl", "shell", "watch", "--json"]
            property bool finished: false
            property double establishedAt: 0
            property Timer deadline: Timer {
                id: initialDeadline
                interval: 8000
                onTriggered: watcher.finish("shell initial snapshot timed out")
            }

            function finish(error) {
                if (finished)
                    return;
                finished = true;
                initialDeadline.stop();
                if (running)
                    signal(9);
                if (root.watchProcess === watcher) {
                    root.watchProcess = null;
                    if (establishedAt && Date.now() - establishedAt >= 60000)
                        root.retryDelay = 500;
                    root.disconnected(error);
                }
                Qt.callLater(() => watcher.destroy());
            }

            stdout: SplitParser {
                onRead: line => {
                    if (watcher.finished)
                        return;
                    try {
                        root.acceptLine(line);
                        initialDeadline.stop();
                        if (!watcher.establishedAt)
                            watcher.establishedAt = Date.now();
                    } catch (e) {
                        watcher.finish(String(e));
                    }
                }
            }
            // Drain diagnostics without retaining an unbounded history.
            stderr: SplitParser {
                splitMarker: ""
            }
            onExited: code => finish("shell stream disconnected (" + code + ")")
            onRunningChanged: {
                if (!running)
                    Qt.callLater(() => {
                        if (!watcher.finished)
                            watcher.finish("aqueousctl could not start");
                    });
            }
        }
    }

    Component {
        id: jsonProcessComponent
        Process {
            id: jsonProcess
            property var input: null
            property var callback: null
            property bool finished: false
            property Timer deadline: Timer {
                id: jsonDeadline
                interval: 8000
                onTriggered: jsonProcess.finish(null, "command completion uncertain: timeout")
            }
            stdinEnabled: input !== null

            function finish(result, error) {
                if (finished)
                    return;
                finished = true;
                jsonDeadline.stop();
                if (running)
                    signal(9);
                root.pendingProcesses = root.pendingProcesses.filter(p => p !== jsonProcess);
                const complete = callback;
                callback = null;
                if (complete)
                    complete(result, error);
                Qt.callLater(() => jsonProcess.destroy());
            }

            onStarted: {
                if (input !== null) {
                    write(input);
                    stdinEnabled = false;
                }
            }
            stdout: StdioCollector {
                waitForEnd: false
                onDataChanged: {
                    if (data.byteLength > root.maxBatchBytes + 1)
                        jsonProcess.finish(null, "process output exceeds 4 MiB");
                }
            }
            stderr: SplitParser {
                splitMarker: ""
            }
            onExited: (code, status) => {
                if (finished)
                    return;
                let result = null;
                let error = "";
                try {
                    result = root.parseJson(stdout.text);
                    if (code !== 0 || status !== 0)
                        error = result?.code ? result.code + ": " + (result.message || "") : (result?.status || "command failed (" + code + ")");
                } catch (e) {
                    error = String(e);
                }
                finish(result, error);
            }
            onRunningChanged: {
                if (!running)
                    Qt.callLater(() => {
                        if (!jsonProcess.finished)
                            jsonProcess.finish(null, "command could not start");
                    });
            }
        }
    }
}
