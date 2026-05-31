pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

// Native MangoWM IPC client.
//
// MangoWM's new IPC is a JSON-over-Unix-socket protocol advertised via the
// MANGO_INSTANCE_SIGNATURE env var (socket at $XDG_RUNTIME_DIR/mango-<pid>.sock).
// A connection issues one verb line ("watch <target>\n"); the server replies
// with an immediate JSON snapshot and then streams newline-delimited JSON on
// every change. Each watch target needs its own connection.
//
// This service replaces the legacy dwl-ipc-v2 path (DwlService via the dms
// daemon) for mango. It exposes a DwlService-compatible tag API plus a rich
// per-client window list from `watch all-clients`.
Singleton {
    id: root
    readonly property var log: Log.scoped("MangoService")

    readonly property string socketPath: Quickshell.env("MANGO_INSTANCE_SIGNATURE")
    readonly property bool available: socketPath.length > 0

    readonly property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
    readonly property string mangoDmsDir: configDir + "/mango/dms"
    readonly property string outputsPath: mangoDmsDir + "/outputs.conf"
    readonly property string layoutPath: mangoDmsDir + "/layout.conf"
    readonly property string cursorPath: mangoDmsDir + "/cursor.conf"

    property int _lastGapValue: -1

    // name -> { name, active, x, y, width, height, scale, layoutIndex,
    //           layoutSymbol, lastOpenSurface, kbLayout, keymode,
    //           tags: [{ tag, state, clients, focused, urgent, layout }] }
    property var outputs: ({})
    property string activeOutput: ""
    property int tagCount: 9
    property var displayScales: ({})
    property string currentKeyboardLayout: ""
    // Rich client list from `watch all-clients` (mango "clients").
    property var windows: []

    signal stateChanged
    signal windowsChanged

    // ── State sockets ──────────────────────────────────────────────────────
    // One connection per watch target; mango streams a fresh full snapshot on
    // every change, so each line is treated as the complete state.

    DankSocket {
        id: monitorsSocket
        path: root.socketPath
        connected: root.available

        onConnectionStateChanged: {
            if (connected)
                send("watch all-monitors");
        }

        parser: SplitParser {
            onRead: line => root._handleMonitors(line)
        }
    }

    DankSocket {
        id: clientsSocket
        path: root.socketPath
        connected: root.available

        onConnectionStateChanged: {
            if (connected)
                send("watch all-clients");
        }

        parser: SplitParser {
            onRead: line => root._handleClients(line)
        }
    }

    function _handleMonitors(line) {
        if (!line || !line.trim())
            return;
        let data;
        try {
            data = JSON.parse(line);
        } catch (e) {
            log.warn("Failed to parse all-monitors:", e);
            return;
        }
        const monitors = data.monitors;
        if (!Array.isArray(monitors))
            return;

        const newOutputs = {};
        const newScales = {};
        let newActive = "";
        let newTagCount = root.tagCount;
        let newKbLayout = root.currentKeyboardLayout;

        for (const m of monitors) {
            if (!m.name)
                continue;
            const tags = (m.tags || []).map(t => ({
                        // 0-based to match the legacy dwl tag model used by consumers
                        "tag": (t.index ?? 1) - 1,
                        "state": t.is_urgent ? 2 : (t.is_active ? 1 : 0),
                        "clients": t.client_count ?? 0,
                        "focused": !!t.is_active,
                        "urgent": !!t.is_urgent,
                        "layout": t.layout ?? ""
                    }));
            newOutputs[m.name] = {
                "name": m.name,
                "active": !!m.active,
                "x": m.x ?? 0,
                "y": m.y ?? 0,
                "width": m.width ?? 0,
                "height": m.height ?? 0,
                "scale": m.scale ?? 1.0,
                "layoutIndex": m.layout_index ?? 0,
                "layoutSymbol": m.layout_symbol ?? "",
                "lastOpenSurface": m.last_open_surface ?? "",
                "keymode": m.keymode ?? "",
                "kbLayout": m.keyboardlayout ?? "",
                "tags": tags
            };
            if (typeof m.scale === "number" && m.scale > 0)
                newScales[m.name] = m.scale;
            if (m.active) {
                newActive = m.name;
                if (m.keyboardlayout)
                    newKbLayout = m.keyboardlayout;
            }
            if (tags.length > 0)
                newTagCount = tags.length;
        }

        root.outputs = newOutputs;
        root.displayScales = newScales;
        root.tagCount = newTagCount;
        if (newActive)
            root.activeOutput = newActive;
        root.currentKeyboardLayout = newKbLayout;
        root.stateChanged();
    }

    function _handleClients(line) {
        if (!line || !line.trim())
            return;
        let data;
        try {
            data = JSON.parse(line);
        } catch (e) {
            log.warn("Failed to parse all-clients:", e);
            return;
        }
        if (!Array.isArray(data.clients))
            return;
        root.windows = data.clients;
        root.windowsChanged();
    }

    // ── DwlService-compatible tag API ──────────────────────────────────────

    function getOutputState(outputName) {
        return (outputs && outputs[outputName]) ? outputs[outputName] : null;
    }

    function getActiveTags(outputName) {
        const output = getOutputState(outputName);
        if (!output || !output.tags)
            return [];
        return output.tags.filter(tag => tag.state === 1).map(tag => tag.tag);
    }

    function getTagsWithClients(outputName) {
        const output = getOutputState(outputName);
        if (!output || !output.tags)
            return [];
        return output.tags.filter(tag => tag.clients > 0).map(tag => tag.tag);
    }

    function getUrgentTags(outputName) {
        const output = getOutputState(outputName);
        if (!output || !output.tags)
            return [];
        return output.tags.filter(tag => tag.state === 2).map(tag => tag.tag);
    }

    function getVisibleTags(outputName) {
        const output = getOutputState(outputName);
        if (!output || !output.tags)
            return [];
        const visibleTags = new Set();
        output.tags.forEach(tag => {
            if (tag.state === 1 || tag.clients > 0)
                visibleTags.add(tag.tag);
        });
        return Array.from(visibleTags).sort((a, b) => a - b);
    }

    function getOutputScale(outputName) {
        return displayScales[outputName];
    }

    // ── Commands (mango verb IPC: mmsg dispatch <func>,<args>) ─────────────

    function reloadConfig() {
        Proc.runCommand("mango-reload", ["mmsg", "dispatch", "reload_config"], (output, exitCode) => {
            if (exitCode !== 0)
                log.warn("mmsg reload_config failed:", output);
        });
    }

    function quit() {
        Quickshell.execDetached(["mmsg", "dispatch", "quit"]);
    }

    // mango tag dispatches act on the focused monitor; tagIndex is 0-based
    // (dwl model), mango `view`/`toggleview` take a 1-based tag number.
    function switchToTag(outputName, tagIndex) {
        Quickshell.execDetached(["mmsg", "dispatch", "view," + (tagIndex + 1)]);
    }

    function toggleTag(outputName, tagIndex) {
        Quickshell.execDetached(["mmsg", "dispatch", "toggleview," + (tagIndex + 1)]);
    }

    function setLayout(index) {
        Quickshell.execDetached(["mmsg", "dispatch", "setlayout," + index]);
    }

    function cycleKeyboardLayout() {
        Quickshell.execDetached(["mmsg", "dispatch", "switch_keyboard_layout"]);
    }

    function powerOffMonitors() {
        const screens = Quickshell.screens || [];
        for (let i = 0; i < screens.length; i++) {
            if (screens[i] && screens[i].name)
                Quickshell.execDetached(["mmsg", "dispatch", "disable_monitor," + screens[i].name]);
        }
    }

    function powerOnMonitors() {
        const screens = Quickshell.screens || [];
        for (let i = 0; i < screens.length; i++) {
            if (screens[i] && screens[i].name)
                Quickshell.execDetached(["mmsg", "dispatch", "enable_monitor," + screens[i].name]);
        }
    }

    // ── Config generation (mango config fragments under ~/.config/mango/dms) ─

    Connections {
        target: SettingsData
        function onBarConfigsChanged() {
            if (!CompositorService.isMango)
                return;
            const newGaps = Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4));
            if (newGaps === root._lastGapValue)
                return;
            root._lastGapValue = newGaps;
            generateLayoutConfig();
        }
    }

    Connections {
        target: CompositorService
        function onIsMangoChanged() {
            if (CompositorService.isMango)
                generateLayoutConfig();
        }
    }

    function transformToMango(transform) {
        switch (transform) {
        case "Normal":
            return 0;
        case "90":
            return 1;
        case "180":
            return 2;
        case "270":
            return 3;
        case "Flipped":
            return 4;
        case "Flipped90":
            return 5;
        case "Flipped180":
            return 6;
        case "Flipped270":
            return 7;
        default:
            return 0;
        }
    }

    function generateOutputsConfig(outputsData, callback) {
        if (!outputsData || Object.keys(outputsData).length === 0) {
            if (callback)
                callback(false);
            return;
        }
        let lines = ["# Auto-generated by DMS - do not edit manually", ""];

        for (const outputName in outputsData) {
            const output = outputsData[outputName];
            if (!output)
                continue;
            let width = 1920;
            let height = 1080;
            let refreshRate = 60;
            if (output.modes && output.current_mode !== undefined) {
                const mode = output.modes[output.current_mode];
                if (mode) {
                    width = mode.width || 1920;
                    height = mode.height || 1080;
                    refreshRate = Math.round((mode.refresh_rate || 60000) / 1000);
                }
            }

            const x = output.logical?.x ?? 0;
            const y = output.logical?.y ?? 0;
            const scale = output.logical?.scale ?? 1.0;
            const transform = transformToMango(output.logical?.transform ?? "Normal");
            const vrr = output.vrr_enabled ? 1 : 0;

            // Anchor the name regex: mango matches `name:` as an unanchored
            // regex with first-match-wins, so a bare "DP-1" also matches
            // "eDP-1" and collapses both outputs onto one position.
            const rule = ["name:^" + outputName + "$", "width:" + width, "height:" + height, "refresh:" + refreshRate, "x:" + x, "y:" + y, "scale:" + scale, "rr:" + transform, "vrr:" + vrr].join(",");

            lines.push("monitorrule=" + rule);
        }

        lines.push("");

        const content = lines.join("\n");

        Proc.runCommand("mango-write-outputs", ["sh", "-c", `mkdir -p "${mangoDmsDir}" && cat > "${outputsPath}" << 'EOF'\n${content}EOF`], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to write outputs config:", output);
                if (callback)
                    callback(false);
                return;
            }
            log.info("Generated outputs config at", outputsPath);
            if (CompositorService.isMango)
                reloadConfig();
            if (callback)
                callback(true);
        });
    }

    function generateLayoutConfig() {
        if (!CompositorService.isMango)
            return;

        const defaultRadius = typeof SettingsData !== "undefined" ? SettingsData.cornerRadius : 12;
        const defaultGaps = typeof SettingsData !== "undefined" ? Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4)) : 4;
        const defaultBorderSize = 2;

        const cornerRadius = (typeof SettingsData !== "undefined" && SettingsData.mangoLayoutRadiusOverride >= 0) ? SettingsData.mangoLayoutRadiusOverride : defaultRadius;
        const gaps = (typeof SettingsData !== "undefined" && SettingsData.mangoLayoutGapsOverride >= 0) ? SettingsData.mangoLayoutGapsOverride : defaultGaps;
        const borderSize = (typeof SettingsData !== "undefined" && SettingsData.mangoLayoutBorderSize >= 0) ? SettingsData.mangoLayoutBorderSize : defaultBorderSize;

        let content = `# Auto-generated by DMS - do not edit manually
border_radius=${cornerRadius}
gappih=${gaps}
gappiv=${gaps}
gappoh=${gaps}
gappov=${gaps}
borderpx=${borderSize}
`;

        Proc.runCommand("mango-write-layout", ["sh", "-c", `mkdir -p "${mangoDmsDir}" && cat > "${layoutPath}" << 'EOF'\n${content}EOF`], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to write layout config:", output);
                return;
            }
            log.info("Generated layout config at", layoutPath);
            reloadConfig();
        });
    }

    function generateCursorConfig() {
        if (!CompositorService.isMango)
            return;

        const settings = typeof SettingsData !== "undefined" ? SettingsData.cursorSettings : null;
        if (!settings) {
            Proc.runCommand("mango-write-cursor", ["sh", "-c", `mkdir -p "${mangoDmsDir}" && : > "${cursorPath}"`], (output, exitCode) => {
                if (exitCode !== 0)
                    log.warn("Failed to write cursor config:", output);
            });
            return;
        }

        const themeName = settings.theme === "System Default" ? (SettingsData.systemDefaultCursorTheme || "") : settings.theme;
        const size = settings.size || 24;
        const hideTimeout = settings.mango?.cursorHideTimeout || 0;

        const isDefaultConfig = !themeName && size === 24 && hideTimeout === 0;
        if (isDefaultConfig) {
            Proc.runCommand("mango-write-cursor", ["sh", "-c", `mkdir -p "${mangoDmsDir}" && : > "${cursorPath}"`], (output, exitCode) => {
                if (exitCode !== 0)
                    log.warn("Failed to write cursor config:", output);
            });
            return;
        }

        let content = `# Auto-generated by DMS - do not edit manually
cursor_size=${size}`;

        if (themeName)
            content += `\ncursor_theme=${themeName}`;

        if (hideTimeout > 0)
            content += `\ncursor_hide_timeout=${hideTimeout}`;

        content += `\n`;

        Proc.runCommand("mango-write-cursor", ["sh", "-c", `mkdir -p "${mangoDmsDir}" && cat > "${cursorPath}" << 'EOF'\n${content}EOF`], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to write cursor config:", output);
                return;
            }
            log.info("Generated cursor config at", cursorPath);
            reloadConfig();
        });
    }
}
