import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property MprisPlayer activePlayer
    property real value: {
        if (!activePlayer || activePlayer.length <= 0) return 0
        const pos = (activePlayer.position || 0) % Math.max(1, activePlayer.length)
        const calculatedRatio = pos / activePlayer.length
        return Math.max(0, Math.min(1, calculatedRatio))
    }
    property bool isSeeking: false

    implicitHeight: 20

    Loader {
        anchors.fill: parent
        visible: activePlayer && activePlayer.length > 0
        sourceComponent: SettingsData.waveProgressEnabled ? waveProgressComponent : flatProgressComponent
        z: 1

        Component {
            id: waveProgressComponent

            M3WaveProgress {
                value: root.value
                isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: activePlayer && activePlayer.canSeek && activePlayer.length > 0

                    property real pendingSeekPosition: -1

                    Timer {
                        id: waveSeekDebounceTimer
                        interval: 150
                        onTriggered: {
                            if (parent.pendingSeekPosition >= 0 && activePlayer && activePlayer.canSeek && activePlayer.length > 0) {
                                const clamped = Math.min(parent.pendingSeekPosition, activePlayer.length * 0.99)
                                activePlayer.position = clamped
                                parent.pendingSeekPosition = -1
                            }
                        }
                    }

                    onPressed: (mouse) => {
                        root.isSeeking = true
                        if (activePlayer && activePlayer.length > 0 && activePlayer.canSeek) {
                            const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                            pendingSeekPosition = r * activePlayer.length
                            waveSeekDebounceTimer.restart()
                        }
                    }
                    onReleased: {
                        root.isSeeking = false
                        waveSeekDebounceTimer.stop()
                        if (pendingSeekPosition >= 0 && activePlayer && activePlayer.canSeek && activePlayer.length > 0) {
                            const clamped = Math.min(pendingSeekPosition, activePlayer.length * 0.99)
                            activePlayer.position = clamped
                            pendingSeekPosition = -1
                        }
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed && root.isSeeking && activePlayer && activePlayer.length > 0 && activePlayer.canSeek) {
                            const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                            pendingSeekPosition = r * activePlayer.length
                            waveSeekDebounceTimer.restart()
                        }
                    }
                    onClicked: (mouse) => {
                        if (activePlayer && activePlayer.length > 0 && activePlayer.canSeek) {
                            const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                            activePlayer.position = r * activePlayer.length
                        }
                    }
                }
            }
        }

        Component {
            id: flatProgressComponent

            Item {
                property real lineWidth: 3
                property color trackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
                property color fillColor: Theme.primary
                property color playheadColor: Theme.primary
                readonly property real midY: height / 2

                Rectangle {
                    width: parent.width
                    height: parent.lineWidth
                    anchors.verticalCenter: parent.verticalCenter
                    color: parent.trackColor
                    radius: height / 2
                }

                Rectangle {
                    width: Math.max(0, Math.min(parent.width, parent.width * root.value))
                    height: parent.lineWidth
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: parent.fillColor
                    radius: height / 2
                    Behavior on width { NumberAnimation { duration: 80 } }
                }

                Rectangle {
                    id: playhead
                    width: 3
                    height: Math.max(parent.lineWidth + 8, 14)
                    radius: width / 2
                    color: parent.playheadColor
                    x: Math.max(0, Math.min(parent.width, parent.width * root.value)) - width / 2
                    y: parent.midY - height / 2
                    z: 3
                    Behavior on x { NumberAnimation { duration: 80 } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: activePlayer && activePlayer.canSeek && activePlayer.length > 0

                    property real pendingSeekPosition: -1

                    Timer {
                        id: flatSeekDebounceTimer
                        interval: 150
                        onTriggered: {
                            if (parent.pendingSeekPosition >= 0 && activePlayer && activePlayer.canSeek && activePlayer.length > 0) {
                                const clamped = Math.min(parent.pendingSeekPosition, activePlayer.length * 0.99)
                                activePlayer.position = clamped
                                parent.pendingSeekPosition = -1
                            }
                        }
                    }

                    onPressed: (mouse) => {
                        root.isSeeking = true
                        if (activePlayer && activePlayer.length > 0 && activePlayer.canSeek) {
                            const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                            pendingSeekPosition = r * activePlayer.length
                            flatSeekDebounceTimer.restart()
                        }
                    }
                    onReleased: {
                        root.isSeeking = false
                        flatSeekDebounceTimer.stop()
                        if (pendingSeekPosition >= 0 && activePlayer && activePlayer.canSeek && activePlayer.length > 0) {
                            const clamped = Math.min(pendingSeekPosition, activePlayer.length * 0.99)
                            activePlayer.position = clamped
                            pendingSeekPosition = -1
                        }
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed && root.isSeeking && activePlayer && activePlayer.length > 0 && activePlayer.canSeek) {
                            const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                            pendingSeekPosition = r * activePlayer.length
                            flatSeekDebounceTimer.restart()
                        }
                    }
                    onClicked: (mouse) => {
                        if (activePlayer && activePlayer.length > 0 && activePlayer.canSeek) {
                            const r = Math.max(0, Math.min(1, mouse.x / parent.width))
                            activePlayer.position = r * activePlayer.length
                        }
                    }
                }
            }
        }
    }
}
