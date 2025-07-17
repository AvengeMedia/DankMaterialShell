import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Common
import qs.Services

Item {
    id: root
    
    property list<real> audioLevels: [0, 0, 0, 0]
    readonly property MprisPlayer  activePlayer: MprisController.activePlayer 
    readonly property bool hasActiveMedia: activePlayer !== null 
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
                console.log("cava found - enabling real audio visualization")
                cavaProcess.running = Qt.binding(() => root.hasActiveMedia && root.activePlayer?.playbackState === MprisPlaybackState.Playing)
            } else {
                console.log("cava not found - using fallback animation")
                fallbackTimer.running = Qt.binding(() => root.hasActiveMedia && root.activePlayer?.playbackState === MprisPlaybackState.Playing)
            }
        }
    }

    Process {
        id: cavaProcess
        running: false
        command: ["sh", "-c", `printf '[general]\nmode=normal\nframerate=30\nautosens=0\nsensitivity=50\nbars=4\n[output]\nmethod=raw\nraw_target=/dev/stdout\ndata_format=ascii\nchannels=mono\nmono_option=average\n[smoothing]\nnoise_reduction=20' | cava -p /dev/stdin`]
        
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