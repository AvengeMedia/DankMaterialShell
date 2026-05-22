pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("CompositorService")

    property bool isHyprland: false
    property bool isNiri: false
    property bool isTriad: false
    property bool isDwl: false
    property bool isSway: false
    property bool isScroll: false
    property bool isMiracle: false
    property bool isLabwc: false
    property string compositor: "unknown"
    readonly property bool useHyprlandFocusGrab: isHyprland && Quickshell.env("DMS_HYPRLAND_EXCLUSIVE_FOCUS") !== "1"

    readonly property string hyprlandSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property string niriSocket: Quickshell.env("NIRI_SOCKET")
    readonly property string triadSocketEnv: Quickshell.env("TRIAD_SOCKET")
    readonly property string triadSocket: {
        if (triadSocketEnv && triadSocketEnv.length > 0)
            return triadSocketEnv;
        const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR");
        return runtimeDir && runtimeDir.length > 0 ? `${runtimeDir}/triad.sock` : "";
    }
    readonly property string currentDesktop: `${Quickshell.env("XDG_CURRENT_DESKTOP")} ${Quickshell.env("XDG_SESSION_DESKTOP")} ${Quickshell.env("DESKTOP_SESSION")}`.toLowerCase()
    readonly property string swaySocket: Quickshell.env("SWAYSOCK")
    readonly property string scrollSocket: Quickshell.env("SWAYSOCK")
    readonly property string miracleSocket: Quickshell.env("MIRACLESOCK")
    readonly property string labwcPid: Quickshell.env("LABWC_PID")
    property bool useNiriSorting: isNiri && NiriService
    property bool useTriadSorting: isTriad && TriadService

    property var randrScales: ({})
    property bool randrReady: false
    signal randrDataReady

    property var sortedToplevels: []
    property var hyprlandVisibleSpecialWorkspaces: ({})
    property bool _sortScheduled: false

    signal toplevelsChanged

    function fetchRandrData() {
        Proc.runCommand("randr", ["dms", "randr", "--json"], (output, exitCode) => {
            if (exitCode === 0 && output) {
                try {
                    const data = JSON.parse(output.trim());
                    if (data.outputs && Array.isArray(data.outputs)) {
                        const scales = {};
                        for (const out of data.outputs) {
                            if (out.name && out.scale > 0)
                                scales[out.name] = out.scale;
                        }
                        randrScales = scales;
                    }
                } catch (e) {
                    log.warn("failed to parse randr data:", e);
                }
            }
            randrReady = true;
            randrDataReady();
        }, 0, 3000);
    }

    function getScreenScale(screen) {
        if (!screen)
            return 1;

        if (Quickshell.env("QT_WAYLAND_FORCE_DPI") || Quickshell.env("QT_SCALE_FACTOR")) {
            return screen.devicePixelRatio || 1;
        }

        const randrScale = randrScales[screen.name];
        if (randrScale !== undefined && randrScale > 0)
            return Math.round(randrScale * 20) / 20;

        if (WlrOutputService.wlrOutputAvailable && screen) {
            const wlrOutput = WlrOutputService.getOutput(screen.name);
            if (wlrOutput?.enabled && wlrOutput.scale !== undefined && wlrOutput.scale > 0) {
                return Math.round(wlrOutput.scale * 20) / 20;
            }
        }

        if (isNiri && screen) {
            const niriScale = NiriService.displayScales[screen.name];
            if (niriScale !== undefined)
                return niriScale;
        }

        if (isTriad && screen) {
            const triadScale = TriadService.displayScales[screen.name];
            if (triadScale !== undefined)
                return triadScale;
        }

        if (isHyprland && screen) {
            const hyprlandMonitor = Hyprland.monitors.values.find(m => m.name === screen.name);
            if (hyprlandMonitor?.scale !== undefined)
                return hyprlandMonitor.scale;
        }

        if (isDwl && screen) {
            const dwlScale = DwlService.getOutputScale(screen.name);
            if (dwlScale !== undefined && dwlScale > 0)
                return dwlScale;
        }

        return screen?.devicePixelRatio || 1;
    }

    function getFocusedScreen() {
        let screenName = "";
        if (isHyprland && Hyprland.focusedWorkspace?.monitor)
            screenName = Hyprland.focusedWorkspace.monitor.name;
        else if (isNiri && NiriService.currentOutput)
            screenName = NiriService.currentOutput;
        else if (isTriad && TriadService.currentOutput)
            screenName = TriadService.currentOutput;
        else if (isSway || isScroll || isMiracle) {
            const focusedWs = I3.workspaces?.values?.find(ws => ws.focused === true);
            screenName = focusedWs?.monitor?.name || "";
        } else if (isDwl && DwlService.activeOutput)
            screenName = DwlService.activeOutput;

        if (!screenName)
            return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;

        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === screenName)
                return Quickshell.screens[i];
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    Timer {
        id: sortDebounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            _sortScheduled = false;
            sortedToplevels = computeSortedToplevels();
            toplevelsChanged();
        }
    }

    function scheduleSort() {
        if (_sortScheduled)
            return;
        _sortScheduled = true;
        sortDebounceTimer.restart();
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() {
            root.scheduleSort();
        }
    }
    Connections {
        target: isHyprland ? Hyprland : null
        enabled: isHyprland

        function onRawEvent(event) {
            if (event.name === "openwindow" || event.name === "closewindow" || event.name === "movewindow" || event.name === "movewindowv2" || event.name === "workspace" || event.name === "workspacev2" || event.name === "focusedmon" || event.name === "focusedmonv2" || event.name === "activewindow" || event.name === "activewindowv2" || event.name === "changefloatingmode" || event.name === "fullscreen" || event.name === "moveintogroup" || event.name === "moveoutofgroup" || event.name === "activespecial") {
                try {
                    Hyprland.refreshToplevels();
                    if (event.name === "workspace" || event.name === "workspacev2" || event.name === "focusedmon" || event.name === "focusedmonv2" || event.name === "activespecial")
                        Hyprland.refreshMonitors();
                } catch (e) {}
                if (event.name === "activespecial")
                    root.updateHyprlandVisibleSpecialWorkspaces(event);
                root.scheduleSort();
            }
        }
    }
    Connections {
        target: NiriService
        function onWindowsChanged() {
            root.scheduleSort();
        }
    }
    Connections {
        target: TriadService
        function onWindowsChanged() {
            root.scheduleSort();
        }
        function onAllWorkspacesChanged() {
            root.scheduleSort();
        }
    }

    Component.onCompleted: {
        fetchRandrData();
        detectCompositor();
        updateHyprlandVisibleSpecialWorkspaces(null);
        scheduleSort();
        Qt.callLater(() => {
            NiriService.generateNiriLayoutConfig();
            HyprlandService.generateLayoutConfig();
            DwlService.generateLayoutConfig();
        });
    }

    Connections {
        target: DwlService
        function onStateChanged() {
            if (isDwl && !isHyprland && !isNiri && !isTriad) {
                scheduleSort();
            }
        }
    }

    function computeSortedToplevels() {
        if (!ToplevelManager.toplevels || !ToplevelManager.toplevels.values)
            return [];

        if (useNiriSorting)
            return NiriService.sortToplevels(ToplevelManager.toplevels.values);

        if (useTriadSorting)
            return TriadService.sortToplevels(ToplevelManager.toplevels.values);

        if (isHyprland)
            return sortHyprlandToplevelsSafe();

        return Array.from(ToplevelManager.toplevels.values);
    }

    function _get(o, path, fallback) {
        try {
            let v = o;
            for (let i = 0; i < path.length; i++) {
                if (v === null || v === undefined)
                    return fallback;
                v = v[path[i]];
            }
            return (v === undefined || v === null) ? fallback : v;
        } catch (e) {
            return fallback;
        }
    }

    function _normalizeSpecialWorkspaceName(name) {
        const raw = String(name ?? "").trim();
        if (raw.length === 0)
            return "";
        if (raw === "special")
            return "special:special";
        return raw.startsWith("special:") ? raw : `special:${raw}`;
    }

    function _hyprlandRawEventParts(event, argumentCount) {
        if (!event)
            return [];
        try {
            const parsed = event.parse(argumentCount);
            if (parsed && parsed.length !== undefined)
                return parsed;
        } catch (e) {}
        const data = String(event.data ?? "");
        return data.length > 0 ? data.split(",") : [];
    }

    function _specialWorkspaceNameFromMonitor(monitor) {
        if (!monitor)
            return "";
        const candidates = [
            monitor.activeSpecialWorkspace?.name,
            monitor.specialWorkspace?.name,
            monitor.lastIpcObject?.specialWorkspace?.name,
            monitor.lastIpcObject?.specialWorkspace,
            monitor.lastIpcObject?.activeSpecialWorkspace?.name
        ];
        for (let i = 0; i < candidates.length; i++) {
            const normalized = _normalizeSpecialWorkspaceName(candidates[i]);
            if (normalized)
                return normalized;
        }
        return "";
    }

    function updateHyprlandVisibleSpecialWorkspaces(event) {
        if (!isHyprland) {
            hyprlandVisibleSpecialWorkspaces = ({});
            return;
        }

        const next = {};
        try {
            const monitors = Hyprland.monitors?.values || [];
            for (const monitor of monitors) {
                const monitorName = monitor?.name ?? monitor?.lastIpcObject?.name ?? "";
                if (!monitorName)
                    continue;
                const specialName = _specialWorkspaceNameFromMonitor(monitor);
                if (specialName)
                    next[monitorName] = specialName;
            }
        } catch (e) {
            log.warn("updateHyprlandVisibleSpecialWorkspaces monitor snapshot failed:", e);
        }

        if (event?.name === "activespecial") {
            const parts = _hyprlandRawEventParts(event, 2);
            const specialName = _normalizeSpecialWorkspaceName(parts[0]);
            const monitorName = String(parts[1] ?? Hyprland.focusedMonitor?.name ?? Hyprland.focusedWorkspace?.monitor?.name ?? "");
            if (monitorName) {
                if (specialName)
                    next[monitorName] = specialName;
                else
                    delete next[monitorName];
            }
        }

        hyprlandVisibleSpecialWorkspaces = next;
    }

    function sortHyprlandToplevelsSafe() {
        if (!Hyprland.toplevels || !Hyprland.toplevels.values)
            return [];

        const items = Array.from(Hyprland.toplevels.values);

        function _get(o, path, fb) {
            try {
                let v = o;
                for (let k of path) {
                    if (v == null)
                        return fb;
                    v = v[k];
                }
                return (v == null) ? fb : v;
            } catch (e) {
                return fb;
            }
        }

        let snap = [];
        for (let i = 0; i < items.length; i++) {
            const t = items[i];
            if (!t)
                continue;
            const addr = t.address || "";
            if (!addr)
                continue;
            const li = t.lastIpcObject || null;

            const monName = _get(li, ["monitor"], null) ?? _get(t, ["monitor", "name"], "");
            const monX = _get(t, ["monitor", "x"], Number.MAX_SAFE_INTEGER);
            const monY = _get(t, ["monitor", "y"], Number.MAX_SAFE_INTEGER);

            const wsId = _get(li, ["workspace", "id"], null) ?? _get(t, ["workspace", "id"], Number.MAX_SAFE_INTEGER);

            const at = _get(li, ["at"], null);
            let atX = (at !== null && at !== undefined && typeof at[0] === "number") ? at[0] : 1e9;
            let atY = (at !== null && at !== undefined && typeof at[1] === "number") ? at[1] : 1e9;

            const relX = Number.isFinite(monX) ? (atX - monX) : atX;
            const relY = Number.isFinite(monY) ? (atY - monY) : atY;

            snap.push({
                monKey: String(monName),
                monOrderX: Number.isFinite(monX) ? monX : Number.MAX_SAFE_INTEGER,
                monOrderY: Number.isFinite(monY) ? monY : Number.MAX_SAFE_INTEGER,
                wsId: (typeof wsId === "number") ? wsId : Number.MAX_SAFE_INTEGER,
                x: relX,
                y: relY,
                title: t.title || "",
                address: addr,
                wayland: t.wayland
            });
        }

        const groups = new Map();
        for (const it of snap) {
            const key = it.monKey + "::" + it.wsId;
            if (!groups.has(key))
                groups.set(key, []);
            groups.get(key).push(it);
        }

        let groupList = [];
        for (const [key, arr] of groups) {
            const repr = arr[0];
            groupList.push({
                key,
                monKey: repr.monKey,
                monOrderX: repr.monOrderX,
                monOrderY: repr.monOrderY,
                wsId: repr.wsId,
                items: arr
            });
        }

        groupList.sort((a, b) => {
            if (a.monOrderX !== b.monOrderX)
                return a.monOrderX - b.monOrderX;
            if (a.monOrderY !== b.monOrderY)
                return a.monOrderY - b.monOrderY;
            if (a.monKey !== b.monKey)
                return a.monKey.localeCompare(b.monKey);
            if (a.wsId !== b.wsId)
                return a.wsId - b.wsId;
            return 0;
        });

        const COLUMN_THRESHOLD = 48;
        const JITTER_Y = 6;

        let ordered = [];
        for (const g of groupList) {
            const arr = g.items;

            const xs = arr.map(it => it.x).filter(x => Number.isFinite(x)).sort((a, b) => a - b);
            let colCenters = [];
            if (xs.length > 0) {
                for (const x of xs) {
                    if (colCenters.length === 0) {
                        colCenters.push(x);
                    } else {
                        const last = colCenters[colCenters.length - 1];
                        if (x - last >= COLUMN_THRESHOLD) {
                            colCenters.push(x);
                        }
                    }
                }
            } else {
                colCenters = [0];
            }

            for (const it of arr) {
                let bestCol = 0;
                let bestDist = Number.POSITIVE_INFINITY;
                for (let ci = 0; ci < colCenters.length; ci++) {
                    const d = Math.abs(it.x - colCenters[ci]);
                    if (d < bestDist) {
                        bestDist = d;
                        bestCol = ci;
                    }
                }
                it._col = bestCol;
            }

            arr.sort((a, b) => {
                if (a._col !== b._col)
                    return a._col - b._col;

                const dy = a.y - b.y;
                if (Math.abs(dy) > JITTER_Y)
                    return dy;

                if (a.title !== b.title)
                    return a.title.localeCompare(b.title);
                if (a.address !== b.address)
                    return a.address.localeCompare(b.address);
                return 0;
            });

            ordered.push.apply(ordered, arr);
        }
        return ordered.map(x => {
            if (!x.wayland)
                return null;
            x.wayland.address = x.address;
            return x.wayland;
        }).filter(w => w !== null && w !== undefined);
    }

    function filterCurrentWorkspace(toplevels, screen) {
        if (useNiriSorting)
            return NiriService.filterCurrentWorkspace(toplevels, screen);
        if (useTriadSorting)
            return TriadService.filterCurrentWorkspace(toplevels, screen);
        if (isHyprland)
            return filterHyprlandCurrentWorkspaceSafe(toplevels, screen);
        return toplevels;
    }

    function filterCurrentDisplay(toplevels, screenName) {
        if (!toplevels || toplevels.length === 0 || !screenName)
            return toplevels;
        if (useNiriSorting) {
            const active = ToplevelManager.activeToplevel;
            if (active && toplevels.length === 1 && toplevels[0] === active) {
                if (NiriService.currentOutput !== screenName)
                    return [];
                const focusedWin = NiriService.windows.find(nw => nw.is_focused);
                if (!focusedWin)
                    return [];
                const screenWsIds = new Set(NiriService.allWorkspaces.filter(ws => ws.output === screenName).map(ws => ws.id));
                return screenWsIds.has(focusedWin.workspace_id) ? toplevels : [];
            }
            return NiriService.filterCurrentDisplay(toplevels, screenName);
        }
        if (useTriadSorting)
            return TriadService.filterCurrentDisplay(toplevels, screenName);
        if (isHyprland)
            return filterHyprlandCurrentDisplaySafe(toplevels, screenName);
        return toplevels;
    }

    function _screenName(screenOrName) {
        if (typeof screenOrName === "string")
            return screenOrName;
        return screenOrName?.name ?? "";
    }

    function _toplevelOnScreen(toplevel, screenName) {
        if (!toplevel || !screenName)
            return false;
        const screens = toplevel.screens;
        if (!screens)
            return false;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i]?.name === screenName)
                return true;
        }
        return false;
    }

    function hasFullscreenToplevelOnScreen(screenOrName) {
        const screenName = _screenName(screenOrName);
        if (!screenName)
            return false;

        if (isNiri || isTriad) {
            const active = ToplevelManager.activeToplevel;
            if (active?.fullscreen && active?.activated && _toplevelOnScreen(active, screenName))
                return true;

            const filtered = filterCurrentWorkspace(sortedToplevels, screenName);
            for (let i = 0; i < filtered.length; i++) {
                if (filtered[i]?.fullscreen)
                    return true;
            }
            return false;
        }

        if (isHyprland) {
            const filtered = filterCurrentWorkspace(sortedToplevels, screenName);
            for (let i = 0; i < filtered.length; i++) {
                if (filtered[i]?.fullscreen)
                    return true;
            }
            return false;
        }

        if (!ToplevelManager.toplevels?.values)
            return false;

        for (const toplevel of ToplevelManager.toplevels.values) {
            if (toplevel?.fullscreen && _toplevelOnScreen(toplevel, screenName))
                return true;
        }
        return false;
    }

    function _hyprlandToplevelMapped(hyprToplevel) {
        if (!hyprToplevel)
            return false;
        if (hyprToplevel.mapped === false)
            return false;
        const ipcMapped = hyprToplevel.lastIpcObject?.mapped;
        if (ipcMapped === false)
            return false;
        if (hyprToplevel.hidden === true)
            return false;
        const ipcHidden = hyprToplevel.lastIpcObject?.hidden;
        if (ipcHidden === true)
            return false;
        return true;
    }

    function hyprlandVisibleSpecialWorkspaceOnScreen(screenOrName) {
        const screenName = _screenName(screenOrName);
        if (!isHyprland || !screenName)
            return "";
        hyprlandVisibleSpecialWorkspaces;
        const trackedName = hyprlandVisibleSpecialWorkspaces[screenName] ?? "";
        if (trackedName)
            return trackedName;
        try {
            const monitor = Hyprland.monitors?.values?.find(m => m.name === screenName);
            return _specialWorkspaceNameFromMonitor(monitor);
        } catch (e) {
            return "";
        }
    }

    function hyprlandSpecialWorkspaceBlocksConnectedFrame(screenOrName) {
        const screenName = _screenName(screenOrName);
        if (!isHyprland || !screenName || !Hyprland.toplevels?.values)
            return false;
        const visibleSpecialWorkspace = hyprlandVisibleSpecialWorkspaceOnScreen(screenName);
        if (!visibleSpecialWorkspace)
            return false;

        try {
            for (const t of Hyprland.toplevels.values) {
                const monName = t.monitor?.name ?? t.lastIpcObject?.monitor ?? "";
                if (monName !== screenName)
                    continue;
                const wsName = _normalizeSpecialWorkspaceName(t.workspace?.name ?? t.lastIpcObject?.workspace?.name ?? "");
                if (!wsName || wsName !== visibleSpecialWorkspace)
                    continue;
                if (_hyprlandToplevelMapped(t))
                    return true;
            }
        } catch (e) {
            log.warn("hyprlandSpecialWorkspaceBlocksConnectedFrame failed:", e);
        }
        return false;
    }

    function connectedFrameBlockedOnScreen(screenOrName) {
        if (hasFullscreenToplevelOnScreen(screenOrName))
            return true;
        return hyprlandSpecialWorkspaceBlocksConnectedFrame(screenOrName);
    }

    function _screenForName(screenOrName) {
        if (screenOrName && typeof screenOrName !== "string")
            return screenOrName;
        const screenName = _screenName(screenOrName);
        if (!screenName)
            return null;
        const screens = Quickshell.screens || [];
        for (let i = 0; i < screens.length; i++) {
            if (screens[i]?.name === screenName)
                return screens[i];
        }
        return null;
    }

    function frameConfiguredForScreen(screenOrName) {
        if (!SettingsData.frameEnabled)
            return false;
        const screen = _screenForName(screenOrName);
        if (!screen || !SettingsData.isScreenInPreferences(screen, SettingsData.frameScreenPreferences))
            return false;
        return true;
    }

    function frameWindowVisibleForScreen(screenOrName) {
        if (!frameConfiguredForScreen(screenOrName))
            return false;
        return !connectedFrameBlockedOnScreen(screenOrName);
    }

    function usesConnectedFrameChromeForScreen(screenOrName) {
        return SettingsData.connectedFrameModeActive && frameWindowVisibleForScreen(screenOrName);
    }

    function framePeerSurfacesUseOverlayForScreen(screenOrName) {
        return frameWindowVisibleForScreen(screenOrName);
    }

    function hyprlandToplevelOverlapsDockEdge(hyprToplevel, screenName, dockPosition, dockThickness, screenWidth, screenHeight) {
        if (!hyprToplevel?.lastIpcObject || !screenName)
            return false;
        const monName = hyprToplevel.monitor?.name ?? hyprToplevel.lastIpcObject?.monitor ?? "";
        if (monName && monName !== screenName)
            return false;
        const ipc = hyprToplevel.lastIpcObject;
        const at = ipc.at;
        const size = ipc.size;
        if (!at || !size)
            return false;
        const monX = hyprToplevel.monitor?.x ?? 0;
        const monY = hyprToplevel.monitor?.y ?? 0;
        const winX = at[0] - monX;
        const winY = at[1] - monY;
        const winW = size[0];
        const winH = size[1];
        switch (dockPosition) {
        case SettingsData.Position.Top:
            return winY < dockThickness;
        case SettingsData.Position.Bottom:
            return winY + winH > screenHeight - dockThickness;
        case SettingsData.Position.Left:
            return winX < dockThickness;
        case SettingsData.Position.Right:
            return winX + winW > screenWidth - dockThickness;
        default:
            return false;
        }
    }

    function hyprlandDockOverlapForSmartAutoHide(screenName, dockPosition, dockThickness, screenWidth, screenHeight) {
        if (!isHyprland || !screenName || !Hyprland.toplevels?.values)
            return false;

        const filtered = filterCurrentWorkspace(sortedToplevels, screenName);
        for (let i = 0; i < filtered.length; i++) {
            const toplevel = filtered[i];
            let hyprToplevel = null;
            for (const t of Hyprland.toplevels.values) {
                if (t.wayland === toplevel) {
                    hyprToplevel = t;
                    break;
                }
            }
            if (hyprlandToplevelOverlapsDockEdge(hyprToplevel, screenName, dockPosition, dockThickness, screenWidth, screenHeight))
                return true;
        }

        const visibleSpecialWorkspace = hyprlandVisibleSpecialWorkspaceOnScreen(screenName);
        if (!visibleSpecialWorkspace)
            return false;

        for (const hyprToplevel of Hyprland.toplevels.values) {
            const wsName = _normalizeSpecialWorkspaceName(hyprToplevel.workspace?.name ?? hyprToplevel.lastIpcObject?.workspace?.name ?? "");
            if (wsName !== visibleSpecialWorkspace)
                continue;
            if (!_hyprlandToplevelMapped(hyprToplevel))
                continue;
            if (hyprlandToplevelOverlapsDockEdge(hyprToplevel, screenName, dockPosition, dockThickness, screenWidth, screenHeight))
                return true;
        }
        return false;
    }

    function filterHyprlandCurrentDisplaySafe(toplevels, screenName) {
        if (!toplevels || toplevels.length === 0 || !Hyprland.toplevels)
            return toplevels;

        let monitorWindows = new Set();
        try {
            const hy = Array.from(Hyprland.toplevels.values);
            for (const t of hy) {
                const mon = _get(t, ["monitor", "name"], "");
                if (mon === screenName && t.wayland)
                    monitorWindows.add(t.wayland);
            }
        } catch (e) {}

        return toplevels.filter(w => monitorWindows.has(w));
    }

    function filterHyprlandCurrentWorkspaceSafe(toplevels, screenName) {
        if (!toplevels || toplevels.length === 0 || !Hyprland.toplevels)
            return toplevels;

        let currentWorkspaceId = null;
        try {
            if (Hyprland.monitors) {
                const monitor = Hyprland.monitors.values.find(m => m.name === screenName);
                if (monitor)
                    currentWorkspaceId = _get(monitor, ["activeWorkspace", "id"], null);
            }

            if (currentWorkspaceId === null) {
                const hy = Array.from(Hyprland.toplevels.values);
                for (const t of hy) {
                    const mon = _get(t, ["monitor", "name"], "");
                    const wsId = _get(t, ["workspace", "id"], null);
                    const active = !!_get(t, ["activated"], false);
                    if (mon === screenName && wsId !== null) {
                        if (active) {
                            currentWorkspaceId = wsId;
                            break;
                        }
                        if (currentWorkspaceId === null)
                            currentWorkspaceId = wsId;
                    }
                }
            }

            if (currentWorkspaceId === null && Hyprland.workspaces) {
                const wss = Array.from(Hyprland.workspaces.values);
                const focusedId = _get(Hyprland, ["focusedWorkspace", "id"], null);
                for (const ws of wss) {
                    const monName = _get(ws, ["monitor", "name"], "");
                    const wsId = _get(ws, ["id"], null);
                    if (monName === screenName && wsId !== null) {
                        if (focusedId !== null && wsId === focusedId) {
                            currentWorkspaceId = wsId;
                            break;
                        }
                        if (currentWorkspaceId === null)
                            currentWorkspaceId = wsId;
                    }
                }
            }
        } catch (e) {
            log.warn("workspace snapshot failed:", e);
        }

        if (currentWorkspaceId === null)
            return toplevels;

        let map = new Map();
        try {
            const hy = Array.from(Hyprland.toplevels.values);
            for (const t of hy) {
                const wsId = _get(t, ["workspace", "id"], null);
                if (t && t.wayland && wsId !== null)
                    map.set(t.wayland, wsId);
            }
        } catch (e) {}

        return toplevels.filter(w => map.get(w) === currentWorkspaceId);
    }

    Timer {
        id: compositorInitTimer
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            detectCompositor();
            Qt.callLater(() => {
                NiriService.generateNiriLayoutConfig();
                HyprlandService.generateLayoutConfig();
                DwlService.generateLayoutConfig();
            });
        }
    }

    function detectCompositor() {
        const desktopLooksTriad = currentDesktop.indexOf("triad") >= 0;
        if ((triadSocketEnv && triadSocketEnv.length > 0) || desktopLooksTriad) {
            Proc.runCommand("triadSocketCheck", ["test", "-S", triadSocket], (output, exitCode) => {
                if (exitCode === 0 || desktopLooksTriad) {
                    isTriad = true;
                    isHyprland = false;
                    isNiri = false;
                    isDwl = false;
                    isSway = false;
                    isScroll = false;
                    isMiracle = false;
                    isLabwc = false;
                    compositor = "triad";
                    log.info("Detected Triad with socket:", triadSocket);
                }
            }, 0);
            return;
        }

        if (hyprlandSignature && hyprlandSignature.length > 0 && !niriSocket && !swaySocket && !scrollSocket && !miracleSocket && !labwcPid) {
            isHyprland = true;
            isNiri = false;
            isTriad = false;
            isDwl = false;
            isSway = false;
            isScroll = false;
            isMiracle = false;
            isLabwc = false;
            compositor = "hyprland";
            log.info("Detected Hyprland");
            return;
        }

        if (niriSocket && niriSocket.length > 0) {
            Proc.runCommand("niriSocketCheck", ["test", "-S", niriSocket], (output, exitCode) => {
                if (exitCode === 0) {
                    isNiri = true;
                    isHyprland = false;
                    isTriad = false;
                    isDwl = false;
                    isSway = false;
                    isScroll = false;
                    isMiracle = false;
                    isLabwc = false;
                    compositor = "niri";
                    log.info("Detected Niri with socket:", niriSocket);
                    NiriService.generateNiriBlurrule();
                }
            }, 0);
            return;
        }

        if (swaySocket && swaySocket.length > 0 && !scrollSocket && scrollSocket.length == 0 && !miracleSocket) {
            Proc.runCommand("swaySocketCheck", ["test", "-S", swaySocket], (output, exitCode) => {
                if (exitCode === 0) {
                    isNiri = false;
                    isHyprland = false;
                    isTriad = false;
                    isDwl = false;
                    isSway = true;
                    isScroll = false;
                    isMiracle = false;
                    isLabwc = false;
                    compositor = "sway";
                    log.info("Detected Sway with socket:", swaySocket);
                }
            }, 0);
            return;
        }

        if (miracleSocket && miracleSocket.length > 0) {
            Proc.runCommand("miracleSocketCheck", ["test", "-S", miracleSocket], (output, exitCode) => {
                if (exitCode === 0) {
                    isNiri = false;
                    isHyprland = false;
                    isTriad = false;
                    isDwl = false;
                    isSway = false;
                    isScroll = false;
                    isMiracle = true;
                    isLabwc = false;
                    compositor = "miracle";
                    log.info("Detected Miracle WM with socket:", miracleSocket);
                }
            }, 0);
            return;
        }

        if (scrollSocket && scrollSocket.length > 0 && !miracleSocket) {
            Proc.runCommand("scrollSocketCheck", ["test", "-S", scrollSocket], (output, exitCode) => {
                if (exitCode === 0) {
                    isNiri = false;
                    isHyprland = false;
                    isTriad = false;
                    isDwl = false;
                    isSway = false;
                    isScroll = true;
                    isMiracle = false;
                    isLabwc = false;
                    compositor = "scroll";
                    log.info("Detected Scroll with socket:", scrollSocket);
                }
            }, 0);
            return;
        }

        if (labwcPid && labwcPid.length > 0) {
            isHyprland = false;
            isNiri = false;
            isTriad = false;
            isDwl = false;
            isSway = false;
            isScroll = false;
            isMiracle = false;
            isLabwc = true;
            compositor = "labwc";
            log.info("Detected LabWC with PID:", labwcPid);
            return;
        }

        if (DMSService.dmsAvailable) {
            Qt.callLater(checkForDwl);
        } else {
            isHyprland = false;
            isNiri = false;
            isTriad = false;
            isDwl = false;
            isSway = false;
            isScroll = false;
            isMiracle = false;
            isLabwc = false;
            compositor = "unknown";
            log.warn("No compositor detected");
        }
    }

    Connections {
        target: DMSService
        function onCapabilitiesReceived() {
            if (!isHyprland && !isNiri && !isTriad && !isDwl && !isLabwc) {
                checkForDwl();
            }
        }
    }

    function checkForDwl() {
        if (DMSService.apiVersion >= 12 && DMSService.capabilities.includes("dwl")) {
            isHyprland = false;
            isNiri = false;
            isTriad = false;
            isDwl = true;
            isSway = false;
            isScroll = false;
            isMiracle = false;
            isLabwc = false;
            compositor = "dwl";
            log.info("Detected DWL via DMS capability");
        }
    }

    function powerOffMonitors() {
        if (isNiri)
            return NiriService.powerOffMonitors();
        if (isTriad)
            return TriadService.powerOffMonitors();
        if (isHyprland)
            return HyprlandService.dpmsOff();
        if (isDwl)
            return _dwlPowerOffMonitors();
        if (isSway || isScroll || isMiracle) {
            try {
                I3.dispatch("output * dpms off");
            } catch (_) {}
            return;
        }
        if (isLabwc) {
            Quickshell.execDetached(["dms", "dpms", "off"]);
        }
        log.warn("Cannot power off monitors, unknown compositor");
    }

    function powerOnMonitors() {
        if (isNiri)
            return NiriService.powerOnMonitors();
        if (isTriad)
            return TriadService.powerOnMonitors();
        if (isHyprland)
            return HyprlandService.dpmsOn();
        if (isDwl)
            return _dwlPowerOnMonitors();
        if (isSway || isScroll || isMiracle) {
            try {
                I3.dispatch("output * dpms on");
            } catch (_) {}
            return;
        }
        if (isLabwc) {
            Quickshell.execDetached(["dms", "dpms", "on"]);
        }
        log.warn("Cannot power on monitors, unknown compositor");
    }

    function _dwlPowerOffMonitors() {
        if (!Quickshell.screens || Quickshell.screens.length === 0) {
            log.warn("No screens available for DWL power off");
            return;
        }

        for (let i = 0; i < Quickshell.screens.length; i++) {
            const screen = Quickshell.screens[i];
            if (screen && screen.name) {
                Quickshell.execDetached(["mmsg", "-d", "disable_monitor," + screen.name]);
            }
        }
    }

    function _dwlPowerOnMonitors() {
        if (!Quickshell.screens || Quickshell.screens.length === 0) {
            log.warn("No screens available for DWL power on");
            return;
        }

        for (let i = 0; i < Quickshell.screens.length; i++) {
            const screen = Quickshell.screens[i];
            if (screen && screen.name) {
                Quickshell.execDetached(["mmsg", "-d", "enable_monitor," + screen.name]);
            }
        }
    }
}
