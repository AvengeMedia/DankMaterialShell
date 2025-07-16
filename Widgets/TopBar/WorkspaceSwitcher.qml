import QtQuick
import Quickshell
import qs.Common
import qs.Services

Rectangle {
    id: root
    
    property string screenName: ""
    
    width: Math.max(120, workspaceRow.implicitWidth + Theme.spacingL * 2)
    height: 30
    radius: Theme.cornerRadiusLarge
    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
    visible: NiriWorkspaceService.niriAvailable
    
    property int currentWorkspace: getDisplayActiveWorkspace()
    property var workspaceList: getDisplayWorkspaces()
    
    function getDisplayWorkspaces() {
        if (!NiriWorkspaceService.niriAvailable || NiriWorkspaceService.allWorkspaces.length === 0) {
            return [1, 2]
        }
        
        if (!root.screenName) {
            return NiriWorkspaceService.getCurrentOutputWorkspaceNumbers()
        }
        
        var displayWorkspaces = []
        for (var i = 0; i < NiriWorkspaceService.allWorkspaces.length; i++) {
            var ws = NiriWorkspaceService.allWorkspaces[i]
            if (ws.output === root.screenName) {
                displayWorkspaces.push(ws.idx + 1)
            }
        }
        
        return displayWorkspaces.length > 0 ? displayWorkspaces : [1, 2]
    }
    
    function getDisplayActiveWorkspace() {
        if (!NiriWorkspaceService.niriAvailable || NiriWorkspaceService.allWorkspaces.length === 0) {
            return 1
        }
        
        if (!root.screenName) {
            return NiriWorkspaceService.getCurrentWorkspaceNumber()
        }
        
        for (var i = 0; i < NiriWorkspaceService.allWorkspaces.length; i++) {
            var ws = NiriWorkspaceService.allWorkspaces[i]
            if (ws.output === root.screenName && ws.is_active) {
                return ws.idx + 1
            }
        }
        
        return 1
    }
    
    Connections {
        target: NiriWorkspaceService
        function onAllWorkspacesChanged() {
            root.workspaceList = root.getDisplayWorkspaces()
            root.currentWorkspace = root.getDisplayActiveWorkspace()
        }
        function onFocusedWorkspaceIndexChanged() {
            root.currentWorkspace = root.getDisplayActiveWorkspace()
        }
        function onNiriAvailableChanged() {
            if (NiriWorkspaceService.niriAvailable) {
                root.workspaceList = root.getDisplayWorkspaces()
                root.currentWorkspace = root.getDisplayActiveWorkspace()
            }
        }
    }
    
    Row {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: Theme.spacingS
        
        Repeater {
            model: root.workspaceList
            
            Rectangle {
                property bool isActive: modelData === root.currentWorkspace
                property bool isHovered: mouseArea.containsMouse
                property int sequentialNumber: index + 1
                
                width: isActive ? Theme.spacingXL + Theme.spacingM : Theme.spacingL + Theme.spacingXS
                height: Theme.spacingM
                radius: height / 2
                color: isActive ? Theme.primary : 
                       isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) :
                       Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
                
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
                
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", sequentialNumber.toString()])
                    }
                }
            }
        }
    }
}