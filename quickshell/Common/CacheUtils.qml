pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell

Singleton {
    id: root

    // Clear all image cache
    function clearImageCache() {
        Quickshell.execDetached(["rm", "-rf", Paths.stringify(Paths.imagecache)]);
        Paths.mkdir(Paths.imagecache);
    }

    // Clear cache older than specified minutes
    function clearOldCache(ageInMinutes) {
        Quickshell.execDetached(["find", Paths.stringify(Paths.imagecache), "-name", "*.png", "-mmin", `+${ageInMinutes}`, "-delete"]);
    }

    // Clear cache for specific size
    function clearCacheForSize(size) {
        Quickshell.execDetached(["find", Paths.stringify(Paths.imagecache), "-name", `*@${size}x${size}.png`, "-delete"]);
    }

    // Get cache size in MB
    function getCacheSize(callback) {
        var process = Qt.createQmlObject(`
                                         import Quickshell.Io
                                         Process {
                                         command: ["du", "-sm", "${Paths.stringify(Paths.imagecache)}"]
                                         running: true
                                         stdout: StdioCollector {
                                         onStreamFinished: {
                                         var sizeMB = parseInt(text.split("\\t")[0]) || 0
                                         callback(sizeMB)
                                         }
                                         }
                                         }
                                         `, root);
    }
}
