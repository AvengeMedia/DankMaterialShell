pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property string cacheDir: ""
    property var thumbnailQueue: []
    property var thumbnailCache: ({})
    property var activeProcesses: ({})
    property bool processing: false
    property int maxConcurrentProcesses: 1  // Severely limit concurrent processes
    property int currentProcessCount: 0
    property bool preloadingEnabled: true   // Re-enable background preloading
    property bool startupComplete: false    // Track if startup is complete

    // Safety and monitoring properties
    property bool emergencyShutdown: false  // Emergency kill switch
    property int processFailureCount: 0     // Track failures
    property int maxFailures: 5             // Max failures before shutdown
    property int maxQueueTime: 30000        // Max time a process can run (30 seconds)
    property var processStartTimes: ({})    // Track when processes started
    property int totalProcessesSpawned: 0   // Track total processes
    property int maxTotalProcesses: 50      // Emergency brake after 50 processes

    // Supported video and image extensions
    property var videoExtensions: ["mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v"]
    property var imageExtensions: ["jpg", "jpeg", "png", "gif", "bmp", "webp", "tiff", "tga"]

    Component.onCompleted: {
        initializeCacheDirectory()

        // Start background preloading after a delay to let system stabilize
        startupDelayTimer.start()

        // Start safety monitoring
        safetyMonitorTimer.start()
    }

    // Emergency shutdown function
    function emergencyStop() {
        console.error("ThumbnailService: EMERGENCY SHUTDOWN ACTIVATED")
        emergencyShutdown = true
        preloadingEnabled = false

        // Stop all timers
        if (startupDelayTimer) startupDelayTimer.running = false
        if (processDelayTimer) processDelayTimer.running = false
        if (safetyMonitorTimer) safetyMonitorTimer.running = false

        // Kill all active processes immediately
        for (const hash in activeProcesses) {
            if (activeProcesses[hash]) {
                console.warn("ThumbnailService: Emergency killing process:", hash)
                activeProcesses[hash].running = false
                activeProcesses[hash].destroy()
            }
        }

        // Clear everything
        activeProcesses = {}
        thumbnailQueue = []
        processStartTimes = {}
        currentProcessCount = 0
    }

    // Safety check function
    function performSafetyCheck() {
        if (emergencyShutdown) return

        // Check for too many failures
        if (processFailureCount >= maxFailures) {
            console.error("ThumbnailService: Too many failures (" + processFailureCount + "), emergency shutdown")
            emergencyStop()
            return
        }

        // Check for too many total processes
        if (totalProcessesSpawned >= maxTotalProcesses) {
            console.error("ThumbnailService: Process limit reached (" + totalProcessesSpawned + "), emergency shutdown")
            emergencyStop()
            return
        }

        // Check for hung processes
        const currentTime = Date.now()
        for (const hash in processStartTimes) {
            const startTime = processStartTimes[hash]
            if (currentTime - startTime > maxQueueTime) {
                console.error("ThumbnailService: Process timeout detected for:", hash)
                if (activeProcesses[hash]) {
                    activeProcesses[hash].running = false
                    activeProcesses[hash].destroy()
                    delete activeProcesses[hash]
                }
                delete processStartTimes[hash]
                currentProcessCount = Math.max(0, currentProcessCount - 1)
                processFailureCount++
            }
        }

        // Check for queue size explosion
        if (thumbnailQueue.length > 20) {
            console.warn("ThumbnailService: Queue too large, emergency clear")
            thumbnailQueue = []
        }
    }

    function initializeCacheDirectory() {
        // Create cache directory using Process
        const homeDir = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString()
        // Remove file:// prefix if present
        const cleanHomeDir = homeDir.replace(/^file:\/\//, '')
        cacheDir = cleanHomeDir + "/.cache/dms/thumbnails"

        const mkdirProcess = processComponent.createObject(root)
        mkdirProcess.command = ["mkdir", "-p", cacheDir]
        mkdirProcess.onExited.connect(function(code) {
            if (code === 0) {
                console.log("ThumbnailService: Cache directory initialized:", cacheDir)
            } else {
                console.error("ThumbnailService: Failed to create cache directory")
            }
            mkdirProcess.destroy()
        })
        mkdirProcess.running = true
    }

    function isVideoFile(filePath) {
        const extension = filePath.split('.').pop().toLowerCase()
        return videoExtensions.includes(extension)
    }

    function isImageFile(filePath) {
        const extension = filePath.split('.').pop().toLowerCase()
        return imageExtensions.includes(extension)
    }

    function isSupportedFile(filePath) {
        return isVideoFile(filePath) || isImageFile(filePath)
    }

    function getVideoHash(videoPath) {
        return Qt.md5(videoPath)
    }

    function getThumbnailPath(videoPath) {
        const hash = getVideoHash(videoPath)
        return cacheDir + "/" + hash + ".jpg"
    }

    function getThumbnail(filePath) {
        if (!isSupportedFile(filePath)) {
            return ""
        }

        const hash = getVideoHash(filePath)
        const thumbnailPath = getThumbnailPath(filePath)

        // Return cached if available in memory
        if (thumbnailCache[hash]) {
            return thumbnailCache[hash]
        }

        // For images, we can return the original file path if no thumbnail exists yet
        if (isImageFile(filePath)) {
            // Still generate a thumbnail for consistency and proper sizing
            checkThumbnailExists(filePath, thumbnailPath, hash)
            return "file://" + filePath // Return original image while thumbnail generates
        }

        // For videos, check if thumbnail exists on disk and validate it
        checkThumbnailExists(filePath, thumbnailPath, hash)
        return "" // Return empty while processing/checking
    }

    function checkThumbnailExists(videoPath, thumbnailPath, hash) {
        const checkProcess = processComponent.createObject(root, {
            videoPath: videoPath,
            outputPath: thumbnailPath,
            hash: hash
        })
        checkProcess.command = ["test", "-f", thumbnailPath, "-a", "-s", thumbnailPath]

        checkProcess.onExited.connect(function(code) {
            if (code === 0) {
                // File exists and has size > 0, validate it's a proper image
                validateThumbnail(checkProcess.videoPath, checkProcess.outputPath, checkProcess.hash)
            } else {
                // File doesn't exist or is empty, queue for generation
                queueThumbnail(checkProcess.videoPath, checkProcess.outputPath, checkProcess.hash)
            }
            checkProcess.destroy()
        })
        checkProcess.running = true
    }

    function validateThumbnail(videoPath, thumbnailPath, hash) {
        const validateProcess = processComponent.createObject(root, {
            videoPath: videoPath,
            outputPath: thumbnailPath,
            hash: hash
        })
        validateProcess.command = ["file", thumbnailPath]

        validateProcess.onExited.connect(function(code) {
            if (code === 0) {
                // Check if output contains "JPEG" to ensure it's a valid image
                const output = validateProcess.stdout.text || ""
                if (output.includes("JPEG")) {
                    // Valid thumbnail, add to cache
                    root.thumbnailCache[validateProcess.hash] = "file://" + validateProcess.outputPath
                    console.log("ThumbnailService: Using cached thumbnail for:", validateProcess.videoPath)
                } else {
                    // Invalid thumbnail, regenerate
                    console.warn("ThumbnailService: Invalid thumbnail detected, regenerating:", validateProcess.outputPath)
                    queueThumbnail(validateProcess.videoPath, validateProcess.outputPath, validateProcess.hash)
                }
            } else {
                // Validation failed, regenerate
                queueThumbnail(validateProcess.videoPath, validateProcess.outputPath, validateProcess.hash)
            }
            validateProcess.destroy()
        })
        validateProcess.running = true
    }

    function queueThumbnail(videoPath, thumbnailPath, hash) {
        // Check if already queued or processing
        const existing = thumbnailQueue.find(item => item.hash === hash)
        if (existing || activeProcesses[hash]) {
            return
        }

        // Limit queue size to prevent resource exhaustion
        limitQueueSize()

        thumbnailQueue.push({
            video: videoPath,
            output: thumbnailPath,
            hash: hash
        })

        console.log("ThumbnailService: Queued thumbnail generation for:", videoPath)
        processQueue()
    }

    function processQueue() {
        // Safety checks before processing
        if (emergencyShutdown) {
            console.warn("ThumbnailService: Processing blocked - emergency shutdown active")
            return
        }

        if (totalProcessesSpawned >= maxTotalProcesses) {
            console.warn("ThumbnailService: Process limit reached, stopping generation")
            emergencyStop()
            return
        }

        // Conservative processing - only process when we have available slots
        if (currentProcessCount >= maxConcurrentProcesses || thumbnailQueue.length === 0) {
            return
        }

        const item = thumbnailQueue.shift()
        generateThumbnail(item)
    }

    // New function to limit queue size
    function limitQueueSize() {
        const maxQueueSize = startupComplete ? 5 : 10  // Smaller queue during background processing
        if (thumbnailQueue.length > maxQueueSize) {
            console.warn("ThumbnailService: Queue too large, clearing excess items")
            thumbnailQueue = thumbnailQueue.slice(0, maxQueueSize)
        }
    }

    function generateThumbnail(item) {
        // Final safety check
        if (emergencyShutdown || totalProcessesSpawned >= maxTotalProcesses) {
            console.warn("ThumbnailService: Thumbnail generation blocked by safety limits")
            return
        }

        currentProcessCount++
        totalProcessesSpawned++
        const process = processComponent.createObject(root)
        process.videoPath = item.video
        process.outputPath = item.output
        process.hash = item.hash

        // Record process start time for timeout monitoring
        processStartTimes[item.hash] = Date.now()
        activeProcesses[item.hash] = process

        console.log("ThumbnailService: Starting process", totalProcessesSpawned, "for:", item.video)

        // Use different commands for images vs videos
        if (isImageFile(item.video)) {
            // For images, use ImageMagick for consistent thumbnail sizing
            process.command = [
                "magick",
                item.video,
                "-thumbnail", "200x150^",
                "-gravity", "center",
                "-extent", "200x150",
                "-quality", "85",
                item.output
            ]
        } else {
            // For videos, use ffmpeg
            process.command = [
                "ffmpeg", "-y",
                "-i", item.video,
                "-ss", "00:00:03",  // Seek to 3 seconds
                "-vframes", "1",    // Extract one frame
                "-vf", "scale=200:150:force_original_aspect_ratio=decrease,pad=200:150:(ow-iw)/2:(oh-ih)/2:black",
                "-q:v", "3",        // Good quality
                "-f", "image2",     // Force image format
                item.output
            ]
        }

        process.onExited.connect(function(code) {
            currentProcessCount = Math.max(0, currentProcessCount - 1) // Ensure it doesn't go negative
            delete activeProcesses[process.hash]
            delete processStartTimes[process.hash] // Clean up timing data

            if (code === 0) {
                // Successful generation
                console.log("ThumbnailService: Successfully completed thumbnail for:", process.videoPath)
                verifyGeneratedThumbnail(process.videoPath, process.outputPath, process.hash)
            } else {
                // Failed generation - increment failure counter
                processFailureCount++
                console.error("ThumbnailService: Failed to generate thumbnail for:", process.videoPath, "exit code:", code, "failure count:", processFailureCount)

                // Log stderr if available
                if (process.stderr && process.stderr.text) {
                    console.error("ThumbnailService: Process error:", process.stderr.text)
                }

                // Check if we need emergency shutdown due to failures
                if (processFailureCount >= maxFailures) {
                    console.error("ThumbnailService: Too many failures, triggering emergency shutdown")
                    emergencyStop()
                    return
                }
            }

            // Ensure process is properly cleaned up
            if (process) {
                process.destroy()
                process = null
            }

            // Only continue processing if not in emergency shutdown
            if (!emergencyShutdown) {
                processDelayTimer.start()
            }
        })

        console.log("ThumbnailService: Generating thumbnail for:", item.video)
        process.running = true
    }

    function verifyGeneratedThumbnail(videoPath, thumbnailPath, hash) {
        const verifyProcess = processComponent.createObject(root, {
            videoPath: videoPath,
            outputPath: thumbnailPath,
            hash: hash
        })
        verifyProcess.command = ["test", "-s", thumbnailPath]

        verifyProcess.onExited.connect(function(code) {
            if (code === 0) {
                // File exists and has size, add to cache
                root.thumbnailCache[verifyProcess.hash] = "file://" + verifyProcess.outputPath
                console.log("ThumbnailService: Successfully generated thumbnail for:", verifyProcess.videoPath)
            } else {
                console.error("ThumbnailService: Generated thumbnail is empty or missing:", verifyProcess.outputPath)
            }
            verifyProcess.destroy()
        })
        verifyProcess.running = true
    }

    function preloadThumbnails(directoryPath) {
        console.log("ThumbnailService: Preloading thumbnails for directory:", directoryPath)

        const lsProcess = processComponent.createObject(root)
        // Use a simple approach with multiple -name patterns
        let cmd = "find \"" + directoryPath + "\" -type f \\( "
        const allExtensions = videoExtensions.concat(imageExtensions)

        for (let i = 0; i < allExtensions.length; i++) {
            if (i > 0) cmd += " -o "
            cmd += "-iname '*." + allExtensions[i] + "'"
        }
        cmd += " \\)"

        lsProcess.command = ["bash", "-c", cmd]

        lsProcess.onExited.connect(function(code) {
            if (code === 0 && lsProcess.stdout && lsProcess.stdout.text) {
                const files = lsProcess.stdout.text.trim().split('\n').filter(f => f.length > 0)
                const videoFiles = files.filter(f => isVideoFile(f))
                const imageFiles = files.filter(f => isImageFile(f))

                console.log("ThumbnailService: Found", videoFiles.length, "video files and", imageFiles.length, "image files to preload")

                // Queue all files for thumbnail generation
                files.forEach(filePath => {
                    getThumbnail(filePath) // This will queue them for generation
                })
            }
            lsProcess.destroy()
        })
        lsProcess.running = true
    }

    function startBackgroundProcessing() {
        if (!preloadingEnabled || !startupComplete) {
            return
        }

        // Start with just the main wallpaper directory
        const homeDir = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString()
        const cleanHomeDir = homeDir.replace(/^file:\/\//, '')
        const mainWallpaperDir = cleanHomeDir + "/Pictures/wallpapers"

        console.log("ThumbnailService: Starting slow background processing for:", mainWallpaperDir)
        preloadThumbnails(mainWallpaperDir)
    }

    function clearCache() {
        console.log("ThumbnailService: Clearing thumbnail cache")
        thumbnailCache = {}

        const rmProcess = processComponent.createObject(root)
        rmProcess.command = ["rm", "-rf", cacheDir + "/*"]
        rmProcess.onExited.connect(function(code) {
            console.log("ThumbnailService: Cache cleared, exit code:", code)
            rmProcess.destroy()
        })
        rmProcess.running = true
    }

    function getServiceStatus() {
        return {
            cacheDir: cacheDir,
            queueLength: thumbnailQueue.length,
            cachedThumbnails: Object.keys(thumbnailCache).length,
            activeProcesses: currentProcessCount,
            maxProcesses: maxConcurrentProcesses
        }
    }

    Component {
        id: processComponent

        Process {
            property string videoPath: ""
            property string outputPath: ""
            property string hash: ""

            running: false

            stdout: StdioCollector {
                id: stdoutCollector
                property string text: ""
                onStreamFinished: {
                    text = data
                }
            }

            stderr: StdioCollector {
                id: stderrCollector
                property string text: ""
                onStreamFinished: {
                    text = data
                }
            }
        }
    }

    // Timer for delaying between thumbnail generations
    Timer {
        id: processDelayTimer
        interval: 2000  // 2 second delay between processes (much slower)
        running: false
        onTriggered: processQueue()
    }

    // Timer to delay startup processing
    Timer {
        id: startupDelayTimer
        interval: 5000  // Wait 5 seconds after startup before beginning
        running: false
        onTriggered: {
            console.log("ThumbnailService: Starting background thumbnail generation")
            startupComplete = true
            startBackgroundProcessing()
        }
    }

    // Safety monitoring timer
    Timer {
        id: safetyMonitorTimer
        interval: 10000  // Check every 10 seconds
        running: false
        repeat: true
        onTriggered: {
            performSafetyCheck()

            // Log status every few checks
            if ((Date.now() / 10000) % 6 === 0) { // Every 60 seconds
                console.log("ThumbnailService: Status - Active processes:", currentProcessCount,
                           "Queue size:", thumbnailQueue.length,
                           "Total spawned:", totalProcessesSpawned,
                           "Failures:", processFailureCount)
            }
        }
    }

    // Clean up when service is destroyed
    Component.onDestruction: {
        console.log("ThumbnailService: Service destruction - cleaning up")

        // Trigger emergency shutdown to ensure clean state
        emergencyStop()

        // Additional cleanup for safety
        processStartTimes = {}
        processFailureCount = 0
        totalProcessesSpawned = 0
    }
}