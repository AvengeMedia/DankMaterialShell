import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import "../Common"
import "../Services"

PanelWindow {
    id: topBar
    
    // modelData contains the screen from Quickshell.screens
    property var modelData
    screen: modelData
    
    // Get the screen name (e.g., "DP-1", "DP-2")
    property string screenName: modelData.name
    
    anchors {
        top: true
        left: true
        right: true
    }
    
    implicitHeight: Theme.barHeight - 4
    color: "transparent"
        
        // Floating panel container with margins
        Item {
            anchors.fill: parent
            anchors.margins: 2
            anchors.topMargin: 6
            anchors.bottomMargin: 0
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            
            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadiusXLarge
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.75)
                
                // Material 3 elevation shadow
                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 4
                    radius: 16
                    samples: 33
                    color: Qt.rgba(0, 0, 0, 0.15)
                    transparentBorder: true
                }
                
                // Subtle border for definition
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    border.width: 1
                    radius: parent.radius
                }
                
                // Subtle surface tint overlay with animation
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(Theme.surfaceTint.r, Theme.surfaceTint.g, Theme.surfaceTint.b, 0.04)
                    radius: parent.radius
                    
                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.08
                            duration: Theme.extraLongDuration
                            easing.type: Theme.standardEasing
                        }
                        NumberAnimation {
                            to: 0.02
                            duration: Theme.extraLongDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }
            
            Item {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                anchors.topMargin: Theme.spacingXS
                anchors.bottomMargin: Theme.spacingXS
                
                Row {
                id: leftSection
                height: parent.height
                spacing: Theme.spacingL
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                
                Rectangle {
                    id: archLauncher
                    width: 40
                    height: 32
                    radius: Theme.cornerRadius
                    color: launcherArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.12) : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        anchors.centerIn: parent
                        text: root.osLogo || "apps"  // Use OS logo if detected, fallback to apps icon
                        font.family: root.osLogo ? "NerdFont" : Theme.iconFont
                        font.pixelSize: root.osLogo ? Theme.iconSize - 2 : Theme.iconSize - 2
                        font.weight: Theme.iconFontWeight
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    MouseArea {
                        id: launcherArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            appLauncher.toggle()
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
                
                Rectangle {
                    id: workspaceSwitcher
                    width: Math.max(120, workspaceRow.implicitWidth + Theme.spacingL * 2)
                    height: 32
                    radius: Theme.cornerRadiusLarge
                    color: Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    property int currentWorkspace: 1
                    property var workspaceList: []
                    
                    Process {
                        id: workspaceQuery
                        command: ["niri", "msg", "workspaces"]
                        running: true
                        
                        stdout: StdioCollector {
                            onStreamFinished: {
                                if (text && text.trim()) {
                                    workspaceSwitcher.parseWorkspaceOutput(text.trim())
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
                        
                        // Show workspaces for THIS screen only
                        if (topBar.screenName && outputWorkspaces[topBar.screenName]) {
                            workspaceList = outputWorkspaces[topBar.screenName]
                            
                            // Always track the active workspace for this display
                            // Parse all lines to find which workspace is active on this display
                            let thisDisplayActiveWorkspace = 1
                            let inThisOutput = false
                            
                            for (const line of lines) {
                                if (line.startsWith('Output "')) {
                                    const outputMatch = line.match(/Output "(.+)"/)
                                    inThisOutput = outputMatch && outputMatch[1] === topBar.screenName
                                    continue
                                }
                                
                                if (inThisOutput && line.trim() && line.match(/^\s*\*\s*(\d+)$/)) {
                                    const wsMatch = line.match(/^\s*\*\s*(\d+)$/)
                                    if (wsMatch) {
                                        thisDisplayActiveWorkspace = parseInt(wsMatch[1])
                                        break
                                    }
                                }
                            }
                            
                            currentWorkspace = thisDisplayActiveWorkspace
                            // console.log("Monitor", topBar.screenName, "active workspace:", thisDisplayActiveWorkspace)
                        } else {
                            // Fallback if screen name not found
                            workspaceList = [1, 2]
                            currentWorkspace = 1
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
                        spacing: Theme.spacingS
                        
                        Repeater {
                            model: workspaceSwitcher.workspaceList
                            
                            Rectangle {
                                property bool isActive: modelData === workspaceSwitcher.currentWorkspace
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
                                        // Set target workspace and focus monitor first
                                        console.log("Clicking workspace", modelData, "on monitor", topBar.screenName)
                                        workspaceSwitcher.targetWorkspace = modelData
                                        focusMonitorProcess.command = ["niri", "msg", "action", "focus-monitor", topBar.screenName]
                                        focusMonitorProcess.running = true
                                    }
                                }
                            }
                        }
                    }
                    
                    Process {
                        id: switchProcess
                        running: false
                        
                        onExited: {
                            // Update current workspace and refresh query
                            workspaceSwitcher.currentWorkspace = workspaceSwitcher.targetWorkspace
                            Qt.callLater(() => {
                                workspaceQuery.running = true
                            })
                        }
                    }
                    
                    Process {
                        id: focusMonitorProcess
                        running: false
                        
                        onExited: {
                            // After focusing the monitor, switch to the workspace
                            Qt.callLater(() => {
                                switchProcess.command = ["niri", "msg", "action", "focus-workspace", workspaceSwitcher.targetWorkspace.toString()]
                                switchProcess.running = true
                            })
                        }
                    }
                    
                    property int targetWorkspace: 1
                }
            }
            
            Rectangle {
                id: clockContainer
                width: {
                    let baseWidth = 200
                    if (root.hasActiveMedia) {
                        // Calculate width needed for media info + time/date + spacing + padding
                        let mediaWidth = 24 + Theme.spacingXS + mediaTitleText.implicitWidth + Theme.spacingM + 180
                        return Math.min(Math.max(mediaWidth, 300), parent.width - Theme.spacingL * 2)
                    } else if (root.weather.available) {
                        return Math.min(280, parent.width - Theme.spacingL * 2)
                    } else {
                        return Math.min(baseWidth, parent.width - Theme.spacingL * 2)
                    }
                }
                height: 32
                radius: Theme.cornerRadius
                color: clockMouseArea.containsMouse ? 
                       Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) :
                       Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                anchors.centerIn: parent
                
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
                
                property date currentDate: new Date()
                
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM
                    
                    // Media info or Weather info
                    Row {
                        spacing: Theme.spacingXS
                        visible: root.hasActiveMedia || root.weather.available
                        anchors.verticalCenter: parent.verticalCenter
                        
                        // Music icon when media is playing
                        Text {
                            text: "music_note"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize - 2
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.hasActiveMedia
                            
                            SequentialAnimation on scale {
                                running: root.activePlayer?.playbackState === MprisPlaybackState.Playing
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.1; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }
                        }
                        
                        // Song title when media is playing
                        Text {
                            id: mediaTitleText
                            text: root.activePlayer?.trackTitle || "Unknown Track"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.hasActiveMedia
                            width: Math.min(implicitWidth, clockContainer.width - 100)
                            elide: Text.ElideRight
                        }
                        
                        // Weather icon when no media but weather available
                        Text {
                            text: WeatherService.getWeatherIcon(root.weather.wCode)
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize - 2
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !root.hasActiveMedia && root.weather.available
                        }
                        
                        // Weather temp when no media but weather available
                        Text {
                            text: (root.useFahrenheit ? root.weather.tempF : root.weather.temp) + "°" + (root.useFahrenheit ? "F" : "C")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !root.hasActiveMedia && root.weather.available
                        }
                    }
                    
                    // Separator
                    Text {
                        text: "•"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.hasActiveMedia || root.weather.available
                    }
                    
                    // Time and date
                    Row {
                        spacing: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Text {
                            text: Qt.formatTime(clockContainer.currentDate, "h:mm AP")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: "•"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: Qt.formatDate(clockContainer.currentDate, "ddd d")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: {
                        clockContainer.currentDate = new Date()
                    }
                }
                
                MouseArea {
                    id: clockMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        root.calendarVisible = !root.calendarVisible
                    }
                }
            }
            
            Row {
                id: rightSection
                height: parent.height
                spacing: Theme.spacingXS
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                
                Rectangle {
                    width: Math.max(40, systemTrayRow.implicitWidth + Theme.spacingS * 2)
                    height: 32
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: systemTrayRow.children.length > 0
                    
                    Row {
                        id: systemTrayRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS
                        
                        Repeater {
                            model: SystemTray.items
                            delegate: Rectangle {
                                width: 24
                                height: 24
                                radius: Theme.cornerRadiusSmall
                                color: trayItemArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                                
                                property var trayItem: modelData
                                
                                Image {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    source: {
                                        let icon = trayItem?.icon || "";
                                        if (!icon) return "";
                                        
                                        if (icon.includes("?path=")) {
                                            const [name, path] = icon.split("?path=");
                                            const fileName = name.substring(name.lastIndexOf("/") + 1);
                                            return `file://${path}/${fileName}`;
                                        }
                                        return icon;
                                    }
                                    asynchronous: true
                                    smooth: true
                                    fillMode: Image.PreserveAspectFit
                                }
                                
                                MouseArea {
                                    id: trayItemArea
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: (mouse) => {
                                        if (!trayItem) return;
                                        
                                        if (mouse.button === Qt.LeftButton) {
                                            if (!trayItem.onlyMenu) {
                                                trayItem.activate()
                                            }
                                        } else if (mouse.button === Qt.RightButton) {
                                            if (trayItem.hasMenu) {
                                                console.log("Right-click detected, showing menu for:", trayItem.title || "Unknown")
                                                customTrayMenu.showMenu(mouse.x, mouse.y)
                                            } else {
                                                console.log("No menu available for:", trayItem.title || "Unknown")
                                            }
                                        }
                                    }
                                }
                                
                                // Custom Material 3 styled menu
                                QtObject {
                                    id: customTrayMenu
                                    
                                    property bool menuVisible: false
                                    
                                    function showMenu(x, y) {
                                        root.currentTrayMenu = customTrayMenu
                                        root.currentTrayItem = trayItem
                                        
                                        // Simple positioning: right side of screen, below the panel
                                        root.trayMenuX = rightSection.x + rightSection.width - 400 - Theme.spacingL
                                        root.trayMenuY = Theme.barHeight + Theme.spacingS
                                        
                                        console.log("Showing menu at:", root.trayMenuX, root.trayMenuY)
                                        menuVisible = true
                                        root.showTrayMenu = true
                                    }
                                    
                                    function hideMenu() {
                                        menuVisible = false
                                        root.showTrayMenu = false
                                        root.currentTrayMenu = null
                                        root.currentTrayItem = null
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
                }
                
                // Clipboard History Button
                Rectangle {
                    width: 40
                    height: 32
                    radius: Theme.cornerRadius
                    color: clipboardArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        anchors.centerIn: parent
                        text: "content_paste"  // Material icon for clipboard
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize - 6
                        font.weight: Theme.iconFontWeight
                        color: Theme.surfaceText
                    }
                    
                    MouseArea {
                        id: clipboardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            clipboardHistoryPopup.toggle()
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
                
                // Color Picker Button
                // Rectangle {
                //     width: 40
                //     height: 32
                //     radius: Theme.cornerRadius
                //     color: colorPickerArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
                //     anchors.verticalCenter: parent.verticalCenter
                    
                //     Text {
                //         anchors.centerIn: parent
                //         text: "colorize"  // Material icon for color picker
                //         font.family: Theme.iconFont
                //         font.pixelSize: Theme.iconSize - 6
                //         font.weight: Theme.iconFontWeight
                //         color: Theme.surfaceText
                //     }
                    
                //     MouseArea {
                //         id: colorPickerArea
                //         anchors.fill: parent
                //         hoverEnabled: true
                //         cursorShape: Qt.PointingHandCursor
                        
                //         onClicked: {
                //             ColorPickerService.pickColor()
                //         }
                //     }
                    
                //     Behavior on color {
                //         ColorAnimation {
                //             duration: Theme.shortDuration
                //             easing.type: Theme.standardEasing
                //         }
                //     }
                // }
                
                // Notification Center Button
                Rectangle {
                    width: 40
                    height: 32
                    radius: Theme.cornerRadius
                    color: notificationArea.containsMouse || root.notificationHistoryVisible ? 
                           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
                           Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    property bool hasUnread: notificationHistory.count > 0
                    
                    Text {
                        anchors.centerIn: parent
                        text: "notifications"  // Material icon for notifications
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize - 6
                        font.weight: Theme.iconFontWeight
                        color: notificationArea.containsMouse || root.notificationHistoryVisible ? 
                               Theme.primary : Theme.surfaceText
                    }
                    
                    // Notification dot indicator
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.error
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 6
                        anchors.topMargin: 6
                        visible: parent.hasUnread
                    }
                    
                    MouseArea {
                        id: notificationArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            root.notificationHistoryVisible = !root.notificationHistoryVisible
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
                
                // Battery Widget
                BatteryWidget {
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                // Control Center Indicators
                Rectangle {
                    width: Math.max(80, controlIndicators.implicitWidth + Theme.spacingS * 2)
                    height: 32
                    radius: Theme.cornerRadius
                    color: controlCenterArea.containsMouse || root.controlCenterVisible ? 
                           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
                           Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Row {
                        id: controlIndicators
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS
                        
                        // Network Status Icon
                        Text {
                            text: {
                                if (root.networkStatus === "ethernet") return "lan"
                                else if (root.networkStatus === "wifi") {
                                    switch (root.wifiSignalStrength) {
                                        case "excellent": return "wifi"
                                        case "good": return "wifi_2_bar"
                                        case "fair": return "wifi_1_bar"
                                        case "poor": return "wifi_calling_3"
                                        default: return "wifi"
                                    }
                                }
                                else return "wifi_off"
                            }
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize - 8
                            font.weight: Theme.iconFontWeight
                            color: root.networkStatus !== "disconnected" ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: true
                        }
                        
                        // Audio Icon
                        Text {
                            text: root.volumeLevel === 0 ? "volume_off" : 
                                  root.volumeLevel < 33 ? "volume_down" : "volume_up"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize - 8
                            font.weight: Theme.iconFontWeight
                            color: controlCenterArea.containsMouse || root.controlCenterVisible ? 
                                   Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        // Microphone Icon (when active)
                        Text {
                            text: "mic"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize - 8
                            font.weight: Theme.iconFontWeight
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            visible: false // TODO: Add mic detection
                        }
                        
                        // Bluetooth Icon (when available and enabled)
                        Text {
                            text: "bluetooth"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize - 8
                            font.weight: Theme.iconFontWeight
                            color: root.bluetoothEnabled ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.bluetoothAvailable && root.bluetoothEnabled
                        }
                    }
                    
                    MouseArea {
                        id: controlCenterArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            root.controlCenterVisible = !root.controlCenterVisible
                            if (root.controlCenterVisible) {
                                // Refresh data when opening control center
                                WifiService.scanWifi()
                                BluetoothService.scanDevices()
                                // Audio sink info is automatically refreshed by AudioService
                            }
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
                
                // Power Button
                PowerButton {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
