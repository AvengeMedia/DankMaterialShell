pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool extWorkspaceAvailable: false
    property var groups: []
    property var _cachedWorkspaces: ({})

    signal stateChanged

    Connections {
        target: DMSService
        function onCapabilitiesReceived() {
            checkCapabilities();
        }
        function onConnectionStateChanged() {
            if (DMSService.isConnected) {
                checkCapabilities();
            } else {
                extWorkspaceAvailable = false;
            }
        }
        function onExtWorkspaceStateUpdate(data) {
            if (extWorkspaceAvailable) {
                handleStateUpdate(data);
            }
        }
    }

    Component.onCompleted: {
        if (DMSService.dmsAvailable) {
            checkCapabilities();
        }
    }

    function checkCapabilities() {
        if (!DMSService.capabilities || !Array.isArray(DMSService.capabilities)) {
            extWorkspaceAvailable = false;
            return;
        }

        const hasExtWorkspace = DMSService.capabilities.includes("extworkspace");
        if (hasExtWorkspace && !extWorkspaceAvailable) {
            if (typeof CompositorService !== "undefined") {
                const useExtWorkspace = DMSService.forceExtWorkspace || (!CompositorService.isNiri && !CompositorService.isHyprland && !CompositorService.isDwl && !CompositorService.isSway && !CompositorService.isScroll && !CompositorService.isMiracle);
                if (!useExtWorkspace) {
                    console.info("ExtWorkspaceService: ext-workspace available but compositor has native support");
                    extWorkspaceAvailable = false;
                    return;
                }
            }
            extWorkspaceAvailable = true;
            console.info("ExtWorkspaceService: ext-workspace capability detected");
            DMSService.addSubscription("extworkspace");
            requestState();
        } else if (!hasExtWorkspace) {
            extWorkspaceAvailable = false;
        }
    }

    function requestState() {
        if (!DMSService.isConnected || !extWorkspaceAvailable) {
            return;
        }

        DMSService.sendRequest("extworkspace.getState", null, response => {
            if (response.result) {
                handleStateUpdate(response.result);
            }
        });
    }

    function handleStateUpdate(state) {
        groups = state.groups || [];
        if (groups.length === 0) {
            console.warn("ExtWorkspaceService: Received empty workspace groups from backend");
        } else {
            console.log("ExtWorkspaceService: Updated with", groups.length, "workspace groups");
        }
        stateChanged();
    }

    function activateWorkspace(workspaceID, groupID = "") {
        if (!DMSService.isConnected || !extWorkspaceAvailable) {
            return;
        }

        DMSService.sendRequest("extworkspace.activateWorkspace", {
            "workspaceID": workspaceID,
            "groupID": groupID
        }, response => {
            if (response.error) {
                console.warn("ExtWorkspaceService: activateWorkspace error:", response.error);
            }
        });
    }

    function deactivateWorkspace(workspaceID, groupID = "") {
        if (!DMSService.isConnected || !extWorkspaceAvailable) {
            return;
        }

        DMSService.sendRequest("extworkspace.deactivateWorkspace", {
            "workspaceID": workspaceID,
            "groupID": groupID
        }, response => {
            if (response.error) {
                console.warn("ExtWorkspaceService: deactivateWorkspace error:", response.error);
            }
        });
    }

    function removeWorkspace(workspaceID, groupID = "") {
        if (!DMSService.isConnected || !extWorkspaceAvailable) {
            return;
        }

        DMSService.sendRequest("extworkspace.removeWorkspace", {
            "workspaceID": workspaceID,
            "groupID": groupID
        }, response => {
            if (response.error) {
                console.warn("ExtWorkspaceService: removeWorkspace error:", response.error);
            }
        });
    }

    function createWorkspace(groupID, name) {
        if (!DMSService.isConnected || !extWorkspaceAvailable) {
            return;
        }

        DMSService.sendRequest("extworkspace.createWorkspace", {
            "groupID": groupID,
            "name": name
        }, response => {
            if (response.error) {
                console.warn("ExtWorkspaceService: createWorkspace error:", response.error);
            }
        });
    }

    function getGroupForOutput(outputName) {
        for (const group of groups) {
            if (group.outputs && group.outputs.includes(outputName)) {
                return group;
            }
        }
        return null;
    }

    function getWorkspacesForOutput(outputName) {
        const group = getGroupForOutput(outputName);
        return group ? (group.workspaces || []) : [];
    }

    function getActiveWorkspaces() {
        const active = [];
        for (const group of groups) {
            if (!group.workspaces)
                continue;
            for (const ws of group.workspaces) {
                if (ws.active) {
                    active.push({
                        workspace: ws,
                        group: group,
                        outputs: group.outputs || []
                    });
                }
            }
        }
        return active;
    }

    function getActiveWorkspaceForOutput(outputName) {
        const group = getGroupForOutput(outputName);
        if (!group || !group.workspaces)
            return null;

        for (const ws of group.workspaces) {
            if (ws.active) {
                return ws;
            }
        }
        return null;
    }

    function getVisibleWorkspaces(outputName) {
        const workspaces = getWorkspacesForOutput(outputName);
        let visible = workspaces.filter(ws => !ws.hidden);

        const hasValidCoordinates = visible.some(ws => ws.coordinates && ws.coordinates.length > 0);
        if (hasValidCoordinates) {
            visible = visible.sort((a, b) => {
                const coordsA = a.coordinates || [0, 0];
                const coordsB = b.coordinates || [0, 0];
                if (coordsA[0] !== coordsB[0])
                    return coordsA[0] - coordsB[0];
                return coordsA[1] - coordsB[1];
            });
        }

        const cacheKey = outputName;
        if (!_cachedWorkspaces[cacheKey]) {
            _cachedWorkspaces[cacheKey] = {
                workspaces: [],
                lastNames: []
            };
        }

        const cache = _cachedWorkspaces[cacheKey];
        const currentNames = visible.map(ws => ws.name || ws.id);
        const namesChanged = JSON.stringify(cache.lastNames) !== JSON.stringify(currentNames);

        if (namesChanged || cache.workspaces.length !== visible.length) {
            cache.workspaces = visible.map(ws => ({
                        id: ws.id,
                        name: ws.name,
                        coordinates: ws.coordinates,
                        state: ws.state,
                        active: ws.active,
                        urgent: ws.urgent,
                        hidden: ws.hidden
                    }));
            cache.lastNames = currentNames;
            return cache.workspaces;
        }

        for (let i = 0; i < visible.length; i++) {
            const src = visible[i];
            const dst = cache.workspaces[i];
            dst.id = src.id;
            dst.name = src.name;
            dst.coordinates = src.coordinates;
            dst.state = src.state;
            dst.active = src.active;
            dst.urgent = src.urgent;
            dst.hidden = src.hidden;
        }

        return cache.workspaces;
    }

    function getUrgentWorkspaces() {
        const urgent = [];
        for (const group of groups) {
            if (!group.workspaces)
                continue;
            for (const ws of group.workspaces) {
                if (ws.urgent) {
                    urgent.push({
                        workspace: ws,
                        group: group,
                        outputs: group.outputs || []
                    });
                }
            }
        }
        return urgent;
    }

    function switchToWorkspace(outputName, workspaceName) {
        const workspaces = getWorkspacesForOutput(outputName);
        for (const ws of workspaces) {
            if (ws.name === workspaceName || ws.id === workspaceName) {
                activateWorkspace(ws.name || ws.id);
                return;
            }
        }
        console.warn("ExtWorkspaceService: workspace not found:", workspaceName);
    }
}
