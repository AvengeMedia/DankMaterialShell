import QtQuick
import QtQuick.Controls
import Quickshell
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

    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 2 : Math.max(Theme.spacingS, SettingsData.topBarInnerPadding)
    
    width: SettingsData.showWorkspacePadding ? Math.max(
                                                   120,
                                                   workspaceRow.implicitWidth + horizontalPadding * 2) : workspaceRow.implicitWidth
                                               + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground) return "transparent"
        const baseColor = Theme.surfaceTextHover
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b,
                       baseColor.a * Theme.widgetTransparency)
    }
    visible: CompositorService.isNiri || CompositorService.isHyprland

    Connections {
        function onAllWorkspacesChanged() {
            if (CompositorService.isNiri) {
                root.workspaceList = SettingsData.showWorkspacePadding ? root.padWorkspaces(
                                                                          root.getNiriWorkspaces()) : root.getNiriWorkspaces()
            }
        }

        target: NiriService
        enabled: CompositorService.isNiri
    }

    Connections {
        function onValuesChanged() {
            if (CompositorService.isHyprland) {
                var workspaces = Hyprland.workspaces ? Hyprland.workspaces.values : []
                if (workspaces.length === 0) {
                    workspaces = [{id: 1, name: "1"}]
                }
                var sorted = workspaces.slice().sort((a, b) => a.id - b.id)
                root.workspaceList = SettingsData.showWorkspacePadding ? root.padWorkspaces(sorted) : sorted
            }
        }

        target: Hyprland.workspaces
        enabled: CompositorService.isHyprland
    }

    Connections {
        function onFocusedWorkspaceChanged() {
            // Hyprland workspace changes handled automatically by currentWorkspace binding
        }

        function onFocusedMonitorChanged() {
            // Hyprland monitor changes handled automatically by currentWorkspace binding
        }

        target: Hyprland
        enabled: CompositorService.isHyprland
    }

    Connections {
        function onShowWorkspacePaddingChanged() {
            if (CompositorService.isHyprland) {
                var workspaces = Hyprland.workspaces ? Hyprland.workspaces.values : []
                if (workspaces.length === 0) {
                    workspaces = [{id: 1, name: "1"}]
                }
                var sorted = workspaces.slice().sort((a, b) => a.id - b.id)
                root.workspaceList = SettingsData.showWorkspacePadding ? root.padWorkspaces(sorted) : sorted
            } else {
                var baseList = root.getNiriWorkspaces()
                root.workspaceList = SettingsData.showWorkspacePadding ? root.padWorkspaces(baseList) : baseList
            }
        }

        target: SettingsData
    }

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
                            if (ws.idx + 1 === modelData)
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

                width: isActive ? widgetHeight * 1.2 + Theme.spacingXS : widgetHeight * 0.8
                height: widgetHeight * 0.6
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

                DankIcon {
                    visible: hasIcon && iconData.type === "icon"
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
                    visible: hasIcon && iconData.type === "text"
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
                    visible: SettingsData.showWorkspaceIndex && !hasIcon
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