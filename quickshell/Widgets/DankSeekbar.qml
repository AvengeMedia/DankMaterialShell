import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property MprisPlayer activePlayer
    property real seekPreviewRatio: -1
    readonly property real playerValue: {
        if (!activePlayer || activePlayer.length <= 0)
            return 0;
        const pos = (activePlayer.position || 0) % Math.max(1, activePlayer.length);
        const calculatedRatio = pos / activePlayer.length;
        return Math.max(0, Math.min(1, calculatedRatio));
    }
    property real value: seekPreviewRatio >= 0 ? seekPreviewRatio : playerValue
    property bool isSeeking: false
    property bool isDraggingSeek: false
    property real committedSeekRatio: -1
    property int previewSettleChecksRemaining: 0
    property real dragThreshold: 4
    property int holdIndicatorDelay: 180

    function clampRatio(ratio) {
        return Math.max(0, Math.min(1, ratio));
    }

    function ratioForPosition(position) {
        if (!activePlayer || activePlayer.length <= 0)
            return 0;
        return clampRatio(position / activePlayer.length);
    }

    function positionForRatio(ratio) {
        if (!activePlayer || activePlayer.length <= 0)
            return 0;
        const rawPosition = clampRatio(ratio) * activePlayer.length;
        return Math.min(rawPosition, activePlayer.length * 0.99);
    }

    function updatePreviewFromMouse(mouseX, width) {
        if (!activePlayer || activePlayer.length <= 0 || width <= 0)
            return;
        seekPreviewRatio = clampRatio(mouseX / width);
    }

    function clearCommittedSeekPreview() {
        previewSettleTimer.stop();
        committedSeekRatio = -1;
        previewSettleChecksRemaining = 0;
        if (!isSeeking)
            seekPreviewRatio = -1;
    }

    function beginCommittedSeekPreview(position) {
        seekPreviewRatio = ratioForPosition(position);
        committedSeekRatio = seekPreviewRatio;
        previewSettleChecksRemaining = 15;
        previewSettleTimer.restart();
    }

    function handleSeekPressed(mouse, width, mouseArea, holdTimer) {
        isSeeking = true;
        isDraggingSeek = false;
        mouseArea.pressX = mouse.x;
        clearCommittedSeekPreview();
        holdTimer.restart();
        if (activePlayer && activePlayer.length > 0 && activePlayer.canSeek) {
            updatePreviewFromMouse(mouse.x, width);
            mouseArea.pendingSeekPosition = positionForRatio(seekPreviewRatio);
        }
    }

    function handleSeekReleased(mouseArea, holdTimer) {
        holdTimer.stop();
        isSeeking = false;
        isDraggingSeek = false;
        if (mouseArea.pendingSeekPosition >= 0 && activePlayer && activePlayer.canSeek && activePlayer.length > 0) {
            const clamped = Math.min(mouseArea.pendingSeekPosition, activePlayer.length * 0.99);
            activePlayer.position = clamped;
            mouseArea.pendingSeekPosition = -1;
            beginCommittedSeekPreview(clamped);
        } else {
            seekPreviewRatio = -1;
        }
    }

    function handleSeekPositionChanged(mouse, width, mouseArea) {
        if (mouseArea.pressed && isSeeking && activePlayer && activePlayer.length > 0 && activePlayer.canSeek) {
            if (!isDraggingSeek && Math.abs(mouse.x - mouseArea.pressX) >= dragThreshold)
                isDraggingSeek = true;
            updatePreviewFromMouse(mouse.x, width);
            mouseArea.pendingSeekPosition = positionForRatio(seekPreviewRatio);
        }
    }

    function handleSeekCanceled(mouseArea, holdTimer) {
        holdTimer.stop();
        isSeeking = false;
        isDraggingSeek = false;
        mouseArea.pendingSeekPosition = -1;
        clearCommittedSeekPreview();
    }

    Timer {
        id: previewSettleTimer
        interval: 80
        repeat: true
        onTriggered: {
            if (root.isSeeking || root.committedSeekRatio < 0) {
                stop();
                return;
            }

            const previewSettled = Math.abs(root.playerValue - root.committedSeekRatio) <= 0.0015;
            if (previewSettled || root.previewSettleChecksRemaining <= 0) {
                root.clearCommittedSeekPreview();
                return;
            }

            root.previewSettleChecksRemaining -= 1;
        }
    }

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
                actualValue: root.playerValue
                showActualPlaybackState: root.isSeeking
                actualProgressColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
                isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

                MouseArea {
                    id: waveMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: activePlayer && activePlayer.canSeek && activePlayer.length > 0

                    property real pendingSeekPosition: -1
                    property real pressX: 0

                    Timer {
                        id: waveHoldIndicatorTimer
                        interval: root.holdIndicatorDelay
                        repeat: false
                        onTriggered: {
                            if (parent.pressed && root.isSeeking)
                                root.isDraggingSeek = true;
                        }
                    }

                    onPressed: mouse => root.handleSeekPressed(mouse, parent.width, waveMouseArea, waveHoldIndicatorTimer)
                    onReleased: root.handleSeekReleased(waveMouseArea, waveHoldIndicatorTimer)
                    onPositionChanged: mouse => root.handleSeekPositionChanged(mouse, parent.width, waveMouseArea)
                    onCanceled: root.handleSeekCanceled(waveMouseArea, waveHoldIndicatorTimer)
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
                property color actualProgressColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
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
                    Behavior on width {
                        NumberAnimation {
                            duration: 80
                        }
                    }
                }

                Rectangle {
                    visible: root.isDraggingSeek
                    width: 2
                    height: Math.max(parent.lineWidth + 4, 10)
                    radius: width / 2
                    color: parent.actualProgressColor
                    x: Math.max(0, Math.min(parent.width, parent.width * root.playerValue)) - width / 2
                    y: parent.midY - height / 2
                    z: 2
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
                    Behavior on x {
                        NumberAnimation {
                            duration: 80
                        }
                    }
                }

                MouseArea {
                    id: flatMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: activePlayer && activePlayer.canSeek && activePlayer.length > 0

                    property real pendingSeekPosition: -1
                    property real pressX: 0

                    Timer {
                        id: flatHoldIndicatorTimer
                        interval: root.holdIndicatorDelay
                        repeat: false
                        onTriggered: {
                            if (parent.pressed && root.isSeeking)
                                root.isDraggingSeek = true;
                        }
                    }

                    onPressed: mouse => root.handleSeekPressed(mouse, parent.width, flatMouseArea, flatHoldIndicatorTimer)
                    onReleased: root.handleSeekReleased(flatMouseArea, flatHoldIndicatorTimer)
                    onPositionChanged: mouse => root.handleSeekPositionChanged(mouse, parent.width, flatMouseArea)
                    onCanceled: root.handleSeekCanceled(flatMouseArea, flatHoldIndicatorTimer)
                }
            }
        }
    }
}
