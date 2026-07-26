pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("CacheData")

    readonly property int cacheConfigVersion: 2

    readonly property bool isGreeterMode: Quickshell.env("DMS_RUN_GREETER") === "1" || Quickshell.env("DMS_RUN_GREETER") === "true"

    readonly property string _stateUrl: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)
    readonly property string _stateDir: Paths.strip(_stateUrl)

    property bool _loading: false
    property bool _hasLoaded: false
    property int _loadedCacheVersion: 0

    readonly property var _pinKeys: ["brightnessDevicePins", "wifiNetworkPins", "bluetoothDevicePins", "audioInputDevicePins", "audioOutputDevicePins"]
    readonly property var _dataKeys: ["wallpaperLastPath", "profileLastPath", "fileBrowserSettings"].concat(_pinKeys)

    property string wallpaperLastPath: ""
    property string profileLastPath: ""

    property var brightnessDevicePins: ({})
    property var wifiNetworkPins: ({})
    property var bluetoothDevicePins: ({})
    property var audioInputDevicePins: ({})
    property var audioOutputDevicePins: ({})

    property var fileBrowserSettings: ({
            "wallpaper": {
                "lastPath": "",
                "viewMode": "grid",
                "sortBy": "name",
                "sortAscending": true,
                "iconSizeIndex": 1,
                "showSidebar": true
            },
            "profile": {
                "lastPath": "",
                "viewMode": "grid",
                "sortBy": "name",
                "sortAscending": true,
                "iconSizeIndex": 1,
                "showSidebar": true
            },
            "notepad_save": {
                "lastPath": "",
                "viewMode": "list",
                "sortBy": "name",
                "sortAscending": true,
                "iconSizeIndex": 1,
                "showSidebar": true
            },
            "notepad_load": {
                "lastPath": "",
                "viewMode": "list",
                "sortBy": "name",
                "sortAscending": true,
                "iconSizeIndex": 1,
                "showSidebar": true
            },
            "generic": {
                "lastPath": "",
                "viewMode": "list",
                "sortBy": "name",
                "sortAscending": true,
                "iconSizeIndex": 1,
                "showSidebar": true
            },
            "default": {
                "lastPath": "",
                "viewMode": "list",
                "sortBy": "name",
                "sortAscending": true,
                "iconSizeIndex": 1,
                "showSidebar": true
            }
        })

    Component.onCompleted: {
        if (!isGreeterMode) {
            loadCache();
        }
    }

    function loadCache() {
        _loading = true;
        try {
            parseCache(cacheFile.text());
        } finally {
            _loading = false;
            _hasLoaded = true;
        }
    }

    function set(key, value) {
        if (_dataKeys.indexOf(key) < 0) {
            log.warn("Unknown cache key:", key);
            return;
        }
        root[key] = value;
        saveCache();
    }

    function migratePins(pins) {
        if (!pins)
            return;
        if (!_hasLoaded)
            loadCache();
        if (_loadedCacheVersion >= cacheConfigVersion)
            return;

        let migrated = false;
        for (const key of _pinKeys) {
            const legacy = pins[key];
            if (!legacy || Object.keys(legacy).length === 0)
                continue;
            if (Object.keys(root[key] || {}).length > 0)
                continue;
            root[key] = legacy;
            migrated = true;
        }

        if (!migrated)
            return;
        log.info("Migrated device pins from settings.json");
        saveCache();
    }

    function parseCache(content) {
        _loading = true;
        try {
            if (content && content.trim()) {
                const cache = JSON.parse(content);
                _loadedCacheVersion = cache.configVersion || 0;

                wallpaperLastPath = cache.wallpaperLastPath !== undefined ? cache.wallpaperLastPath : "";
                profileLastPath = cache.profileLastPath !== undefined ? cache.profileLastPath : "";

                if (cache.fileBrowserSettings !== undefined) {
                    fileBrowserSettings = cache.fileBrowserSettings;
                } else if (cache.fileBrowserViewMode !== undefined) {
                    fileBrowserSettings = {
                        "wallpaper": {
                            "lastPath": cache.wallpaperLastPath || "",
                            "viewMode": cache.fileBrowserViewMode || "grid",
                            "sortBy": cache.fileBrowserSortBy || "name",
                            "sortAscending": cache.fileBrowserSortAscending !== undefined ? cache.fileBrowserSortAscending : true,
                            "iconSizeIndex": cache.fileBrowserIconSizeIndex !== undefined ? cache.fileBrowserIconSizeIndex : 1,
                            "showSidebar": cache.fileBrowserShowSidebar !== undefined ? cache.fileBrowserShowSidebar : true
                        },
                        "profile": {
                            "lastPath": cache.profileLastPath || "",
                            "viewMode": cache.fileBrowserViewMode || "grid",
                            "sortBy": cache.fileBrowserSortBy || "name",
                            "sortAscending": cache.fileBrowserSortAscending !== undefined ? cache.fileBrowserSortAscending : true,
                            "iconSizeIndex": cache.fileBrowserIconSizeIndex !== undefined ? cache.fileBrowserIconSizeIndex : 1,
                            "showSidebar": cache.fileBrowserShowSidebar !== undefined ? cache.fileBrowserShowSidebar : true
                        },
                        "file": {
                            "lastPath": "",
                            "viewMode": "list",
                            "sortBy": "name",
                            "sortAscending": true,
                            "iconSizeIndex": 1,
                            "showSidebar": true
                        }
                    };
                }

                for (const key of _pinKeys) {
                    root[key] = cache[key] !== undefined ? cache[key] : {};
                }

                if (cache.configVersion === undefined) {
                    migrateFromUndefinedToV1(cache);
                    cleanupUnusedKeys();
                    saveCache();
                }
            }
        } catch (e) {
            log.warn("Failed to parse cache:", e.message);
        } finally {
            _loading = false;
        }
    }

    function saveCache() {
        if (_loading)
            return;
        const data = {
            "wallpaperLastPath": wallpaperLastPath,
            "profileLastPath": profileLastPath,
            "fileBrowserSettings": fileBrowserSettings,
            "configVersion": cacheConfigVersion
        };
        for (const key of _pinKeys) {
            data[key] = root[key];
        }
        cacheFile.setText(JSON.stringify(data, null, 2));
    }

    function migrateFromUndefinedToV1(cache) {
        log.info("Migrating configuration from undefined to version 1");
    }

    function cleanupUnusedKeys() {
        const validKeys = _dataKeys.concat(["configVersion"]);

        try {
            const content = cacheFile.text();
            if (!content || !content.trim())
                return;
            const cache = JSON.parse(content);
            let needsSave = false;

            for (const key in cache) {
                if (!validKeys.includes(key)) {
                    log.debug("Removing unused key:", key);
                    delete cache[key];
                    needsSave = true;
                }
            }

            if (needsSave) {
                cacheFile.setText(JSON.stringify(cache, null, 2));
            }
        } catch (e) {
            log.warn("Failed to cleanup unused keys:", e.message);
        }
    }

    function loadLauncherCache() {
        try {
            var content = launcherCacheFile.text();
            if (content && content.trim())
                return JSON.parse(content);
        } catch (e) {
            log.warn("Failed to parse launcher cache:", e.message);
        }
        return null;
    }

    function saveLauncherCache(sections) {
        if (_loading)
            return;
        launcherCacheFile.setText(JSON.stringify(sections));
    }

    FileView {
        id: launcherCacheFile

        path: isGreeterMode ? "" : _stateDir + "/DankMaterialShell/launcher_cache.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: false
    }

    FileView {
        id: cacheFile

        path: isGreeterMode ? "" : _stateDir + "/DankMaterialShell/cache.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: !isGreeterMode
        onLoaded: {
            if (!isGreeterMode) {
                parseCache(cacheFile.text());
            }
        }
        onLoadFailed: error => {
            if (!isGreeterMode) {
                log.info("No cache file found, starting fresh");
            }
        }
    }
}
