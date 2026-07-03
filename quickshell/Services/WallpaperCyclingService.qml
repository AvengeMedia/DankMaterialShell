pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services

Singleton {
    id: root

    property bool cyclingActive: false
    readonly property bool fullscreenShowing: {
        if (!ToplevelManager.toplevels?.values)
            return false;
        for (const toplevel of ToplevelManager.toplevels.values) {
            if (toplevel.fullscreen && toplevel.activated)
                return true;
        }
        return false;
    }
    readonly property bool shouldPauseCycling: fullscreenShowing || SessionService.locked
    readonly property bool serverSchedulingAvailable: DMSService.capabilities.includes("wallpaper")
    property real lastCycleSeq: -1
    property var monitorProcesses: ({})

    Connections {
        target: DMSService

        function onWallpaperCycleUpdate(data) {
            if (!data)
                return;
            const seq = data.cycleSeq || 0;
            if (lastCycleSeq < 0) {
                lastCycleSeq = seq;
                return;
            }
            if (seq <= lastCycleSeq)
                return;
            lastCycleSeq = seq;
            if (shouldPauseCycling)
                return;
            const target = data.target || "";
            if (target === "") {
                cycleToNextWallpaper();
            } else {
                cycleNextForMonitor(target);
            }
        }

        function onCapabilitiesReceived() {
            lastCycleSeq = -1;
            updateCyclingState();
        }
    }

    Connections {
        target: SessionData

        function onWallpaperCyclingEnabledChanged() {
            updateCyclingState();
        }

        function onWallpaperCyclingModeChanged() {
            updateCyclingState();
        }

        function onWallpaperCyclingIntervalChanged() {
            updateCyclingState();
        }

        function onWallpaperCyclingTimeChanged() {
            updateCyclingState();
        }

        function onPerMonitorWallpaperChanged() {
            updateCyclingState();
        }

        function onMonitorCyclingSettingsChanged() {
            updateCyclingState();
        }
    }

    Connections {
        target: SessionService

        function onSessionUnlocked() {
            updateCyclingState();
        }
    }

    function updateCyclingState() {
        cyclingActive = serverSchedulingAvailable && (SessionData.wallpaperCyclingEnabled || SessionData.perMonitorWallpaper);
        pushConfigToServer();
    }

    function buildServerConfig() {
        var monitors = {};
        if (SessionData.perMonitorWallpaper && typeof Quickshell !== "undefined") {
            var screens = Quickshell.screens;
            for (var i = 0; i < screens.length; i++) {
                var name = screens[i].name;
                var s = SessionData.getMonitorCyclingSettings(name);
                var wp = SessionData.getMonitorWallpaper(name);
                monitors[name] = {
                    "enabled": !!(s.enabled && wp && !wp.startsWith("#")),
                    "mode": s.mode || "interval",
                    "intervalSec": s.interval || 300,
                    "time": s.time || "06:00"
                };
            }
        }
        return {
            "perMonitor": SessionData.perMonitorWallpaper,
            "global": {
                "enabled": !!(SessionData.wallpaperCyclingEnabled && SessionData.wallpaperPath),
                "mode": SessionData.wallpaperCyclingMode,
                "intervalSec": SessionData.wallpaperCyclingInterval,
                "time": SessionData.wallpaperCyclingTime
            },
            "monitors": monitors
        };
    }

    function pushConfigToServer() {
        if (!serverSchedulingAvailable)
            return;
        DMSService.sendRequest("wallpaper.setConfig", {
            "config": buildServerConfig()
        }, null);
    }

    function findCommand(wallpaperDir) {
        return ["sh", "-c", `find -L "${wallpaperDir}" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.jxl" -o -iname "*.avif" -o -iname "*.heif" -o -iname "*.exr" \\) 2>/dev/null | sort`];
    }

    function monitorProcessFor(screenName) {
        var process = monitorProcesses[screenName];
        if (process)
            return process;
        var newProcesses = Object.assign({}, monitorProcesses);
        process = monitorProcessComponent.createObject(root);
        newProcesses[screenName] = process;
        monitorProcesses = newProcesses;
        return process;
    }

    function cycle(screenName, wallpaperPath, goToPrevious) {
        const currentWallpaper = wallpaperPath || SessionData.wallpaperPath;
        if (!currentWallpaper)
            return;
        const wallpaperDir = currentWallpaper.substring(0, currentWallpaper.lastIndexOf('/'));

        if (screenName && monitorProcessComponent.status === Component.Ready) {
            var process = monitorProcessFor(screenName);
            process.command = findCommand(wallpaperDir);
            process.targetScreenName = screenName;
            process.currentWallpaper = currentWallpaper;
            process.goToPrevious = goToPrevious;
            process.running = true;
            return;
        }

        var globalProcess = goToPrevious ? prevCyclingProcess : cyclingProcess;
        globalProcess.command = findCommand(wallpaperDir);
        globalProcess.targetScreenName = screenName || "";
        globalProcess.currentWallpaper = currentWallpaper;
        globalProcess.running = true;
    }

    function cycleToNextWallpaper(screenName, wallpaperPath) {
        cycle(screenName, wallpaperPath, false);
    }

    function cycleToPrevWallpaper(screenName, wallpaperPath) {
        cycle(screenName, wallpaperPath, true);
    }

    function resetScheduleAfterManual() {
        if (!serverSchedulingAvailable)
            return;
        DMSService.sendRequest("wallpaper.trigger", {
            "target": ""
        }, null);
    }

    function cycleNextManually() {
        if (!SessionData.wallpaperPath)
            return;
        cycleToNextWallpaper();
        resetScheduleAfterManual();
    }

    function cyclePrevManually() {
        if (!SessionData.wallpaperPath)
            return;
        cycleToPrevWallpaper();
        resetScheduleAfterManual();
    }

    function cycleNextForMonitor(screenName) {
        if (!screenName)
            return;
        var currentWallpaper = SessionData.getMonitorWallpaper(screenName);
        if (currentWallpaper) {
            cycleToNextWallpaper(screenName, currentWallpaper);
        }
    }

    function cyclePrevForMonitor(screenName) {
        if (!screenName)
            return;
        var currentWallpaper = SessionData.getMonitorWallpaper(screenName);
        if (currentWallpaper) {
            cycleToPrevWallpaper(screenName, currentWallpaper);
        }
    }

    function applyCycledWallpaper(text, currentPath, targetScreenName, goToPrevious) {
        if (!text || !text.trim())
            return;
        const files = text.trim().split('\n').filter(file => file.length > 0);
        if (files.length <= 1)
            return;
        const wallpaperList = files.sort();
        let currentIndex = wallpaperList.findIndex(path => path === currentPath);
        if (currentIndex === -1)
            currentIndex = 0;

        let targetIndex;
        if (goToPrevious) {
            targetIndex = currentIndex === 0 ? wallpaperList.length - 1 : currentIndex - 1;
        } else {
            targetIndex = (currentIndex + 1) % wallpaperList.length;
        }
        const targetWallpaper = wallpaperList[targetIndex];
        if (!targetWallpaper || targetWallpaper === currentPath)
            return;

        if (targetScreenName) {
            SessionData.setMonitorWallpaper(targetScreenName, targetWallpaper);
        } else {
            SessionData.setWallpaper(targetWallpaper);
        }
    }

    Component {
        id: monitorProcessComponent
        Process {
            property string targetScreenName: ""
            property string currentWallpaper: ""
            property bool goToPrevious: false
            running: false
            stdout: StdioCollector {
                onStreamFinished: root.applyCycledWallpaper(text, currentWallpaper, targetScreenName, goToPrevious)
            }
        }
    }

    Process {
        id: cyclingProcess
        property string targetScreenName: ""
        property string currentWallpaper: ""
        property bool goToPrevious: false
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.applyCycledWallpaper(text, cyclingProcess.currentWallpaper, cyclingProcess.targetScreenName, cyclingProcess.goToPrevious)
        }
    }

    Process {
        id: prevCyclingProcess
        property string targetScreenName: ""
        property string currentWallpaper: ""
        property bool goToPrevious: true
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.applyCycledWallpaper(text, prevCyclingProcess.currentWallpaper, prevCyclingProcess.targetScreenName, prevCyclingProcess.goToPrevious)
        }
    }
}
