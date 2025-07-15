import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property int volumeLevel: 50
    property var audioSinks: []
    property string currentAudioSink: ""
    
    property int micLevel: 50
    property var audioSources: []
    property string currentAudioSource: ""
    
    property bool deviceScanningEnabled: false
    property bool initialScanComplete: false
    Process {
        id: volumeChecker
        command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ | grep -o '[0-9]*%' | head -1 | tr -d '%'"]
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    root.volumeLevel = Math.min(100, parseInt(data.trim()) || 50)
                }
            }
        }
    }
    
    Process {
        id: micLevelChecker
        command: ["bash", "-c", "pactl get-source-volume @DEFAULT_SOURCE@ | grep -o '[0-9]*%' | head -1 | tr -d '%'"]
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    root.micLevel = Math.min(100, parseInt(data.trim()) || 50)
                }
            }
        }
    }
    
    Process {
        id: audioSinkLister
        command: ["pactl", "list", "sinks"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let sinks = []
                    let lines = text.trim().split('\n')
                    
                    let currentSink = null
                    
                    for (let line of lines) {
                        line = line.trim()
                        
                        if (line.startsWith('Sink #')) {
                            if (currentSink && currentSink.name && currentSink.id) {
                                sinks.push(currentSink)
                            }
                            
                            let sinkId = line.replace('Sink #', '').trim()
                            currentSink = {
                                id: sinkId,
                                name: "",
                                displayName: "",
                                description: "",
                                nick: "",
                                active: false
                            }
                        }
                        else if (line.startsWith('Name: ') && currentSink) {
                            currentSink.name = line.replace('Name: ', '').trim()
                        }
                        else if (line.startsWith('Description: ') && currentSink) {
                            currentSink.description = line.replace('Description: ', '').trim()
                        }
                        else if (line.includes('device.description = ') && currentSink && !currentSink.description) {
                            currentSink.description = line.replace('device.description = ', '').replace(/"/g, '').trim()
                        }
                        else if (line.includes('node.nick = ') && currentSink && !currentSink.description) {
                            currentSink.nick = line.replace('node.nick = ', '').replace(/"/g, '').trim()
                        }
                    }
                    
                    if (currentSink && currentSink.name && currentSink.id) {
                        sinks.push(currentSink)
                    }
                    
                    for (let sink of sinks) {
                        let displayName = sink.description
                        
                        if (!displayName || displayName === sink.name) {
                            displayName = sink.nick
                        }
                        
                        if (!displayName || displayName === sink.name) {
                            if (sink.name.includes("analog-stereo")) displayName = "Built-in Speakers"
                            else if (sink.name.includes("bluez")) displayName = "Bluetooth Audio"
                            else if (sink.name.includes("usb")) displayName = "USB Audio"
                            else if (sink.name.includes("hdmi")) displayName = "HDMI Audio"
                            else if (sink.name.includes("easyeffects")) displayName = "EasyEffects"
                            else displayName = sink.name
                        }
                        
                        sink.displayName = displayName
                    }
                    
                    root.audioSinks = sinks
                    defaultSinkChecker.running = true
                }
            }
        }
    }
    
    Process {
        id: audioSourceLister
        command: ["pactl", "list", "sources"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let sources = []
                    let lines = text.trim().split('\n')
                    
                    let currentSource = null
                    
                    for (let line of lines) {
                        line = line.trim()
                        
                        if (line.startsWith('Source #')) {
                            if (currentSource && currentSource.name && currentSource.id) {
                                sources.push(currentSource)
                            }
                            currentSource = {
                                id: line.replace('Source #', '').replace(':', ''),
                                name: '',
                                displayName: '',
                                active: false
                            }
                        }
                        else if (line.startsWith('Name: ') && currentSource) {
                            currentSource.name = line.replace('Name: ', '')
                        }
                        else if (line.startsWith('Description: ') && currentSource) {
                            let desc = line.replace('Description: ', '')
                            currentSource.displayName = desc
                        }
                    }
                    
                    if (currentSource && currentSource.name && currentSource.id) {
                        sources.push(currentSource)
                    }
                    
                    sources = sources.filter(source => !source.name.includes('.monitor'))
                    
                    root.audioSources = sources
                    defaultSourceChecker.running = true
                }
            }
        }
    }
    
    Process {
        id: defaultSinkChecker
        command: ["pactl", "get-default-sink"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    root.currentAudioSink = data.trim()
                    
                    let updatedSinks = []
                    for (let sink of root.audioSinks) {
                        updatedSinks.push({
                            id: sink.id,
                            name: sink.name,
                            displayName: sink.displayName,
                            active: sink.name === root.currentAudioSink
                        })
                    }
                    root.audioSinks = updatedSinks
                }
            }
        }
    }
    
    Process {
        id: defaultSourceChecker
        command: ["pactl", "get-default-source"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    root.currentAudioSource = data.trim()
                    
                    let updatedSources = []
                    for (let source of root.audioSources) {
                        updatedSources.push({
                            id: source.id,
                            name: source.name,
                            displayName: source.displayName,
                            active: source.name === root.currentAudioSource
                        })
                    }
                    root.audioSources = updatedSources
                }
            }
        }
    }
    
    function setVolume(percentage) {
        let volumeSetProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "' + percentage + '%"]
                running: true
                onExited: volumeChecker.running = true
            }
        ', root)
    }
    
    function setMicLevel(percentage) {
        let micSetProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["pactl", "set-source-volume", "@DEFAULT_SOURCE@", "' + percentage + '%"]
                running: true
                onExited: micLevelChecker.running = true
            }
        ', root)
    }
    
    function setAudioSink(sinkName) {
        console.log("Setting audio sink to:", sinkName)
        
        sinkSetProcess.command = ["pactl", "set-default-sink", sinkName]
        sinkSetProcess.running = true
    }
    
    Process {
        id: sinkSetProcess
        running: false
        
        onExited: (exitCode) => {
            console.log("Audio sink change exit code:", exitCode)
            if (exitCode === 0) {
                console.log("Audio sink changed successfully")
                defaultSinkChecker.running = true
                if (root.deviceScanningEnabled) {
                    audioSinkLister.running = true
                }
            } else {
                console.error("Failed to change audio sink")
            }
        }
    }
    
    function setAudioSource(sourceName) {
        console.log("Setting audio source to:", sourceName)
        
        sourceSetProcess.command = ["pactl", "set-default-source", sourceName]
        sourceSetProcess.running = true
    }
    
    Process {
        id: sourceSetProcess
        running: false
        
        onExited: (exitCode) => {
            console.log("Audio source change exit code:", exitCode)
            if (exitCode === 0) {
                console.log("Audio source changed successfully")
                defaultSourceChecker.running = true
                if (root.deviceScanningEnabled) {
                    audioSourceLister.running = true
                }
            } else {
                console.error("Failed to change audio source")
            }
        }
    }
    
    Timer {
        interval: 5000
        running: root.deviceScanningEnabled && root.initialScanComplete
        repeat: true
        onTriggered: {
            if (root.deviceScanningEnabled) {
                audioSinkLister.running = true
                audioSourceLister.running = true
            }
        }
    }
    
    Component.onCompleted: {
        console.log("AudioService: Starting initialization...")
        audioSinkLister.running = true
        audioSourceLister.running = true
        initialScanComplete = true
        console.log("AudioService: Initialization complete")
    }
    
    function enableDeviceScanning(enabled) {
        console.log("AudioService: Device scanning", enabled ? "enabled" : "disabled")
        root.deviceScanningEnabled = enabled
        if (enabled && root.initialScanComplete) {
            audioSinkLister.running = true
            audioSourceLister.running = true
        }
    }
    
    function refreshDevices() {
        console.log("AudioService: Manual device refresh triggered")
        audioSinkLister.running = true
        audioSourceLister.running = true
    }
}