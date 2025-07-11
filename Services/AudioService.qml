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
    
    Process {
        id: audioSinkLister
        command: ["pactl", "list", "sinks"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.log("Parsing pactl sink output...")
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
                                active: false
                            }
                        }
                        // Get the Name field  
                        else if (line.startsWith('Name: ') && currentSink) {
                            currentSink.name = line.replace('Name: ', '').trim()
                        }
                        // Get description
                        else if (line.includes('device.description = ') && currentSink) {
                            currentSink.description = line.replace('device.description = ', '').replace(/"/g, '').trim()
                        }
                    }
                    
                    // Add the last sink
                    if (currentSink && currentSink.name && currentSink.id) {
                        sinks.push(currentSink)
                    }
                    
                    // Process display names
                    for (let sink of sinks) {
                        let displayName = sink.description
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
                    
                    console.log("Final audio sinks:", JSON.stringify(sinks, null, 2))
                    root.audioSinks = sinks
                    defaultSinkChecker.running = true
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
                    console.log("Default audio sink:", root.currentAudioSink)
                    
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
}