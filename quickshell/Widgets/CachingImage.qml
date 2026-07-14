import QtQuick
import qs.Common

Item {
    id: root

    property string imagePath: ""
    property int maxCacheSize: 512
    property int status: isAnimated ? animatedImg.status : staticImg.status
    property int fillMode: Image.PreserveAspectCrop
    // AnimatedImage decodes full-size on the GUI thread and is never cached;
    // disable for thumbnail grids
    property bool animate: true
    property bool _fromCache: false

    readonly property bool isRemoteUrl: imagePath.startsWith("http://") || imagePath.startsWith("https://")
    readonly property bool isAnimated: {
        if (!animate || !imagePath)
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
    readonly property string cacheFileName: imageHash && !isRemoteUrl && !isAnimated ? `${imageHash}@${maxCacheSize}x${maxCacheSize}.png` : ""
    readonly property string cachePath: cacheFileName ? `${Paths.stringify(Paths.imagecache)}/${cacheFileName}` : ""
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
            switch (status) {
            case Image.Error:
                if (!root._fromCache)
                    return;
                root._fromCache = false;
                source = root.encodedImagePath;
                return;
            case Image.Ready:
                if (root._fromCache || root.isRemoteUrl || !root.cachePath)
                    return;
                if (!visible || width <= 0 || height <= 0 || !Window.window?.visible)
                    return;
                const grabPath = root.cachePath;
                grabToImage(res => {
                    res.saveToFile(grabPath);
                });
                return;
            }
        }
    }

    // Derives everything from a local snapshot of imagePath: sibling property
    // bindings (isRemoteUrl, encodedImagePath, ...) are still stale when
    // onImagePathChanged runs, so reading them here routes remote URLs down
    // the local-file branch on the first path change
    function resolveSource() {
        const path = imagePath;
        if (!path) {
            _fromCache = false;
            staticImg.source = "";
            return;
        }
        const lower = path.toLowerCase();
        if (animate && (lower.endsWith(".gif") || lower.endsWith(".webp")))
            return;
        if (path.startsWith("http://") || path.startsWith("https://")) {
            _fromCache = false;
            staticImg.source = path;
            return;
        }
        const stripped = path.startsWith("file://") ? path.substring(7) : path;
        const encoded = "file://" + stripped.split('/').map(s => encodeURIComponent(s)).join('/');
        const hash = djb2Hash(stripped);
        if (!hash) {
            _fromCache = false;
            staticImg.source = encoded;
            return;
        }
        // Cache-first; a miss errors and falls back to encodedImagePath
        _fromCache = true;
        staticImg.source = `${Paths.stringify(Paths.imagecache)}/${hash}@${maxCacheSize}x${maxCacheSize}.png`;
    }

    onImagePathChanged: resolveSource()
    // During creation onImagePathChanged fires before sibling properties (maxCacheSize) initialize
    onCachePathChanged: resolveSource()
}
