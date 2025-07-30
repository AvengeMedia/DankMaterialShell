import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Common
import qs.Services

Item {
    id: root

    property var audioLevels: [0, 0, 0, 0, 0, 0]
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool hasActiveMedia: activePlayer !== null
    property bool cavaAvailable: false

    width: 20
    height: Theme.iconSize

    Process {
        id: cavaCheck

        command: ["which", "cava"]
        running: true
        onExited: (exitCode) => {
            root.cavaAvailable = exitCode === 0;
            if (root.cavaAvailable)
                cavaProcess.running = Qt.binding(() => {
                return root.hasActiveMedia && root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing;
            });
            else
                fallbackTimer.running = Qt.binding(() => {
                return root.hasActiveMedia && root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing;
            });
        }
    }

    Process {
        id: cavaProcess

        running: false
        command: ["sh", "-c", `printf '[general]\nmode=normal\nframerate=25\nautosens=0\nsensitivity=30\nbars=6\nlower_cutoff_freq=50\nhigher_cutoff_freq=12000\n[output]\nmethod=raw\nraw_target=/dev/stdout\ndata_format=ascii\nchannels=mono\nmono_option=average\n[smoothing]\nnoise_reduction=35\nintegral=90\ngravity=95\nignore=2\nmonstercat=1.5' | cava -p /dev/stdin`]
        onRunningChanged: {
            if (!running)
                root.audioLevels = [0, 0, 0, 0, 0, 0];

        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let points = data.split(";").map((p) => {
                        return parseFloat(p.trim());
                    }).filter((p) => {
                        return !isNaN(p);
                    });
                    if (points.length >= 6)
                        root.audioLevels = [points[0], points[1], points[2], points[3], points[4], points[5]];

                }
            }
        }

    }

    Timer {
        id: fallbackTimer

        running: false
        interval: 256
        repeat: true
        onTriggered: {
            root.audioLevels = [Math.random() * 40 + 10, Math.random() * 60 + 20, Math.random() * 50 + 15, Math.random() * 35 + 20, Math.random() * 45 + 15, Math.random() * 55 + 25];
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 1.5

        Repeater {
            model: 6

            Rectangle {
                width: 2
                height: {
                    if (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing && root.audioLevels.length > index) {
                        const rawLevel = root.audioLevels[index] || 0;
                        const scaledLevel = Math.sqrt(Math.min(Math.max(rawLevel, 0), 100) / 100) * 100;
                        const maxHeight = Theme.iconSize - 2;
                        const minHeight = 3;
                        return minHeight + (scaledLevel / 100) * (maxHeight - minHeight);
                    }
                    return 3;
                }
                radius: 1.5
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation {
                        duration: Anims.durShort
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Anims.standardDecel
                    }

                }

            }

        }

    }

}
