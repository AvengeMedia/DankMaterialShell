import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.I3
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string screenName: ""
    property real widgetHeight: 30
    property real barThickness: 48
    property var barConfig: null
    property var hyprlandOverviewLoader: null
    property var parentScreen: null
    property int _desktopEntriesUpdateTrigger: 0
    readonly property var sortedToplevels: {
        return CompositorService.filterCurrentWorkspace(CompositorService.sortedToplevels, screenName);
    }

    readonly property bool useExtWorkspace: DMSService.forceExtWorkspace || (!CompositorService.isNiri && !CompositorService.isHyprland && !CompositorService.isDwl && !CompositorService.isSway && !CompositorService.isScroll && ExtWorkspaceService.extWorkspaceAvailable)

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            _desktopEntriesUpdateTrigger++;
        }
    }

    property var currentWorkspace: {
        if (useExtWorkspace)
            return getExtWorkspaceActiveWorkspace();

        switch (CompositorService.compositor) {
        case "niri":
            return getNiriActiveWorkspace();
        case "hyprland":
            return getHyprlandActiveWorkspace();
        case "dwl":
            const activeTags = getDwlActiveTags();
            return activeTags.length > 0 ? activeTags[0] : -1;
        case "sway":
        case "scroll":
            return getSwayActiveWorkspace();
        default:
            return 1;
        }
    }
    property var dwlActiveTags: {
        if (CompositorService.isDwl) {
            return getDwlActiveTags();
        }
        return [];
    }
    property var workspaceList: {
        if (useExtWorkspace) {
            const baseList = getExtWorkspaceWorkspaces();
            return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList;
        }

        let baseList;
        switch (CompositorService.compositor) {
        case "niri":
            baseList = getNiriWorkspaces();
            break;
        case "hyprland":
            baseList = getHyprlandWorkspaces();
            break;
        case "dwl":
            baseList = getDwlTags();
            break;
        case "sway":
        case "scroll":
            baseList = getSwayWorkspaces();
            break;
        default:
            return [1];
        }
        return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList;
    }

    function getSwayWorkspaces() {
        const workspaces = I3.workspaces?.values || [];
        if (workspaces.length === 0)
            return [
                {
                    "num": 1
                }
            ];

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return workspaces.slice().sort((a, b) => a.num - b.num);
        }

        const monitorWorkspaces = workspaces.filter(ws => ws.monitor?.name === root.screenName);
        return monitorWorkspaces.length > 0 ? monitorWorkspaces.sort((a, b) => a.num - b.num) : [
            {
                "num": 1
            }
        ];
    }

    function getSwayActiveWorkspace() {
        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            const focusedWs = I3.workspaces?.values?.find(ws => ws.focused === true);
            return focusedWs ? focusedWs.num : 1;
        }

        const focusedWs = I3.workspaces?.values?.find(ws => ws.monitor?.name === root.screenName && ws.focused === true);
        return focusedWs ? focusedWs.num : 1;
    }

    function getHyprlandWorkspaces() {
        const workspaces = Hyprland.workspaces?.values || [];
        if (workspaces.length === 0) {
            return [
                {
                    id: 1,
                    name: "1"
                }
            ];
        }

        let filtered = workspaces.filter(ws => ws.id > -1);
        if (filtered.length === 0) {
            return [
                {
                    id: 1,
                    name: "1"
                }
            ];
        }

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            filtered = filtered.slice().sort((a, b) => a.id - b.id);
        } else {
            const monitorWorkspaces = filtered.filter(ws => ws.monitor?.name === root.screenName);
            filtered = monitorWorkspaces.length > 0 ? monitorWorkspaces.sort((a, b) => a.id - b.id) : [
                {
                    id: 1,
                    name: "1"
                }
            ];
        }

        if (!SettingsData.showOccupiedWorkspacesOnly) {
            return filtered;
        }

        const hyprlandToplevels = Array.from(Hyprland.toplevels?.values || []);
        const activeWsId = root.currentWorkspace;
        return filtered.filter(ws => {
            if (ws.id === activeWsId)
                return true;
            return hyprlandToplevels.some(tl => tl.workspace?.id === ws.id);
        });
    }

    function getHyprlandActiveWorkspace() {
        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return Hyprland.focusedWorkspace?.id || 1;
        }

        const monitor = Hyprland.monitors?.values?.find(m => m.name === root.screenName);
        return monitor?.activeWorkspace?.id || 1;
    }

    function getWorkspaceIcons(ws) {
        _desktopEntriesUpdateTrigger;
        if (!SettingsData.showWorkspaceApps || !ws) {
            return [];
        }

        let targetWorkspaceId;
        if (CompositorService.isNiri) {
            const wsNumber = typeof ws === "number" ? ws : -1;
            if (wsNumber <= 0) {
                return [];
            }
            const workspace = NiriService.allWorkspaces.find(w => w.idx + 1 === wsNumber && w.output === root.screenName);
            if (!workspace) {
                return [];
            }
            targetWorkspaceId = workspace.id;
        } else if (CompositorService.isHyprland) {
            targetWorkspaceId = ws.id !== undefined ? ws.id : ws;
        } else if (CompositorService.isDwl) {
            if (typeof ws !== "object" || ws.tag === undefined) {
                return [];
            }
            targetWorkspaceId = ws.tag;
        } else if (CompositorService.isSway || CompositorService.isScroll) {
            targetWorkspaceId = ws.num !== undefined ? ws.num : ws;
        } else {
            return [];
        }

        const wins = CompositorService.isNiri ? (NiriService.windows || []) : CompositorService.sortedToplevels;

        const byApp = {};
        let isActiveWs = false;
        if (CompositorService.isNiri) {
            isActiveWs = NiriService.allWorkspaces.some(ws => ws.id === targetWorkspaceId && ws.is_active);
        } else if (CompositorService.isSway || CompositorService.isScroll) {
            const focusedWs = I3.workspaces?.values?.find(ws => ws.focused === true);
            isActiveWs = focusedWs ? (focusedWs.num === targetWorkspaceId) : false;
        } else if (CompositorService.isDwl) {
            const output = DwlService.getOutputState(root.screenName);
            if (output && output.tags) {
                const tag = output.tags.find(t => t.tag === targetWorkspaceId);
                isActiveWs = tag ? (tag.state === 1) : false;
            }
        } else {
            isActiveWs = targetWorkspaceId === root.currentWorkspace;
        }

        wins.forEach((w, i) => {
            if (!w) {
                return;
            }

            let winWs = null;
            if (CompositorService.isNiri) {
                winWs = w.workspace_id;
            } else if (CompositorService.isSway || CompositorService.isScroll) {
                winWs = w.workspace?.num;
            } else {
                const hyprlandToplevels = Array.from(Hyprland.toplevels?.values || []);
                const hyprToplevel = hyprlandToplevels.find(ht => ht.wayland === w);
                winWs = hyprToplevel?.workspace?.id;
            }

            if (winWs === undefined || winWs === null || winWs !== targetWorkspaceId) {
                return;
            }

            const keyBase = (w.app_id || w.appId || w.class || w.windowClass || "unknown");
            const key = isActiveWs || !SettingsData.groupWorkspaceApps ? `${keyBase}_${i}` : keyBase;

            if (!byApp[key]) {
                const moddedId = Paths.moddedAppId(keyBase);
                const isSteamApp = moddedId.toLowerCase().includes("steam_app");
                const isQuickshell = keyBase === "org.quickshell";
                const desktopEntry = DesktopEntries.heuristicLookup(keyBase);
                const icon = isSteamApp ? "" : Paths.getAppIcon(keyBase, desktopEntry);
                byApp[key] = {
                    "type": "icon",
                    "icon": icon,
                    "isSteamApp": isSteamApp,
                    "isQuickshell": isQuickshell,
                    "active": !!((w.activated || w.is_focused) || (CompositorService.isNiri && w.is_focused)),
                    "count": 1,
                    "windowId": w.address || w.id,
                    "fallbackText": w.appId || w.class || w.title || ""
                };
            } else {
                byApp[key].count++;
                if ((w.activated || w.is_focused) || (CompositorService.isNiri && w.is_focused)) {
                    byApp[key].active = true;
                }
            }
        });

        return Object.values(byApp);
    }

    function padWorkspaces(list) {
        const padded = list.slice();
        let placeholder;
        if (useExtWorkspace) {
            placeholder = {
                "id": "",
                "name": "",
                "active": false,
                "hidden": true
            };
        } else if (CompositorService.isHyprland) {
            placeholder = {
                "id": -1,
                "name": ""
            };
        } else if (CompositorService.isDwl) {
            placeholder = {
                "tag": -1
            };
        } else if (CompositorService.isSway || CompositorService.isScroll) {
            placeholder = {
                "num": -1
            };
        } else {
            placeholder = -1;
        }
        while (padded.length < 3) {
            padded.push(placeholder);
        }
        return padded;
    }

    function getNiriWorkspaces() {
        if (NiriService.allWorkspaces.length === 0) {
            return [1, 2];
        }

        let workspaces;
        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            workspaces = NiriService.getCurrentOutputWorkspaceNumbers();
        } else {
            const displayWorkspaces = NiriService.allWorkspaces.filter(ws => ws.output === root.screenName).map(ws => ws.idx + 1);
            workspaces = displayWorkspaces.length > 0 ? displayWorkspaces : [1, 2];
        }

        if (!SettingsData.showOccupiedWorkspacesOnly) {
            return workspaces;
        }

        return workspaces.filter(wsNum => {
            const workspace = NiriService.allWorkspaces.find(w => w.idx + 1 === wsNum && w.output === root.screenName);
            if (!workspace)
                return false;
            if (workspace.is_active)
                return true;
            return NiriService.windows?.some(win => win.workspace_id === workspace.id) ?? false;
        });
    }

    function getNiriActiveWorkspace() {
        if (NiriService.allWorkspaces.length === 0) {
            return 1;
        }

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return NiriService.getCurrentWorkspaceNumber();
        }

        const activeWs = NiriService.allWorkspaces.find(ws => ws.output === root.screenName && ws.is_active);
        return activeWs ? activeWs.idx + 1 : 1;
    }

    function getDwlTags() {
        if (!DwlService.dwlAvailable) {
            return [];
        }

        const output = DwlService.getOutputState(root.screenName);
        if (!output || !output.tags || output.tags.length === 0) {
            return [];
        }

        if (SettingsData.dwlShowAllTags) {
            return output.tags.map(tag => ({
                        "tag": tag.tag,
                        "state": tag.state,
                        "clients": tag.clients,
                        "focused": tag.focused
                    }));
        }

        const visibleTagIndices = DwlService.getVisibleTags(root.screenName);
        return visibleTagIndices.map(tagIndex => {
            const tagData = output.tags.find(t => t.tag === tagIndex);
            return {
                "tag": tagIndex,
                "state": tagData?.state ?? 0,
                "clients": tagData?.clients ?? 0,
                "focused": tagData?.focused ?? false
            };
        });
    }

    function getDwlActiveTags() {
        if (!DwlService.dwlAvailable) {
            return [];
        }

        const activeTags = DwlService.getActiveTags(root.screenName);
        return activeTags;
    }

    function getExtWorkspaceWorkspaces() {
        const groups = ExtWorkspaceService.groups;
        if (!ExtWorkspaceService.extWorkspaceAvailable || groups.length === 0) {
            return [
                {
                    "id": "1",
                    "name": "1",
                    "active": false
                }
            ];
        }

        const group = groups.find(g => g.outputs && g.outputs.includes(root.screenName));
        if (!group || !group.workspaces) {
            return [
                {
                    "id": "1",
                    "name": "1",
                    "active": false
                }
            ];
        }

        let visible = group.workspaces.filter(ws => !ws.hidden);

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

        visible = visible.map(ws => ({
                    id: ws.id,
                    name: ws.name,
                    coordinates: ws.coordinates,
                    state: ws.state,
                    active: ws.active,
                    urgent: ws.urgent,
                    hidden: ws.hidden,
                    groupID: group.id
                }));

        return visible.length > 0 ? visible : [
            {
                "id": "1",
                "name": "1",
                "active": false
            }
        ];
    }

    function getExtWorkspaceActiveWorkspace() {
        if (!ExtWorkspaceService.extWorkspaceAvailable) {
            return 1;
        }

        const activeWs = ExtWorkspaceService.getActiveWorkspaceForOutput(root.screenName);
        return activeWs ? (activeWs.id || activeWs.name || "1") : "1";
    }

    readonly property real padding: Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))
    readonly property real visualWidth: isVertical ? widgetHeight : (workspaceRow.implicitWidth + padding * 2)
    readonly property real visualHeight: isVertical ? (workspaceRow.implicitHeight + padding * 2) : widgetHeight
    readonly property real appIconSize: Theme.barIconSize(barThickness, -6)

    function getRealWorkspaces() {
        return root.workspaceList.filter(ws => {
            if (useExtWorkspace)
                return ws && (ws.id !== "" || ws.name !== "") && !ws.hidden;
            if (CompositorService.isHyprland)
                return ws && ws.id !== -1;
            if (CompositorService.isDwl)
                return ws && ws.tag !== -1;
            if (CompositorService.isSway || CompositorService.isScroll)
                return ws && ws.num !== -1;
            return ws !== -1;
        });
    }

    function switchWorkspace(direction) {
        if (useExtWorkspace) {
            const realWorkspaces = getRealWorkspaces();
            if (realWorkspaces.length < 2) {
                return;
            }

            const currentIndex = realWorkspaces.findIndex(ws => (ws.id || ws.name) === root.currentWorkspace);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex === validIndex) {
                return;
            }

            const nextWorkspace = realWorkspaces[nextIndex];
            ExtWorkspaceService.activateWorkspace(nextWorkspace.id || nextWorkspace.name, nextWorkspace.groupID || "");
        } else if (CompositorService.isNiri) {
            const realWorkspaces = getRealWorkspaces();
            if (realWorkspaces.length < 2) {
                return;
            }

            const currentIndex = realWorkspaces.findIndex(ws => ws === root.currentWorkspace);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex === validIndex) {
                return;
            }

            NiriService.switchToWorkspace(realWorkspaces[nextIndex] - 1);
        } else if (CompositorService.isHyprland) {
            const realWorkspaces = getRealWorkspaces();
            if (realWorkspaces.length < 2) {
                return;
            }

            const currentIndex = realWorkspaces.findIndex(ws => ws.id === root.currentWorkspace);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex === validIndex) {
                return;
            }

            Hyprland.dispatch(`workspace ${realWorkspaces[nextIndex].id}`);
        } else if (CompositorService.isDwl) {
            const realWorkspaces = getRealWorkspaces();
            if (realWorkspaces.length < 2) {
                return;
            }

            const currentIndex = realWorkspaces.findIndex(ws => ws.tag === root.currentWorkspace);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex === validIndex) {
                return;
            }

            DwlService.switchToTag(root.screenName, realWorkspaces[nextIndex].tag);
        } else if (CompositorService.isSway || CompositorService.isScroll) {
            const realWorkspaces = getRealWorkspaces();
            if (realWorkspaces.length < 2) {
                return;
            }

            const currentIndex = realWorkspaces.findIndex(ws => ws.num === root.currentWorkspace);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex === validIndex) {
                return;
            }

            try {
                I3.dispatch(`workspace number ${realWorkspaces[nextIndex].num}`);
            } catch (_) {}
        }
    }

    function getWorkspaceIndex(modelData, index) {
        let isPlaceholder;
        if (root.useExtWorkspace) {
            isPlaceholder = modelData?.hidden === true;
        } else if (CompositorService.isHyprland) {
            isPlaceholder = modelData?.id === -1;
        } else if (CompositorService.isDwl) {
            isPlaceholder = modelData?.tag === -1;
        } else if (CompositorService.isSway || CompositorService.isScroll) {
            isPlaceholder = modelData?.num === -1;
        } else {
            isPlaceholder = modelData === -1;
        }

        if (isPlaceholder)
            return index + 1;

        if (SettingsData.showWorkspaceName) {
            let workspaceName = modelData?.name;

            if (workspaceName && workspaceName !== "") {
                if (root.isVertical) {
                    return workspaceName.charAt(0);
                }
                return workspaceName;
            }
        }

        if (root.useExtWorkspace)
            return index + 1;
        if (CompositorService.isHyprland)
            return modelData?.id || "";
        if (CompositorService.isDwl)
            return (modelData?.tag !== undefined) ? (modelData.tag + 1) : "";
        if (CompositorService.isSway || CompositorService.isScroll)
            return modelData?.num || "";
        return modelData - 1;
    }

    readonly property bool hasNativeWorkspaceSupport: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isDwl || CompositorService.isSway || CompositorService.isScroll
    readonly property bool hasWorkspaces: getRealWorkspaces().length > 0
    readonly property bool shouldShow: hasNativeWorkspaceSupport || (useExtWorkspace && hasWorkspaces)

    width: shouldShow ? (isVertical ? barThickness : visualWidth) : 0
    height: shouldShow ? (isVertical ? visualHeight : barThickness) : 0
    visible: shouldShow

    Item {
        id: visualBackground
        width: root.visualWidth
        height: root.visualHeight
        anchors.centerIn: parent

        Rectangle {
            id: outline
            anchors.centerIn: parent
            width: {
                const borderWidth = (barConfig?.widgetOutlineEnabled ?? false) ? (barConfig?.widgetOutlineThickness ?? 1) : 0;
                return parent.width + borderWidth * 2;
            }
            height: {
                const borderWidth = (barConfig?.widgetOutlineEnabled ?? false) ? (barConfig?.widgetOutlineThickness ?? 1) : 0;
                return parent.height + borderWidth * 2;
            }
            radius: (barConfig?.noBackground ?? false) ? 0 : Theme.cornerRadius
            color: "transparent"
            border.width: {
                if (barConfig?.widgetOutlineEnabled ?? false) {
                    return barConfig?.widgetOutlineThickness ?? 1;
                }
                return 0;
            }
            border.color: {
                if (!(barConfig?.widgetOutlineEnabled ?? false)) {
                    return "transparent";
                }
                const colorOption = barConfig?.widgetOutlineColor || "primary";
                const opacity = barConfig?.widgetOutlineOpacity ?? 1.0;
                switch (colorOption) {
                case "surfaceText":
                    return Theme.withAlpha(Theme.surfaceText, opacity);
                case "secondary":
                    return Theme.withAlpha(Theme.secondary, opacity);
                case "primary":
                    return Theme.withAlpha(Theme.primary, opacity);
                default:
                    return Theme.withAlpha(Theme.primary, opacity);
                }
            }
        }

        Rectangle {
            id: background
            anchors.fill: parent
            radius: (barConfig?.noBackground ?? false) ? 0 : Theme.cornerRadius
            color: {
                if ((barConfig?.noBackground ?? false))
                    return "transparent";
                const baseColor = Theme.widgetBaseBackgroundColor;
                const transparency = (root.barConfig && root.barConfig.widgetTransparency !== undefined) ? root.barConfig.widgetTransparency : 1.0;
                if (Theme.widgetBackgroundHasAlpha) {
                    return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * transparency);
                }
                return Theme.withAlpha(baseColor, transparency);
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton

        property real touchpadAccumulator: 0
        property real mouseAccumulator: 0
        property bool scrollInProgress: false

        Timer {
            id: scrollCooldown
            interval: 100
            onTriggered: parent.scrollInProgress = false
        }

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (CompositorService.isNiri) {
                    NiriService.toggleOverview();
                } else if (CompositorService.isHyprland && root.hyprlandOverviewLoader?.item) {
                    root.hyprlandOverviewLoader.item.overviewOpen = !root.hyprlandOverviewLoader.item.overviewOpen;
                }
            }
        }

        onWheel: wheel => {
            if (scrollInProgress)
                return;

            const delta = wheel.angleDelta.y;
            const isTouchpad = wheel.pixelDelta && wheel.pixelDelta.y !== 0;
            const reverse = SettingsData.reverseScrolling ? -1 : 1;

            if (isTouchpad) {
                touchpadAccumulator += delta;
                if (Math.abs(touchpadAccumulator) < 500)
                    return;
                const direction = touchpadAccumulator * reverse < 0 ? 1 : -1;
                root.switchWorkspace(direction);
                scrollInProgress = true;
                scrollCooldown.restart();
                touchpadAccumulator = 0;
                return;
            }

            mouseAccumulator += delta;
            if (Math.abs(mouseAccumulator) < 120)
                return;
            const direction = mouseAccumulator * reverse < 0 ? 1 : -1;
            root.switchWorkspace(direction);
            scrollInProgress = true;
            scrollCooldown.restart();
            mouseAccumulator = 0;
        }
    }

    Flow {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: Theme.spacingS
        flow: isVertical ? Flow.TopToBottom : Flow.LeftToRight

        Repeater {
            model: ScriptModel {
                values: root.workspaceList
            }

            Item {
                id: delegateRoot

                property bool isActive: {
                    if (root.useExtWorkspace)
                        return (modelData?.id || modelData?.name) === root.currentWorkspace;
                    if (CompositorService.isHyprland)
                        return !!(modelData && modelData.id === root.currentWorkspace);
                    if (CompositorService.isDwl)
                        return !!(modelData && root.dwlActiveTags.includes(modelData.tag));
                    if (CompositorService.isSway || CompositorService.isScroll)
                        return !!(modelData && modelData.num === root.currentWorkspace);
                    return modelData === root.currentWorkspace;
                }
                property bool isPlaceholder: {
                    if (root.useExtWorkspace)
                        return !!(modelData && modelData.hidden);
                    if (CompositorService.isHyprland)
                        return !!(modelData && modelData.id === -1);
                    if (CompositorService.isDwl)
                        return !!(modelData && modelData.tag === -1);
                    if (CompositorService.isSway || CompositorService.isScroll)
                        return !!(modelData && modelData.num === -1);
                    return modelData === -1;
                }
                property bool isHovered: mouseArea.containsMouse

                property var loadedWorkspaceData: null
                property bool loadedIsUrgent: false
                property bool isUrgent: {
                    if (root.useExtWorkspace)
                        return modelData?.urgent ?? false;
                    if (CompositorService.isHyprland)
                        return modelData?.urgent ?? false;
                    if (CompositorService.isNiri)
                        return loadedIsUrgent;
                    if (CompositorService.isDwl)
                        return modelData?.state === 2;
                    if (CompositorService.isSway || CompositorService.isScroll)
                        return loadedIsUrgent;
                    return false;
                }
                property var loadedIconData: null
                property bool loadedHasIcon: false
                property var loadedIcons: []

                readonly property real baseWidth: root.isVertical ? (SettingsData.showWorkspaceApps ? widgetHeight * 0.7 : widgetHeight * 0.5) : (isActive ? root.widgetHeight * 1.05 : root.widgetHeight * 0.7)
                readonly property real baseHeight: root.isVertical ? (isActive ? root.widgetHeight * 1.05 : root.widgetHeight * 0.7) : (SettingsData.showWorkspaceApps ? widgetHeight * 0.7 : widgetHeight * 0.5)

                readonly property real iconsExtraWidth: {
                    if (!root.isVertical && SettingsData.showWorkspaceApps && loadedIcons.length > 0) {
                        const numIcons = Math.min(loadedIcons.length, SettingsData.maxWorkspaceIcons);
                        return numIcons * root.appIconSize + (numIcons > 0 ? (numIcons - 1) * Theme.spacingXS : 0) + (isActive ? Theme.spacingXS : 0);
                    }
                    return 0;
                }
                readonly property real iconsExtraHeight: {
                    if (root.isVertical && SettingsData.showWorkspaceApps && loadedIcons.length > 0) {
                        const numIcons = Math.min(loadedIcons.length, SettingsData.maxWorkspaceIcons);
                        return numIcons * root.appIconSize + (numIcons > 0 ? (numIcons - 1) * Theme.spacingXS : 0) + (isActive ? Theme.spacingXS : 0);
                    }
                    return 0;
                }

                readonly property real visualWidth: baseWidth + iconsExtraWidth
                readonly property real visualHeight: baseHeight + iconsExtraHeight

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: !isPlaceholder
                    cursorShape: isPlaceholder ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !isPlaceholder
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (isPlaceholder)
                            return;
                        const isRightClick = mouse.button === Qt.RightButton;

                        if (root.useExtWorkspace && (modelData?.id || modelData?.name)) {
                            ExtWorkspaceService.activateWorkspace(modelData.id || modelData.name, modelData.groupID || "");
                        } else if (CompositorService.isNiri) {
                            if (isRightClick) {
                                NiriService.toggleOverview();
                            } else {
                                NiriService.switchToWorkspace(modelData - 1);
                            }
                        } else if (CompositorService.isHyprland && modelData?.id) {
                            if (isRightClick && root.hyprlandOverviewLoader?.item) {
                                root.hyprlandOverviewLoader.item.overviewOpen = !root.hyprlandOverviewLoader.item.overviewOpen;
                            } else {
                                Hyprland.dispatch(`workspace ${modelData.id}`);
                            }
                        } else if (CompositorService.isDwl && modelData?.tag !== undefined) {
                            console.log("DWL click - tag:", modelData.tag, "rightClick:", isRightClick);
                            if (isRightClick) {
                                console.log("Calling toggleTag");
                                DwlService.toggleTag(root.screenName, modelData.tag);
                            } else {
                                console.log("Calling switchToTag");
                                DwlService.switchToTag(root.screenName, modelData.tag);
                            }
                        } else if ((CompositorService.isSway || CompositorService.isScroll) && modelData?.num) {
                            try {
                                I3.dispatch(`workspace number ${modelData.num}`);
                            } catch (_) {}
                        }
                    }
                }

                Timer {
                    id: dataUpdateTimer
                    interval: 50
                    onTriggered: {
                        if (isPlaceholder) {
                            delegateRoot.loadedWorkspaceData = null;
                            delegateRoot.loadedIconData = null;
                            delegateRoot.loadedHasIcon = false;
                            delegateRoot.loadedIcons = [];
                            delegateRoot.loadedIsUrgent = false;
                            return;
                        }

                        var wsData = null;
                        if (root.useExtWorkspace) {
                            wsData = modelData;
                        } else if (CompositorService.isNiri) {
                            wsData = NiriService.allWorkspaces.find(ws => ws.idx + 1 === modelData && ws.output === root.screenName) || null;
                        } else if (CompositorService.isHyprland) {
                            wsData = modelData;
                        } else if (CompositorService.isDwl) {
                            wsData = modelData;
                        } else if (CompositorService.isSway || CompositorService.isScroll) {
                            wsData = modelData;
                        }
                        delegateRoot.loadedWorkspaceData = wsData;
                        if (CompositorService.isNiri) {
                            const workspaceId = wsData?.id;
                            delegateRoot.loadedIsUrgent = workspaceId ? NiriService.windows.some(w => w.workspace_id === workspaceId && w.is_urgent) : false;
                        } else {
                            delegateRoot.loadedIsUrgent = wsData?.urgent ?? false;
                        }

                        var icData = null;
                        if (wsData?.name) {
                            icData = SettingsData.getWorkspaceNameIcon(wsData.name);
                        }
                        delegateRoot.loadedIconData = icData;
                        delegateRoot.loadedHasIcon = icData !== null;

                        if (SettingsData.showWorkspaceApps) {
                            if (CompositorService.isDwl || CompositorService.isSway || CompositorService.isScroll) {
                                delegateRoot.loadedIcons = root.getWorkspaceIcons(modelData);
                            } else {
                                delegateRoot.loadedIcons = root.getWorkspaceIcons(CompositorService.isHyprland ? modelData : (modelData === -1 ? null : modelData));
                            }
                        } else {
                            delegateRoot.loadedIcons = [];
                        }
                    }
                }

                function updateAllData() {
                    dataUpdateTimer.restart();
                }

                width: root.isVertical ? root.barThickness : visualWidth
                height: root.isVertical ? visualHeight : root.barThickness

                Rectangle {
                    id: visualContent
                    width: delegateRoot.visualWidth
                    height: delegateRoot.visualHeight
                    anchors.centerIn: parent
                    radius: Theme.cornerRadius
                    color: isActive ? Theme.primary : isUrgent ? Theme.error : isPlaceholder ? Theme.surfaceTextLight : isHovered ? Theme.withAlpha(Theme.surfaceText, 0.45) : Theme.surfaceTextAlpha

                    border.width: isUrgent ? 2 : 0
                    border.color: isUrgent ? Theme.error : Theme.withAlpha(Theme.error, 0)

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on border.width {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Loader {
                        id: appIconsLoader
                        anchors.fill: parent
                        active: SettingsData.showWorkspaceApps
                        sourceComponent: Item {
                            Loader {
                                id: contentRow
                                anchors.centerIn: parent
                                sourceComponent: root.isVertical ? columnLayout : rowLayout
                            }

                            Component {
                                id: rowLayout
                                Row {
                                    spacing: 4
                                    visible: loadedIcons.length > 0 || SettingsData.showWorkspaceIndex || SettingsData.showWorkspaceName || loadedHasIcon

                                    Item {
                                        visible: loadedHasIcon && loadedIconData?.type === "icon"
                                        width: wsIcon.width + (isActive && loadedIcons.length > 0 ? 4 : 0)
                                        height: root.appIconSize

                                        DankIcon {
                                            id: wsIcon
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: loadedIconData?.value ?? ""
                                            size: Theme.barTextSize(barThickness, barConfig?.fontScale)
                                            color: (isActive || isUrgent) ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                                            weight: (isActive && !isPlaceholder) ? 500 : 400
                                        }
                                    }

                                    Item {
                                        visible: loadedHasIcon && loadedIconData?.type === "text"
                                        width: wsText.implicitWidth + (isActive && loadedIcons.length > 0 ? 4 : 0)
                                        height: root.appIconSize

                                        StyledText {
                                            id: wsText
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: loadedIconData?.value ?? ""
                                            color: (isActive || isUrgent) ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                                            font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale)
                                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                                        }
                                    }

                                    Item {
                                        visible: (SettingsData.showWorkspaceIndex || SettingsData.showWorkspaceName) && !loadedHasIcon
                                        width: wsIndexText.implicitWidth + (isActive && loadedIcons.length > 0 ? 4 : 0)
                                        height: root.appIconSize

                                        StyledText {
                                            id: wsIndexText
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.getWorkspaceIndex(modelData, index)
                                            color: (isActive || isUrgent) ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                                            font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale)
                                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                                        }
                                    }

                                    Repeater {
                                        model: ScriptModel {
                                            values: loadedIcons.slice(0, SettingsData.maxWorkspaceIcons)
                                        }
                                        delegate: Item {
                                            width: root.appIconSize
                                            height: root.appIconSize

                                            IconImage {
                                                id: rowAppIcon
                                                anchors.fill: parent
                                                source: modelData.icon
                                                opacity: modelData.active ? 1.0 : rowAppMouseArea.containsMouse ? 0.8 : 0.6
                                                visible: !modelData.isSteamApp && !modelData.isQuickshell
                                            }

                                            IconImage {
                                                anchors.fill: parent
                                                source: modelData.icon
                                                opacity: modelData.active ? 1.0 : rowAppMouseArea.containsMouse ? 0.8 : 0.6
                                                visible: modelData.isQuickshell
                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    saturation: 0
                                                    colorization: 1
                                                    colorizationColor: isActive ? Theme.primaryContainer : Theme.primary
                                                }
                                            }

                                            DankIcon {
                                                anchors.centerIn: parent
                                                size: root.appIconSize
                                                name: "sports_esports"
                                                color: Theme.widgetTextColor
                                                opacity: modelData.active ? 1.0 : rowAppMouseArea.containsMouse ? 0.8 : 0.6
                                                visible: modelData.isSteamApp
                                            }

                                            MouseArea {
                                                id: rowAppMouseArea
                                                anchors.fill: parent
                                                enabled: isActive
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const winId = modelData.windowId;
                                                    if (!winId)
                                                        return;
                                                    if (CompositorService.isHyprland) {
                                                        Hyprland.dispatch(`focuswindow address:${winId}`);
                                                    } else if (CompositorService.isNiri) {
                                                        NiriService.focusWindow(winId);
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: modelData.count > 1 && !isActive
                                                width: root.appIconSize * 0.67
                                                height: root.appIconSize * 0.67
                                                radius: root.appIconSize * 0.33
                                                color: "black"
                                                border.color: "white"
                                                border.width: 1
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                z: 2

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.count
                                                    font.pixelSize: root.appIconSize * 0.44
                                                    color: "white"
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Component {
                                id: columnLayout
                                Column {
                                    spacing: 4
                                    visible: loadedIcons.length > 0 || SettingsData.showWorkspaceIndex || SettingsData.showWorkspaceName || loadedHasIcon

                                    DankIcon {
                                        visible: loadedHasIcon && loadedIconData?.type === "icon"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        name: loadedIconData?.value ?? ""
                                        size: Theme.barTextSize(barThickness, barConfig?.fontScale)
                                        color: (isActive || isUrgent) ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                                        weight: (isActive && !isPlaceholder) ? 500 : 400
                                    }

                                    StyledText {
                                        visible: loadedHasIcon && loadedIconData?.type === "text"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: loadedIconData?.value ?? ""
                                        color: (isActive || isUrgent) ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                                        font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale)
                                        font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                                    }

                                    Repeater {
                                        model: ScriptModel {
                                            values: loadedIcons.slice(0, SettingsData.maxWorkspaceIcons)
                                        }
                                        delegate: Item {
                                            width: root.appIconSize
                                            height: root.appIconSize

                                            IconImage {
                                                id: colAppIcon
                                                anchors.fill: parent
                                                source: modelData.icon
                                                opacity: modelData.active ? 1.0 : colAppMouseArea.containsMouse ? 0.8 : 0.6
                                                visible: !modelData.isSteamApp && !modelData.isQuickshell
                                            }

                                            IconImage {
                                                anchors.fill: parent
                                                source: modelData.icon
                                                opacity: modelData.active ? 1.0 : colAppMouseArea.containsMouse ? 0.8 : 0.6
                                                visible: modelData.isQuickshell
                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    saturation: 0
                                                    colorization: 1
                                                    colorizationColor: isActive ? Theme.primaryContainer : Theme.primary
                                                }
                                            }

                                            DankIcon {
                                                anchors.centerIn: parent
                                                size: root.appIconSize
                                                name: "sports_esports"
                                                color: Theme.widgetTextColor
                                                opacity: modelData.active ? 1.0 : colAppMouseArea.containsMouse ? 0.8 : 0.6
                                                visible: modelData.isSteamApp
                                            }

                                            MouseArea {
                                                id: colAppMouseArea
                                                anchors.fill: parent
                                                enabled: isActive
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const winId = modelData.windowId;
                                                    if (!winId)
                                                        return;
                                                    if (CompositorService.isHyprland) {
                                                        Hyprland.dispatch(`focuswindow address:${winId}`);
                                                    } else if (CompositorService.isNiri) {
                                                        NiriService.focusWindow(winId);
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: modelData.count > 1 && !isActive
                                                width: root.appIconSize * 0.67
                                                height: root.appIconSize * 0.67
                                                radius: root.appIconSize * 0.33
                                                color: "black"
                                                border.color: "white"
                                                border.width: 1
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                z: 2

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.count
                                                    font.pixelSize: root.appIconSize * 0.44
                                                    color: "white"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Loader for Custom Name Icon
                    Loader {
                        id: customIconLoader
                        anchors.fill: parent
                        active: !isPlaceholder && loadedHasIcon && loadedIconData.type === "icon" && !SettingsData.showWorkspaceApps
                        sourceComponent: Item {
                            DankIcon {
                                anchors.centerIn: parent
                                name: loadedIconData ? loadedIconData.value : "" // NULL CHECK
                                size: Theme.fontSizeSmall
                                color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                                weight: isActive && !isPlaceholder ? 500 : 400
                            }
                        }
                    }

                    // Loader for Custom Name Text
                    Loader {
                        id: customTextLoader
                        anchors.fill: parent
                        active: !isPlaceholder && loadedHasIcon && loadedIconData.type === "text" && !SettingsData.showWorkspaceApps
                        sourceComponent: Item {
                            StyledText {
                                anchors.centerIn: parent
                                text: loadedIconData ? loadedIconData.value : "" // NULL CHECK
                                color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                                font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale)
                                font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                            }
                        }
                    }

                    // Loader for Workspace Index
                    Loader {
                        id: indexLoader
                        anchors.fill: parent
                        active: (SettingsData.showWorkspaceIndex || SettingsData.showWorkspaceName) && !loadedHasIcon && !SettingsData.showWorkspaceApps
                        sourceComponent: Item {
                            StyledText {
                                anchors.centerIn: parent
                                text: {
                                    return root.getWorkspaceIndex(modelData, index);
                                }
                                color: (isActive || isUrgent) ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                                font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale)
                                font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                            }
                        }
                    }
                }

                Component.onCompleted: updateAllData()

                Connections {
                    target: CompositorService
                    function onSortedToplevelsChanged() {
                        delegateRoot.updateAllData();
                    }
                }
                Connections {
                    target: NiriService
                    enabled: CompositorService.isNiri
                    function onAllWorkspacesChanged() {
                        delegateRoot.updateAllData();
                    }
                    function onWindowUrgentChanged() {
                        delegateRoot.updateAllData();
                    }
                    function onWindowsChanged() {
                        delegateRoot.updateAllData();
                    }
                }
                Connections {
                    target: SettingsData
                    function onShowWorkspaceAppsChanged() {
                        delegateRoot.updateAllData();
                    }
                    function onWorkspaceNameIconsChanged() {
                        delegateRoot.updateAllData();
                    }
                }
                Connections {
                    target: DwlService
                    enabled: CompositorService.isDwl
                    function onStateChanged() {
                        delegateRoot.updateAllData();
                    }
                }
                Connections {
                    target: Hyprland.workspaces
                    enabled: CompositorService.isHyprland
                    function onValuesChanged() {
                        delegateRoot.updateAllData();
                    }
                }
                Connections {
                    target: I3.workspaces
                    enabled: (CompositorService.isSway || CompositorService.isScroll)
                    function onValuesChanged() {
                        delegateRoot.updateAllData();
                    }
                }
                Connections {
                    target: ExtWorkspaceService
                    enabled: root.useExtWorkspace
                    function onStateChanged() {
                        delegateRoot.updateAllData();
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (useExtWorkspace && !DMSService.activeSubscriptions.includes("extworkspace")) {
            DMSService.addSubscription("extworkspace");
        }
    }
}
