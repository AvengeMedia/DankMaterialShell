import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string screenName: ""
    property real widgetHeight: 30
    property real barThickness: 48
    property int currentWorkspace: {
        if (CompositorService.isNiri) {
            return getNiriActiveWorkspace()
        } else if (CompositorService.isHyprland) {
            return getHyprlandActiveWorkspace()
        }
        return 1
    }
    property var workspaceList: {
        if (CompositorService.isNiri) {
            const baseList = getNiriWorkspaces()
            return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList
        }
        if (CompositorService.isHyprland) {
            const baseList = getHyprlandWorkspaces()
            // Filter out special workspaces
			const filteredList = baseList.filter(ws => ws.id > -1)
            return SettingsData.showWorkspacePadding ? padWorkspaces(filteredList) : filteredList
        }
        return [1]
    }

    function getWorkspaceIcons(ws) {
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
        } else {
            return []
        }

        const wins = CompositorService.isNiri ? (NiriService.windows || []) : CompositorService.sortedToplevels


        const byApp = {}
        const isActiveWs = CompositorService.isNiri ? NiriService.allWorkspaces.some(ws => ws.id === targetWorkspaceId && ws.is_active) : targetWorkspaceId === root.currentWorkspace

        wins.forEach((w, i) => {
                         if (!w) {
                             return
                         }

                         let winWs = null
                         if (CompositorService.isNiri) {
                             winWs = w.workspace_id
                         } else {
                             // For Hyprland, we need to find the corresponding Hyprland toplevel to get workspace
                             const hyprlandToplevels = Array.from(Hyprland.toplevels?.values || [])
                             const hyprToplevel = hyprlandToplevels.find(ht => ht.wayland === w)
                             winWs = hyprToplevel?.workspace?.id
                         }


                         if (winWs === undefined || winWs === null || winWs !== targetWorkspaceId) {
                             return
                         }

                         const keyBase = (w.app_id || w.appId || w.class || w.windowClass || "unknown").toLowerCase()
                         const key = isActiveWs ? `${keyBase}_${i}` : keyBase

                         if (!byApp[key]) {
                             const moddedId = Paths.moddedAppId(keyBase)
                             const isSteamApp = moddedId.toLowerCase().includes("steam_app")
                             const icon = isSteamApp ? "" : Quickshell.iconPath(DesktopEntries.heuristicLookup(moddedId)?.icon, true)
                             byApp[key] = {
                                 "type": "icon",
                                 "icon": icon,
                                 "isSteamApp": isSteamApp,
                                 "active": !!(w.activated || (CompositorService.isNiri && w.is_focused)),
                                 "count": 1,
                                 "windowId": w.address || w.id,
                                 "fallbackText": w.appId || w.class || w.title || ""
                             }
                         } else {
                             byApp[key].count++
                             if (w.activated || (CompositorService.isNiri && w.is_focused)) {
                                 byApp[key].active = true
                             }
                         }
                     })

        return Object.values(byApp)
    }

    function padWorkspaces(list) {
        const padded = list.slice()
        const placeholder = CompositorService.isHyprland ? {
                                                               "id": -1,
                                                               "name": ""
                                                           } : -1
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

    function getHyprlandWorkspaces() {
        const workspaces = Hyprland.workspaces?.values || []

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            // Show all workspaces on all monitors if per-monitor filtering is disabled
            const sorted = workspaces.slice().sort((a, b) => a.id - b.id)
            return sorted.length > 0 ? sorted : [{
                        "id": 1,
                        "name": "1"
                    }]
        }

        // Filter workspaces for this specific monitor using lastIpcObject.monitor
        // This matches the approach from the original kyle-config
        const monitorWorkspaces = workspaces.filter(ws => {
            return ws.lastIpcObject && ws.lastIpcObject.monitor === root.screenName
        })

        if (monitorWorkspaces.length === 0) {
            // Fallback if no workspaces exist for this monitor
            return [{
                        "id": 1,
                        "name": "1"
                    }]
        }

        // Return all workspaces for this monitor, sorted by ID
        return monitorWorkspaces.sort((a, b) => a.id - b.id)
    }

    function getHyprlandActiveWorkspace() {
        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
        }

        // Find the monitor object for this screen
        const monitors = Hyprland.monitors?.values || []
        const currentMonitor = monitors.find(monitor => monitor.name === root.screenName)

        if (!currentMonitor) {
            return 1
        }

        // Use the monitor's active workspace ID (like original config)
        return currentMonitor.activeWorkspace?.id ?? 1
    }

    readonly property real padding: isVertical
        ? Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))
        : (widgetHeight - workspaceRow.implicitHeight) / 2

    function getRealWorkspaces() {
        return root.workspaceList.filter(ws => {
                                             if (CompositorService.isHyprland) {
                                                 return ws && ws.id !== -1
                                             }
                                             return ws !== -1
                                         })
    }

    function switchWorkspace(direction) {
        if (CompositorService.isNiri) {
            const realWorkspaces = getRealWorkspaces()
            if (realWorkspaces.length < 2) {
                return
            }

            const currentIndex = realWorkspaces.findIndex(ws => ws === root.currentWorkspace)
            const validIndex = currentIndex === -1 ? 0 : currentIndex
            const nextIndex = direction > 0 ? (validIndex + 1) % realWorkspaces.length : (validIndex - 1 + realWorkspaces.length) % realWorkspaces.length

            NiriService.switchToWorkspace(realWorkspaces[nextIndex] - 1)
        } else if (CompositorService.isHyprland) {
            const command = direction > 0 ? "workspace r+1" : "workspace r-1"
            Hyprland.dispatch(command)
        }
    }

    width: isVertical ? widgetHeight : (workspaceRow.implicitWidth + padding * 2)
    height: isVertical ? (workspaceRow.implicitHeight + padding * 2) : widgetHeight
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground)
            return "transparent"
        const baseColor = Theme.widgetBaseBackgroundColor
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
    }
    visible: CompositorService.isNiri || CompositorService.isHyprland

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        property real scrollAccumulator: 0
        property real touchpadThreshold: 500

        onWheel: wheel => {
                     const deltaY = wheel.angleDelta.y
                     const isMouseWheel = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0
                     const direction = deltaY < 0 ? 1 : -1

                     if (isMouseWheel) {
                         switchWorkspace(direction)
                     } else {
                         scrollAccumulator += deltaY

                         if (Math.abs(scrollAccumulator) >= touchpadThreshold) {
                             const touchDirection = scrollAccumulator < 0 ? 1 : -1
                             switchWorkspace(touchDirection)
                             scrollAccumulator = 0
                         }
                     }

                     wheel.accepted = true
                 }
    }

    Flow {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: Theme.spacingS
        flow: isVertical ? Flow.TopToBottom : Flow.LeftToRight

        Repeater {
            model: root.workspaceList

            Rectangle {
                id: delegateRoot

                property bool isActive: {
                    if (CompositorService.isHyprland) {
                        return modelData && modelData.id === root.currentWorkspace
                    }
                    return modelData === root.currentWorkspace
                }
                property bool isPlaceholder: {
                    if (CompositorService.isHyprland) {
                        return modelData && modelData.id === -1
                    }
                    return modelData === -1
                }
                property bool isHovered: mouseArea.containsMouse

                property var loadedWorkspaceData: null
                property bool loadedIsUrgent: false
                property bool isUrgent: {
                    if (CompositorService.isHyprland) {
                        return modelData?.urgent ?? false
                    }
                    if (CompositorService.isNiri) {
                        return loadedIsUrgent
                    }
                    return false
                }
                property var loadedIconData: null
                property bool loadedHasIcon: false
                property var loadedIcons: []

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
                        if (CompositorService.isNiri) {
                            wsData = NiriService.allWorkspaces.find(ws => ws.idx + 1 === modelData && ws.output === root.screenName) || null;
                        } else if (CompositorService.isHyprland) {
                            wsData = modelData;
                        }
                        delegateRoot.loadedWorkspaceData = wsData;
                        delegateRoot.loadedIsUrgent = wsData?.is_urgent ?? false;

                        var icData = null;
                        if (wsData?.name) {
                            icData = SettingsData.getWorkspaceNameIcon(wsData.name);
                        }
                        delegateRoot.loadedIconData = icData;
                        delegateRoot.loadedHasIcon = icData !== null;

                        if (SettingsData.showWorkspaceApps) {
                            delegateRoot.loadedIcons = root.getWorkspaceIcons(CompositorService.isHyprland ? modelData : (modelData === -1 ? null : modelData));
                        } else {
                            delegateRoot.loadedIcons = [];
                        }
                    }
                }

                function updateAllData() {
                    dataUpdateTimer.restart()
                }

                width: {
                    if (root.isVertical) {
                        return SettingsData.showWorkspaceApps ? widgetHeight * 0.7 : widgetHeight * 0.5;
                    } else {
                        if (SettingsData.showWorkspaceApps && loadedIcons.length > 0) {
                            const numIcons = Math.min(loadedIcons.length, SettingsData.maxWorkspaceIcons);
                            const iconsWidth = numIcons * 18 + (numIcons > 0 ? (numIcons - 1) * Theme.spacingXS : 0);
                            const baseWidth = isActive ? root.widgetHeight * 0.9 + Theme.spacingXS : root.widgetHeight * 0.7;
                            return baseWidth + iconsWidth;
                        }
                        return isActive ? root.widgetHeight * 1.05 : root.widgetHeight * 0.7;
                    }
                }
                height: {
                    if (root.isVertical) {
                        if (SettingsData.showWorkspaceApps && loadedIcons.length > 0) {
                            const numIcons = Math.min(loadedIcons.length, SettingsData.maxWorkspaceIcons);
                            const iconsHeight = numIcons * 18 + (numIcons > 0 ? (numIcons - 1) * Theme.spacingXS : 0);
                            const baseHeight = isActive ? root.widgetHeight * 0.9 + Theme.spacingXS : root.widgetHeight * 0.7;
                            return baseHeight + iconsHeight;
                        }
                        return isActive ? root.widgetHeight * 1.05 : root.widgetHeight * 0.7;
                    } else {
                        return SettingsData.showWorkspaceApps ? widgetHeight * 0.7 : widgetHeight * 0.5;
                    }
                }
                radius: Theme.cornerRadius
                color: isActive ? Theme.primary : isUrgent ? Theme.error : isPlaceholder ? Theme.surfaceTextLight : isHovered ? Theme.outlineButton : Theme.surfaceTextAlpha

                border.width: isUrgent && !isActive ? 2 : 0
                border.color: isUrgent && !isActive ? Theme.error : Theme.withAlpha(Theme.error, 0)

                Behavior on width {
                    enabled: (!SettingsData.showWorkspaceApps || SettingsData.maxWorkspaceIcons <= 3)
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }

                Behavior on height {
                    enabled: root.isVertical && (!SettingsData.showWorkspaceApps || SettingsData.maxWorkspaceIcons <= 3)
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
                        duration: Theme.shortDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: !isPlaceholder
                    cursorShape: isPlaceholder ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !isPlaceholder
                    onClicked: {
                        if (isPlaceholder) {
                            return
                        }

                        if (CompositorService.isNiri) {
                            NiriService.switchToWorkspace(modelData - 1)
                        } else if (CompositorService.isHyprland && modelData?.id) {
                            Hyprland.dispatch(`workspace ${modelData.id}`)
                        }
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
                                    model: loadedIcons.slice(0, SettingsData.maxWorkspaceIcons)
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
                                            hoverEnabled: true
                                            anchors.fill: parent
                                            enabled: isActive
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
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
                                    model: loadedIcons.slice(0, SettingsData.maxWorkspaceIcons)
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
                                            hoverEnabled: true
                                            anchors.fill: parent
                                            enabled: isActive
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
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
                                const isPlaceholder = CompositorService.isHyprland ? (modelData?.id === -1) : (modelData === -1)
                                if (isPlaceholder) {
                                    return index + 1
                                }
                                return CompositorService.isHyprland ? (modelData?.id || "") : (modelData - 1);
                            }
                            color: (isActive || isUrgent) ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                            font.pixelSize: Theme.barTextSize(barThickness)
                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                        }
                    }
                }

                // --- LOGIC / TRIGGERS ---
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
                }
                Connections {
                    target: SettingsData
                    function onShowWorkspaceAppsChanged() { delegateRoot.updateAllData() }
                    function onWorkspaceNameIconsChanged() { delegateRoot.updateAllData() }
                }
            }
        }
    }
}
