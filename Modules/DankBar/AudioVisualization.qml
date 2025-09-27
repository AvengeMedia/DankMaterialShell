import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services

Item {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool hasActiveMedia: activePlayer !== null
    readonly property bool isPlaying: hasActiveMedia && activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

    width: 20
    height: Theme.iconSize

    Loader {
        active: isPlaying

        sourceComponent: Component {
            Ref {
                service: CavaService
            }

        }

    }

    Timer {
        id: fallbackTimer

        running: !CavaService.cavaAvailable && isPlaying
        interval: 256
        repeat: true
        onTriggered: {
            CavaService.values = [Math.random() * 40 + 10, Math.random() * 60 + 20, Math.random() * 50 + 15, Math.random() * 35 + 20, Math.random() * 45 + 15, Math.random() * 55 + 25];
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
                    if (root.isPlaying && CavaService.values.length > index) {
                        const rawLevel = CavaService.values[index] || 0;
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
