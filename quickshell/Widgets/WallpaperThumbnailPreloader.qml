pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// Preload the CachingImage disk cache for a folder of wallpapers via ffmpegthumbnailer
// so the switcher grid renders instantly. No-op (graceful fallback) if the tool is absent.
Item {
    id: root

    visible: false

    property var paths: []
    property int cacheSize: 256
    property bool autoStart: true
    property int maxConcurrent: 3

    property int _active: 0
    property var _queue: []
    property int _toolState: -1 // -1 unknown, 0 unavailable, 1 available

    onPathsChanged: if (autoStart)
        preload()

    // Must match djb2Hash + cachePath in Widgets/CachingImage.qml.
    function _hash(str) {
        if (!str)
            return "";
        let hash = 5381;
        for (let i = 0; i < str.length; i++) {
            hash = ((hash << 5) + hash) + str.charCodeAt(i);
            hash = hash & 0x7FFFFFFF;
        }
        return hash.toString(16).padStart(8, '0');
    }

    function _cachePathFor(path) {
        const hash = _hash(path);
        if (!hash)
            return "";
        return `${Paths.stringify(Paths.imagecache)}/${hash}@${cacheSize}x${cacheSize}.png`;
    }

    function _isAnimated(path) {
        const lower = path.toLowerCase();
        return lower.endsWith(".gif") || lower.endsWith(".webp");
    }

    function preload() {
        if (!paths || paths.length === 0 || _toolState === 0)
            return;
        if (_toolState === -1) {
            Proc.runCommand("wallpaperThumbToolCheck", ["sh", "-c", "command -v ffmpegthumbnailer"], function (out, code) {
                root._toolState = code === 0 ? 1 : 0;
                if (root._toolState === 1)
                    root._start();
            });
            return;
        }
        _start();
    }

    function _start() {
        Paths.mkdir(Paths.imagecache);
        const q = [];
        for (let i = 0; i < paths.length; i++) {
            const p = paths[i];
            if (!p || p.startsWith("#") || _isAnimated(p))
                continue;
            q.push(p);
        }
        _queue = q;
        for (let i = 0; i < maxConcurrent; i++)
            _pump();
    }

    function _pump() {
        if (_queue.length === 0)
            return;
        const path = _queue.shift();
        const cachePath = _cachePathFor(path);
        if (!cachePath) {
            _pump();
            return;
        }
        _active++;
        // One process per file: skip if already cached, otherwise generate.
        const script = "test -f \"$1\" || ffmpegthumbnailer -i \"$2\" -o \"$1\" -s " + cacheSize;
        Proc.runCommand(null, ["sh", "-c", script, "thumb", cachePath, path], function (out, code) {
            root._active--;
            root._pump();
        }, 0, 20000);
    }
}
