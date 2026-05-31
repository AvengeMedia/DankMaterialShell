pragma Singleton
pragma ComponentBehavior: Bound

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
}
