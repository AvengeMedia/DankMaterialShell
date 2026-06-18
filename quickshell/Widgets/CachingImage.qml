import QtQuick
import Quickshell.Io
import qs.Common

Item {
    id: root

    property string imagePath: ""
    property int maxCacheSize: 512
    property int status: isAnimated ? animatedImg.status : staticImg.status
    property int fillMode: Image.PreserveAspectCrop

    readonly property bool isRemoteUrl: imagePath.startsWith("http://") || imagePath.startsWith("https://")
    readonly property bool isAnimated: {
        if (!imagePath)
            return false;
        const lower = imagePath.toLowerCase();
        return lower.endsWith(".gif") || lower.endsWith(".webp");
    }
    readonly property string normalizedPath: {
        if (!imagePath)
            return "";
        if (isRemoteUrl)
            return imagePath;
        if (imagePath.startsWith("file://"))
            return imagePath.substring(7);
        return imagePath;
    }

    function djb2Hash(str) {
        if (!str)
            return "";
        let hash = 5381;
        for (let i = 0; i < str.length; i++) {
            hash = ((hash << 5) + hash) + str.charCodeAt(i);
            hash = hash & 0x7FFFFFFF;
        }
        return hash.toString(16).padStart(8, '0');
    }

    readonly property string imageHash: normalizedPath ? djb2Hash(normalizedPath) : ""
    readonly property string cachePath: imageHash && !isRemoteUrl && !isAnimated ? `${Paths.stringify(Paths.imagecache)}/${imageHash}@${maxCacheSize}x${maxCacheSize}.png` : ""
    readonly property string encodedImagePath: {
        if (!normalizedPath)
            return "";
        if (isRemoteUrl)
            return normalizedPath;
        return "file://" + normalizedPath.split('/').map(s => encodeURIComponent(s)).join('/');
    }

    AnimatedImage {
        id: animatedImg
        anchors.fill: parent
        visible: root.isAnimated
        asynchronous: true
        fillMode: root.fillMode
        source: root.isAnimated ? root.imagePath : ""
        playing: visible && status === AnimatedImage.Ready
    }

    Image {
        id: staticImg
        anchors.fill: parent
        visible: !root.isAnimated
        asynchronous: true
        fillMode: root.fillMode
        sourceSize.width: root.maxCacheSize
        sourceSize.height: root.maxCacheSize
        smooth: true

        onStatusChanged: {
            if (source === root.cachePath && status === Image.Error) {
                source = root.encodedImagePath;
                return;
            }
            if (root.isRemoteUrl || source !== root.encodedImagePath || status !== Image.Ready || !root.cachePath)
                return;
            Paths.mkdir(Paths.imagecache);
            const grabPath = root.cachePath;
            if (visible && width > 0 && height > 0 && Window.window?.visible) {
                grabToImage(res => res.saveToFile(grabPath));
            }
        }
    }

    Process {
        id: cacheProbe

        property string cachePath: ""
        property string fallbackSource: ""

        running: false
        command: ["test", "-f", cachePath]

        onExited: exitCode => {
            if (cacheProbe.cachePath !== root.cachePath)
                return;
            staticImg.source = exitCode === 0 ? cacheProbe.cachePath : cacheProbe.fallbackSource;
        }
    }

    onImagePathChanged: {
        if (!imagePath) {
            staticImg.source = "";
            return;
        }
        if (isAnimated)
            return;
        if (isRemoteUrl) {
            staticImg.source = imagePath;
            return;
        }
        Paths.mkdir(Paths.imagecache);
        const hash = djb2Hash(normalizedPath);
        const cPath = hash ? `${Paths.stringify(Paths.imagecache)}/${hash}@${maxCacheSize}x${maxCacheSize}.png` : "";
        const encoded = "file://" + normalizedPath.split('/').map(s => encodeURIComponent(s)).join('/');
        if (!cPath) {
            staticImg.source = encoded;
            return;
        }
        cacheProbe.running = false;
        cacheProbe.cachePath = cPath;
        cacheProbe.fallbackSource = encoded;
        cacheProbe.running = true;
    }
}
