pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell.Io
import qs.Common
import qs.Services

Item {
    id: root

    required property string screenName
    property bool active: false
    property string videoSource: ""
    property bool inputEnabled: false
    property point lastMousePos: Qt.point(-1, -1)
    property bool mouseInitialized: false

    signal dismissed

    visible: active
    z: 1000

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: root.active
    }

    Video {
        id: videoPlayer
        anchors.fill: parent
        source: root.videoSource
        fillMode: VideoOutput.PreserveAspectCrop
        loops: MediaPlayer.Infinite
        volume: 0

        onSourceChanged: {
            console.log("VideoScreensaver: source changed to", source);
            if (source && root.active) {
                play();
            }
        }

        onErrorOccurred: (error, errorString) => {
            console.warn("VideoScreensaver: playback error:", errorString);
            ToastService.showError(I18n.tr("Video Screensaver"), I18n.tr("Playback error: ") + errorString);
            root.dismiss();
        }
    }

    Timer {
        id: inputEnableTimer
        interval: 500
        onTriggered: {
            console.log("VideoScreensaver: input now enabled");
            root.inputEnabled = true;
        }
    }

    Process {
        id: videoPicker
        property string result: ""
        property string folder: ""

        // random picker
        command: ["sh", "-c", "find '" + folder + "' -maxdepth 1 -type f \\( " + "-iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o " + "-iname '*.mov' -o -iname '*.avi' -o -iname '*.m4v' " + "\\) 2>/dev/null | shuf -n1"]

        stdout: SplitParser {
            onRead: data => {
                const path = data.trim();
                console.log("VideoScreensaver: found video:", path);
                if (path) {
                    videoPicker.result = path;
                    root.videoSource = "file://" + path;
                }
            }
        }

        onExited: exitCode => {
            console.log("VideoScreensaver: videoPicker exited with code", exitCode, "result:", videoPicker.result);
            if (exitCode !== 0 || !videoPicker.result) {
                console.warn("VideoScreensaver: no video found");
                ToastService.showError(I18n.tr("Video Screensaver"), I18n.tr("No video found in folder"));
                root.dismiss();
            }
        }
    }

    function start() {
        console.log("VideoScreensaver: start() called, enabled:", SettingsData.lockScreenVideoEnabled, "path:", SettingsData.lockScreenVideoPath, "cycling:", SettingsData.lockScreenVideoCycling);
        if (!SettingsData.lockScreenVideoEnabled || !SettingsData.lockScreenVideoPath)
            return;
        videoPicker.result = "";
        videoPicker.folder = "";
        inputEnabled = false;
        mouseInitialized = false;
        lastMousePos = Qt.point(-1, -1);
        active = true;
        inputEnableTimer.start();
        fileChecker.running = true;
    }

    Process {
        id: fileChecker
        command: ["test", "-d", SettingsData.lockScreenVideoPath]

        onExited: exitCode => {
            const isDir = exitCode === 0;
            const videoPath = SettingsData.lockScreenVideoPath;
            console.log("VideoScreensaver: fileChecker exited, isDir:", isDir, "cycling:", SettingsData.lockScreenVideoCycling);

            if (isDir) {
                videoPicker.folder = videoPath;
                videoPicker.running = true;
            } else if (SettingsData.lockScreenVideoCycling) {
                const parentFolder = videoPath.substring(0, videoPath.lastIndexOf('/'));
                console.log("VideoScreensaver: resolved parent folder:", parentFolder);
                videoPicker.folder = parentFolder;
                videoPicker.running = true;
            } else {
                root.videoSource = "file://" + videoPath;
            }
        }
    }

    function dismiss() {
        if (!active)
            return;
        console.log("VideoScreensaver: dismiss() called");
        videoPlayer.stop();
        inputEnabled = false;
        active = false;
        videoSource = "";
        dismissed();
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.active && root.inputEnabled
        hoverEnabled: true
        propagateComposedEvents: false

        onPositionChanged: mouse => {
            if (!root.mouseInitialized) {
                console.log("VideoScreensaver: mouse initialized at", mouse.x, mouse.y);
                root.lastMousePos = Qt.point(mouse.x, mouse.y);
                root.mouseInitialized = true;
                return;
            }
            var dx = Math.abs(mouse.x - root.lastMousePos.x);
            var dy = Math.abs(mouse.y - root.lastMousePos.y);
            if (dx > 5 || dy > 5) {
                console.log("VideoScreensaver: mouse moved by", dx, dy);
                root.dismiss();
            }
        }
        onClicked: {
            console.log("VideoScreensaver: mouse clicked");
            root.dismiss();
        }
        onPressed: {
            console.log("VideoScreensaver: mouse pressed");
            root.dismiss();
        }
        onWheel: {
            console.log("VideoScreensaver: mouse wheel");
            root.dismiss();
        }
    }

    onActiveChanged: {
        console.log("VideoScreensaver: active changed to", active);
    }

    Connections {
        target: IdleService

        function onLockRequested() {
            if (SettingsData.lockScreenVideoEnabled && !root.active) {
                console.log("VideoScreensaver: idle timeout while locked, restarting");
                root.start();
            }
        }

        function onFadeToLockRequested() {
            if (SettingsData.lockScreenVideoEnabled && !root.active) {
                console.log("VideoScreensaver: fade-to-lock while locked, restarting");
                IdleService.cancelFadeToLock();
                root.start();
            }
        }
    }
}
