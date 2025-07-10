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
        command: ["bash", "-c", "pactl list sinks | grep -E '^Sink #|device.description|Name:' | paste - - - | sed 's/Sink #//g' | sed 's/Name: //g' | sed 's/device.description = //g' | sed 's/\"//g'"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let sinks = []
                    let lines = text.trim().split('\n')
                    
                    for (let line of lines) {
                        let parts = line.split('\t')
                        if (parts.length >= 3) {
                            let id = parts[0].trim()
                            let name = parts[1].trim()
                            let description = parts[2].trim()
                            
                            // Use description as display name if available, fallback to name processing
                            let displayName = description
                            if (!description || description === name) {
                                if (name.includes("analog-stereo")) displayName = "Built-in Speakers"
                                else if (name.includes("bluez")) displayName = "Bluetooth Audio"
                                else if (name.includes("usb")) displayName = "USB Audio"
                                else if (name.includes("hdmi")) displayName = "HDMI Audio"
                                else if (name.includes("easyeffects")) displayName = "EasyEffects"
                                else displayName = name
                            }
                            
                            sinks.push({
                                id: id,
                                name: name,
                                displayName: displayName,
                                active: false // Will be determined by default sink
                            })
                        }
                    }
                    
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
        let sinkSetProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["pactl", "set-default-sink", "' + sinkName + '"]
                running: true
                onExited: {
                    defaultSinkChecker.running = true
                    audioSinkLister.running = true
                }
            }
        ', root)
    }
}