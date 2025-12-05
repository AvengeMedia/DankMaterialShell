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

    readonly property real maxBarHeight: Theme.iconSize - 2
    readonly property real minBarHeight: 3
    readonly property real heightRange: maxBarHeight - minBarHeight
    property var barHeights: [minBarHeight, minBarHeight, minBarHeight, minBarHeight, minBarHeight, minBarHeight]

    Timer {
        id: fallbackTimer

        running: !CavaService.cavaAvailable && isPlaying
        interval: 500
        repeat: true
        onTriggered: {
            CavaService.values = [Math.random() * 20 + 5, Math.random() * 25 + 8, Math.random() * 22 + 6, Math.random() * 20 + 5, Math.random() * 22 + 6, Math.random() * 25 + 8];
        }
    }

    Connections {
        target: CavaService
        function onValuesChanged() {
            if (!root.isPlaying) {
                root.barHeights = [root.minBarHeight, root.minBarHeight, root.minBarHeight, root.minBarHeight, root.minBarHeight, root.minBarHeight];
                return;
            }

            const newHeights = [];
            for (let i = 0; i < 6; i++) {
                if (CavaService.values.length <= i) {
                    newHeights.push(root.minBarHeight);
                    continue;
                }

                const rawLevel = CavaService.values[i];
                if (rawLevel <= 0) {
                    newHeights.push(root.minBarHeight);
                } else if (rawLevel >= 100) {
                    newHeights.push(root.maxBarHeight);
                } else {
                    newHeights.push(root.minBarHeight + Math.sqrt(rawLevel * 0.01) * root.heightRange);
                }
            }
            root.barHeights = newHeights;
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 1.5

        Repeater {
            model: 6

            Rectangle {
                width: 2
                height: root.barHeights[index]
                radius: 1.5
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    enabled: root.isPlaying && !CavaService.cavaAvailable
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }
}
