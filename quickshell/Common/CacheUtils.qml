pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root

    function clearImageCache() {
        Quickshell.execDetached(["rm", "-rf", Paths.stringify(Paths.imagecache)]);
        Paths.mkdir(Paths.imagecache);
    }

    function clearOldCache(ageInMinutes) {
        Quickshell.execDetached(["find", Paths.stringify(Paths.imagecache), "-name", "*.png", "-mmin", `+${ageInMinutes}`, "-delete"]);
    }

    function clearCacheForSize(size) {
        Quickshell.execDetached(["find", Paths.stringify(Paths.imagecache), "-name", `*@${size}x${size}.png`, "-delete"]);
    }

    function getCacheSize(callback) {
        Proc.runCommand("cache_size", ["du", "-sm", Paths.stringify(Paths.imagecache)], function (output, exitCode) {
            const sizeMB = parseInt(output.split("\t")[0]) || 0;
            callback(sizeMB);
        });
    }
}
