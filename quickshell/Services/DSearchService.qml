pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool dsearchAvailable: false
    property int searchIdCounter: 0
    property int indexVersion: 0
    property bool supportsTypeFilter: false
    property bool versionChecked: false

    signal searchResultsReceived(var results)
    signal statsReceived(var stats)
    signal errorOccurred(string error)

    Process {
        id: checkProcess
        command: ["sh", "-c", "command -v dsearch"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                if (line && line.trim().length > 0) {
                    root.dsearchAvailable = true;
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.dsearchAvailable = false;
            } else {
                root._checkVersion();
            }
        }
    }

    function _checkVersion() {
        Proc.runCommand("dsearch-version", ["dsearch", "version", "--json"], (stdout, exitCode) => {
            root.versionChecked = true;
            if (exitCode !== 0)
                return;
            const response = JSON.parse(stdout);
            root.indexVersion = response.index_schema || 0;
            root.supportsTypeFilter = root.indexVersion >= 2;
        });
    }

    function ping(callback) {
        if (!dsearchAvailable) {
            if (callback) {
                callback({
                    "error": "dsearch not available"
                });
            }
            return;
        }

        Proc.runCommand("dsearch-ping", ["dsearch", "ping", "--json"], (stdout, exitCode) => {
            if (callback) {
                if (exitCode === 0) {
                    try {
                        const response = JSON.parse(stdout);
                        callback({
                            "result": response
                        });
                    } catch (e) {
                        callback({
                            "error": "failed to parse ping response"
                        });
                    }
                } else {
                    callback({
                        "error": "ping failed"
                    });
                }
            }
        });
    }

    function search(query, params, callback) {
        if (!query || query.length === 0) {
            if (callback) {
                callback({
                    "error": "query is required"
                });
            }
            return;
        }

        if (!dsearchAvailable) {
            if (callback) {
                callback({
                    "error": "dsearch not available"
                });
            }
            return;
        }

        const args = ["dsearch", "search", query, "--json"];

        if (params) {
            if (params.limit !== undefined) {
                args.push("-n", String(params.limit));
            }
            if (params.type) {
                args.push("-t", params.type);
            }
            if (params.ext) {
                args.push("-e", params.ext);
            }
            if (params.folder) {
                args.push("--folder", params.folder);
            }
            if (params.field) {
                args.push("-f", params.field);
            }
            if (params.fuzzy) {
                args.push("--fuzzy");
            }
            if (params.sort) {
                args.push("--sort", params.sort);
            }
            if (params.desc !== undefined) {
                args.push("--desc=" + (params.desc ? "true" : "false"));
            }
            if (params.minSize !== undefined) {
                args.push("--min-size", String(params.minSize));
            }
            if (params.maxSize !== undefined) {
                args.push("--max-size", String(params.maxSize));
            }
        }

        Proc.runCommand("dsearch-search", args, (stdout, exitCode) => {
            if (exitCode === 0) {
                try {
                    const response = JSON.parse(stdout);
                    searchResultsReceived(response);
                    if (callback) {
                        callback({
                            "result": response
                        });
                    }
                } catch (e) {
                    const error = "failed to parse search response";
                    errorOccurred(error);
                    if (callback) {
                        callback({
                            "error": error
                        });
                    }
                }
            } else if (exitCode === 124) {
                const error = "search timed out";
                errorOccurred(error);
                if (callback) {
                    callback({
                        "error": error
                    });
                }
            } else {
                const error = "search failed";
                errorOccurred(error);
                if (callback) {
                    callback({
                        "error": error
                    });
                }
            }
        }, 100, 5000);
    }

    function rediscover() {
        checkProcess.running = true;
    }
}
