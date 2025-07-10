import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: workspaceSwitcher
    
    property var theme
    property var root
    
    width: Math.max(120, workspaceRow.implicitWidth + theme.spacingL * 2)
    height: 32
    radius: theme.cornerRadiusLarge
    color: Qt.rgba(theme.surfaceContainerHigh.r, theme.surfaceContainerHigh.g, theme.surfaceContainerHigh.b, 0.8)
    anchors.verticalCenter: parent.verticalCenter
    
    property int currentWorkspace: 1
    property var workspaceList: []
    
    Process {
        id: workspaceQuery
        command: ["niri", "msg", "workspaces"]
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    workspaceSwitcher.parseWorkspaceOutput(data.trim())
                }
            }
        }
    }
    
    function parseWorkspaceOutput(data) {
        const lines = data.split('\n')
        let currentOutputName = ""
        let focusedOutput = ""
        let focusedWorkspace = 1
        let outputWorkspaces = {}
        
        for (const line of lines) {
            if (line.startsWith('Output "')) {
                const outputMatch = line.match(/Output "(.+)"/)
                if (outputMatch) {
                    currentOutputName = outputMatch[1]
                    outputWorkspaces[currentOutputName] = []
                }
                continue
            }
            
            if (line.trim() && line.match(/^\s*\*?\s*(\d+)$/)) {
                const wsMatch = line.match(/^\s*(\*?)\s*(\d+)$/)
                if (wsMatch) {
                    const isActive = wsMatch[1] === '*'
                    const wsNum = parseInt(wsMatch[2])
                    
                    if (currentOutputName && outputWorkspaces[currentOutputName]) {
                        outputWorkspaces[currentOutputName].push(wsNum)
                    }
                    
                    if (isActive) {
                        focusedOutput = currentOutputName
                        focusedWorkspace = wsNum
                    }
                }
            }
        }
        
        currentWorkspace = focusedWorkspace
        
        if (focusedOutput && outputWorkspaces[focusedOutput]) {
            workspaceList = outputWorkspaces[focusedOutput]
        } else {
            workspaceList = [1, 2]
        }
    }
    
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            workspaceQuery.running = true
        }
    }
    
    Row {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: theme.spacingS
        
        Repeater {
            model: workspaceSwitcher.workspaceList
            
            Rectangle {
                property bool isActive: modelData === workspaceSwitcher.currentWorkspace
                property bool isHovered: mouseArea.containsMouse
                
                width: isActive ? theme.spacingXL + theme.spacingS : theme.spacingL
                height: theme.spacingS
                radius: height / 2
                color: isActive ? theme.primary : 
                       isHovered ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.5) :
                       Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.3)
                
                Behavior on width {
                    NumberAnimation {
                        duration: theme.mediumDuration
                        easing.type: theme.emphasizedEasing
                    }
                }
                
                Behavior on color {
                    ColorAnimation {
                        duration: theme.mediumDuration
                        easing.type: theme.emphasizedEasing
                    }
                }
                
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        switchProcess.command = ["niri", "msg", "action", "focus-workspace", modelData.toString()]
                        switchProcess.running = true
                        workspaceSwitcher.currentWorkspace = modelData
                        Qt.callLater(() => {
                            workspaceQuery.running = true
                        })
                    }
                }
            }
        }
    }
    
    Process {
        id: switchProcess
        running: false
    }
}