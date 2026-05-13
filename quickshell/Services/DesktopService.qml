pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell.Io

import QtQuick
import Quickshell

Singleton {
    id: root

    property var _cache: ({})
	property bool gioAvailable: false;
	// For the queue that setDefaultApp uses
	property var _setDefaultAppQueue: []
	property bool _isProcessingQueue: false

	Component.onCompleted: {
		checkGioAndXdgMime.running = true;
	}

	Process {
		id: checkGioAndXdgMime
		command: ["sh", "-c", "which gio && which xdg-mime"]
		running: false
		onExited: (exitCode) => {
			if (exitCode === 0) {
				root.gioAvailable = true;
			} else {
				root.gioAvailable = false;
			}
		}
	}

    function resolveIconPath(moddedAppId) {
        if (!moddedAppId)
            return "";

        if (_cache[moddedAppId] !== undefined)
            return _cache[moddedAppId];

        const result = (function () {
                // 1. Try heuristic lookup (standard)
                const entry = DesktopEntries.heuristicLookup(moddedAppId);
                let icon = Quickshell.iconPath(entry?.icon, true);
                if (icon && icon !== "")
                    return icon;

                // 2. Try the appId itself as an icon name
                icon = Quickshell.iconPath(moddedAppId, true);
                if (icon && icon !== "")
                    return icon;

                // 3. Try variations of the appId (lowercase, last part)
                const appIds = [moddedAppId.toLowerCase()];
                const lastPart = moddedAppId.split('.').pop();
                if (lastPart && lastPart !== moddedAppId) {
                    appIds.push(lastPart);
                    appIds.push(lastPart.toLowerCase());
                }

                for (const id of appIds) {
                    icon = Quickshell.iconPath(id, true);
                    if (icon && icon !== "")
                        return icon;
                }

                // 4. Deep search in all desktop entries (if the above fail)
                // This is slow-ish but only happens once for failed icons
                const strippedId = moddedAppId.replace(/-bin$/, "").toLowerCase();
                const allEntries = DesktopEntries.applications.values;
                for (let i = 0; i < allEntries.length; i++) {
                    const e = allEntries[i];
                    const eId = (e.id || "").toLowerCase();
                    const eName = (e.name || "").toLowerCase();
                    const eExec = (e.execString || "").toLowerCase();

                    if (eId.includes(strippedId) || eName.includes(strippedId) || eExec.includes(strippedId)) {
                        icon = Quickshell.iconPath(e.icon, true);
                        if (icon && icon !== "")
                            return icon;
                    }
                }

                // 5. Nix/Guix specific store check (as a last resort)
                for (const appId of appIds) {
                    let execPath = entry?.execString?.replace(/\/bin.*/, "");
                    if (!execPath)
                        continue;

                    if (execPath.startsWith("/nix/store/") || execPath.startsWith("/gnu/store/")) {
                        const basePath = execPath;
                        const sizes = ["256x256", "128x128", "64x64", "48x48", "32x32", "24x24", "16x16"];

                        let iconPath = `${basePath}/share/icons/hicolor/scalable/apps/${appId}.svg`;
                        icon = Quickshell.iconPath(iconPath, true);
                        if (icon && icon !== "")
                            return icon;

                        for (const size of sizes) {
                            iconPath = `${basePath}/share/icons/hicolor/${size}/apps/${appId}.png`;
                            icon = Quickshell.iconPath(iconPath, true);
                            if (icon && icon !== "")
                                return icon;
                        }
                    }
                }

                return "";
            })();

        _cache[moddedAppId] = result;
        return result;
    }


	// Set default app for a MIME type
	Component {
		id: gioSetDefaultApp

		Process {
			property string targetMimeType: ""
			property string targetDesktopFileId: ""
			property string callbackId: ""

			// Check if the app actually supports the MIME type before setting it as default
			// This uses a shell script
			command: ["sh", "-c", `
				apps=$(gio mime "${targetMimeType}" 2>/dev/null | grep -v "^Default" | awk '{print $1}')
				if echo "$apps" | grep -Fxq "${targetDesktopFileId}"; then
					xdg-mime default "${targetDesktopFileId}" "${targetMimeType}"
					gio mime "${targetMimeType}" "${targetDesktopFileId}"
				fi
			`]

            onExited: (exitCode, exitStatus) => {
                const success = (exitCode === 0)
                if (!success) {
                    log.error("DesktopService: failed to set default app for", targetMimeType, "to", targetDesktopFileId, "(exit code:", exitCode + ")")
                }
                root._processDefaultAppQueue()
                destroy()
            }
        }
    }

	function setDefaultApp(mimeType, desktopFileId, callbackId = "") {
		// Add .desktop in case it's missing, xdg-mime needs it
		if (!desktopFileId.endsWith(".desktop")) {
			desktopFileId += ".desktop";
		}

        // Queue the request to avoid race conditions
        _setDefaultAppQueue.push({
            mimeType: mimeType,
            desktopFileId: desktopFileId,
            callbackId: callbackId
        })

        // Start processing the queue if not already running
        if (!_isProcessingQueue) {
            _processDefaultAppQueue()
        }
    }

	function _processDefaultAppQueue() {
		if (_setDefaultAppQueue.length === 0) {
			_isProcessingQueue = false;
			return;
		}

		_isProcessingQueue = true;
		const request = _setDefaultAppQueue.shift();

        const proc = gioSetDefaultApp.createObject(root, {
            targetMimeType: request.mimeType,
            targetDesktopFileId: request.desktopFileId,
            callbackId: request.callbackId,
            running: true
        })

        if (!proc) {
            log.warn("DesktopService: couldn't create process for", request.mimeType, request.desktopFileId)
            _processDefaultAppQueue()
        }
    }



    // Get default app for a MIME type
    Component {
        id: xdgGetDefaultApp

        Process {
            property string targetMimeType: ""
            property string callbackId: ""

			stdout: StdioCollector {
				onStreamFinished: {
					const desktopFileId = text.trim();
					root.getDefaultAppResult(targetMimeType, desktopFileId, callbackId);
				}
			}

            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length > 0) {
                        log.error("DesktopService: xdg-mime query error:", text, "mime:", targetMimeType)
                    }
                }
            }

            onExited: (exitCode, exitStatus) => { destroy() }
        }
    }

    function getDefaultApp(mimeType, callbackId = "") {
        const proc = xdgGetDefaultApp.createObject(root, {
            targetMimeType: mimeType,
            callbackId: callbackId,
            command: ["xdg-mime", "query", "default", mimeType],
            running: true
        })

        if (!proc) {
            log.warn("DesktopService: couldn't create process for", mimeType)
        }
    }

    signal getDefaultAppResult(string mimeType, string desktopFileId, string callbackId)



    // Get apps that support a MIME type
    Component {
        id: gioGetAppsForMime

        Process {
            property string targetMimeType: ""
            property string callbackId: ""

			stdout: StdioCollector {
				onStreamFinished: {
					const lines = text.split("\n");
					let appIds = [];
					let seen = {};

					for (let line of lines) {
						const trimmed = line.trim();
						if (
							trimmed &&
							trimmed.endsWith(".desktop") &&
							!trimmed.startsWith("Default") &&
							!trimmed.startsWith("default=")
						) {
							if (!seen[trimmed]) {
								seen[trimmed] = true;
								appIds.push(trimmed);
							}
						}
					}
					root.getAppsForMimeResult(targetMimeType, appIds, callbackId);
				}
			}

			stderr: StdioCollector {
				onStreamFinished: {
					if (text.trim().length > 0) {
						log.error("DesktopService: gio mime query error:", text, "command:", command, "mime:", targetMimeType);
					}
				}
			}

            onExited: (exitCode, exitStatus) => { destroy() }
        }
    }

	function getAppsForMimeType(mimeType, callbackId = "") {
		const proc = gioGetAppsForMime.createObject(root, {
			targetMimeType: mimeType,
			callbackId: callbackId,
			command: ["gio", "mime", mimeType],
			running: true
		});

        if (!proc) {
            log.warn("DesktopService: couldn't create process for", mimeType)
        }
    }

    signal getAppsForMimeResult(string mimeType, var appIds, string callbackId)
}
