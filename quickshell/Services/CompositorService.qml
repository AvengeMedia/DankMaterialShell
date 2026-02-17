pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common

Singleton {
    id: root

    property bool isHyprland: false
    property bool isNiri: false
    property bool isDwl: false
    property bool isSway: false
    property bool isScroll: false
    property bool isMiracle: false
    property bool isLabwc: false
    property string compositor: "unknown"
    readonly property bool useHyprlandFocusGrab: isHyprland && Quickshell.env("DMS_HYPRLAND_EXCLUSIVE_FOCUS") !== "1"

    readonly property string hyprlandSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property string niriSocket: Quickshell.env("NIRI_SOCKET")
    readonly property string swaySocket: Quickshell.env("SWAYSOCK")
    readonly property string scrollSocket: Quickshell.env("SWAYSOCK")
    readonly property string miracleSocket: Quickshell.env("MIRACLESOCK")
    readonly property string labwcPid: Quickshell.env("LABWC_PID")
    property bool useNiriSorting: isNiri && NiriService

    property var sortedToplevels: []
    property bool _sortScheduled: false

    signal toplevelsChanged

    function getScreenScale(screen) {
        if (!screen)
            return 1;

        if (Quickshell.env("QT_WAYLAND_FORCE_DPI") || Quickshell.env("QT_SCALE_FACTOR")) {
            return screen.devicePixelRatio || 1;
        }

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
            if (event.name === "openwindow" || event.name === "closewindow" || event.name === "movewindow" || event.name === "movewindowv2" || event.name === "workspace" || event.name === "workspacev2" || event.name === "focusedmon" || event.name === "focusedmonv2" || event.name === "activewindow" || event.name === "activewindowv2" || event.name === "changefloatingmode" || event.name === "fullscreen" || event.name === "moveintogroup" || event.name === "moveoutofgroup") {
                try {
                    Hyprland.refreshToplevels();
                } catch (e) {}
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

    Component.onCompleted: {
        detectCompositor();
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
            if (isDwl && !isHyprland && !isNiri) {
                scheduleSort();
            }
        }
    }

    function computeSortedToplevels() {
        if (!ToplevelManager.toplevels || !ToplevelManager.toplevels.values)
            return [];

        if (useNiriSorting)
            return NiriService.sortToplevels(ToplevelManager.toplevels.values);

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

        return ordered.map(x => x.wayland).filter(w => w !== null && w !== undefined);
    }

    function filterCurrentWorkspace(toplevels, screen) {
        if (useNiriSorting)
            return NiriService.filterCurrentWorkspace(toplevels, screen);
        if (isHyprland)
            return filterHyprlandCurrentWorkspaceSafe(toplevels, screen);
        return toplevels;
    }

    function filterCurrentDisplay(toplevels, screenName) {
        if (!toplevels || toplevels.length === 0 || !screenName)
            return toplevels;
        if (useNiriSorting)
            return NiriService.filterCurrentDisplay(toplevels, screenName);
        if (isHyprland)
            return filterHyprlandCurrentDisplaySafe(toplevels, screenName);
        return toplevels;
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
            console.warn("CompositorService: workspace snapshot failed:", e);
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
        if (hyprlandSignature && hyprlandSignature.length > 0 && !niriSocket && !swaySocket && !scrollSocket && !miracleSocket && !labwcPid) {
            isHyprland = true;
            isNiri = false;
            isDwl = false;
            isSway = false;
            isScroll = false;
            isMiracle = false;
            isLabwc = false;
            compositor = "hyprland";
            console.info("CompositorService: Detected Hyprland");
            return;
        }

        if (niriSocket && niriSocket.length > 0) {
            Proc.runCommand("niriSocketCheck", ["test", "-S", niriSocket], (output, exitCode) => {
                if (exitCode === 0) {
                    isNiri = true;
                    isHyprland = false;
                    isDwl = false;
                    isSway = false;
                    isScroll = false;
                    isMiracle = false;
                    isLabwc = false;
                    compositor = "niri";
                    console.info("CompositorService: Detected Niri with socket:", niriSocket);
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
                    isDwl = false;
                    isSway = true;
                    isScroll = false;
                    isMiracle = false;
                    isLabwc = false;
                    compositor = "sway";
                    console.info("CompositorService: Detected Sway with socket:", swaySocket);
                }
            }, 0);
            return;
        }

        if (miracleSocket && miracleSocket.length > 0) {
            Proc.runCommand("miracleSocketCheck", ["test", "-S", miracleSocket], (output, exitCode) => {
                if (exitCode === 0) {
                    isNiri = false;
                    isHyprland = false;
                    isDwl = false;
                    isSway = false;
                    isScroll = false;
                    isMiracle = true;
                    isLabwc = false;
                    compositor = "miracle";
                    console.info("CompositorService: Detected Miracle WM with socket:", miracleSocket);
                }
            }, 0);
            return;
        }

        if (scrollSocket && scrollSocket.length > 0 && !miracleSocket) {
            Proc.runCommand("scrollSocketCheck", ["test", "-S", scrollSocket], (output, exitCode) => {
                if (exitCode === 0) {
                    isNiri = false;
                    isHyprland = false;
                    isDwl = false;
                    isSway = false;
                    isScroll = true;
                    isMiracle = false;
                    isLabwc = false;
                    compositor = "scroll";
                    console.info("CompositorService: Detected Scroll with socket:", scrollSocket);
                }
            }, 0);
            return;
        }

        if (labwcPid && labwcPid.length > 0) {
            isHyprland = false;
            isNiri = false;
            isDwl = false;
            isSway = false;
            isScroll = false;
            isMiracle = false;
            isLabwc = true;
            compositor = "labwc";
            console.info("CompositorService: Detected LabWC with PID:", labwcPid);
            return;
        }

        if (DMSService.dmsAvailable) {
            Qt.callLater(checkForDwl);
        } else {
            isHyprland = false;
            isNiri = false;
            isDwl = false;
            isSway = false;
            isScroll = false;
            isMiracle = false;
            isLabwc = false;
            compositor = "unknown";
            console.warn("CompositorService: No compositor detected");
        }
    }

    Connections {
        target: DMSService
        function onCapabilitiesReceived() {
            if (!isHyprland && !isNiri && !isDwl && !isLabwc) {
                checkForDwl();
            }
        }
    }

    function checkForDwl() {
        if (DMSService.apiVersion >= 12 && DMSService.capabilities.includes("dwl")) {
            isHyprland = false;
            isNiri = false;
            isDwl = true;
            isSway = false;
            isScroll = false;
            isMiracle = false;
            isLabwc = false;
            compositor = "dwl";
            console.info("CompositorService: Detected DWL via DMS capability");
        }
    }

    function powerOffMonitors() {
        if (isNiri)
            return NiriService.powerOffMonitors();
        if (isHyprland)
            return Hyprland.dispatch("dpms off");
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
        console.warn("CompositorService: Cannot power off monitors, unknown compositor");
    }

    function powerOnMonitors() {
        if (isNiri)
            return NiriService.powerOnMonitors();
        if (isHyprland)
            return Hyprland.dispatch("dpms on");
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
        console.warn("CompositorService: Cannot power on monitors, unknown compositor");
    }

    function _dwlPowerOffMonitors() {
        if (!Quickshell.screens || Quickshell.screens.length === 0) {
            console.warn("CompositorService: No screens available for DWL power off");
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
            console.warn("CompositorService: No screens available for DWL power on");
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
