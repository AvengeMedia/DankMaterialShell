pragma Singleton

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool ffmpegAvailable: false
    property var generatingThumbnails: ({}) // Track which thumbnails are being generated
    property string thumbnailDir: {
        const cacheUrl = StandardPaths.writableLocation(StandardPaths.CacheLocation)
        const cachePath = cacheUrl.toString().replace("file://", "")
        return cachePath + "/video-thumbnails"
    }

    signal thumbnailReady(string videoPath, string thumbnailPath)

    Component.onCompleted: {
        checkFfmpegAvailability()
        createThumbnailDirectory()
    }

    function checkFfmpegAvailability() {
        ffmpegCheck.running = true
    }

    function createThumbnailDirectory() {
        createDirProcess.command = ["mkdir", "-p", thumbnailDir]
        createDirProcess.running = true
    }

    function getThumbnailPath(videoPath) {
        // Create a unique filename based on video path and modification time
        const fileName = videoPath.split('/').pop()
        const baseName = fileName.substring(0, fileName.lastIndexOf('.')) || fileName
        const hash = Qt.md5(videoPath)
        return thumbnailDir + "/" + baseName + "_" + hash + ".jpg"
    }

    function hasThumbnail(videoPath) {
        const thumbnailPath = getThumbnailPath(videoPath)
        thumbnailExists.path = thumbnailPath
        return thumbnailExists.exists
    }

    function generateThumbnail(videoPath) {
        if (!ffmpegAvailable) {
            console.warn("VideoThumbnailService: ffmpeg not available, cannot generate thumbnail")
            return ""
        }

        const thumbnailPath = getThumbnailPath(videoPath)

        // Check if already generating
        if (generatingThumbnails[videoPath]) {
            console.log("VideoThumbnailService: Already generating thumbnail for", videoPath)
            return thumbnailPath
        }

        // Skip existence check for now - just generate if not already generating
        console.log("VideoThumbnailService: Generating thumbnail for", videoPath)
        generatingThumbnails[videoPath] = true

        const process = processComponent.createObject(root)
        if (!process) {
            console.error("VideoThumbnailService: Failed to create process")
            delete generatingThumbnails[videoPath]
            return ""
        }

        // Generate thumbnail - simpler approach
        process.command = [
            "ffmpeg", "-y", "-loglevel", "error",
            "-i", videoPath,
            "-ss", "00:00:01",
            "-vframes", "1",
            "-vf", "scale=320:180",
            "-q:v", "3",
            thumbnailPath
        ]
        process.videoPath = videoPath
        process.thumbnailPath = thumbnailPath
        process.running = true

        return thumbnailPath
    }

    function getThumbnailUrl(videoPath) {
        const thumbnailPath = generateThumbnail(videoPath)
        return thumbnailPath ? "file://" + thumbnailPath : ""
    }

    function clearThumbnailCache() {
        console.log("VideoThumbnailService: Clearing thumbnail cache")
        clearCacheProcess.command = ["rm", "-rf", thumbnailDir]
        clearCacheProcess.running = true
        Qt.callLater(() => {
            createThumbnailDirectory()
        })
    }

    Process {
        id: ffmpegCheck
        command: ["which", "ffmpeg"]
        running: false

        onExited: code => {
            ffmpegAvailable = (code === 0)
            if (!ffmpegAvailable) {
                console.warn("VideoThumbnailService: ffmpeg not found - video thumbnail generation disabled")
            } else {
                console.log("VideoThumbnailService: ffmpeg found - video thumbnail generation enabled")
            }
        }
    }

    Process {
        id: createDirProcess
        running: false

        onExited: code => {
            if (code === 0) {
                console.log("VideoThumbnailService: Thumbnail directory created:", thumbnailDir)
            } else {
                console.error("VideoThumbnailService: Failed to create thumbnail directory")
            }
        }
    }

    Process {
        id: clearCacheProcess
        running: false

        onExited: code => {
            console.log("VideoThumbnailService: Cache cleared, exit code:", code)
        }
    }

    FileView {
        id: thumbnailExists
        path: ""
        // Used to check if thumbnail files exist
    }

    Component {
        id: processComponent

        Process {
            property string videoPath: ""
            property string thumbnailPath: ""

            running: false

            onExited: code => {
                const success = (code === 0)
                console.log("VideoThumbnailService: Thumbnail generation", success ? "succeeded" : "failed", "for", videoPath, "exit code:", code)

                if (success) {
                    thumbnailReady(videoPath, thumbnailPath)
                }

                // Clean up tracking
                delete root.generatingThumbnails[videoPath]
                destroy()
            }

            stderr: StdioCollector {
                onStreamFinished: {
                    if (text && text.trim()) {
                        console.warn("VideoThumbnailService ffmpeg stderr:", text.trim())
                    }
                }
            }
        }
    }
}