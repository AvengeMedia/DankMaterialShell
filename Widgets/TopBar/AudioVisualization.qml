import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../Common"

Item {
    id: root
    
    property list<real> audioLevels: [0, 0, 0, 0]
    property bool hasActiveMedia: false
    property var activePlayer: null
    property bool cavaAvailable: false
    
    width: 20
    height: Theme.iconSize
    
    Process {
        id: cavaCheck
        command: ["which", "cava"]
        running: true
        onExited: (exitCode) => {
            root.cavaAvailable = exitCode === 0
            if (root.cavaAvailable) {
                console.log("cava found - creating config and enabling real audio visualization")
                configWriter.running = true
            } else {
                console.log("cava not found - using fallback animation")
                fallbackTimer.running = Qt.binding(() => root.hasActiveMedia && root.activePlayer?.playbackState === MprisPlaybackState.Playing)
            }
        }
    }
    
    Process {
        id: configWriter
        running: root.cavaAvailable
        command: [
            "sh", "-c", 
            `cat > /tmp/quickshell_cava_config << 'EOF'
[general]
mode = normal
framerate = 30
autosens = 0
sensitivity = 50
bars = 4

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
channels = mono
mono_option = average

[smoothing]
noise_reduction = 20
EOF`
        ]
        
        onExited: {
            if (root.cavaAvailable) {
                cavaProcess.running = Qt.binding(() => root.hasActiveMedia && root.activePlayer?.playbackState === MprisPlaybackState.Playing)
            }
        }
    }

    Process {
        id: cavaProcess
        running: false
        command: ["cava", "-p", "/tmp/quickshell_cava_config"]
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim()) {
                    let points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
                    if (points.length >= 4) {
                        root.audioLevels = [points[0], points[1], points[2], points[3]]
                    }
                }
            }
        }
        
        onRunningChanged: {
            if (!running) {
                root.audioLevels = [0, 0, 0, 0]
            }
        }
    }
    
    Timer {
        id: fallbackTimer
        running: false
        interval: 100
        repeat: true
        onTriggered: {
            root.audioLevels = [
                Math.random() * 40 + 10,
                Math.random() * 60 + 20,
                Math.random() * 50 + 15,
                Math.random() * 35 + 20
            ]
        }
    }
    
    Row {
        anchors.centerIn: parent
        spacing: 2
        
        Repeater {
            model: 4
            
            Rectangle {
                width: 3
                height: {
                    if (root.activePlayer?.playbackState === MprisPlaybackState.Playing && root.audioLevels.length > index) {
                        const rawLevel = root.audioLevels[index] || 0
                        const scaledLevel = Math.sqrt(Math.min(Math.max(rawLevel, 0), 100) / 100) * 100
                        const maxHeight = Theme.iconSize - 2
                        const minHeight = 3
                        return minHeight + (scaledLevel / 100) * (maxHeight - minHeight)
                    }
                    return 3
                }
                radius: 1.5
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
                
                Behavior on height {
                    NumberAnimation {
                        duration: 80
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }
}