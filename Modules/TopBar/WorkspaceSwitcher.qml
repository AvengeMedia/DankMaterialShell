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

    property string screenName: ""
    property real widgetHeight: 30
    property int currentWorkspace: {
        if (CompositorService.isNiri) {
            return getNiriActiveWorkspace()
        } else if (CompositorService.isHyprland) {
            return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
        }
        return 1
    }
    property var workspaceList: {
        if (CompositorService.isNiri) {
            var baseList = getNiriWorkspaces()
            return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList
        } else if (CompositorService.isHyprland) {
            var workspaces = Hyprland.workspaces ? Hyprland.workspaces.values : []
            if (workspaces.length === 0) {
                return [{id: 1, name: "1"}]
            }
            var sorted = workspaces.slice().sort((a, b) => a.id - b.id)
            return SettingsData.showWorkspacePadding ? padWorkspaces(sorted) : sorted
        }
        return [1]
    }

    function getWorkspaceIcons(ws) {
        if (!SettingsData.showWorkspaceApps) return []
        
        var chunks = []
        if (!ws) return chunks

        var targetWorkspaceId
        if (CompositorService.isNiri) {
            // For Niri, we need to find the workspace ID from allWorkspaces
            var wsNumber = typeof ws === "number" ? ws : -1
            if (wsNumber > 0) {
                for (var j = 0; j < NiriService.allWorkspaces.length; j++) {
                    var workspace = NiriService.allWorkspaces[j]
                    if (workspace.idx + 1 === wsNumber && workspace.output === root.screenName) {
                        targetWorkspaceId = workspace.id
                        break
                    }
                }
            }
            if (targetWorkspaceId === undefined) return chunks
        } else if (CompositorService.isHyprland) {
            targetWorkspaceId = ws.id !== undefined ? ws.id : ws
        } else {
            return chunks
        }

        var wins = []
        if (CompositorService.isNiri) {
            wins = NiriService.windows || []
        } else if (CompositorService.isHyprland) {
            wins = Hyprland.clients ? Hyprland.clients.values : []
        }

        var byApp = {}
        var isActiveWs = false
        if (CompositorService.isNiri) {
            for (var j = 0; j < NiriService.allWorkspaces.length; j++) {
                var ws2 = NiriService.allWorkspaces[j]
                if (ws2.id === targetWorkspaceId && ws2.is_active) {
                    isActiveWs = true
                    break
                }
            }
        } else if (CompositorService.isHyprland) {
            isActiveWs = targetWorkspaceId === root.currentWorkspace
        }

        for (var i = 0; i < wins.length; i++) {
            var w = wins[i]
            if (!w) continue

            var winWs
            if (CompositorService.isNiri) {
                winWs = w.workspace_id
            } else if (CompositorService.isHyprland) {
                winWs = w.workspace && w.workspace.id !== undefined ? w.workspace.id : w.workspaceId
            }
            
            if (winWs === undefined || winWs === null) continue
            if (winWs !== targetWorkspaceId) continue

            var keyBase = (w.app_id || w.appId || w.class || w.windowClass || w.exe || "unknown").toLowerCase()
            var key = isActiveWs ? keyBase + "_" + i : keyBase

            if (!byApp[key]) {
                var icon = Quickshell.iconPath(DesktopEntries.heuristicLookup(Paths.moddedAppId(keyBase))?.icon, true)
                byApp[key] = {
                    type: "icon",
                    icon: icon,
                    active: !!w.is_focused || !!w.activated,
                    count: 1,
                    windowId: w.id || w.address,
                    fallbackText: w.app_id || w.appId || w.class || w.title || ""
                }
            } else {
                byApp[key].count++
                if (w.is_focused || w.activated) byApp[key].active = true
            }
        }

        for (var k in byApp)
            chunks.push(byApp[k])

        return chunks
    }

    function padWorkspaces(list) {
        var padded = list.slice()
        while (padded.length < 3) {
            if (CompositorService.isHyprland) {
                padded.push({id: -1, name: ""})
            } else {
                padded.push(-1)
            }
        }
        return padded
    }

    function getNiriWorkspaces() {
        if (NiriService.allWorkspaces.length === 0)
            return [1, 2]

        if (!root.screenName)
            return NiriService.getCurrentOutputWorkspaceNumbers()

        var displayWorkspaces = []
        for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
            var ws = NiriService.allWorkspaces[i]
            if (ws.output === root.screenName)
                displayWorkspaces.push(ws.idx + 1)
        }
        return displayWorkspaces.length > 0 ? displayWorkspaces : [1, 2]
    }

    function getNiriActiveWorkspace() {
        if (NiriService.allWorkspaces.length === 0)
            return 1

        if (!root.screenName)
            return NiriService.getCurrentWorkspaceNumber()

        for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
            var ws = NiriService.allWorkspaces[i]
            if (ws.output === root.screenName && ws.is_active)
                return ws.idx + 1
        }
        return 1
    }

    readonly property real padding: (widgetHeight - workspaceRow.implicitHeight) / 2
    
    width: workspaceRow.implicitWidth + padding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground) return "transparent"
        const baseColor = Theme.surfaceTextHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }
    visible: CompositorService.isNiri || CompositorService.isHyprland


    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        
        property real scrollAccumulator: 0
        property real touchpadThreshold: 500
        
        onWheel: (wheel) => {
            const deltaY = wheel.angleDelta.y
            const isMouseWheel = Math.abs(deltaY) >= 120
                && (Math.abs(deltaY) % 120) === 0
            
            if (isMouseWheel) {
                // Direct mouse wheel action
                if (CompositorService.isNiri) {
                    var realWorkspaces = [];
                    for (var i = 0; i < root.workspaceList.length; i++) {
                        if (root.workspaceList[i] !== -1) {
                            realWorkspaces.push(root.workspaceList[i]);
                        }
                    }

                    if (realWorkspaces.length < 2) return;

                    var currentIndex = -1;
                    for (var i = 0; i < realWorkspaces.length; i++) {
                        if (realWorkspaces[i] === root.currentWorkspace) {
                            currentIndex = i;
                            break;
                        }
                    }
                    if (currentIndex === -1) currentIndex = 0;

                    var nextIndex;
                    if (deltaY < 0) {
                        nextIndex = (currentIndex + 1) % realWorkspaces.length;
                    } else {
                        nextIndex = (currentIndex - 1 + realWorkspaces.length) % realWorkspaces.length;
                    }
                    NiriService.switchToWorkspace(realWorkspaces[nextIndex] - 1);

                } else if (CompositorService.isHyprland) {
                    if (deltaY < 0) {
                        Hyprland.dispatch("workspace r+1");
                    } else {
                        Hyprland.dispatch("workspace r-1");
                    }
                }
            } else {
                // Touchpad - accumulate small deltas
                scrollAccumulator += deltaY
                
                if (Math.abs(scrollAccumulator) >= touchpadThreshold) {
                    if (CompositorService.isNiri) {
                        var realWorkspaces = [];
                        for (var i = 0; i < root.workspaceList.length; i++) {
                            if (root.workspaceList[i] !== -1) {
                                realWorkspaces.push(root.workspaceList[i]);
                            }
                        }

                        if (realWorkspaces.length < 2) {
                            scrollAccumulator = 0;
                            return;
                        }

                        var currentIndex = -1;
                        for (var i = 0; i < realWorkspaces.length; i++) {
                            if (realWorkspaces[i] === root.currentWorkspace) {
                                currentIndex = i;
                                break;
                            }
                        }
                        if (currentIndex === -1) currentIndex = 0;

                        var nextIndex;
                        if (scrollAccumulator < 0) {
                            nextIndex = (currentIndex + 1) % realWorkspaces.length;
                        } else {
                            nextIndex = (currentIndex - 1 + realWorkspaces.length) % realWorkspaces.length;
                        }
                        NiriService.switchToWorkspace(realWorkspaces[nextIndex] - 1);

                    } else if (CompositorService.isHyprland) {
                        if (scrollAccumulator < 0) {
                            Hyprland.dispatch("workspace r+1");
                        } else {
                            Hyprland.dispatch("workspace r-1");
                        }
                    }
                    
                    scrollAccumulator = 0
                }
            }
            
            wheel.accepted = true
        }
    }

    Row {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        Repeater {
            model: root.workspaceList

            Rectangle {
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
                property var workspaceData: {
                    if (isPlaceholder)
                        return null
                    
                    if (CompositorService.isNiri) {
                        for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
                            var ws = NiriService.allWorkspaces[i]
                            if (ws.idx + 1 === modelData && ws.output === root.screenName)
                                return ws
                        }
                    } else if (CompositorService.isHyprland) {
                        return modelData
                    }
                    return null
                }
                property var iconData: workspaceData
                                       && workspaceData.name ? SettingsData.getWorkspaceNameIcon(
                                                                   workspaceData.name) : null
                property bool hasIcon: iconData !== null
                property var icons: SettingsData.showWorkspaceApps ? root.getWorkspaceIcons(CompositorService.isHyprland ? modelData : (modelData === -1 ? null : modelData)) : []

                width: {
                    if (SettingsData.showWorkspaceApps) {
                        if (icons.length > 0) {
                            return isActive ? widgetHeight * 1.0 + Theme.spacingXS + contentRow.implicitWidth : widgetHeight * 0.8 + contentRow.implicitWidth
                        } else {
                            return isActive ? widgetHeight * 1.0 + Theme.spacingXS : widgetHeight * 0.8
                        }
                    }
                    return isActive ? widgetHeight * 1.2 + Theme.spacingXS : widgetHeight * 0.8
                }
                height: SettingsData.showWorkspaceApps ? widgetHeight * 0.8 : widgetHeight * 0.6
                radius: height / 2
                color: isActive ? Theme.primary : isPlaceholder ? Theme.surfaceTextLight : isHovered ? Theme.outlineButton : Theme.surfaceTextAlpha

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: !isPlaceholder
                    cursorShape: isPlaceholder ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !isPlaceholder
                    onClicked: {
                        if (!isPlaceholder) {
                            if (CompositorService.isNiri) {
                                NiriService.switchToWorkspace(modelData - 1)
                            } else if (CompositorService.isHyprland) {
                                if (modelData && modelData.id) {
                                    Hyprland.dispatch(`workspace ${modelData.id}`)
                                }
                            }
                        }
                    }
                }

                Row {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: 4
                    visible: SettingsData.showWorkspaceApps && icons.length > 0

                    Repeater {
                        model: icons.slice(0, SettingsData.maxWorkspaceIcons)
                        delegate: Item {
                            width: 18
                            height: 18

                            IconImage {
                                id: appIcon
                                property var windowId: modelData.windowId
                                anchors.fill: parent
                                source: modelData.icon
                                opacity: modelData.active ? 1.0 : appMouseArea.containsMouse ? 0.8 : 0.6
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

                DankIcon {
                    visible: hasIcon && iconData.type === "icon" && (!SettingsData.showWorkspaceApps || icons.length === 0)
                    anchors.centerIn: parent
                    name: hasIcon
                          && iconData.type === "icon" ? iconData.value : ""
                    size: Theme.fontSizeSmall
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r,
                                              Theme.surfaceContainer.g,
                                              Theme.surfaceContainer.b,
                                              0.95) : Theme.surfaceTextMedium
                    weight: isActive && !isPlaceholder ? 500 : 400
                }

                StyledText {
                    visible: hasIcon && iconData.type === "text" && (!SettingsData.showWorkspaceApps || icons.length === 0)
                    anchors.centerIn: parent
                    text: hasIcon
                          && iconData.type === "text" ? iconData.value : ""
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r,
                                              Theme.surfaceContainer.g,
                                              Theme.surfaceContainer.b,
                                              0.95) : Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: isActive
                                 && !isPlaceholder ? Font.DemiBold : Font.Normal
                }

                StyledText {
                    visible: (SettingsData.showWorkspaceIndex && !hasIcon && (!SettingsData.showWorkspaceApps || icons.length === 0))
                    anchors.centerIn: parent
                    text: {
                        if (CompositorService.isHyprland) {
                            if (modelData && modelData.id === -1) {
                                return index + 1
                            }
                            return modelData && modelData.id ? modelData.id : ""
                        }
                        if (modelData === -1) {
                            return index + 1
                        }
                        return modelData - 1
                    }
                    color: isActive ? Qt.rgba(
                                          Theme.surfaceContainer.r,
                                          Theme.surfaceContainer.g,
                                          Theme.surfaceContainer.b,
                                          0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: isActive
                                 && !isPlaceholder ? Font.DemiBold : Font.Normal
                }

                Behavior on width {
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
            }
        }
    }
}