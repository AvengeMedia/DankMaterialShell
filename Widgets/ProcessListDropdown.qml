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
    
    implicitWidth: 600
    implicitHeight: 600
    
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
        width: Math.min(600, parent.width - Theme.spacingL * 2)
        height: Math.min(600, parent.height - Theme.barHeight - Theme.spacingS * 2)
        x: Math.max(Theme.spacingL, parent.width - width - Theme.spacingL)
        y: Theme.barHeight + Theme.spacingXS
        
        radius: Theme.cornerRadiusLarge
        color: Theme.surfaceContainer
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        border.width: 1
        clip: true
        
        // TopBar dropdown animation - slide down from bar
        transform: [
            Scale {
                id: scaleTransform
                origin.x: parent.width * 0.85  // Scale from top-right
                origin.y: 0
                xScale: processDropdown.isVisible ? 1.0 : 0.95
                yScale: processDropdown.isVisible ? 1.0 : 0.8
                
                Behavior on xScale {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
                
                Behavior on yScale {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            },
            Translate {
                id: translateTransform
                x: processDropdown.isVisible ? 0 : 20
                y: processDropdown.isVisible ? 0 : -30
                
                Behavior on x {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
                
                Behavior on y {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }
        ]
        
        opacity: processDropdown.isVisible ? 1.0 : 0.0
        
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
        
        Behavior on opacity {
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
            
            // System overview and controls
            Column {
                Layout.fillWidth: true
                spacing: Theme.spacingM
                
                // Enhanced system overview with integrated controls
                Row {
                    width: parent.width
                    spacing: Theme.spacingM
                    
                    // CPU Overview Card (clickable for sorting)
                    Rectangle {
                        width: (parent.width - Theme.spacingM * 2) / 3
                        height: 80
                        radius: Theme.cornerRadiusLarge
                        color: {
                            if (ProcessMonitorService.sortBy === "cpu") {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                            } else if (cpuCardMouseArea.containsMouse) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            } else {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                            }
                        }
                        border.color: ProcessMonitorService.sortBy === "cpu" ? 
                                     Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) :
                                     Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                        border.width: ProcessMonitorService.sortBy === "cpu" ? 2 : 1
                        
                        MouseArea {
                            id: cpuCardMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ProcessMonitorService.setSortBy("cpu")
                        }
                        
                        Behavior on color {
                            ColorAnimation { duration: Theme.shortDuration }
                        }
                        
                        Behavior on border.color {
                            ColorAnimation { duration: Theme.shortDuration }
                        }
                        
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            
                            Text {
                                text: "CPU"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: ProcessMonitorService.sortBy === "cpu" ? Theme.primary : Theme.secondary
                                opacity: ProcessMonitorService.sortBy === "cpu" ? 1.0 : 0.8
                            }
                            
                            Text {
                                text: ProcessMonitorService.totalCpuUsage.toFixed(1) + "%"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }
                            
                            Text {
                                text: ProcessMonitorService.cpuCount + " cores"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                opacity: 0.7
                            }
                        }
                    }
                    
                    // Memory Overview Card (clickable for sorting)
                    Rectangle {
                        width: (parent.width - Theme.spacingM * 2) / 3
                        height: 80
                        radius: Theme.cornerRadiusLarge
                        color: {
                            if (ProcessMonitorService.sortBy === "memory") {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                            } else if (memoryCardMouseArea.containsMouse) {
                                return Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.12)
                            } else {
                                return Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
                            }
                        }
                        border.color: ProcessMonitorService.sortBy === "memory" ? 
                                     Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) :
                                     Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.2)
                        border.width: ProcessMonitorService.sortBy === "memory" ? 2 : 1
                        
                        MouseArea {
                            id: memoryCardMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ProcessMonitorService.setSortBy("memory")
                        }
                        
                        Behavior on color {
                            ColorAnimation { duration: Theme.shortDuration }
                        }
                        
                        Behavior on border.color {
                            ColorAnimation { duration: Theme.shortDuration }
                        }
                        
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            
                            Text {
                                text: "Memory"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: ProcessMonitorService.sortBy === "memory" ? Theme.primary : Theme.secondary
                                opacity: ProcessMonitorService.sortBy === "memory" ? 1.0 : 0.8
                            }
                            
                            Text {
                                text: ProcessMonitorService.formatSystemMemory(ProcessMonitorService.usedMemoryKB)
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }
                            
                            Text {
                                text: "of " + ProcessMonitorService.formatSystemMemory(ProcessMonitorService.totalMemoryKB)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                opacity: 0.7
                            }
                        }
                    }
                    
                    // Swap Overview Card  
                    Rectangle {
                        width: (parent.width - Theme.spacingM * 2) / 3
                        height: 80
                        radius: Theme.cornerRadiusLarge
                        color: ProcessMonitorService.totalSwapKB > 0 ? 
                               Qt.rgba(Theme.tertiary.r, Theme.tertiary.g, Theme.tertiary.b, 0.08) :
                               Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.04)
                        border.color: ProcessMonitorService.totalSwapKB > 0 ? 
                                     Qt.rgba(Theme.tertiary.r, Theme.tertiary.g, Theme.tertiary.b, 0.2) :
                                     Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.12)
                        border.width: 1
                        
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            
                            Text {
                                text: "Swap"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: ProcessMonitorService.totalSwapKB > 0 ? Theme.tertiary : Theme.surfaceText
                                opacity: 0.8
                            }
                            
                            Text {
                                text: ProcessMonitorService.totalSwapKB > 0 ? ProcessMonitorService.formatSystemMemory(ProcessMonitorService.usedSwapKB) : "None"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }
                            
                            Text {
                                text: ProcessMonitorService.totalSwapKB > 0 ? "of " + ProcessMonitorService.formatSystemMemory(ProcessMonitorService.totalSwapKB) : "No swap configured"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                opacity: 0.7
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
            Item {
                id: columnHeaders
                Layout.fillWidth: true
                Layout.leftMargin: 8
                height: 24
                
                // Process name header
                Text {
                    text: "Process"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    opacity: 0.7
                    anchors.left: parent.left
                    anchors.leftMargin: 0  // Left align with content area
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                // CPU header - positioned exactly like CPU badge
                Rectangle {
                    width: 80
                    height: 20
                    color: "transparent"
                    anchors.right: parent.right
                    anchors.rightMargin: 200  // Slight adjustment to move right
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        text: "CPU"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        opacity: 0.7
                        anchors.centerIn: parent
                    }
                }
                
                // RAM header - positioned exactly like memory badge
                Rectangle {
                    width: 80
                    height: 20
                    color: "transparent"
                    anchors.right: parent.right
                    anchors.rightMargin: 112  // Move right by decreasing rightMargin
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        text: "RAM"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        opacity: 0.7
                        anchors.centerIn: parent
                    }
                }
                
                // PID header - positioned exactly like PID text
                Text {
                    text: "PID"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    opacity: 0.7
                    width: 50
                    horizontalAlignment: Text.AlignRight
                    anchors.right: parent.right
                    anchors.rightMargin: 53  // Move left by increasing rightMargin
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                // Sort direction arrow - far right
                Rectangle {
                    width: 28
                    height: 28
                    radius: Theme.cornerRadius
                    color: sortOrderArea.containsMouse ? 
                           Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : 
                           "transparent"
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    
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
                    spacing: 4
                    
                    delegate: Rectangle {
                        width: processListView.width
                        height: 40
                        radius: Theme.cornerRadiusLarge
                        color: processMouseArea.containsMouse ? 
                               Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
                               "transparent"
                        border.color: processMouseArea.containsMouse ? 
                                     Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                                     "transparent"
                        border.width: 1
                        
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
                        
                        Item {
                            anchors.fill: parent
                            anchors.margins: 8
                            
                            // Process icon
                            Text {
                                id: processIcon
                                text: ProcessMonitorService.getProcessIcon(modelData ? modelData.command : "")
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize - 4
                                color: {
                                    if (modelData && modelData.cpu > 80) return Theme.error
                                    if (modelData && modelData.cpu > 50) return Theme.warning
                                    return Theme.surfaceText
                                }
                                opacity: 0.8
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // Process name
                            Text {
                                text: modelData ? modelData.displayName : ""
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                width: 250
                                elide: Text.ElideRight
                                anchors.left: processIcon.right
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            
                            // CPU usage
                            Rectangle {
                                id: cpuBadge
                                width: 80
                                height: 20
                                radius: Theme.cornerRadius
                                color: {
                                    if (modelData && modelData.cpu > 80) return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                                    if (modelData && modelData.cpu > 50) return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                                    return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                                }
                                anchors.right: parent.right
                                anchors.rightMargin: 194  // 28 (menu) + 12 + 50 (pid) + 12 + 80 (mem) + 12 spacing
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Text {
                                    text: ProcessMonitorService.formatCpuUsage(modelData ? modelData.cpu : 0)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: {
                                        if (modelData && modelData.cpu > 80) return Theme.error
                                        if (modelData && modelData.cpu > 50) return Theme.warning
                                        return Theme.surfaceText
                                    }
                                    anchors.centerIn: parent
                                }
                            }
                            
                            // Memory usage
                            Rectangle {
                                id: memoryBadge
                                width: 80
                                height: 20
                                radius: Theme.cornerRadius
                                color: {
                                    if (modelData && modelData.memoryKB > 1024 * 1024) return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)  // > 1GB
                                    if (modelData && modelData.memoryKB > 512 * 1024) return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)  // > 512MB
                                    return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                                }
                                anchors.right: parent.right
                                anchors.rightMargin: 102  // 28 (menu) + 12 + 50 (pid) + 12 spacing
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Text {
                                    text: ProcessMonitorService.formatMemoryUsage(modelData ? modelData.memoryKB : 0)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: {
                                        if (modelData && modelData.memoryKB > 1024 * 1024) return Theme.error  // > 1GB
                                        if (modelData && modelData.memoryKB > 512 * 1024) return Theme.warning  // > 512MB
                                        return Theme.surfaceText
                                    }
                                    anchors.centerIn: parent
                                }
                            }
                            
                            // PID
                            Text {
                                text: modelData ? modelData.pid.toString() : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                opacity: 0.7
                                width: 50
                                horizontalAlignment: Text.AlignRight
                                anchors.right: parent.right
                                anchors.rightMargin: 40  // 28 (menu) + 12 spacing
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // 3-dot menu button (far right)
                            Rectangle {
                                id: menuButton
                                width: 28
                                height: 28
                                radius: Theme.cornerRadius
                                color: menuButtonArea.containsMouse ? 
                                       Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : 
                                       "transparent"
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                
                                    Text {
                                        text: "more_vert"
                                        font.family: Theme.iconFont
                                        font.weight: Theme.iconFontWeight
                                        font.pixelSize: Theme.iconSize - 2
                                        color: Theme.surfaceText
                                        opacity: 0.6
                                        anchors.centerIn: parent
                                    }
                                    
                                    MouseArea {
                                        id: menuButtonArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        
                                        onClicked: {
                                            if (modelData && modelData.pid > 0) {
                                                processContextMenuWindow.processData = modelData
                                                let globalPos = menuButtonArea.mapToGlobal(menuButtonArea.width / 2, menuButtonArea.height)
                                                processContextMenuWindow.show(globalPos.x, globalPos.y)
                                            }
                                        }
                                    }
                                    
                                Behavior on color {
                                    ColorAnimation { duration: Theme.shortDuration }
                                }
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
        opacity: processContextMenuWindow.menuVisible ? 1.0 : 0.0
        scale: processContextMenuWindow.menuVisible ? 1.0 : 0.85
        
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
            // Smart positioning to prevent off-screen cutoff
            const menuWidth = 180
            const menuHeight = menuColumn.implicitHeight + Theme.spacingS * 2
            
            // Get screen dimensions from the monitor
            const screenWidth = processContextMenuWindow.screen ? processContextMenuWindow.screen.width : 1920
            const screenHeight = processContextMenuWindow.screen ? processContextMenuWindow.screen.height : 1080
            
            // Calculate optimal position
            let finalX = x
            let finalY = y
            
            // Check horizontal bounds - if too close to right edge, position to the left
            if (x + menuWidth > screenWidth - 20) {
                finalX = x - menuWidth
            }
            
            // Check vertical bounds - if too close to bottom edge, position above
            if (y + menuHeight > screenHeight - 20) {
                finalY = y - menuHeight
            }
            
            // Ensure we don't go off the left or top edges
            finalX = Math.max(20, finalX)
            finalY = Math.max(20, finalY)
            
            processContextMenu.x = finalX
            processContextMenu.y = finalY
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
        ProcessMonitorService.updateSystemInfo()
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