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
    property string cachedCyclingTime: SessionData.wallpaperCyclingTime
    property int cachedCyclingInterval: SessionData.wallpaperCyclingInterval
    property string lastTimeCheck: ""
    property var monitorTimers: ({})
    property var monitorLastTimeChecks: ({})
    property var monitorProcesses: ({})

    Component {
        id: monitorTimerComponent
        Timer {
            property string targetScreen: ""
            running: false
            repeat: true
	        onTriggered: {
                if (typeof WallpaperCyclingService !== "undefined" && targetScreen !== "" && !WallpaperCyclingService.shouldPauseCycling) {
                    WallpaperCyclingService.cycleNextForMonitor(targetScreen);
                }
            }
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
                onStreamFinished: {
                    if (text && text.trim()) {
                        const files = text.trim().split('\n').filter(file => file.length > 0);
                        if (files.length <= 1)
                            return;
                        const wallpaperList = files.sort();
                        const currentPath = currentWallpaper;
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
                        if (targetWallpaper && targetWallpaper !== currentPath) {
                            if (targetScreenName) {
                                SessionData.setMonitorWallpaper(targetScreenName, targetWallpaper);
                            } else {
                                SessionData.setWallpaper(targetWallpaper);
                            }
                        }
                    }
                }
            }
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
            cachedCyclingInterval = SessionData.wallpaperCyclingInterval;
            if (SessionData.wallpaperCyclingMode === "interval") {
                updateCyclingState();
            }
        }

        function onWallpaperCyclingTimeChanged() {
            cachedCyclingTime = SessionData.wallpaperCyclingTime;
            if (SessionData.wallpaperCyclingMode === "time") {
                updateCyclingState();
            }
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
            if (SessionData.wallpaperCyclingEnabled || SessionData.perMonitorWallpaper) {
                updateCyclingState();
            }
        }
    }

    function updateCyclingState() {
        if (SessionData.perMonitorWallpaper) {
            stopCycling();
            updatePerMonitorCycling();
        } else if (SessionData.wallpaperCyclingEnabled && SessionData.wallpaperPath) {
            startCycling();
            stopAllMonitorCycling();
        } else {
            stopCycling();
            stopAllMonitorCycling();
        }
    }

    function updatePerMonitorCycling() {
        if (typeof Quickshell === "undefined")
            return;
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            var screenName = screens[i].name;
            var settings = SessionData.getMonitorCyclingSettings(screenName);
            var wallpaper = SessionData.getMonitorWallpaper(screenName);

            if (settings.enabled && wallpaper && !wallpaper.startsWith("#")) {
                startMonitorCycling(screenName, settings);
            } else {
                stopMonitorCycling(screenName);
            }
        }
    }

    function stopAllMonitorCycling() {
        var screenNames = Object.keys(monitorTimers);
        for (var i = 0; i < screenNames.length; i++) {
            stopMonitorCycling(screenNames[i]);
        }
    }

    function startCycling() {
        switch (SessionData.wallpaperCyclingMode) {
        case "interval":
            lastTimeCheck = "";
            intervalTimer.interval = cachedCyclingInterval * 1000;
            intervalTimer.start();
            cyclingActive = true;
            break;
        case "time":
            intervalTimer.stop();
            cyclingActive = true;
            checkTimeBasedCycling();
            break;
        }
    }

    function stopCycling() {
        intervalTimer.stop();
        cyclingActive = false;
    }

    function startMonitorCycling(screenName, settings) {
        switch (settings.mode) {
        case "interval":
            {
                var newChecks = Object.assign({}, monitorLastTimeChecks);
                delete newChecks[screenName];
                monitorLastTimeChecks = newChecks;

                var timer = monitorTimers[screenName];
                if (!timer && monitorTimerComponent && monitorTimerComponent.status === Component.Ready) {
                    var newTimers = Object.assign({}, monitorTimers);
                    newTimers[screenName] = monitorTimerComponent.createObject(root);
                    newTimers[screenName].targetScreen = screenName;
                    monitorTimers = newTimers;
                    timer = monitorTimers[screenName];
                }
                if (timer) {
                    timer.interval = settings.interval * 1000;
                    timer.start();
                }
                break;
            }
        case "time":
            {
                var existingTimer = monitorTimers[screenName];
                if (existingTimer) {
                    existingTimer.stop();
                    existingTimer.destroy();
                    var newTimers = Object.assign({}, monitorTimers);
                    delete newTimers[screenName];
                    monitorTimers = newTimers;
                }

                var newChecks = Object.assign({}, monitorLastTimeChecks);
                newChecks[screenName] = "";
                monitorLastTimeChecks = newChecks;
                break;
            }
        }
    }

    function stopMonitorCycling(screenName) {
        var timer = monitorTimers[screenName];
        if (timer) {
            timer.stop();
            timer.destroy();
            var newTimers = Object.assign({}, monitorTimers);
            delete newTimers[screenName];
            monitorTimers = newTimers;
        }

        var process = monitorProcesses[screenName];
        if (process) {
            process.destroy();
            var newProcesses = Object.assign({}, monitorProcesses);
            delete newProcesses[screenName];
            monitorProcesses = newProcesses;
        }

        var newChecks = Object.assign({}, monitorLastTimeChecks);
        delete newChecks[screenName];
        monitorLastTimeChecks = newChecks;
    }

    function cycleToNextWallpaper(screenName, wallpaperPath) {
        const currentWallpaper = wallpaperPath || SessionData.wallpaperPath;
        if (!currentWallpaper)
            return;
        const wallpaperDir = currentWallpaper.substring(0, currentWallpaper.lastIndexOf('/'));

        if (screenName && monitorProcessComponent && monitorProcessComponent.status === Component.Ready) {
            // Use per-monitor process
            var process = monitorProcesses[screenName];
            if (!process) {
                var newProcesses = Object.assign({}, monitorProcesses);
                newProcesses[screenName] = monitorProcessComponent.createObject(root);
                monitorProcesses = newProcesses;
                process = monitorProcesses[screenName];
            }

            if (process) {
                process.command = ["sh", "-c", `find "${wallpaperDir}" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.jxl" -o -iname "*.avif" -o -iname "*.heif" -o -iname "*.exr" \\) 2>/dev/null | sort`];
                process.targetScreenName = screenName;
                process.currentWallpaper = currentWallpaper;
                process.goToPrevious = false;
                process.running = true;
            }
        } else {
            // Use global process for fallback
            cyclingProcess.command = ["sh", "-c", `find "${wallpaperDir}" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.jxl" -o -iname "*.avif" -o -iname "*.heif" -o -iname "*.exr" \\) 2>/dev/null | sort`];
            cyclingProcess.targetScreenName = screenName || "";
            cyclingProcess.currentWallpaper = currentWallpaper;
            cyclingProcess.running = true;
        }
    }

    function cycleToPrevWallpaper(screenName, wallpaperPath) {
        const currentWallpaper = wallpaperPath || SessionData.wallpaperPath;
        if (!currentWallpaper)
            return;
        const wallpaperDir = currentWallpaper.substring(0, currentWallpaper.lastIndexOf('/'));

        if (screenName && monitorProcessComponent && monitorProcessComponent.status === Component.Ready) {
            // Use per-monitor process (same as next, but with prev flag)
            var process = monitorProcesses[screenName];
            if (!process) {
                var newProcesses = Object.assign({}, monitorProcesses);
                newProcesses[screenName] = monitorProcessComponent.createObject(root);
                monitorProcesses = newProcesses;
                process = monitorProcesses[screenName];
            }

            if (process) {
                process.command = ["sh", "-c", `find "${wallpaperDir}" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.jxl" -o -iname "*.avif" -o -iname "*.heif" -o -iname "*.exr" \\) 2>/dev/null | sort`];
                process.targetScreenName = screenName;
                process.currentWallpaper = currentWallpaper;
                process.goToPrevious = true;
                process.running = true;
            }
        } else {
            // Use global process for fallback
            prevCyclingProcess.command = ["sh", "-c", `find "${wallpaperDir}" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.jxl" -o -iname "*.avif" -o -iname "*.heif" -o -iname "*.exr" \\) 2>/dev/null | sort`];
            prevCyclingProcess.targetScreenName = screenName || "";
            prevCyclingProcess.currentWallpaper = currentWallpaper;
            prevCyclingProcess.running = true;
        }
    }

    function cycleNextManually() {
        if (SessionData.wallpaperPath) {
            cycleToNextWallpaper();
            // Restart timers if cycling is active
            if (cyclingActive && SessionData.wallpaperCyclingEnabled) {
                if (SessionData.wallpaperCyclingMode === "interval") {
                    intervalTimer.interval = cachedCyclingInterval * 1000;
                    intervalTimer.restart();
                }
            }
        }
    }

    function cyclePrevManually() {
        if (SessionData.wallpaperPath) {
            cycleToPrevWallpaper();
            // Restart timers if cycling is active
            if (cyclingActive && SessionData.wallpaperCyclingEnabled) {
                if (SessionData.wallpaperCyclingMode === "interval") {
                    intervalTimer.interval = cachedCyclingInterval * 1000;
                    intervalTimer.restart();
                }
            }
        }
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

    function checkTimeBasedCycling() {
        if (shouldPauseCycling)
            return;
        const currentTime = Qt.formatTime(systemClock.date, "hh:mm");

        if (!SessionData.perMonitorWallpaper) {
            if (currentTime === cachedCyclingTime && currentTime !== lastTimeCheck) {
                lastTimeCheck = currentTime;
                cycleToNextWallpaper();
            } else if (currentTime !== cachedCyclingTime) {
                lastTimeCheck = "";
            }
        } else {
            checkPerMonitorTimeBasedCycling(currentTime);
        }
    }

    function checkPerMonitorTimeBasedCycling(currentTime) {
        if (typeof Quickshell === "undefined")
            return;
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            var screenName = screens[i].name;
            var settings = SessionData.getMonitorCyclingSettings(screenName);
            var wallpaper = SessionData.getMonitorWallpaper(screenName);

            if (settings.enabled && settings.mode === "time" && wallpaper && !wallpaper.startsWith("#")) {
                var lastCheck = monitorLastTimeChecks[screenName] || "";

                if (currentTime === settings.time && currentTime !== lastCheck) {
                    var newChecks = Object.assign({}, monitorLastTimeChecks);
                    newChecks[screenName] = currentTime;
                    monitorLastTimeChecks = newChecks;
                    cycleNextForMonitor(screenName);
                } else if (currentTime !== settings.time) {
                    var newChecks = Object.assign({}, monitorLastTimeChecks);
                    newChecks[screenName] = "";
                    monitorLastTimeChecks = newChecks;
                }
            }
        }
    }

    Timer {
        id: intervalTimer
        interval: cachedCyclingInterval * 1000
        running: false
        repeat: true
        onTriggered: {
            if (shouldPauseCycling)
                return;
            cycleToNextWallpaper();
        }
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
        onDateChanged: {
            if ((SessionData.wallpaperCyclingMode === "time" && cyclingActive) || SessionData.perMonitorWallpaper) {
                checkTimeBasedCycling();
            }
        }
    }

    Process {
        id: cyclingProcess

        property string targetScreenName: ""
        property string currentWallpaper: ""

        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    const files = text.trim().split('\n').filter(file => file.length > 0);
                    if (files.length <= 1)
                        return;
                    const wallpaperList = files.sort();
                    const currentPath = cyclingProcess.currentWallpaper;
                    let currentIndex = wallpaperList.findIndex(path => path === currentPath);
                    if (currentIndex === -1)
                        currentIndex = 0;

                    const nextIndex = (currentIndex + 1) % wallpaperList.length;
                    const nextWallpaper = wallpaperList[nextIndex];

                    if (nextWallpaper && nextWallpaper !== currentPath) {
                        if (cyclingProcess.targetScreenName) {
                            SessionData.setMonitorWallpaper(cyclingProcess.targetScreenName, nextWallpaper);
                        } else {
                            SessionData.setWallpaper(nextWallpaper);
                        }
                    }
                }
            }
        }
    }

    Process {
        id: prevCyclingProcess

        property string targetScreenName: ""
        property string currentWallpaper: ""

        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    const files = text.trim().split('\n').filter(file => file.length > 0);
                    if (files.length <= 1)
                        return;
                    const wallpaperList = files.sort();
                    const currentPath = prevCyclingProcess.currentWallpaper;
                    let currentIndex = wallpaperList.findIndex(path => path === currentPath);
                    if (currentIndex === -1)
                        currentIndex = 0;

                    const prevIndex = currentIndex === 0 ? wallpaperList.length - 1 : currentIndex - 1;
                    const prevWallpaper = wallpaperList[prevIndex];

                    if (prevWallpaper && prevWallpaper !== currentPath) {
                        if (prevCyclingProcess.targetScreenName) {
                            SessionData.setMonitorWallpaper(prevCyclingProcess.targetScreenName, prevWallpaper);
                        } else {
                            SessionData.setWallpaper(prevWallpaper);
                        }
                    }
                }
            }
        }
    }
}
