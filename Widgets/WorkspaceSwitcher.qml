import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Common"
import "../Services"

Rectangle {
    id: workspaceSwitcher
    
    width: Math.max(120, workspaceRow.implicitWidth + Theme.spacingL * 2)
    height: 32
    radius: Theme.cornerRadiusLarge
    color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
    anchors.verticalCenter: parent.verticalCenter
    visible: NiriWorkspaceService.niriAvailable
    
    // Use the reactive workspace service
    property int currentWorkspace: NiriWorkspaceService.getCurrentWorkspaceNumber()
    property var workspaceList: NiriWorkspaceService.getCurrentOutputWorkspaceNumbers()
    
    Row {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: Theme.spacingS
        
        Repeater {
            model: workspaceSwitcher.workspaceList
            
            Rectangle {
                property bool isActive: NiriWorkspaceService.isWorkspaceActive(modelData)
                property bool isHovered: mouseArea.containsMouse
                
                width: isActive ? Theme.spacingXL + Theme.spacingS : Theme.spacingL
                height: Theme.spacingS
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
                        // Use the service to switch workspaces
                        // modelData is workspace number (1-based)
                        NiriWorkspaceService.switchToWorkspaceByNumber(modelData)
                    }
                }
            }
        }
    }
    
}