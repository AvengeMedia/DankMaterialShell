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
            return getNiriActiveWorkspace();
        } else if (CompositorService.isHyprland) {
            return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
        }
        return 1;
    }
    property var workspaceList: {
        if (CompositorService.isNiri) {
            var baseList = getNiriWorkspaces();
            return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList;
        } else if (CompositorService.isHyprland) {
            var workspaces = Hyprland.workspaces ? Hyprland.workspaces.values : [];
            if (workspaces.length === 0) {
                return [
                    {
                        id: 1,
                        name: "1"
                    }
                ];
            }
            var sorted = workspaces.slice().sort((a, b) => a.id - b.id);
            return SettingsData.showWorkspacePadding ? padWorkspaces(sorted) : sorted;
        }
        return [1];
    }

    function getWorkspaceIcons(ws) {
        var chunks = [];
        if (!ws)
            return chunks;

        var wsCandidates = [ws.id, ws.idx].filter(x => typeof x !== "undefined");

        var wins = [];
        if (CompositorService.isNiri) {
            wins = NiriService.windows || [];
        } else if (CompositorService.isHyprland) {
            wins = Hyprland.clients ? Hyprland.clients.values : [];
        }

        var byApp = {}; // key = app_id/class, value = 

        var isActiveWs = ws.is_active;

        for (var i = 0; i < wins.length; i++) {
            var w = wins[i];
            if (!w)
                continue;

            var winWs = w.workspace_id || w.workspaceId || (w.workspace && w.workspace.id) || w.idx || null;
            if (winWs === null)
                continue;
            if (wsCandidates.indexOf(winWs) === -1)
                continue;

            // --- normalize app id
            var keyBase = (w.app_id || w.appId || w.class || w.windowClass || w.exe || "unknown").toLowerCase();

            // For active workspace every key should be unique. For inactive we just count the duplicates
            var key = isActiveWs ? keyBase + "_" + i : keyBase;

            if (!byApp[key]) {
                var icon = Quickshell.iconPath(DesktopEntries.heuristicLookup(Paths.moddedAppId(keyBase))?.icon, true);
                byApp[key] = {
                    type: "icon",
                    icon: icon,
                    active: !!w.is_focused,
                    count: 1,
                    windowId: w.id,
                    fallbackText: w.app_id || w.class || w.title || ""
                };
            } else {
                byApp[key].count++;
                if (w.is_focused)
                    byApp[key].active = true;
            }
        }

        for (var k in byApp)
            chunks.push(byApp[k]);

        return chunks;
    }

    function padWorkspaces(list) {
        var padded = list.slice();
        while (padded.length < 3) {
            if (CompositorService.isHyprland) {
                padded.push({
                    id: -1,
                    name: ""
                });
            } else {
                padded.push(-1);
            }
        }
        return padded;
    }

    function getNiriWorkspaces() {
        if (NiriService.allWorkspaces.length === 0)
            return [1, 2];

        if (!root.screenName)
            return NiriService.getCurrentOutputWorkspaceNumbers();

        var displayWorkspaces = [];
        for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
            var ws = NiriService.allWorkspaces[i];
            if (ws.output === root.screenName)
                displayWorkspaces.push(ws.idx + 1);
        }
        return displayWorkspaces.length > 0 ? displayWorkspaces : [1, 2];
    }

    function getNiriActiveWorkspace() {
        if (NiriService.allWorkspaces.length === 0)
            return 1;

        if (!root.screenName)
            return NiriService.getCurrentWorkspaceNumber();

        for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
            var ws = NiriService.allWorkspaces[i];
            if (ws.output === root.screenName && ws.is_active)
                return ws.idx + 1;
        }
        return 1;
    }

    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 2 : Math.max(Theme.spacingS, SettingsData.topBarInnerPadding)

    width: SettingsData.showWorkspacePadding ? Math.max(120, workspaceRow.implicitWidth + horizontalPadding * 2) : workspaceRow.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground)
            return "transparent";
        const baseColor = Theme.surfaceTextHover;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    visible: CompositorService.isNiri || CompositorService.isHyprland

    Row {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: Theme.spacingS

        Repeater {
            model: root.workspaceList

            Rectangle {
                id: wsBox
                property bool isActive: {
                    if (CompositorService.isHyprland)
                        return modelData && modelData.id === root.currentWorkspace;
                    return modelData === root.currentWorkspace;
                }

                property var wsData: {
                    if (CompositorService.isHyprland)
                        return modelData;
                    if (CompositorService.isNiri) {
                        for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
                            var ws = NiriService.allWorkspaces[i];
                            if (ws.idx + 1 === modelData)
                                return ws;
                        }
                    }
                    return null;
                }

                property var icons: wsData ? root.getWorkspaceIcons(wsData) : []
                property bool isHovered: mouseArea.containsMouse

                width: isActive ? widgetHeight * 1.2 + Theme.spacingXS + contentRow.implicitWidth : widgetHeight * 0.8 + contentRow.implicitWidth
                height: widgetHeight * 0.8
                radius: height / 2
                color: isActive ? Theme.primary : isHovered ? Theme.outlineButton : Theme.surfaceTextAlpha

                MouseArea {
                    id: mouseArea
                    hoverEnabled: true
                    anchors.fill: parent
                    enabled: wsData !== null
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!wsData)
                            return;
                        if (CompositorService.isHyprland) {
                            Hyprland.dispatch(`workspace ${wsData.id}`);
                        } else if (CompositorService.isNiri) {
                            NiriService.switchToWorkspace(wsData.idx);
                        }
                    }
                }

                Row {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: root.getWorkspaceIcons(wsData)
                        delegate: Item {
                            width: wsBox.height * 0.9
                            height: wsBox.height * 0.9

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
                                    enabled: wsBox.isActive
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (CompositorService.isHyprland) {
                                            Hyprland.dispatch(`focuswindow address:${appIcon.windowId}`);
                                        } else if (CompositorService.isNiri) {
                                            NiriService.focusWindow(appIcon.windowId);
                                        } else {
                                            console.log("ERROR: Can't focus window with ", appIcon.windowId);
                                        }
                                    }
                                }
                            }

                            // Counter Badge
                            Rectangle {
                                visible: modelData.count > 1 && !wsBox.isActive
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
                                    font.pixelSize: 9
                                    color: "white"
                                }
                            }
                        }
                    }

                    // fallback: if there're no apps - we show workspace number/name
                    Rectangle {
                        visible: root.getWorkspaceIcons(wsData).length === 0
                        anchors.centerIn: parent
                        color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                        Text {
                            anchors.centerIn: parent
                            text: wsData ? (wsData.name || (wsData.idx ? wsData.idx : (wsData.id ? wsData.id : ""))) : ""
                            font.pixelSize: 12
                            color: modelData && modelData.active ? Theme.surfaceContainer : Theme.surfaceTextMedium
                        }
                    }
                }
            }
        }
    }
}
