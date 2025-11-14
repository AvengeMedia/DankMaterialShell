import QtQuick
import QtQuick.Controls
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
    property var hyprlandOverviewLoader: null
    property var parentScreen: null
    property int _desktopEntriesUpdateTrigger: 0
    readonly property var sortedToplevels: {
        return CompositorService.filterCurrentWorkspace(CompositorService.sortedToplevels, screenName);
    }

    readonly property bool useExtWorkspace: DMSService.forceExtWorkspace || (!CompositorService.isNiri && !CompositorService.isHyprland && !CompositorService.isDwl && !CompositorService.isSway && ExtWorkspaceService.extWorkspaceAvailable)

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            _desktopEntriesUpdateTrigger++
        }
    }

    property var currentWorkspace: {
        if (useExtWorkspace) return getExtWorkspaceActiveWorkspace()

        switch (CompositorService.compositor) {
        case "niri":
            return getNiriActiveWorkspace()
        case "hyprland":
            return getHyprlandActiveWorkspace()
        case "dwl":
            const activeTags = getDwlActiveTags()
            return activeTags.length > 0 ? activeTags[0] : -1
        case "sway":
            return getSwayActiveWorkspace()
        default:
            return 1
        }
    }
    property var dwlActiveTags: {
        if (CompositorService.isDwl) {
            return getDwlActiveTags()
        }
        return []
    }
    property var workspaceList: {
        if (useExtWorkspace) {
            const baseList = getExtWorkspaceWorkspaces()
            return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList
        }

        let baseList
        switch (CompositorService.compositor) {
        case "niri":
            baseList = getNiriWorkspaces()
            break
        case "hyprland":
            baseList = getHyprlandWorkspaces()
            break
        case "dwl":
            baseList = getDwlTags()
            break
        case "sway":
            baseList = getSwayWorkspaces()
            break
        default:
            return [1]
        }
        return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList
    }

    function getSwayWorkspaces() {
        const workspaces = I3.workspaces?.values || []
        if (workspaces.length === 0) return [{"num": 1}]

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return workspaces.slice().sort((a, b) => a.num - b.num)
        }

        const monitorWorkspaces = workspaces.filter(ws => ws.monitor?.name === root.screenName)
        return monitorWorkspaces.length > 0 ? monitorWorkspaces.sort((a, b) => a.num - b.num) : [{"num": 1}]
    }

    function getSwayActiveWorkspace() {
        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            const focusedWs = I3.workspaces?.values?.find(ws => ws.focused === true)
            return focusedWs ? focusedWs.num : 1
        }

        const focusedWs = I3.workspaces?.values?.find(ws => ws.monitor?.name === root.screenName && ws.focused === true)
        return focusedWs ? focusedWs.num : 1
    }

    function getHyprlandWorkspaces() {
        const workspaces = Hyprland.workspaces?.values || []
        if (workspaces.length === 0) return [{id: 1, name: "1"}]

        const filtered = workspaces.filter(ws => ws.id > -1)
        if (filtered.length === 0) return [{id: 1, name: "1"}]

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return filtered.slice().sort((a, b) => a.id - b.id)
        }

        const monitorWorkspaces = filtered.filter(ws => ws.monitor?.name === root.screenName)
        return monitorWorkspaces.length > 0 ? monitorWorkspaces.sort((a, b) => a.id - b.id) : [{id: 1, name: "1"}]
    }

    function getHyprlandActiveWorkspace() {
        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return Hyprland.focusedWorkspace?.id || 1
        }

        const monitor = Hyprland.monitors?.values?.find(m => m.name === root.screenName)
        return monitor?.activeWorkspace?.id || 1
    }

    function getWorkspaceIcons(ws) {
        _desktopEntriesUpdateTrigger
        if (!SettingsData.showWorkspaceApps || !ws) {
            return []
        }

        let targetWorkspaceId
        if (CompositorService.isNiri) {
            const wsNumber = typeof ws === "number" ? ws : -1
            if (wsNumber <= 0) {
                return []
            }
            const workspace = NiriService.allWorkspaces.find(w => w.idx + 1 === wsNumber && w.output === root.screenName)
            if (!workspace) {
                return []
            }
            targetWorkspaceId = workspace.id
        } else if (CompositorService.isHyprland) {
            targetWorkspaceId = ws.id !== undefined ? ws.id : ws
        } else if (CompositorService.isDwl) {
            if (typeof ws !== "object" || ws.tag === undefined) {
                return []
            }
            targetWorkspaceId = ws.tag
        } else if (CompositorService.isSway) {
            targetWorkspaceId = ws.num !== undefined ? ws.num : ws
        } else {
            return []
        }

        const wins = CompositorService.isNiri ? (NiriService.windows || []) : CompositorService.sortedToplevels

        const byApp = {}
        let isActiveWs = false
        if (CompositorService.isNiri) {
            isActiveWs = NiriService.allWorkspaces.some(ws => ws.id === targetWorkspaceId && ws.is_active)
        } else if (CompositorService.isSway) {
            const focusedWs = I3.workspaces?.values?.find(ws => ws.focused === true)
            isActiveWs = focusedWs ? (focusedWs.num === targetWorkspaceId) : false
        } else if (CompositorService.isDwl) {
            const output = DwlService.getOutputState(root.screenName)
            if (output && output.tags) {
                const tag = output.tags.find(t => t.tag === targetWorkspaceId)
                isActiveWs = tag ? (tag.state === 1) : false
            }
        } else {
            isActiveWs = targetWorkspaceId === root.currentWorkspace
        }

        wins.forEach((w, i) => {
                         if (!w) {
                             return
                         }

                         let winWs = null
                         if (CompositorService.isNiri) {
                             winWs = w.workspace_id
                         } else if (CompositorService.isSway) {
                             winWs = w.workspace?.num
                         } else {
                             const hyprlandToplevels = Array.from(Hyprland.toplevels?.values || [])
                             const hyprToplevel = hyprlandToplevels.find(ht => ht.wayland === w)
                             winWs = hyprToplevel?.workspace?.id
                         }


                         if (winWs === undefined || winWs === null || winWs !== targetWorkspaceId) {
                             return
                         }

                         const keyBase = (w.app_id || w.appId || w.class || w.windowClass || "unknown")
                         const key = isActiveWs ? `${keyBase}_${i}` : keyBase

                         if (!byApp[key]) {
                             const moddedId = Paths.moddedAppId(keyBase)
                             const isSteamApp = moddedId.toLowerCase().includes("steam_app")
                             const icon = isSteamApp ? "" : DesktopService.resolveIconPath(moddedId)
                             byApp[key] = {
                                 "type": "icon",
                                 "icon": icon,
                                 "isSteamApp": isSteamApp,
                                 "active": !!((w.activated || w.is_focused) || (CompositorService.isNiri && w.is_focused)),
                                 "count": 1,
                                 "windowId": w.address || w.id,
                                 "fallbackText": w.appId || w.class || w.title || ""
                             }
                         } else {
                             byApp[key].count++
                             if ((w.activated || w.is_focused) || (CompositorService.isNiri && w.is_focused)) {
                                 byApp[key].active = true
                             }
                         }
                     })

        return Object.values(byApp)
    }

    function padWorkspaces(list) {
        const padded = list.slice()
        let placeholder
        if (useExtWorkspace) {
            placeholder = {"id": "", "name": "", "active": false, "hidden": true}
        } else if (CompositorService.isHyprland) {
            placeholder = {"id": -1, "name": ""}
        } else if (CompositorService.isDwl) {
            placeholder = {"tag": -1}
        } else if (CompositorService.isSway) {
            placeholder = {"num": -1}
        } else {
            placeholder = -1
        }
        while (padded.length < 3) {
            padded.push(placeholder)
        }
        return padded
    }

    function getNiriWorkspaces() {
        if (NiriService.allWorkspaces.length === 0) {
            return [1, 2]
        }

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return NiriService.getCurrentOutputWorkspaceNumbers()
        }

        const displayWorkspaces = NiriService.allWorkspaces.filter(ws => ws.output === root.screenName).map(ws => ws.idx + 1)
        return displayWorkspaces.length > 0 ? displayWorkspaces : [1, 2]
    }

    function getNiriActiveWorkspace() {
        if (NiriService.allWorkspaces.length === 0) {
            return 1
        }

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return NiriService.getCurrentWorkspaceNumber()
        }

        const activeWs = NiriService.allWorkspaces.find(ws => ws.output === root.screenName && ws.is_active)
        return activeWs ? activeWs.idx + 1 : 1
    }

    function getDwlTags() {
        if (!DwlService.dwlAvailable) {
            return []
        }

        const output = DwlService.getOutputState(root.screenName)
        if (!output || !output.tags || output.tags.length === 0) {
            return []
        }

        if (SettingsData.dwlShowAllTags) {
            return output.tags.map(tag => ({"tag": tag.tag, "state": tag.state, "clients": tag.clients, "focused": tag.focused}))
        }

        const visibleTagIndices = DwlService.getVisibleTags(root.screenName)
        return visibleTagIndices.map(tagIndex => {
            const tagData = output.tags.find(t => t.tag === tagIndex)
            return {
                "tag": tagIndex,
                "state": tagData?.state ?? 0,
                "clients": tagData?.clients ?? 0,
                "focused": tagData?.focused ?? false
            }
        })
    }

    function getDwlActiveTags() {
        if (!DwlService.dwlAvailable) {
            return []
        }

        const activeTags = DwlService.getActiveTags(root.screenName)
        return activeTags
    }

    function getExtWorkspaceWorkspaces() {
        const groups = ExtWorkspaceService.groups
        if (!ExtWorkspaceService.extWorkspaceAvailable || groups.length === 0) {
            return [{"id": "1", "name": "1", "active": false}]
        }

        const group = groups.find(g => g.outputs && g.outputs.includes(root.screenName))
        if (!group || !group.workspaces) {
            return [{"id": "1", "name": "1", "active": false}]
        }

        const visible = group.workspaces.filter(ws => !ws.hidden).sort((a, b) => {
            const coordsA = a.coordinates || [0, 0]
            const coordsB = b.coordinates || [0, 0]
            if (coordsA[0] !== coordsB[0]) return coordsA[0] - coordsB[0]
            return coordsA[1] - coordsB[1]
        }).map(ws => ({
            id: ws.id,
            name: ws.name,
            coordinates: ws.coordinates,
            state: ws.state,
            active: ws.active,
            urgent: ws.urgent,
            hidden: ws.hidden,
            groupID: group.id
        }))

        return visible.length > 0 ? visible : [{"id": "1", "name": "1", "active": false}]
    }

    function getExtWorkspaceActiveWorkspace() {
        if (!ExtWorkspaceService.extWorkspaceAvailable) {
            return 1
        }

        const activeWs = ExtWorkspaceService.getActiveWorkspaceForOutput(root.screenName)
        return activeWs ? (activeWs.id || activeWs.name || "1") : "1"
    }

    readonly property real padding: Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))
    readonly property real visualWidth: isVertical ? widgetHeight : (workspaceRow.implicitWidth + padding * 2)
    readonly property real visualHeight: isVertical ? (workspaceRow.implicitHeight + padding * 2) : widgetHeight

    function getRealWorkspaces() {
        return root.workspaceList.filter(ws => {
                                             if (useExtWorkspace) return ws && ws.id !== "" && !ws.hidden
                                             if (CompositorService.isHyprland) return ws && ws.id !== -1
                                             if (CompositorService.isDwl) return ws && ws.tag !== -1
                                             if (CompositorService.isSway) return ws && ws.num !== -1
                                             return ws !== -1
                                         })
    }

    function switchWorkspace(direction) {
        if (useExtWorkspace) {
            const realWorkspaces = getRealWorkspaces()
            if (realWorkspaces.length < 2) {
                return
            }

            const currentIndex = realWorkspaces.findIndex(ws => (ws.id || ws.name) === root.currentWorkspace)
            const validIndex = currentIndex === -1 ? 0 : currentIndex
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0)

            if (nextIndex === validIndex) {
                return
            }

            const nextWorkspace = realWorkspaces[nextIndex]
            ExtWorkspaceService.activateWorkspace(nextWorkspace.id || nextWorkspace.name, nextWorkspace.groupID || "")
        } else if (CompositorService.isNiri) {
            const realWorkspaces = getRealWorkspaces()
            if (realWorkspaces.length < 2) {
                return
            }

            const currentIndex = realWorkspaces.findIndex(ws => ws === root.currentWorkspace)
            const validIndex = currentIndex === -1 ? 0 : currentIndex
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0)

            if (nextIndex === validIndex) {
                return
            }

            NiriService.switchToWorkspace(realWorkspaces[nextIndex] - 1)
        } else if (CompositorService.isHyprland) {
            const realWorkspaces = getRealWorkspaces()
            if (realWorkspaces.length < 2) {
                return
            }

            const currentIndex = realWorkspaces.findIndex(ws => ws.id === root.currentWorkspace)
            const validIndex = currentIndex === -1 ? 0 : currentIndex
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0)

            if (nextIndex === validIndex) {
                return
            }

            Hyprland.dispatch(`workspace ${realWorkspaces[nextIndex].id}`)
        } else if (CompositorService.isDwl) {
            const realWorkspaces = getRealWorkspaces()
            if (realWorkspaces.length < 2) {
                return
            }

            const currentIndex = realWorkspaces.findIndex(ws => ws.tag === root.currentWorkspace)
            const validIndex = currentIndex === -1 ? 0 : currentIndex
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0)

            if (nextIndex === validIndex) {
                return
            }

            DwlService.switchToTag(root.screenName, realWorkspaces[nextIndex].tag)
        } else if (CompositorService.isSway) {
            const realWorkspaces = getRealWorkspaces()
            if (realWorkspaces.length < 2) {
                return
            }

            const currentIndex = realWorkspaces.findIndex(ws => ws.num === root.currentWorkspace)
            const validIndex = currentIndex === -1 ? 0 : currentIndex
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0)

            if (nextIndex === validIndex) {
                return
            }

            try { I3.dispatch(`workspace number ${realWorkspaces[nextIndex].num}`) } catch(_){}
        }
    }

    width: isVertical ? barThickness : visualWidth
    height: isVertical ? visualHeight : barThickness
    visible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isDwl || CompositorService.isSway || useExtWorkspace

    Rectangle {
        id: visualBackground
        width: root.visualWidth
        height: root.visualHeight
        anchors.centerIn: parent
        radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
        color: {
            if (SettingsData.dankBarNoBackground)
                return "transparent"
            const baseColor = Theme.widgetBaseBackgroundColor
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (CompositorService.isNiri) {
                    NiriService.toggleOverview()
                } else if (CompositorService.isHyprland && root.hyprlandOverviewLoader?.item) {
                    root.hyprlandOverviewLoader.item.overviewOpen = !root.hyprlandOverviewLoader.item.overviewOpen
                }
            }
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
                    if (root.useExtWorkspace) return (modelData?.id || modelData?.name) === root.currentWorkspace
                    if (CompositorService.isHyprland) return !!(modelData && modelData.id === root.currentWorkspace)
                    if (CompositorService.isDwl) return !!(modelData && root.dwlActiveTags.includes(modelData.tag))
                    if (CompositorService.isSway) return !!(modelData && modelData.num === root.currentWorkspace)
                    return modelData === root.currentWorkspace
                }
                property bool isPlaceholder: {
                    if (root.useExtWorkspace) return !!(modelData && modelData.hidden)
                    if (CompositorService.isHyprland) return !!(modelData && modelData.id === -1)
                    if (CompositorService.isDwl) return !!(modelData && modelData.tag === -1)
                    if (CompositorService.isSway) return !!(modelData && modelData.num === -1)
                    return modelData === -1
                }
                property bool isHovered: mouseArea.containsMouse

                property var loadedWorkspaceData: null
                property bool loadedIsUrgent: false
                property bool isUrgent: {
                    if (root.useExtWorkspace) return modelData?.urgent ?? false
                    if (CompositorService.isHyprland) return modelData?.urgent ?? false
                    if (CompositorService.isNiri) return loadedIsUrgent
                    if (CompositorService.isDwl) return modelData?.state === 2
                    if (CompositorService.isSway) return loadedIsUrgent
                    return false
                }
                property var loadedIconData: null
                property bool loadedHasIcon: false
                property var loadedIcons: []

                readonly property real baseWidth: root.isVertical ? (SettingsData.showWorkspaceApps ? widgetHeight * 0.7 : widgetHeight * 0.5) : (isActive ? root.widgetHeight * 1.05 : root.widgetHeight * 0.7)
                readonly property real baseHeight: root.isVertical ? (isActive ? root.widgetHeight * 1.05 : root.widgetHeight * 0.7) : (SettingsData.showWorkspaceApps ? widgetHeight * 0.7 : widgetHeight * 0.5)

                readonly property real iconsExtraWidth: {
                    if (!root.isVertical && SettingsData.showWorkspaceApps && loadedIcons.length > 0) {
                        const numIcons = Math.min(loadedIcons.length, SettingsData.maxWorkspaceIcons)
                        return numIcons * 18 + (numIcons > 0 ? (numIcons - 1) * Theme.spacingXS : 0) + (isActive ? Theme.spacingXS : 0)
                    }
                    return 0
                }
                readonly property real iconsExtraHeight: {
                    if (root.isVertical && SettingsData.showWorkspaceApps && loadedIcons.length > 0) {
                        const numIcons = Math.min(loadedIcons.length, SettingsData.maxWorkspaceIcons)
                        return numIcons * 18 + (numIcons > 0 ? (numIcons - 1) * Theme.spacingXS : 0) + (isActive ? Theme.spacingXS : 0)
                    }
                    return 0
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
                        if (isPlaceholder) return

                        const isRightClick = mouse.button === Qt.RightButton

                        if (root.useExtWorkspace && (modelData?.id || modelData?.name)) {
                            ExtWorkspaceService.activateWorkspace(modelData.id || modelData.name, modelData.groupID || "")
                        } else if (CompositorService.isNiri) {
                            if (isRightClick) {
                                NiriService.toggleOverview()
                            } else {
                                NiriService.switchToWorkspace(modelData - 1)
                            }
                        } else if (CompositorService.isHyprland && modelData?.id) {
                            if (isRightClick && root.hyprlandOverviewLoader?.item) {
                                root.hyprlandOverviewLoader.item.overviewOpen = !root.hyprlandOverviewLoader.item.overviewOpen
                            } else {
                                Hyprland.dispatch(`workspace ${modelData.id}`)
                            }
                        } else if (CompositorService.isDwl && modelData?.tag !== undefined) {
                            console.log("DWL click - tag:", modelData.tag, "rightClick:", isRightClick)
                            if (isRightClick) {
                                console.log("Calling toggleTag")
                                DwlService.toggleTag(root.screenName, modelData.tag)
                            } else {
                                console.log("Calling switchToTag")
                                DwlService.switchToTag(root.screenName, modelData.tag)
                            }
                        } else if (CompositorService.isSway && modelData?.num) {
                            try { I3.dispatch(`workspace number ${modelData.num}`) } catch(_){}
                        }
                    }
                }

                Timer {
                    id: dataUpdateTimer
                    interval: 50
                    onTriggered: {
                        if (isPlaceholder) {
                            delegateRoot.loadedWorkspaceData = null
                            delegateRoot.loadedIconData = null
                            delegateRoot.loadedHasIcon = false
                            delegateRoot.loadedIcons = []
                            delegateRoot.loadedIsUrgent = false
                            return
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
                        } else if (CompositorService.isSway) {
                            wsData = modelData;
                        }
                        delegateRoot.loadedWorkspaceData = wsData;
                        delegateRoot.loadedIsUrgent = wsData?.urgent ?? false;

                        var icData = null;
                        if (wsData?.name) {
                            icData = SettingsData.getWorkspaceNameIcon(wsData.name);
                        }
                        delegateRoot.loadedIconData = icData;
                        delegateRoot.loadedHasIcon = icData !== null;

                        if (SettingsData.showWorkspaceApps) {
                            if (CompositorService.isDwl || CompositorService.isSway) {
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
                    dataUpdateTimer.restart()
                }

                width: root.isVertical ? root.barThickness : visualWidth
                height: root.isVertical ? visualHeight : root.barThickness

                Rectangle {
                    id: visualContent
                    width: delegateRoot.visualWidth
                    height: delegateRoot.visualHeight
                    anchors.centerIn: parent
                    radius: Theme.cornerRadius
                    color: isActive ? Theme.primary : isUrgent ? Theme.error : isPlaceholder ? Theme.surfaceTextLight : isHovered ? Theme.outlineButton : Theme.surfaceTextAlpha

                    border.width: isUrgent && !isActive ? 2 : 0
                    border.color: isUrgent && !isActive ? Theme.error : Theme.withAlpha(Theme.error, 0)

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
                                visible: loadedIcons.length > 0

                                Repeater {
                                    model: ScriptModel {
                                        values: loadedIcons.slice(0, SettingsData.maxWorkspaceIcons)
                                    }
                                    delegate: Item {
                                        width: 18
                                        height: 18

                                        IconImage {
                                            id: appIcon
                                            property var windowId: modelData.windowId
                                            anchors.fill: parent
                                            source: modelData.icon
                                            opacity: modelData.active ? 1.0 : appMouseArea.containsMouse ? 0.8 : 0.6
                                            visible: !modelData.isSteamApp
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            size: 18
                                            name: "sports_esports"
                                            color: Theme.surfaceText
                                            opacity: modelData.active ? 1.0 : appMouseArea.containsMouse ? 0.8 : 0.6
                                            visible: modelData.isSteamApp
                                        }

                                        MouseArea {
                                            id: appMouseArea
                                            anchors.fill: parent
                                            enabled: isActive
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (!appIcon.windowId) return
                                                if (CompositorService.isHyprland) {
                                                    Hyprland.dispatch(`focuswindow address:${appIcon.windowId}`)
                                                } else if (CompositorService.isNiri) {
                                                    NiriService.focusWindow(appIcon.windowId)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: modelData.count > 1 && !isActive
                                            width: 12
                                            height: 12
                                            radius: 6
                                            color: "black"
                                            border.color: "white"
                                            border.width: 1
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            z: 2

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.count
                                                font.pixelSize: 8
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
                                visible: loadedIcons.length > 0

                                Repeater {
                                    model: ScriptModel {
                                        values: loadedIcons.slice(0, SettingsData.maxWorkspaceIcons)
                                    }
                                    delegate: Item {
                                        width: 18
                                        height: 18

                                        IconImage {
                                            id: appIcon
                                            property var windowId: modelData.windowId
                                            anchors.fill: parent
                                            source: modelData.icon
                                            opacity: modelData.active ? 1.0 : appMouseArea.containsMouse ? 0.8 : 0.6
                                            visible: !modelData.isSteamApp
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            size: 18
                                            name: "sports_esports"
                                            color: Theme.surfaceText
                                            opacity: modelData.active ? 1.0 : appMouseArea.containsMouse ? 0.8 : 0.6
                                            visible: modelData.isSteamApp
                                        }

                                        MouseArea {
                                            id: appMouseArea
                                            anchors.fill: parent
                                            enabled: isActive
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (!appIcon.windowId) return
                                                if (CompositorService.isHyprland) {
                                                    Hyprland.dispatch(`focuswindow address:${appIcon.windowId}`)
                                                } else if (CompositorService.isNiri) {
                                                    NiriService.focusWindow(appIcon.windowId)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: modelData.count > 1 && !isActive
                                            width: 12
                                            height: 12
                                            radius: 6
                                            color: "black"
                                            border.color: "white"
                                            border.width: 1
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            z: 2

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.count
                                                font.pixelSize: 8
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
                            font.pixelSize: Theme.barTextSize(barThickness)
                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                        }
                    }
                }

                // Loader for Workspace Index
                Loader {
                    id: indexLoader
                    anchors.fill: parent
                    active: !isPlaceholder && SettingsData.showWorkspaceIndex && !loadedHasIcon && !SettingsData.showWorkspaceApps
                    sourceComponent: Item {
                        StyledText {
                            anchors.centerIn: parent
                            text: {
                                let isPlaceholder
                                if (root.useExtWorkspace) {
                                    isPlaceholder = modelData?.hidden === true
                                } else if (CompositorService.isHyprland) {
                                    isPlaceholder = modelData?.id === -1
                                } else if (CompositorService.isDwl) {
                                    isPlaceholder = modelData?.tag === -1
                                } else if (CompositorService.isSway) {
                                    isPlaceholder = modelData?.num === -1
                                } else {
                                    isPlaceholder = modelData === -1
                                }

                                if (isPlaceholder) return index + 1

                                if (root.useExtWorkspace) return modelData?.name || modelData?.id || ""
                                if (CompositorService.isHyprland) return modelData?.id || ""
                                if (CompositorService.isDwl) return (modelData?.tag !== undefined) ? (modelData.tag + 1) : ""
                                if (CompositorService.isSway) return modelData?.num || ""
                                return modelData - 1
                            }
                            color: (isActive || isUrgent) ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                            font.pixelSize: Theme.barTextSize(barThickness)
                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                        }
                    }
                }
                }

                Component.onCompleted: updateAllData()

                Connections {
                    target: CompositorService
                    function onSortedToplevelsChanged() { delegateRoot.updateAllData() }
                }
                Connections {
                    target: NiriService
                    enabled: CompositorService.isNiri
                    function onAllWorkspacesChanged() { delegateRoot.updateAllData() }
                    function onWindowUrgentChanged() { delegateRoot.updateAllData() }
		    function onWindowsChanged() { delegateRoot.updateAllData() }
                }
                Connections {
                    target: SettingsData
                    function onShowWorkspaceAppsChanged() { delegateRoot.updateAllData() }
                    function onWorkspaceNameIconsChanged() { delegateRoot.updateAllData() }
                }
                Connections {
                    target: DwlService
                    enabled: CompositorService.isDwl
                    function onStateChanged() { delegateRoot.updateAllData() }
                }
                Connections {
                    target: Hyprland.workspaces
                    enabled: CompositorService.isHyprland
                    function onValuesChanged() { delegateRoot.updateAllData() }
                }
                Connections {
                    target: I3.workspaces
                    enabled: CompositorService.isSway
                    function onValuesChanged() { delegateRoot.updateAllData() }
                }
                Connections {
                    target: ExtWorkspaceService
                    enabled: root.useExtWorkspace
                    function onStateChanged() { delegateRoot.updateAllData() }
                }
            }
        }
    }

    Component.onCompleted: {
        if (useExtWorkspace && !DMSService.activeSubscriptions.includes("extworkspace")) {
            DMSService.addSubscription("extworkspace")
        }
    }
}
