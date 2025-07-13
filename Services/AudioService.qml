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
    
    // Microphone properties
    property int micLevel: 50
    property var audioSources: []
    property string currentAudioSource: ""
    
    // Real Audio Control
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
    
    // Microphone level checker
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
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let sinks = []
                    let lines = text.trim().split('\n')
                    
                    let currentSink = null
                    
                    for (let line of lines) {
                        line = line.trim()
                        
                        // New sink starts
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
                        // Get the Name field  
                        else if (line.startsWith('Name: ') && currentSink) {
                            currentSink.name = line.replace('Name: ', '').trim()
                        }
                        // Get the Description field (main display name)
                        else if (line.startsWith('Description: ') && currentSink) {
                            currentSink.description = line.replace('Description: ', '').trim()
                        }
                        // Get device.description as fallback
                        else if (line.includes('device.description = ') && currentSink && !currentSink.description) {
                            currentSink.description = line.replace('device.description = ', '').replace(/"/g, '').trim()
                        }
                        // Get node.nick as another fallback option
                        else if (line.includes('node.nick = ') && currentSink && !currentSink.description) {
                            currentSink.nick = line.replace('node.nick = ', '').replace(/"/g, '').trim()
                        }
                    }
                    
                    // Add the last sink
                    if (currentSink && currentSink.name && currentSink.id) {
                        sinks.push(currentSink)
                    }
                    
                    // Process display names
                    for (let sink of sinks) {
                        let displayName = sink.description
                        
                        // If no good description, try nick
                        if (!displayName || displayName === sink.name) {
                            displayName = sink.nick
                        }
                        
                        // Still no good name? Fall back to smart defaults
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
    
    // Audio source (microphone) lister
    Process {
        id: audioSourceLister
        command: ["pactl", "list", "sources"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let sources = []
                    let lines = text.trim().split('\n')
                    
                    let currentSource = null
                    
                    for (let line of lines) {
                        line = line.trim()
                        
                        // New source starts
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
                        // Source name
                        else if (line.startsWith('Name: ') && currentSource) {
                            currentSource.name = line.replace('Name: ', '')
                        }
                        // Description (display name)
                        else if (line.startsWith('Description: ') && currentSource) {
                            let desc = line.replace('Description: ', '')
                            currentSource.displayName = desc
                        }
                    }
                    
                    // Add the last source
                    if (currentSource && currentSource.name && currentSource.id) {
                        sources.push(currentSource)
                    }
                    
                    // Filter out monitor sources (we want actual input devices)
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
                    
                    // Update active status in audioSinks
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
    
    // Default source (microphone) checker
    Process {
        id: defaultSourceChecker
        command: ["pactl", "get-default-source"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    root.currentAudioSource = data.trim()
                    
                    // Update active status in audioSources
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
        
        // Use a more reliable approach instead of Qt.createQmlObject
        sinkSetProcess.command = ["pactl", "set-default-sink", sinkName]
        sinkSetProcess.running = true
    }
    
    // Dedicated process for setting audio sink
    Process {
        id: sinkSetProcess
        running: false
        
        onExited: (exitCode) => {
            console.log("Audio sink change exit code:", exitCode)
            if (exitCode === 0) {
                console.log("Audio sink changed successfully")
                // Refresh current sink and list
                defaultSinkChecker.running = true
                audioSinkLister.running = true
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
    
    // Dedicated process for setting audio source
    Process {
        id: sourceSetProcess
        running: false
        
        onExited: (exitCode) => {
            console.log("Audio source change exit code:", exitCode)
            if (exitCode === 0) {
                console.log("Audio source changed successfully")
                // Refresh current source and list
                defaultSourceChecker.running = true
                audioSourceLister.running = true
            } else {
                console.error("Failed to change audio source")
            }
        }
    }
    
    // Timer to refresh audio devices regularly (catches new Bluetooth devices)
    Timer {
        interval: 4000          // 4s refresh to catch new BT devices
        running: true; repeat: true
        onTriggered: {
            audioSinkLister.running = true
            audioSourceLister.running = true
        }
    }
}