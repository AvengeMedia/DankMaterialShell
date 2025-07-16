import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import qs.Common
import qs.Services

PanelWindow {
    id: processListWidget
    
    property bool isVisible: false
    property int currentTab: 0
    property var tabNames: ["Processes", "Performance", "System"]
    
    // Full screen overlay setup for proper focus
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    // Proper layer shell configuration
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-processlist"
    
    visible: isVisible
    color: "transparent"
    
    // Monitor process widget visibility to enable/disable process monitoring
    onIsVisibleChanged: {
        console.log("Process list widget", isVisible ? "opened" : "closed")
        ProcessMonitorService.enableMonitoring(isVisible)
    }
    
    // Background dim with click to close
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
        opacity: processListWidget.isVisible ? 1.0 : 0.0
        visible: processListWidget.isVisible
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
        
        MouseArea {
            anchors.fill: parent
            enabled: processListWidget.isVisible
            onClicked: processListWidget.hide()
        }
    }
    
    // Main container with process list
    Rectangle {
        id: mainContainer
        width: 900
        height: 680
        anchors.centerIn: parent
        color: Theme.popupBackground()
        radius: Theme.cornerRadiusXLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        
        // Material 3 elevation with shadow
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 8
            shadowBlur: 1.0
            shadowColor: Qt.rgba(0, 0, 0, 0.3)
            shadowOpacity: 0.3
        }
        
        // Center-screen fade with subtle scale
        opacity: processListWidget.isVisible ? 1.0 : 0.0
        scale: processListWidget.isVisible ? 1.0 : 0.96
        
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
        
        // Content with focus management
        Item {
            anchors.fill: parent
            focus: true
            
            // Handle keyboard shortcuts
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    processListWidget.hide()
                    event.accepted = true
                } else if (event.key === Qt.Key_1) {
                    currentTab = 0
                    event.accepted = true
                } else if (event.key === Qt.Key_2) {
                    currentTab = 1
                    event.accepted = true
                } else if (event.key === Qt.Key_3) {
                    currentTab = 2
                    event.accepted = true
                }
            }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingXL
                spacing: Theme.spacingL
                
                // Header section with proper layout
                Row {
                    Layout.fillWidth: true
                    height: 40
                    spacing: Theme.spacingM
                    
                    // Title
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "System Monitor"
                        font.pixelSize: Theme.fontSizeLarge + 4
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }
                    
                    // Spacer
                    Item { 
                        width: parent.width - 280
                        height: 1
                    }
                    
                    // Process count with proper constraints
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ProcessMonitorService.processes.length + " processes"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        width: Math.min(implicitWidth, 120)
                        elide: Text.ElideRight
                    }
                }
                
                // Elegant tab navigation - the soul of our interface
                Rectangle {
                    Layout.fillWidth: true
                    height: 52
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.04)
                    radius: Theme.cornerRadiusLarge
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
                    border.width: 1
                    
                    Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 2
                        
                        Repeater {
                            model: tabNames
                            
                            Rectangle {
                                width: (parent.width - (tabNames.length - 1) * 2) / tabNames.length
                                height: 44
                                radius: Theme.cornerRadiusLarge
                                color: currentTab === index ? 
                                       Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) :
                                       (tabMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent")
                                border.color: currentTab === index ? Theme.primary : "transparent"
                                border.width: currentTab === index ? 1 : 0
                                
                                Behavior on color {
                                    ColorAnimation { duration: Theme.shortDuration }
                                }
                                
                                Behavior on border.color {
                                    ColorAnimation { duration: Theme.shortDuration }
                                }
                                
                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingS
                                    
                                    // Tab icons for visual hierarchy
                                    Text {
                                        text: {
                                            switch(index) {
                                                case 0: return "list_alt"
                                                case 1: return "analytics"
                                                case 2: return "settings"
                                                default: return "tab"
                                            }
                                        }
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.iconSize - 2
                                        color: currentTab === index ? Theme.primary : Theme.surfaceText
                                        opacity: currentTab === index ? 1.0 : 0.7
                                        
                                        Behavior on color {
                                            ColorAnimation { duration: Theme.shortDuration }
                                        }
                                    }
                                    
                                    Text {
                                        text: modelData
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: currentTab === index ? Font.Bold : Font.Medium
                                        color: currentTab === index ? Theme.primary : Theme.surfaceText
                                        
                                        Behavior on color {
                                            ColorAnimation { duration: Theme.shortDuration }
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    id: tabMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        currentTab = index
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Tab content area with smooth transitions
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    // Processes Tab
                    Loader {
                        id: processesTab
                        anchors.fill: parent
                        visible: currentTab === 0
                        opacity: currentTab === 0 ? 1.0 : 0.0
                        sourceComponent: processesTabComponent
                        
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.emphasizedEasing
                            }
                        }
                    }
                    
                    // Performance Tab
                    Loader {
                        id: performanceTab
                        anchors.fill: parent
                        visible: currentTab === 1
                        opacity: currentTab === 1 ? 1.0 : 0.0
                        sourceComponent: performanceTabComponent
                        
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.emphasizedEasing
                            }
                        }
                    }
                    
                    // System Tab
                    Loader {
                        id: systemTab
                        anchors.fill: parent
                        visible: currentTab === 2
                        opacity: currentTab === 2 ? 1.0 : 0.0
                        sourceComponent: systemTabComponent
                        
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.emphasizedEasing
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Processes Tab Component
    Component {
        id: processesTabComponent
        
        Column {
            anchors.fill: parent
            spacing: Theme.spacingM
                
                // Quick system overview
                Row {
                    width: parent.width
                    height: 80
                    spacing: Theme.spacingM
                    
                    // CPU Card
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
                    
                    // Memory Card
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
                    
                    // Swap Card
                    Rectangle {
                        width: (parent.width - Theme.spacingM * 2) / 3
                        height: 80
                        radius: Theme.cornerRadiusLarge
                        color: ProcessMonitorService.totalSwapKB > 0 ? 
                               Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.08) :
                               Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.04)
                        border.color: ProcessMonitorService.totalSwapKB > 0 ? 
                                     Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.2) :
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
                                color: ProcessMonitorService.totalSwapKB > 0 ? Theme.warning : Theme.surfaceText
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
                
                // Process list headers
                Item {
                    width: parent.width
                    height: 24
                    
                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: Theme.spacingM
                            
                            Text {
                                text: "Process"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                opacity: 0.7
                                width: parent.width - 280  // Match process name width
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Text {
                                text: "CPU"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                opacity: 0.7
                                width: 80
                                horizontalAlignment: Text.AlignHCenter
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Text {
                                text: "Memory"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                opacity: 0.7
                                width: 80
                                horizontalAlignment: Text.AlignHCenter
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Text {
                                text: "PID"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                opacity: 0.7
                                width: 60
                                horizontalAlignment: Text.AlignHCenter
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // Sort indicator
                            Rectangle {
                                width: 28
                                height: 28
                                radius: Theme.cornerRadius
                                color: sortOrderArea.containsMouse ? 
                                       Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : 
                                       "transparent"
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
                            }
                    }
                }
                
                // Process list
                ScrollView {
                    width: parent.width
                    height: parent.height - 80 - 24 - Theme.spacingM * 2
                    clip: true
                    
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    
                    ListView {
                        id: processListView
                        width: parent.width
                        height: parent.height
                        model: ProcessMonitorService.processes
                        spacing: 2
                        
                        delegate: Rectangle {
                            width: parent.width
                            height: 44
                            radius: Theme.cornerRadius
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
                            }
                            
                            Row {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: Theme.spacingM
                                
                                // Process name and icon
                                Row {
                                    width: parent.width - 280  // Leave space for other columns
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    
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
                                    
                                    Text {
                                        text: modelData ? modelData.displayName : ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        width: parent.width - 32  // Icon width + spacing
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                // CPU usage
                                Rectangle {
                                    width: 80
                                    height: 20
                                    radius: Theme.cornerRadius
                                    color: {
                                        if (modelData && modelData.cpu > 80) return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                                        if (modelData && modelData.cpu > 50) return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                                        return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                                    }
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
                                    width: 80
                                    height: 20
                                    radius: Theme.cornerRadius
                                    color: {
                                        if (modelData && modelData.memoryKB > 1024 * 1024) return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                                        if (modelData && modelData.memoryKB > 512 * 1024) return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                                        return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Text {
                                        text: ProcessMonitorService.formatMemoryUsage(modelData ? modelData.memoryKB : 0)
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: {
                                            if (modelData && modelData.memoryKB > 1024 * 1024) return Theme.error
                                            if (modelData && modelData.memoryKB > 512 * 1024) return Theme.warning
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
                                    width: 60
                                    horizontalAlignment: Text.AlignHCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                // Menu button
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: Theme.cornerRadius
                                    color: menuButtonArea.containsMouse ? 
                                           Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : 
                                           "transparent"
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
                                }
                            }
                        }
                    }
                }
        }
    }
    
    // Define inline components for tabs
    Component {
        id: performanceTabComponent
        
        Column {
            anchors.fill: parent
            spacing: Theme.spacingM
            
            // CPU Section - Compact with per-core bars
            Rectangle {
                width: parent.width
                height: 200
                radius: Theme.cornerRadiusLarge
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.04)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
                border.width: 1
                
                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS
                    
                    // CPU Header with overall usage
                    Row {
                        width: parent.width
                        height: 32
                        spacing: Theme.spacingM
                        
                        Text {
                            text: "CPU"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Rectangle {
                            width: 80
                            height: 24
                            radius: Theme.cornerRadiusSmall
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: ProcessMonitorService.totalCpuUsage.toFixed(1) + "%"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                        
                        Item { width: parent.width - 280; height: 1 }
                        
                        Text {
                            text: ProcessMonitorService.cpuCount + " cores"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    // Per-core CPU bars - Scrollable
                    ScrollView {
                        width: parent.width
                        height: parent.height - 40
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        
                        Column {
                            width: parent.width
                            spacing: 6
                            
                            Repeater {
                                model: ProcessMonitorService.perCoreCpuUsage.length
                                
                                Row {
                                    width: parent.width
                                    height: 20
                                    spacing: Theme.spacingS
                                    
                                    // Core label
                                    Text {
                                        text: "C" + index
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        width: 24
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    // Usage bar
                                    Rectangle {
                                        width: parent.width - 80
                                        height: 6
                                        radius: 3
                                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Rectangle {
                                            width: parent.width * Math.min(1.0, ProcessMonitorService.perCoreCpuUsage[index] / 100)
                                            height: parent.height
                                            radius: parent.radius
                                            color: {
                                                const usage = ProcessMonitorService.perCoreCpuUsage[index]
                                                if (usage > 80) return Theme.error
                                                if (usage > 60) return Theme.warning
                                                return Theme.primary
                                            }
                                            
                                            Behavior on width {
                                                NumberAnimation { duration: Theme.shortDuration }
                                            }
                                        }
                                    }
                                    
                                    // Usage percentage
                                    Text {
                                        text: ProcessMonitorService.perCoreCpuUsage[index] ? 
                                              ProcessMonitorService.perCoreCpuUsage[index].toFixed(0) + "%" : "0%"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        width: 32
                                        horizontalAlignment: Text.AlignRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Memory Section - Simplified
            Rectangle {
                width: parent.width
                height: 80
                radius: Theme.cornerRadiusLarge
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.04)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
                border.width: 1
                
                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM
                    
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        
                        Text {
                            text: "Memory"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }
                        
                        Text {
                            text: ProcessMonitorService.formatSystemMemory(ProcessMonitorService.usedMemoryKB) + 
                                  " / " + ProcessMonitorService.formatSystemMemory(ProcessMonitorService.totalMemoryKB)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                    
                    Item { width: Theme.spacingL; height: 1 }
                    
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        width: 200
                        
                        Rectangle {
                            width: parent.width
                            height: 16
                            radius: 8
                            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            
                            Rectangle {
                                width: ProcessMonitorService.totalMemoryKB > 0 ? 
                                       parent.width * (ProcessMonitorService.usedMemoryKB / ProcessMonitorService.totalMemoryKB) : 0
                                height: parent.height
                                radius: parent.radius
                                color: {
                                    const usage = ProcessMonitorService.totalMemoryKB > 0 ? 
                                                 (ProcessMonitorService.usedMemoryKB / ProcessMonitorService.totalMemoryKB) : 0
                                    if (usage > 0.9) return Theme.error
                                    if (usage > 0.7) return Theme.warning
                                    return Theme.secondary
                                }
                                
                                Behavior on width {
                                    NumberAnimation { duration: Theme.mediumDuration }
                                }
                            }
                        }
                        
                        Text {
                            text: ProcessMonitorService.totalMemoryKB > 0 ? 
                                  ((ProcessMonitorService.usedMemoryKB / ProcessMonitorService.totalMemoryKB) * 100).toFixed(1) + "% used" :
                                  "No data"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }
                    }
                    
                    Item { width: parent.width - 300; height: 1 }
                    
                    // Swap info - compact
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        visible: ProcessMonitorService.totalSwapKB > 0
                        
                        Text {
                            text: "Swap"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.warning
                        }
                        
                        Text {
                            text: ProcessMonitorService.formatSystemMemory(ProcessMonitorService.usedSwapKB) + 
                                  " / " + ProcessMonitorService.formatSystemMemory(ProcessMonitorService.totalSwapKB)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }
            
            // Network & Disk I/O - Combined compact view
            Row {
                width: parent.width
                height: 80
                spacing: Theme.spacingM
                
                // Network I/O
                Rectangle {
                    width: (parent.width - Theme.spacingM) / 2
                    height: 80
                    radius: Theme.cornerRadiusLarge
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.04)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
                    border.width: 1
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS
                        
                        Text {
                            text: "Network"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Row {
                            spacing: Theme.spacingS
                            anchors.horizontalCenter: parent.horizontalCenter
                            
                            Row {
                                spacing: 4
                                
                                Text {
                                    text: "↓"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.info
                                }
                                
                                Text {
                                    text: formatNetworkSpeed(ProcessMonitorService.networkRxRate)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                }
                            }
                            
                            Row {
                                spacing: 4
                                
                                Text {
                                    text: "↑"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.error
                                }
                                
                                Text {
                                    text: formatNetworkSpeed(ProcessMonitorService.networkTxRate)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }
                }
                
                // Disk I/O
                Rectangle {
                    width: (parent.width - Theme.spacingM) / 2
                    height: 80
                    radius: Theme.cornerRadiusLarge
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.04)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
                    border.width: 1
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS
                        
                        Text {
                            text: "Disk"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Row {
                            spacing: Theme.spacingS
                            anchors.horizontalCenter: parent.horizontalCenter
                            
                            Row {
                                spacing: 4
                                
                                Text {
                                    text: "R"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
                                }
                                
                                Text {
                                    text: formatDiskSpeed(ProcessMonitorService.diskReadRate)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                }
                            }
                            
                            Row {
                                spacing: 4
                                
                                Text {
                                    text: "W"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.warning
                                }
                                
                                Text {
                                    text: formatDiskSpeed(ProcessMonitorService.diskWriteRate)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    Component {
        id: systemTabComponent
        
        ScrollView {
            anchors.fill: parent
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            
            Column {
                width: parent.width
                spacing: Theme.spacingM
                
                Row {
                    width: parent.width
                    height: 140
                    spacing: Theme.spacingM
                    
                    Rectangle {
                        width: (parent.width - Theme.spacingM) / 2
                        height: 140
                        radius: Theme.cornerRadiusLarge
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                        border.width: 1
                        
                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            anchors.bottomMargin: Theme.spacingM + 4
                            spacing: Theme.spacingXS
                            
                            Row {
                                width: parent.width
                                spacing: Theme.spacingS
                                
                                Text {
                                    text: "computer"
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: "System"
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            Text {
                                text: "Host: " + SystemMonitorService.hostname
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: "OS: " + SystemMonitorService.distribution
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: "Arch: " + SystemMonitorService.architecture
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: "Kernel: " + SystemMonitorService.kernelVersion
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }
                    }
                    
                    Rectangle {
                        width: (parent.width - Theme.spacingM) / 2
                        height: 140
                        radius: Theme.cornerRadiusLarge
                        color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
                        border.color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.16)
                        border.width: 1
                        
                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            anchors.bottomMargin: Theme.spacingM + 4
                            spacing: Theme.spacingXS
                            
                            Row {
                                width: parent.width
                                spacing: Theme.spacingS
                                
                                Text {
                                    text: "developer_board"
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    color: Theme.secondary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: "Hardware"
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            Text {
                                text: "CPU: " + SystemMonitorService.cpuModel
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: "Motherboard: " + SystemMonitorService.motherboard
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: "BIOS: " + SystemMonitorService.biosVersion
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: "Memory: " + SystemMonitorService.formatMemory(SystemMonitorService.totalMemory)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
                
                Row {
                    width: parent.width
                    height: 120
                    spacing: Theme.spacingM
                    
                    Rectangle {
                        width: (parent.width - Theme.spacingM) / 2
                        height: 120
                        radius: Theme.cornerRadiusLarge
                        color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.08)
                        border.color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.16)
                        border.width: 1
                        
                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            anchors.bottomMargin: Theme.spacingM + 4
                            spacing: Theme.spacingXS
                            
                            Row {
                                width: parent.width
                                spacing: Theme.spacingS
                                
                                Text {
                                    text: "timer"
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    color: Theme.warning
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: "Uptime"
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            Text {
                                text: SystemMonitorService.uptime
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: "Boot: " + SystemMonitorService.bootTime
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: "Load: " + SystemMonitorService.loadAverage
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }
                    }
                    
                    Rectangle {
                        width: (parent.width - Theme.spacingM) / 2
                        height: 120
                        radius: Theme.cornerRadiusLarge
                        color: Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.08)
                        border.color: Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.16)
                        border.width: 1
                        
                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            anchors.bottomMargin: Theme.spacingM + 4
                            spacing: Theme.spacingXS
                            
                            Row {
                                width: parent.width
                                spacing: Theme.spacingS
                                
                                Text {
                                    text: "list_alt"
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    color: Theme.info
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: "Processes"
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            Text {
                                text: SystemMonitorService.processCount + " Running"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: SystemMonitorService.threadCount + " Total Created"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: Math.max(200, diskMountRepeater.count * 28 + 60)
                    radius: Theme.cornerRadiusLarge
                    color: Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.08)
                    border.color: Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.16)
                    border.width: 1
                    
                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS
                        
                        Row {
                            width: parent.width
                            spacing: Theme.spacingS
                            
                            Text {
                                text: "storage"
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize
                                color: Theme.success
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Text {
                                text: "Storage & Disks"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        
                        Text {
                            text: "I/O Scheduler: " + SystemMonitorService.scheduler
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            width: parent.width
                            elide: Text.ElideRight
                        }
                        
                        ScrollView {
                            width: parent.width
                            height: parent.height - 60
                            clip: true
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            
                            Column {
                                width: parent.width
                                spacing: 2
                                
                                Row {
                                    width: parent.width
                                    height: 24
                                    spacing: Theme.spacingS
                                    
                                    Text {
                                        text: "Device"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                        width: parent.width * 0.25
                                        elide: Text.ElideRight
                                    }
                                    
                                    Text {
                                        text: "Mount"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                        width: parent.width * 0.2
                                        elide: Text.ElideRight
                                    }
                                    
                                    Text {
                                        text: "Size"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                        width: parent.width * 0.15
                                        elide: Text.ElideRight
                                    }
                                    
                                    Text {
                                        text: "Used"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                        width: parent.width * 0.15
                                        elide: Text.ElideRight
                                    }
                                    
                                    Text {
                                        text: "Available"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                        width: parent.width * 0.15
                                        elide: Text.ElideRight
                                    }
                                    
                                    Text {
                                        text: "Use%"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                        width: parent.width * 0.1
                                        elide: Text.ElideRight
                                    }
                                }
                                
                                Repeater {
                                    id: diskMountRepeater
                                    model: SystemMonitorService.diskMounts
                                    
                                    Rectangle {
                                        width: parent.width
                                        height: 24
                                        radius: Theme.cornerRadiusSmall
                                        color: diskMouseArea.containsMouse ? 
                                               Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.04) : 
                                               "transparent"
                                        
                                        MouseArea {
                                            id: diskMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }
                                        
                                        Row {
                                            anchors.fill: parent
                                            spacing: Theme.spacingS
                                            
                                            Text {
                                                text: modelData.device
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceText
                                                width: parent.width * 0.25
                                                elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Text {
                                                text: modelData.mount
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceText
                                                width: parent.width * 0.2
                                                elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Text {
                                                text: modelData.size
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceText
                                                width: parent.width * 0.15
                                                elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Text {
                                                text: modelData.used
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceText
                                                width: parent.width * 0.15
                                                elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Text {
                                                text: modelData.avail
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceText
                                                width: parent.width * 0.15
                                                elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Text {
                                                text: modelData.percent
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: {
                                                    const percent = parseInt(modelData.percent)
                                                    if (percent > 90) return Theme.error
                                                    if (percent > 75) return Theme.warning
                                                    return Theme.surfaceText
                                                }
                                                width: parent.width * 0.1
                                                elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Context menu for process actions
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
            color: Theme.popupBackground()
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
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
            const menuWidth = 180
            const menuHeight = menuColumn.implicitHeight + Theme.spacingS * 2
            
            const screenWidth = processContextMenuWindow.screen ? processContextMenuWindow.screen.width : 1920
            const screenHeight = processContextMenuWindow.screen ? processContextMenuWindow.screen.height : 1080
            
            let finalX = x
            let finalY = y
            
            if (x + menuWidth > screenWidth - 20) {
                finalX = x - menuWidth
            }
            
            if (y + menuHeight > screenHeight - 20) {
                finalY = y - menuHeight
            }
            
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
    
    // IPC Handler for process list events
    IpcHandler {
        target: "processlist"
        function open() {
            console.log("ProcessListWidget: IPC open() called")
            processListWidget.show()
            return "PROCESSLIST_OPEN_SUCCESS"
        }
        function close() {
            console.log("ProcessListWidget: IPC close() called")
            processListWidget.hide()
            return "PROCESSLIST_CLOSE_SUCCESS"
        }
        function toggle() {
            console.log("ProcessListWidget: IPC toggle() called")
            processListWidget.toggle()
            return "PROCESSLIST_TOGGLE_SUCCESS"
        }
    }
    
    function show() {
        processListWidget.isVisible = true
        ProcessMonitorService.updateSystemInfo()
        ProcessMonitorService.updateProcessList()
        SystemMonitorService.enableDetailedMonitoring(true)
        SystemMonitorService.updateSystemInfo()
    }
    
    function hide() {
        processListWidget.isVisible = false
        SystemMonitorService.enableDetailedMonitoring(false)
    }
    
    function toggle() {
        if (processListWidget.isVisible) {
            hide()
        } else {
            show()
        }
    }
    
    // Helper functions for formatting
    function formatNetworkSpeed(bytesPerSec) {
        if (bytesPerSec < 1024) {
            return bytesPerSec.toFixed(0) + " B/s"
        } else if (bytesPerSec < 1024 * 1024) {
            return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        } else if (bytesPerSec < 1024 * 1024 * 1024) {
            return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
        } else {
            return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(1) + " GB/s"
        }
    }
    
    function formatDiskSpeed(bytesPerSec) {
        if (bytesPerSec < 1024 * 1024) {
            return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        } else if (bytesPerSec < 1024 * 1024 * 1024) {
            return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
        } else {
            return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(1) + " GB/s"
        }
    }
}