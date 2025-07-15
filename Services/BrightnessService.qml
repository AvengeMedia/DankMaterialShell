import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property list<var> ddcMonitors: []
    readonly property list<Monitor> monitors: variants.instances
    property bool brightnessAvailable: false
    property int brightnessLevel: 75
    
    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(function(m) { return m.modelData === screen; });
    }
    
    property var debounceTimer: Timer {
        id: debounceTimer
        interval: 50
        repeat: false
        property int pendingValue: 0
        onTriggered: {
            const focusedMonitor = monitors.find(function(m) { return m.modelData === Quickshell.screens[0]; });
            if (focusedMonitor) {
                focusedMonitor.setBrightness(pendingValue / 100);
            }
        }
    }
    
    function setBrightness(percentage) {
        root.brightnessLevel = percentage;
        debounceTimer.pendingValue = percentage;
        debounceTimer.restart();
    }
    
    function increaseBrightness(): void {
        const focusedMonitor = monitors.find(function(m) { return m.modelData === Quickshell.screens[0]; });
        if (focusedMonitor)
            focusedMonitor.setBrightness(focusedMonitor.brightness + 0.1);
    }
    
    function decreaseBrightness(): void {
        const focusedMonitor = monitors.find(function(m) { return m.modelData === Quickshell.screens[0]; });
        if (focusedMonitor)
            focusedMonitor.setBrightness(focusedMonitor.brightness - 0.1);
    }
    
    onMonitorsChanged: {
        ddcMonitors = [];
        if (ddcAvailable) {
            ddcProc.running = true;
        }
        
        // Update brightness level from first monitor
        if (monitors.length > 0) {
            root.brightnessLevel = Math.round(monitors[0].brightness * 100);
        }
    }
    
    Component.onCompleted: {
        ddcAvailabilityChecker.running = true;
    }
    
    Variants {
        id: variants
        model: Quickshell.screens
        Monitor {}
    }
    
    Process {
        id: ddcAvailabilityChecker
        command: ["which", "ddcutil"]
        onExited: function(exitCode) {
            root.brightnessAvailable = (exitCode === 0);
            if (root.brightnessAvailable) {
                ddcProc.running = true;
            }
        }
    }
    
    Process {
        id: ddcProc
        command: ["ddcutil", "detect", "--brief"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    root.ddcMonitors = text.trim().split("\n\n").filter(function(d) { return d.startsWith("Display "); }).map(function(d) { return ({
                        model: d.match(/Monitor:.*:(.*):.*/)?.[1] || "Unknown",
                        busNum: d.match(/I2C bus:[ ]*\/dev\/i2c-([0-9]+)/)?.[1] || "0"
                    }); });
                } else {
                    root.ddcMonitors = [];
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.ddcMonitors = [];
            }
        }
    }
    
    component Monitor: QtObject {
        id: monitor
        
        required property ShellScreen modelData
        readonly property bool isDdc: root.ddcMonitors.some(function(m) { return m.model === modelData.model; })
        readonly property string busNum: root.ddcMonitors.find(function(m) { return m.model === modelData.model; })?.busNum ?? ""
        property real brightness: 0.75
        
        readonly property Process initProc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim()) {
                        const parts = text.trim().split(" ");
                        if (parts.length >= 5) {
                            const current = parseInt(parts[3]) || 75;
                            const max = parseInt(parts[4]) || 100;
                            monitor.brightness = current / max;
                            root.brightnessLevel = Math.round(monitor.brightness * 100);
                        }
                    }
                }
            }
            onExited: function(exitCode) {
                if (exitCode !== 0) {
                    monitor.brightness = 0.75;
                    root.brightnessLevel = 75;
                }
            }
        }
        
        function setBrightness(value: real): void {
            value = Math.max(0, Math.min(1, value));
            const rounded = Math.round(value * 100);
            if (Math.round(brightness * 100) === rounded)
                return;
            
            brightness = value;
            root.brightnessLevel = rounded;
            
            if (isDdc && busNum) {
                Quickshell.execDetached(["ddcutil", "-b", busNum, "setvcp", "10", rounded.toString()]);
            }
        }
        
        onBusNumChanged: {
            if (isDdc && busNum) {
                initProc.command = ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"];
                initProc.running = true;
            }
        }
        
        Component.onCompleted: {
            Qt.callLater(function() {
                if (isDdc && busNum) {
                    initProc.command = ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"];
                    initProc.running = true;
                }
            });
        }
    }
}