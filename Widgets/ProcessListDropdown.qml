import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import "../Common"
import "../Services"

PanelWindow {
    id: processDropdown
    
    property bool isVisible: false
    property var parentWidget: null
    
    visible: isVisible
    
    implicitWidth: 500
    implicitHeight: 500
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    
    color: "transparent"
    
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    // Click outside to close
    MouseArea {
        anchors.fill: parent
        onClicked: processDropdown.hide()
    }
    
    Rectangle {
        id: dropdownContent
        width: Math.min(500, parent.width - Theme.spacingL * 2)
        height: Math.min(500, parent.height - Theme.barHeight - Theme.spacingS * 2)
        x: Math.max(Theme.spacingL, parent.width - width - Theme.spacingL)
        y: Theme.barHeight + Theme.spacingXS
        
        radius: Theme.cornerRadiusLarge
        color: Theme.surfaceContainer
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        border.width: 1
        clip: true
        
        opacity: processDropdown.isVisible ? 1.0 : 0.0
        scale: processDropdown.isVisible ? 1.0 : 0.85
        
        // Add shadow effect
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 8
            shadowBlur: 1.0
            shadowColor: Qt.rgba(0, 0, 0, 0.15)
            shadowOpacity: processDropdown.isVisible ? 0.15 : 0
        }
        
        // Smooth animations
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
        
        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
        
        // Click inside dropdown - consume the event
        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Consume clicks inside dropdown to prevent closing
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM
            
            // Header
            Column {
                Layout.fillWidth: true
                spacing: Theme.spacingM
                
                Row {
                    width: parent.width
                    height: 32
                    
                    Text {
                        id: processTitle
                        text: "System Processes"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Item { 
                        width: parent.width - processTitle.width - sortControls.width - Theme.spacingM
                        height: 1 
                    }
                    
                    // Sort controls
                    Row {
                        id: sortControls
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: cpuButton.width + ramButton.width + Theme.spacingXS
                            height: 28
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                            
                            Row {
                                anchors.centerIn: parent
                                spacing: 0
                                
                                Button {
                                    id: cpuButton
                                    text: "CPU"
                                    flat: true
                                    checkable: true
                                    checked: ProcessMonitorService.sortBy === "cpu"
                                    onClicked: ProcessMonitorService.setSortBy("cpu")
                                    font.pixelSize: Theme.fontSizeSmall
                                    hoverEnabled: true
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: parent.clicked()
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        font: parent.font
                                        color: parent.checked ? Theme.primary : Theme.surfaceText
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    background: Rectangle {
                                        color: parent.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                                        radius: Theme.cornerRadius
                                        
                                        Behavior on color {
                                            ColorAnimation { duration: Theme.shortDuration }
                                        }
                                    }
                                }
                                
                                Button {
                                    id: ramButton
                                    text: "RAM"
                                    flat: true
                                    checkable: true
                                    checked: ProcessMonitorService.sortBy === "memory"
                                    onClicked: ProcessMonitorService.setSortBy("memory")
                                    font.pixelSize: Theme.fontSizeSmall
                                    hoverEnabled: true
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: parent.clicked()
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        font: parent.font
                                        color: parent.checked ? Theme.primary : Theme.surfaceText
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    background: Rectangle {
                                        color: parent.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                                        radius: Theme.cornerRadius
                                        
                                        Behavior on color {
                                            ColorAnimation { duration: Theme.shortDuration }
                                        }
                                    }
                                }
                            }
                        }
                        
                        Rectangle {
                            width: 28
                            height: 28
                            radius: Theme.cornerRadius
                            color: sortOrderArea.containsMouse ? 
                                   Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : 
                                   "transparent"
                            
                            Text {
                                text: ProcessMonitorService.sortDescending ? "↓" : "↑"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                anchors.centerIn: parent
                            }
                            
                            MouseArea {
                                id: sortOrderArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ProcessMonitorService.toggleSortOrder()
                            }
                            
                            Behavior on color {
                                ColorAnimation { duration: Theme.shortDuration }
                            }
                        }
                    }
                }
                
                // Separator
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                }
            }
            
            // Headers
            Row {
                id: columnHeaders
                Layout.fillWidth: true
                
                Text {
                    text: "Process"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    opacity: 0.7
                    width: 180
                }
                
                Text {
                    text: "CPU"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    opacity: 0.7
                    width: 60
                    horizontalAlignment: Text.AlignRight
                }
                
                Text {
                    text: "RAM"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    opacity: 0.7
                    width: 60
                    horizontalAlignment: Text.AlignRight
                }
                
                Text {
                    text: "PID"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    opacity: 0.7
                    width: 60
                    horizontalAlignment: Text.AlignRight
                }
            }
            
            // Process list
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 200
                clip: true
                
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                
                ListView {
                    id: processListView
                    anchors.fill: parent
                    model: ProcessMonitorService.processes
                    spacing: 2
                    
                    delegate: Rectangle {
                        width: processListView.width - 16
                        height: 36
                        radius: Theme.cornerRadius
                        color: processMouseArea.containsMouse ? 
                               Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
                               "transparent"
                        
                        MouseArea {
                            id: processMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    if (modelData && modelData.pid > 0) {
                                        processContextMenuWindow.processData = modelData
                                        let globalPos = processMouseArea.mapToGlobal(mouse.x, mouse.y)
                                        processContextMenuWindow.show(globalPos.x, globalPos.y)
                                    }
                                }
                            }
                            
                            onPressAndHold: {
                                // Context menu for kill process etc
                                if (modelData && modelData.pid > 0) {
                                    processContextMenuWindow.processData = modelData
                                    let globalPos = processMouseArea.mapToGlobal(processMouseArea.width / 2, processMouseArea.height / 2)
                                    processContextMenuWindow.show(globalPos.x, globalPos.y)
                                }
                            }
                        }
                        
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            width: parent.width - 16
                            
                            // Process icon
                            Text {
                                text: ProcessMonitorService.getProcessIcon(modelData ? modelData.command : "")
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize - 4
                                color: {
                                    if (modelData && modelData.cpu > 80) return Theme.error
                                    if (modelData && modelData.cpu > 50) return Theme.warning
                                    return Theme.surfaceText
                                }
                                opacity: 0.8
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // Process name
                            Text {
                                text: modelData ? modelData.displayName : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: 150
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Item { width: parent.width - 280 }
                            
                            // CPU usage
                            Text {
                                text: ProcessMonitorService.formatCpuUsage(modelData ? modelData.cpu : 0)
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: {
                                    if (modelData && modelData.cpu > 80) return Theme.error
                                    if (modelData && modelData.cpu > 50) return Theme.warning
                                    return Theme.surfaceText
                                }
                                width: 60
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // Memory usage
                            Text {
                                text: ProcessMonitorService.formatMemoryUsage(modelData ? modelData.memory : 0)
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: {
                                    if (modelData && modelData.memory > 10) return Theme.error
                                    if (modelData && modelData.memory > 5) return Theme.warning
                                    return Theme.surfaceText
                                }
                                width: 60
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // PID
                            Text {
                                text: modelData ? modelData.pid.toString() : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                opacity: 0.7
                                width: 60
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
            
        }
    }
    
    // Styled context menu for process actions - positioned in global coordinates
    PanelWindow {
        id: processContextMenuWindow
        property var processData: null
        property bool menuVisible: false
        
        visible: menuVisible
        color: "transparent"
        
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        
        Rectangle {
            id: processContextMenu
            width: 180
            height: menuColumn.implicitHeight + Theme.spacingS * 2
            radius: Theme.cornerRadiusLarge
            color: Theme.surfaceContainer
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            border.width: 1
        
        // Material 3 drop shadow
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: parent.z - 1
        }
        
        // Material 3 animations
        opacity: menuVisible ? 1.0 : 0.0
        scale: menuVisible ? 1.0 : 0.85
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
        
        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
        
        Column {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: 1
            
            // Copy PID
            Rectangle {
                width: parent.width
                height: 28
                radius: Theme.cornerRadiusSmall
                color: copyPidArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Copy PID"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                }
                
                MouseArea {
                    id: copyPidArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        if (processContextMenuWindow.processData) {
                            copyPidProcess.command = ["wl-copy", processContextMenuWindow.processData.pid.toString()]
                            copyPidProcess.running = true
                        }
                        processContextMenuWindow.hide()
                    }
                }
                
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }
            
            // Copy Process Name
            Rectangle {
                width: parent.width
                height: 28
                radius: Theme.cornerRadiusSmall
                color: copyNameArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Copy Process Name"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                }
                
                MouseArea {
                    id: copyNameArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        if (processContextMenuWindow.processData) {
                            let processName = processContextMenuWindow.processData.displayName || processContextMenuWindow.processData.command
                            copyNameProcess.command = ["wl-copy", processName]
                            copyNameProcess.running = true
                        }
                        processContextMenuWindow.hide()
                    }
                }
                
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }
            
            // Separator
            Rectangle {
                width: parent.width - Theme.spacingS * 2
                height: 5
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 1
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                }
            }
            
            // Kill Process
            Rectangle {
                width: parent.width
                height: 28
                radius: Theme.cornerRadiusSmall
                color: killArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"
                enabled: processContextMenuWindow.processData && processContextMenuWindow.processData.pid > 1000
                opacity: enabled ? 1.0 : 0.5
                
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Kill Process"
                    font.pixelSize: Theme.fontSizeSmall
                    color: parent.enabled ? (killArea.containsMouse ? Theme.error : Theme.surfaceText) : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                    font.weight: Font.Normal
                }
                
                MouseArea {
                    id: killArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: parent.enabled
                    
                    onClicked: {
                        if (processContextMenuWindow.processData) {
                            killProcess.command = ["kill", processContextMenuWindow.processData.pid.toString()]
                            killProcess.running = true
                        }
                        processContextMenuWindow.hide()
                    }
                }
                
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }
            
            // Force Kill Process
            Rectangle {
                width: parent.width
                height: 28
                radius: Theme.cornerRadiusSmall
                color: forceKillArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"
                enabled: processContextMenuWindow.processData && processContextMenuWindow.processData.pid > 1000
                opacity: enabled ? 1.0 : 0.5
                
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Force Kill Process"
                    font.pixelSize: Theme.fontSizeSmall
                    color: parent.enabled ? (forceKillArea.containsMouse ? Theme.error : Theme.surfaceText) : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                    font.weight: Font.Normal
                }
                
                MouseArea {
                    id: forceKillArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: parent.enabled
                    
                    onClicked: {
                        if (processContextMenuWindow.processData) {
                            forceKillProcess.command = ["kill", "-9", processContextMenuWindow.processData.pid.toString()]
                            forceKillProcess.running = true
                        }
                        processContextMenuWindow.hide()
                    }
                }
                
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }
        }
        
        }
        
        function show(x, y) {
            processContextMenu.x = x
            processContextMenu.y = y
            processContextMenuWindow.menuVisible = true
        }
        
        function hide() {
            processContextMenuWindow.menuVisible = false
        }
        
        // Click outside to close
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                processContextMenuWindow.menuVisible = false
            }
        }
        
        // Process objects for commands
        Process {
            id: copyPidProcess
            running: false
        }
        
        Process {
            id: copyNameProcess
            running: false
        }
        
        Process {
            id: killProcess
            running: false
        }
        
        Process {
            id: forceKillProcess
            running: false
        }
    }
    
    // Close dropdown when clicking outside
    function hide() {
        isVisible = false
    }
    
    function show() {
        isVisible = true
        ProcessMonitorService.updateProcessList()
    }
    
    function toggle() {
        if (isVisible) {
            hide()
        } else {
            show()
        }
    }
}