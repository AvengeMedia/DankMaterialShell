//@ pragma UseQApplication

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
import "Services"

ShellRoot {
    id: root
    
    property bool calendarVisible: false
    property bool showTrayMenu: false
    property real trayMenuX: 0
    property real trayMenuY: 0
    property var currentTrayMenu: null
    property var currentTrayItem: null
    property string osLogo: ""
    property string osName: ""
    property bool notificationHistoryVisible: false
    property var activeNotification: null
    property bool showNotificationPopup: false
    property bool mediaPlayerVisible: false
    property MprisPlayer activePlayer: MprisController.activePlayer
    property bool hasActiveMedia: activePlayer && (activePlayer.trackTitle || activePlayer.trackArtist)
    property bool controlCenterVisible: false
    property string networkStatus: "disconnected" // "ethernet", "wifi", "disconnected"
    property string wifiSignalStrength: "excellent" // "excellent", "good", "fair", "poor"
    property string currentWifiSSID: ""
    property bool bluetoothEnabled: false
    property bool bluetoothAvailable: false
    property bool wifiEnabled: true
    property bool wifiAvailable: false
    property string ethernetIP: ""
    property string wifiIP: ""
    property int volumeLevel: 50
    property int brightnessLevel: 75
    property var wifiNetworks: []
    property var savedWifiNetworks: []
    property var bluetoothDevices: []
    property var audioSinks: []
    property string currentAudioSink: ""
    property bool wifiPasswordDialogVisible: false
    property string wifiPasswordSSID: ""
    property string wifiPasswordInput: ""
    property string wifiConnectionStatus: "" // "connecting", "connected", "failed"
    property bool wifiAutoRefreshEnabled: false
    
    // Screen size breakpoints for responsive design
    property real screenWidth: Screen.width
    property bool isSmallScreen: screenWidth < 1200
    property bool isMediumScreen: screenWidth >= 1200 && screenWidth < 1600
    property bool isLargeScreen: screenWidth >= 1600
    
    // Weather data
    property var weather: ({
        available: false,
        temp: 0,
        tempF: 0,
        city: "",
        wCode: "113", 
        humidity: 0,
        wind: "",
        sunrise: "06:00",
        sunset: "18:00",
        uv: 0,
        pressure: 0
    })
    
    // Weather configuration
    property bool useFahrenheit: true  // Default to Fahrenheit
    
    // WiFi Auto-refresh Timer
    Timer {
        id: wifiAutoRefreshTimer
        interval: 10000  // 10 seconds
        running: root.wifiAutoRefreshEnabled && root.controlCenterVisible && root.currentTab === 0 && root.networkSubTab === 1
        repeat: true
        onTriggered: {
            wifiScanner.running = true
            savedWifiScanner.running = true
        }
    }
    
    // WiFi Connection Status Timer
    Timer {
        id: wifiConnectionStatusTimer
        interval: 3000  // 3 seconds
        running: false
        repeat: false
        onTriggered: {
            root.wifiConnectionStatus = ""
        }
    }

    // Material 3 theme system
    QtObject {
        id: theme
        
        property color primary: "#D0BCFF"
        property color primaryText: "#381E72"
        property color primaryContainer: "#4F378B"
        property color secondary: "#CCC2DC"
        property color surface: "#10121E"
        property color surfaceText: "#E6E0E9"
        property color surfaceVariant: "#49454F"
        property color surfaceVariantText: "#CAC4D0"
        property color surfaceTint: "#D0BCFF"
        property color background: "#10121E"
        property color backgroundText: "#E6E0E9"
        property color outline: "#938F99"
        property color surfaceContainer: "#1D1B20"
        property color surfaceContainerHigh: "#2B2930"
        property color archBlue: "#1793D1"
        property color success: "#4CAF50"
        property color warning: "#FF9800"
        property color info: "#2196F3"
        property color error: "#F2B8B5"
        
        property int shortDuration: 150
        property int mediumDuration: 300
        property int longDuration: 500
        property int extraLongDuration: 1000
        
        property int standardEasing: Easing.OutCubic
        property int emphasizedEasing: Easing.OutQuart
        
        property real cornerRadius: 12
        property real cornerRadiusSmall: 8
        property real cornerRadiusLarge: 16
        property real cornerRadiusXLarge: 24
        
        property real spacingXS: 4
        property real spacingS: 8
        property real spacingM: 12
        property real spacingL: 16
        property real spacingXL: 24
        
        property real fontSizeSmall: 12
        property real fontSizeMedium: 14
        property real fontSizeLarge: 16
        property real fontSizeXLarge: 20
        
        property real barHeight: 48
        property real iconSize: 24
        property real iconSizeSmall: 16
        property real iconSizeLarge: 32
        
        property real opacityDisabled: 0.38
        property real opacityMedium: 0.60
        property real opacityHigh: 0.87
        property real opacityFull: 1.0
        
        property string iconFont: "Material Symbols Rounded"
        property string iconFontFilled: "Material Symbols Rounded"
        property int iconFontWeight: Font.Normal
        property int iconFontFilledWeight: Font.Medium
    }
    
    // Weather icon mapping (based on wttr.in weather codes)
    property var weatherIcons: ({
        "113": "clear_day",
        "116": "partly_cloudy_day", 
        "119": "cloud",
        "122": "cloud",
        "143": "foggy",
        "176": "rainy",
        "179": "rainy",
        "182": "rainy",
        "185": "rainy",
        "200": "thunderstorm",
        "227": "cloudy_snowing",
        "230": "snowing_heavy",
        "248": "foggy",
        "260": "foggy",
        "263": "rainy",
        "266": "rainy",
        "281": "rainy",
        "284": "rainy",
        "293": "rainy",
        "296": "rainy",
        "299": "rainy",
        "302": "weather_hail",
        "305": "rainy",
        "308": "weather_hail",
        "311": "rainy",
        "314": "rainy",
        "317": "rainy",
        "320": "cloudy_snowing",
        "323": "cloudy_snowing",
        "326": "cloudy_snowing",
        "329": "snowing_heavy",
        "332": "snowing_heavy",
        "335": "snowing",
        "338": "snowing_heavy",
        "350": "rainy",
        "353": "rainy",
        "356": "rainy",
        "359": "weather_hail",
        "362": "rainy",
        "365": "rainy",
        "368": "cloudy_snowing",
        "371": "snowing",
        "374": "rainy",
        "377": "rainy",
        "386": "thunderstorm",
        "389": "thunderstorm",
        "392": "thunderstorm",
        "395": "snowing"
    })

    // Top bar - one instance per screen
    Variants {
        model: Quickshell.screens

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
            
            implicitHeight: theme.barHeight
            color: "transparent"
        
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(theme.surfaceContainer.r, theme.surfaceContainer.g, theme.surfaceContainer.b, 0.95)
            
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.12)
                border.width: 1
            }
            
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(theme.surfaceTint.r, theme.surfaceTint.g, theme.surfaceTint.b, 0.08)
                
                SequentialAnimation on opacity {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.12
                        duration: theme.extraLongDuration
                        easing.type: theme.standardEasing
                    }
                    NumberAnimation {
                        to: 0.06
                        duration: theme.extraLongDuration
                        easing.type: theme.standardEasing
                    }
                }
            }
        }
        
        Item {
            anchors.fill: parent
            anchors.leftMargin: theme.spacingL
            anchors.rightMargin: theme.spacingL
            
            Row {
                id: leftSection
                height: parent.height
                spacing: theme.spacingL
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                
                Rectangle {
                    id: archLauncher
                    width: Math.max(120, launcherRow.implicitWidth + theme.spacingM * 2)
                    height: 32
                    radius: theme.cornerRadius
                    color: launcherArea.containsMouse ? Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.12) : Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Row {
                        id: launcherRow
                        anchors.centerIn: parent
                        spacing: theme.spacingS
                        
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.osLogo || "apps"  // Use OS logo if detected, fallback to apps icon
                            font.family: root.osLogo ? "NerdFont" : theme.iconFont
                            font.pixelSize: root.osLogo ? theme.iconSize - 2 : theme.iconSize - 2
                            font.weight: theme.iconFontWeight
                            color: theme.surfaceText
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.isSmallScreen ? "Apps" : "Applications"
                            font.pixelSize: theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: theme.surfaceText
                            visible: !root.isSmallScreen || width > 60
                        }
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
                            duration: theme.shortDuration
                            easing.type: theme.standardEasing
                        }
                    }
                }
                
                Rectangle {
                    id: workspaceSwitcher
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
                            console.log("Monitor", topBar.screenName, "active workspace:", thisDisplayActiveWorkspace)
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
                        let mediaWidth = 24 + theme.spacingXS + mediaTitleText.implicitWidth + theme.spacingM + 180
                        return Math.min(Math.max(mediaWidth, 300), parent.width - theme.spacingL * 2)
                    } else if (root.weather.available) {
                        return Math.min(280, parent.width - theme.spacingL * 2)
                    } else {
                        return Math.min(baseWidth, parent.width - theme.spacingL * 2)
                    }
                }
                height: 32
                radius: theme.cornerRadius
                color: clockMouseArea.containsMouse ? 
                       Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) :
                       Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.08)
                anchors.centerIn: parent
                
                Behavior on color {
                    ColorAnimation {
                        duration: theme.shortDuration
                        easing.type: theme.standardEasing
                    }
                }
                
                property date currentDate: new Date()
                
                Row {
                    anchors.centerIn: parent
                    spacing: theme.spacingM
                    
                    // Media info or Weather info
                    Row {
                        spacing: theme.spacingXS
                        visible: root.hasActiveMedia || root.weather.available
                        anchors.verticalCenter: parent.verticalCenter
                        
                        // Music icon when media is playing
                        Text {
                            text: "music_note"
                            font.family: theme.iconFont
                            font.pixelSize: theme.iconSize - 2
                            color: theme.primary
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
                            font.pixelSize: theme.fontSizeMedium
                            color: theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.hasActiveMedia
                            width: Math.min(implicitWidth, clockContainer.width - 100)
                            elide: Text.ElideRight
                        }
                        
                        // Weather icon when no media but weather available
                        Text {
                            text: root.weatherIcons[root.weather.wCode] || "clear_day"
                            font.family: theme.iconFont
                            font.pixelSize: theme.iconSize - 2
                            color: theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !root.hasActiveMedia && root.weather.available
                        }
                        
                        // Weather temp when no media but weather available
                        Text {
                            text: (root.useFahrenheit ? root.weather.tempF : root.weather.temp) + "°" + (root.useFahrenheit ? "F" : "C")
                            font.pixelSize: theme.fontSizeMedium
                            color: theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !root.hasActiveMedia && root.weather.available
                        }
                    }
                    
                    // Separator
                    Text {
                        text: "•"
                        font.pixelSize: theme.fontSizeMedium
                        color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.5)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.hasActiveMedia || root.weather.available
                    }
                    
                    // Time and date
                    Row {
                        spacing: theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Text {
                            text: Qt.formatTime(clockContainer.currentDate, "h:mm AP")
                            font.pixelSize: theme.fontSizeMedium
                            color: theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: "•"
                            font.pixelSize: theme.fontSizeMedium
                            color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.5)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: Qt.formatDate(clockContainer.currentDate, "ddd d")
                            font.pixelSize: theme.fontSizeMedium
                            color: theme.surfaceText
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
                spacing: theme.spacingXS
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                
                Rectangle {
                    width: Math.max(40, systemTrayRow.implicitWidth + theme.spacingS * 2)
                    height: 32
                    radius: theme.cornerRadius
                    color: Qt.rgba(theme.secondary.r, theme.secondary.g, theme.secondary.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: systemTrayRow.children.length > 0
                    
                    Row {
                        id: systemTrayRow
                        anchors.centerIn: parent
                        spacing: theme.spacingXS
                        
                        Repeater {
                            model: SystemTray.items
                            delegate: Rectangle {
                                width: 24
                                height: 24
                                radius: theme.cornerRadiusSmall
                                color: trayItemArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : "transparent"
                                
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
                                        root.trayMenuX = rightSection.x + rightSection.width - 180 - theme.spacingL
                                        root.trayMenuY = theme.barHeight + theme.spacingS
                                        
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
                                        duration: theme.shortDuration
                                        easing.type: theme.standardEasing
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
                    radius: theme.cornerRadius
                    color: clipboardArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : Qt.rgba(theme.secondary.r, theme.secondary.g, theme.secondary.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        anchors.centerIn: parent
                        text: "content_paste"  // Material icon for clipboard
                        font.family: theme.iconFont
                        font.pixelSize: theme.iconSize - 6
                        font.weight: theme.iconFontWeight
                        color: theme.surfaceText
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
                            duration: theme.shortDuration
                            easing.type: theme.standardEasing
                        }
                    }
                }
                
                // Color Picker Button
                Rectangle {
                    width: 40
                    height: 32
                    radius: theme.cornerRadius
                    color: colorPickerArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : Qt.rgba(theme.secondary.r, theme.secondary.g, theme.secondary.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        anchors.centerIn: parent
                        text: "colorize"  // Material icon for color picker
                        font.family: theme.iconFont
                        font.pixelSize: theme.iconSize - 6
                        font.weight: theme.iconFontWeight
                        color: theme.surfaceText
                    }
                    
                    MouseArea {
                        id: colorPickerArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            colorPickerProcess.running = true
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: theme.shortDuration
                            easing.type: theme.standardEasing
                        }
                    }
                }
                
                // Notification Center Button
                Rectangle {
                    width: 40
                    height: 32
                    radius: theme.cornerRadius
                    color: notificationArea.containsMouse || root.notificationHistoryVisible ? 
                           Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16) : 
                           Qt.rgba(theme.secondary.r, theme.secondary.g, theme.secondary.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    property bool hasUnread: notificationHistory.count > 0
                    
                    Text {
                        anchors.centerIn: parent
                        text: "notifications"  // Material icon for notifications
                        font.family: theme.iconFont
                        font.pixelSize: theme.iconSize - 6
                        font.weight: theme.iconFontWeight
                        color: notificationArea.containsMouse || root.notificationHistoryVisible ? 
                               theme.primary : theme.surfaceText
                    }
                    
                    // Notification dot indicator
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: theme.error
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
                            duration: theme.shortDuration
                            easing.type: theme.standardEasing
                        }
                    }
                }
                
                // Control Center Indicators
                Rectangle {
                    width: Math.max(80, controlIndicators.implicitWidth + theme.spacingS * 2)
                    height: 32
                    radius: theme.cornerRadius
                    color: controlCenterArea.containsMouse || root.controlCenterVisible ? 
                           Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16) : 
                           Qt.rgba(theme.secondary.r, theme.secondary.g, theme.secondary.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Row {
                        id: controlIndicators
                        anchors.centerIn: parent
                        spacing: theme.spacingXS
                        
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
                            font.family: theme.iconFont
                            font.pixelSize: theme.iconSize - 8
                            font.weight: theme.iconFontWeight
                            color: root.networkStatus !== "disconnected" ? theme.primary : Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.5)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: true
                        }
                        
                        // Audio Icon
                        Text {
                            text: root.volumeLevel === 0 ? "volume_off" : 
                                  root.volumeLevel < 33 ? "volume_down" : "volume_up"
                            font.family: theme.iconFont
                            font.pixelSize: theme.iconSize - 8
                            font.weight: theme.iconFontWeight
                            color: controlCenterArea.containsMouse || root.controlCenterVisible ? 
                                   theme.primary : theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        // Microphone Icon (when active)
                        Text {
                            text: "mic"
                            font.family: theme.iconFont
                            font.pixelSize: theme.iconSize - 8
                            font.weight: theme.iconFontWeight
                            color: theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            visible: false // TODO: Add mic detection
                        }
                        
                        // Bluetooth Icon (when available and enabled)
                        Text {
                            text: "bluetooth"
                            font.family: theme.iconFont
                            font.pixelSize: theme.iconSize - 8
                            font.weight: theme.iconFontWeight
                            color: root.bluetoothEnabled ? theme.primary : Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.5)
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
                                wifiScanner.running = true
                                savedWifiScanner.running = true
                                bluetoothDeviceScanner.running = true
                                audioSinkLister.running = true
                            }
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: theme.shortDuration
                            easing.type: theme.standardEasing
                        }
                    }
                }
            }
        }
    }
    }  // End of Variants for topBar
    
    PanelWindow {
        id: calendarPopup
        
        visible: root.calendarVisible
        
        implicitWidth: 320
        implicitHeight: 400
        
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
        
        property date displayDate: new Date()
        property date selectedDate: new Date()
        
        Rectangle {
            width: 400
            height: root.hasActiveMedia ? 580 : (root.weather.available ? 480 : 400)
            x: (parent.width - width) / 2
            y: theme.barHeight + theme.spacingS
            color: theme.surfaceContainer
            radius: theme.cornerRadiusLarge
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.12)
            border.width: 1
            
            opacity: root.calendarVisible ? 1.0 : 0.0
            scale: root.calendarVisible ? 1.0 : 0.85
            
            Behavior on opacity {
                NumberAnimation {
                    duration: theme.mediumDuration
                    easing.type: theme.emphasizedEasing
                }
            }
            
            Behavior on scale {
                NumberAnimation {
                    duration: theme.mediumDuration
                    easing.type: theme.emphasizedEasing
                }
            }
            
            Column {
                anchors.fill: parent
                anchors.margins: theme.spacingL
                spacing: theme.spacingM
                
                // Media Player (when active)
                Rectangle {
                    visible: root.hasActiveMedia
                    width: parent.width
                    height: 180
                    radius: theme.cornerRadius
                    color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08)
                    border.color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.2)
                    border.width: 1
                    
                    Column {
                        anchors.fill: parent
                        anchors.margins: theme.spacingM
                        spacing: theme.spacingS
                        
                        Row {
                            width: parent.width
                            height: 100
                            spacing: theme.spacingM
                            
                            Rectangle {
                                width: 100
                                height: 100
                                radius: theme.cornerRadius
                                color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.3)
                                
                                Item {
                                    anchors.fill: parent
                                    clip: true
                                    
                                    Image {
                                        anchors.fill: parent
                                        source: root.activePlayer?.trackArtUrl || ""
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                    }
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        visible: parent.children[0].status !== Image.Ready
                                        color: "transparent"
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "album"
                                            font.family: theme.iconFont
                                            font.pixelSize: 48
                                            color: theme.surfaceVariantText
                                        }
                                    }
                                }
                            }
                            
                            Column {
                                width: parent.width - 100 - theme.spacingM
                                spacing: theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Text {
                                    text: root.activePlayer?.trackTitle || "Unknown Track"
                                    font.pixelSize: theme.fontSizeLarge
                                    font.weight: Font.Bold
                                    color: theme.surfaceText
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    text: root.activePlayer?.trackArtist || "Unknown Artist"
                                    font.pixelSize: theme.fontSizeMedium
                                    color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.8)
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    text: root.activePlayer?.trackAlbum || ""
                                    font.pixelSize: theme.fontSizeSmall
                                    color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.6)
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }
                            }
                        }
                        
                        // Progress bar
                        Rectangle {
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.3)
                            
                            Rectangle {
                                width: parent.width * (root.activePlayer?.position / Math.max(root.activePlayer?.length || 1, 1))
                                height: parent.height
                                radius: parent.radius
                                color: theme.primary
                                
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: (mouse) => {
                                    if (root.activePlayer && root.activePlayer.length > 0) {
                                        const ratio = mouse.x / width
                                        const newPosition = ratio * root.activePlayer.length
                                        console.log("Seeking to position:", newPosition, "ratio:", ratio, "canSeek:", root.activePlayer.canSeek)
                                        if (root.activePlayer.canSeek) {
                                            root.activePlayer.position = newPosition
                                        } else {
                                            console.log("Player does not support seeking")
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Control buttons
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: theme.spacingL
                            
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: prevBtnAreaCal.containsMouse ? Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.12) : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "skip_previous"
                                    font.family: theme.iconFont
                                    font.pixelSize: 20
                                    color: theme.surfaceText
                                }
                                
                                MouseArea {
                                    id: prevBtnAreaCal
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activePlayer?.previous()
                                }
                            }
                            
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                color: theme.primary
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: root.activePlayer?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                                    font.family: theme.iconFont
                                    font.pixelSize: 24
                                    color: theme.background
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activePlayer?.togglePlaying()
                                }
                            }
                            
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: nextBtnAreaCal.containsMouse ? Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.12) : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "skip_next"
                                    font.family: theme.iconFont
                                    font.pixelSize: 20
                                    color: theme.surfaceText
                                }
                                
                                MouseArea {
                                    id: nextBtnAreaCal
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activePlayer?.next()
                                }
                            }
                        }
                    }
                }
                
                // Weather header (when available and no media)
                Rectangle {
                    visible: root.weather.available && !root.hasActiveMedia
                    width: parent.width
                    height: 80
                    radius: theme.cornerRadius
                    color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08)
                    border.color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.2)
                    border.width: 1
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: theme.spacingL
                        
                        // Weather icon and temp
                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: root.weatherIcons[root.weather.wCode] || "clear_day"
                                font.family: theme.iconFont
                                font.pixelSize: theme.iconSize + 4
                                color: theme.primary
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            
                            Text {
                                text: (root.useFahrenheit ? root.weather.tempF : root.weather.temp) + "°" + (root.useFahrenheit ? "F" : "C")
                                font.pixelSize: theme.fontSizeLarge
                                color: theme.surfaceText
                                font.weight: Font.Bold
                                anchors.horizontalCenter: parent.horizontalCenter
                                
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.useFahrenheit = !root.useFahrenheit
                                }
                            }
                            
                            Text {
                                text: root.weather.city
                                font.pixelSize: theme.fontSizeSmall
                                color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                        
                        // Weather details grid
                        Grid {
                            columns: 2
                            spacing: theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Row {
                                spacing: theme.spacingXS
                                Text {
                                    text: "humidity_low"
                                    font.family: theme.iconFont
                                    font.pixelSize: theme.fontSizeSmall
                                    color: theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.weather.humidity + "%"
                                    font.pixelSize: theme.fontSizeSmall
                                    color: theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            Row {
                                spacing: theme.spacingXS
                                Text {
                                    text: "air"
                                    font.family: theme.iconFont
                                    font.pixelSize: theme.fontSizeSmall
                                    color: theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.weather.wind
                                    font.pixelSize: theme.fontSizeSmall
                                    color: theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            Row {
                                spacing: theme.spacingXS
                                Text {
                                    text: "wb_twilight"
                                    font.family: theme.iconFont
                                    font.pixelSize: theme.fontSizeSmall
                                    color: theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.weather.sunrise
                                    font.pixelSize: theme.fontSizeSmall
                                    color: theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            Row {
                                spacing: theme.spacingXS
                                Text {
                                    text: "bedtime"
                                    font.family: theme.iconFont
                                    font.pixelSize: theme.fontSizeSmall
                                    color: theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.weather.sunset
                                    font.pixelSize: theme.fontSizeSmall
                                    color: theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
                
                Row {
                    width: parent.width
                    height: 40
                    
                    Rectangle {
                        width: 40
                        height: 40
                        radius: theme.cornerRadius
                        color: prevMonthArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "chevron_left"
                            font.family: theme.iconFont
                            font.pixelSize: theme.iconSize
                            color: theme.primary
                            font.weight: theme.iconFontWeight
                        }
                        
                        MouseArea {
                            id: prevMonthArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                let newDate = new Date(calendarPopup.displayDate)
                                newDate.setMonth(newDate.getMonth() - 1)
                                calendarPopup.displayDate = newDate
                            }
                        }
                    }
                    
                    Text {
                        width: parent.width - 80
                        height: 40
                        text: Qt.formatDate(calendarPopup.displayDate, "MMMM yyyy")
                        font.pixelSize: theme.fontSizeLarge
                        color: theme.surfaceText
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    Rectangle {
                        width: 40
                        height: 40
                        radius: theme.cornerRadius
                        color: nextMonthArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "chevron_right"
                            font.family: theme.iconFont
                            font.pixelSize: theme.iconSize
                            color: theme.primary
                            font.weight: theme.iconFontWeight
                        }
                        
                        MouseArea {
                            id: nextMonthArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                let newDate = new Date(calendarPopup.displayDate)
                                newDate.setMonth(newDate.getMonth() + 1)
                                calendarPopup.displayDate = newDate
                            }
                        }
                    }
                }
                
                Row {
                    width: parent.width
                    height: 32
                    
                    Repeater {
                        model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                        
                        Rectangle {
                            width: parent.width / 7
                            height: 32
                            color: "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: theme.fontSizeSmall
                                color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.6)
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
                
                Grid {
                    width: parent.width
                    height: root.hasActiveMedia ? parent.height - 300 : (root.weather.available ? parent.height - 200 : parent.height - 120)
                    columns: 7
                    rows: 6
                    
                    property date firstDay: {
                        let date = new Date(calendarPopup.displayDate.getFullYear(), calendarPopup.displayDate.getMonth(), 1)
                        let dayOfWeek = date.getDay()
                        date.setDate(date.getDate() - dayOfWeek)
                        return date
                    }
                    
                    Repeater {
                        model: 42
                        
                        Rectangle {
                            width: parent.width / 7
                            height: parent.height / 6
                            
                            property date dayDate: {
                                let date = new Date(parent.firstDay)
                                date.setDate(date.getDate() + index)
                                return date
                            }
                            
                            property bool isCurrentMonth: dayDate.getMonth() === calendarPopup.displayDate.getMonth()
                            property bool isToday: dayDate.toDateString() === new Date().toDateString()
                            property bool isSelected: dayDate.toDateString() === calendarPopup.selectedDate.toDateString()
                            
                            color: isSelected ? theme.primary :
                                   isToday ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) :
                                   dayArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08) : "transparent"
                            
                            radius: theme.cornerRadiusSmall
                            
                            Text {
                                anchors.centerIn: parent
                                text: dayDate.getDate()
                                font.pixelSize: theme.fontSizeMedium
                                color: isSelected ? theme.surface :
                                       isToday ? theme.primary :
                                       isCurrentMonth ? theme.surfaceText : 
                                       Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.4)
                                font.weight: isToday || isSelected ? Font.Medium : Font.Normal
                            }
                            
                            MouseArea {
                                id: dayArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: {
                                    calendarPopup.selectedDate = dayDate
                                }
                            }
                        }
                    }
                }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                root.calendarVisible = false
            }
        }
    }
    
    // Custom Material 3 System Tray Menu
    PanelWindow {
        id: trayMenuPopup
        
        visible: root.showTrayMenu
        
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
        
        Rectangle {
            id: menuContainer
            x: root.trayMenuX
            y: root.trayMenuY
            width: 180
            height: Math.max(60, menuList.contentHeight + theme.spacingS * 2)
            color: theme.surfaceContainer
            radius: theme.cornerRadiusLarge
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.12)
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
            opacity: root.showTrayMenu ? 1.0 : 0.0
            scale: root.showTrayMenu ? 1.0 : 0.85
            
            Behavior on opacity {
                NumberAnimation {
                    duration: theme.mediumDuration
                    easing.type: theme.emphasizedEasing
                }
            }
            
            Behavior on scale {
                NumberAnimation {
                    duration: theme.mediumDuration
                    easing.type: theme.emphasizedEasing
                }
            }
            
            Item {
                anchors.fill: parent
                anchors.margins: theme.spacingS
                
                QsMenuOpener {
                    id: menuOpener
                    menu: root.currentTrayItem?.menu
                }
                
                // Custom menu styling using ListView
                ListView {
                    id: menuList
                    anchors.fill: parent
                    spacing: 1
                    model: ScriptModel {
                        values: menuOpener.children ? [...menuOpener.children.values].filter(item => {
                            // Filter out empty items and separators
                            return item && item.text && item.text.trim().length > 0 && !item.isSeparator
                        }) : []
                    }
                    
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: modelData.isSeparator ? 5 : 28
                        radius: modelData.isSeparator ? 0 : theme.cornerRadiusSmall
                        color: modelData.isSeparator ? "transparent" : 
                               (menuItemArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : "transparent")
                        
                        // Separator line
                        Rectangle {
                            visible: modelData.isSeparator
                            anchors.centerIn: parent
                            width: parent.width - theme.spacingS * 2
                            height: 1
                            color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.2)
                        }
                        
                        // Menu item content
                        Row {
                            visible: !modelData.isSeparator
                            anchors.left: parent.left
                            anchors.leftMargin: theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: theme.spacingXS
                            
                            Text {
                                text: modelData.text || ""
                                font.pixelSize: theme.fontSizeSmall
                                color: theme.surfaceText
                                font.weight: Font.Normal
                            }
                        }
                        
                        MouseArea {
                            id: menuItemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: modelData.isSeparator ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !modelData.isSeparator
                            
                            onClicked: {
                                if (modelData.triggered) {
                                    modelData.triggered()
                                }
                                root.showTrayMenu = false
                            }
                        }
                        
                        Behavior on color {
                            ColorAnimation {
                                duration: theme.shortDuration
                                easing.type: theme.standardEasing
                            }
                        }
                    }
                }
            }
        }
        
        // Click outside to close
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                root.showTrayMenu = false
            }
        }
    }
    
    // Notification Popup (using PanelWindow like reference)
    PanelWindow {
        id: notificationPopup
        
        visible: root.showNotificationPopup && root.activeNotification
        
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        
        color: "transparent"
        
        anchors {
            top: true
            right: true
            bottom: true
        }
        
        implicitWidth: 400
        
        Rectangle {
            id: popupContainer
            width: 380
            height: 100
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: theme.barHeight + 16
            anchors.rightMargin: 16
            
            color: theme.surfaceContainer
            radius: theme.cornerRadiusLarge
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.2)
            border.width: 1
            
            opacity: root.showNotificationPopup ? 1.0 : 0.0
            
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: hideNotificationPopup()
            }
            
            // Close button with cursor pointer
            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                text: "×"
                font.pixelSize: 16
                color: theme.surfaceText
                
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: hideNotificationPopup()
                }
            }
            
            // Content layout
            Row {
                anchors.fill: parent
                anchors.margins: 12
                anchors.rightMargin: 32
                spacing: 12
                
                // Notification icon using reference pattern
                Rectangle {
                    width: 40
                    height: 40
                    radius: 8
                    color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.1)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    // Fallback material icon when no app icon
                    Loader {
                        active: !root.activeNotification || root.activeNotification.appIcon === ""
                        anchors.fill: parent
                        sourceComponent: Text {
                            anchors.centerIn: parent
                            text: "notifications"
                            font.family: theme.iconFont
                            font.pixelSize: 20
                            color: theme.primary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    // App icon when no notification image
                    Loader {
                        active: root.activeNotification && root.activeNotification.appIcon !== "" && (root.activeNotification.image === "" || !root.activeNotification.image)
                        anchors.fill: parent
                        anchors.margins: 4
                        sourceComponent: IconImage {
                            anchors.fill: parent
                            asynchronous: true
                            source: {
                                if (!root.activeNotification) return ""
                                let iconPath = root.activeNotification.appIcon
                                // Skip file:// URLs as they're usually screenshots/images, not icons
                                if (iconPath && iconPath.startsWith("file://")) return ""
                                return iconPath ? Quickshell.iconPath(iconPath, "image-missing") : ""
                            }
                        }
                    }
                    
                    // Notification image with rounded corners
                    Loader {
                        active: root.activeNotification && root.activeNotification.image !== ""
                        anchors.fill: parent
                        sourceComponent: Item {
                            anchors.fill: parent
                            Image {
                                id: notifImage
                                anchors.fill: parent
                                source: root.activeNotification ? root.activeNotification.image : ""
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                                antialiasing: true
                                asynchronous: true
                                
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: notifImage.width
                                        height: notifImage.height
                                        radius: 8
                                    }
                                }
                            }
                            
                            // Small app icon overlay when showing notification image
                            Loader {
                                active: root.activeNotification && root.activeNotification.appIcon !== ""
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 2
                                sourceComponent: IconImage {
                                    width: 16
                                    height: 16
                                    asynchronous: true
                                    source: root.activeNotification ? Quickshell.iconPath(root.activeNotification.appIcon, "image-missing") : ""
                                }
                            }
                        }
                    }
                }
                
                // Text content
                Column {
                    width: parent.width - 52
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    
                    Text {
                        text: root.activeNotification ? (root.activeNotification.summary || "") : ""
                        font.pixelSize: 14
                        color: theme.surfaceText
                        font.weight: Font.Medium
                        width: parent.width
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                    
                    Text {
                        text: root.activeNotification ? (root.activeNotification.body || "") : ""
                        font.pixelSize: 12
                        color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                        width: parent.width
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }
            }
        }
    }
    
    // Auto-hide notification popup timer
    Timer {
        id: notificationTimer
        interval: 5000  // 5 seconds
        repeat: false
        onTriggered: hideNotificationPopup()
    }
    
    // Timer for clearing active notification after animation
    Timer {
        id: clearNotificationTimer
        interval: theme.mediumDuration + 50
        repeat: false
        onTriggered: root.activeNotification = null
    }
    
    function showNotificationPopup(notification) {
        root.activeNotification = notification
        root.showNotificationPopup = true
        notificationTimer.restart()
    }
    
    function hideNotificationPopup() {
        root.showNotificationPopup = false
        notificationTimer.stop()
        clearNotificationTimer.restart()
    }
    
    // Notification History Panel
    PanelWindow {
        id: notificationHistoryPopup
        
        visible: root.notificationHistoryVisible
        
        implicitWidth: 400
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
        
        Rectangle {
            width: 400
            height: 500
            x: parent.width - width - theme.spacingL
            y: theme.barHeight + theme.spacingS
            color: theme.surfaceContainer
            radius: theme.cornerRadiusLarge
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.12)
            border.width: 1
            
            opacity: root.notificationHistoryVisible ? 1.0 : 0.0
            scale: root.notificationHistoryVisible ? 1.0 : 0.85
            
            Behavior on opacity {
                NumberAnimation {
                    duration: theme.mediumDuration
                    easing.type: theme.emphasizedEasing
                }
            }
            
            Behavior on scale {
                NumberAnimation {
                    duration: theme.mediumDuration
                    easing.type: theme.emphasizedEasing
                }
            }
            
            Column {
                anchors.fill: parent
                anchors.margins: theme.spacingL
                spacing: theme.spacingM
                
                // Header
                Column {
                    width: parent.width
                    spacing: theme.spacingM
                    
                    Row {
                        width: parent.width
                        height: 32
                        
                        Text {
                            text: "Notifications"
                            font.pixelSize: theme.fontSizeLarge
                            color: theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Item { width: parent.width - 200; height: 1 }
                    }
                    
                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: theme.cornerRadius
                        color: clearArea.containsMouse ? Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.16) : Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.12)
                        border.color: Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.5)
                        border.width: 1
                        visible: notificationHistory.count > 0
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: theme.spacingS
                            
                            Text {
                                text: "delete_sweep"
                                font.family: theme.iconFont
                                font.pixelSize: theme.iconSizeSmall + 2
                                color: theme.error
                                font.weight: theme.iconFontWeight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Text {
                                text: "Clear All Notifications"
                                font.pixelSize: theme.fontSizeMedium
                                color: theme.error
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        
                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                notificationHistory.clear()
                            }
                        }
                        
                        Behavior on color {
                            ColorAnimation {
                                duration: theme.shortDuration
                                easing.type: theme.standardEasing
                            }
                        }
                        
                        Behavior on border.color {
                            ColorAnimation {
                                duration: theme.shortDuration
                                easing.type: theme.standardEasing
                            }
                        }
                    }
                }
                
                // Notification List
                ScrollView {
                    width: parent.width
                    height: parent.height - 120
                    clip: true
                    
                    ListView {
                        id: notificationListView
                        model: notificationHistory
                        spacing: theme.spacingS
                        
                        delegate: Rectangle {
                            width: notificationListView.width
                            height: 80
                            radius: theme.cornerRadius
                            color: notifArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08) : Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.08)
                            
                            Row {
                                anchors.fill: parent
                                anchors.margins: theme.spacingM
                                spacing: theme.spacingM
                                
                                // Notification icon using reference pattern
                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: theme.cornerRadius
                                    color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12)
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    // Fallback material icon when no app icon
                                    Loader {
                                        active: !model.appIcon || model.appIcon === ""
                                        anchors.fill: parent
                                        sourceComponent: Text {
                                            anchors.centerIn: parent
                                            text: model.appName ? model.appName.charAt(0).toUpperCase() : "notifications"
                                            font.family: model.appName ? "Roboto" : theme.iconFont
                                            font.pixelSize: model.appName ? theme.fontSizeMedium : 16
                                            color: theme.primary
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    
                                    // App icon when no notification image
                                    Loader {
                                        active: model.appIcon && model.appIcon !== "" && (!model.image || model.image === "")
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        sourceComponent: IconImage {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            asynchronous: true
                                            source: {
                                                if (!model.appIcon) return ""
                                                // Skip file:// URLs as they're usually screenshots/images, not icons
                                                if (model.appIcon.startsWith("file://")) return ""
                                                return Quickshell.iconPath(model.appIcon, "image-missing")
                                            }
                                        }
                                    }
                                    
                                    // Notification image with rounded corners
                                    Loader {
                                        active: model.image && model.image !== ""
                                        anchors.fill: parent
                                        sourceComponent: Item {
                                            anchors.fill: parent
                                            Image {
                                                id: historyNotifImage
                                                anchors.fill: parent
                                                source: model.image || ""
                                                fillMode: Image.PreserveAspectCrop
                                                cache: false
                                                antialiasing: true
                                                asynchronous: true
                                                
                                                layer.enabled: true
                                                layer.effect: OpacityMask {
                                                    maskSource: Rectangle {
                                                        width: historyNotifImage.width
                                                        height: historyNotifImage.height
                                                        radius: theme.cornerRadius
                                                    }
                                                }
                                            }
                                            
                                            // Small app icon overlay when showing notification image
                                            Loader {
                                                active: model.appIcon && model.appIcon !== ""
                                                anchors.bottom: parent.bottom
                                                anchors.right: parent.right
                                                anchors.margins: 2
                                                sourceComponent: IconImage {
                                                    width: 12
                                                    height: 12
                                                    asynchronous: true
                                                    source: model.appIcon ? Quickshell.iconPath(model.appIcon, "image-missing") : ""
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Content
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 80
                                    spacing: theme.spacingXS
                                    
                                    Text {
                                        text: model.appName || "App"
                                        font.pixelSize: theme.fontSizeSmall
                                        color: theme.primary
                                        font.weight: Font.Medium
                                    }
                                    
                                    Text {
                                        text: model.summary || ""
                                        font.pixelSize: theme.fontSizeMedium
                                        color: theme.surfaceText
                                        font.weight: Font.Medium
                                        width: parent.width
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                    }
                                    
                                    Text {
                                        text: model.body || ""
                                        font.pixelSize: theme.fontSizeSmall
                                        color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                    }
                                }
                            }
                            
                            MouseArea {
                                id: notifArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: {
                                    notificationHistory.remove(index)
                                }
                            }
                            
                            Behavior on color {
                                ColorAnimation {
                                    duration: theme.shortDuration
                                    easing.type: theme.standardEasing
                                }
                            }
                        }
                    }
                    
                    // Empty state - properly centered
                    Rectangle {
                        anchors.fill: parent
                        visible: notificationHistory.count === 0
                        color: "transparent"
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: theme.spacingM
                            width: parent.width * 0.8
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "notifications_none"
                                font.family: theme.iconFont
                                font.pixelSize: theme.iconSizeLarge + 16
                                color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.3)
                                font.weight: theme.iconFontWeight
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "No notifications"
                                font.pixelSize: theme.fontSizeLarge
                                color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.6)
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Notifications will appear here"
                                font.pixelSize: theme.fontSizeMedium
                                color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.4)
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }
                }
            }
        }
        
        // Click outside to close
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                root.notificationHistoryVisible = false
            }
        }
    }
    
    AppLauncher {
        id: appLauncher
        theme: root.theme
    }
    
    ClipboardHistory {
        id: clipboardHistoryPopup
        theme: root.theme
    }
    
    // Control Center Popup
    PanelWindow {
        id: controlCenterPopup
        
        visible: root.controlCenterVisible
        
        implicitWidth: 600
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
        
        property int currentTab: 0 // 0: Network, 1: Audio, 2: Bluetooth, 3: Display
        property int networkSubTab: 0 // 0: Ethernet, 1: WiFi
        
        Rectangle {
            width: Math.min(600, parent.width - theme.spacingL * 2)
            height: Math.min(500, parent.height - theme.barHeight - theme.spacingS * 2)
            x: Math.max(theme.spacingL, parent.width - width - theme.spacingL)
            y: theme.barHeight + theme.spacingS
            color: theme.surfaceContainer
            radius: theme.cornerRadiusLarge
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.12)
            border.width: 1
            
            opacity: root.controlCenterVisible ? 1.0 : 0.0
            scale: root.controlCenterVisible ? 1.0 : 0.85
            
            Behavior on opacity {
                NumberAnimation {
                    duration: theme.mediumDuration
                    easing.type: theme.emphasizedEasing
                }
            }
            
            Behavior on scale {
                NumberAnimation {
                    duration: theme.mediumDuration
                    easing.type: theme.emphasizedEasing
                }
            }
            
            Column {
                anchors.fill: parent
                anchors.margins: theme.spacingL
                spacing: theme.spacingM
                
                // Header with tabs
                Column {
                    width: parent.width
                    spacing: theme.spacingM
                    
                    Row {
                        width: parent.width
                        height: 32
                        
                        Text {
                            text: "Control Center"
                            font.pixelSize: theme.fontSizeLarge
                            color: theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Item { width: parent.width - 200; height: 1 }
                    }
                    
                    // Tab buttons
                    Row {
                        width: parent.width
                        spacing: theme.spacingXS
                        
                        Repeater {
                            model: {
                                let tabs = [
                                    {name: "Network", icon: "wifi", id: "network", available: true}
                                ]
                                
                                // Always show audio
                                tabs.push({name: "Audio", icon: "volume_up", id: "audio", available: true})
                                
                                // Show Bluetooth only if available
                                if (root.bluetoothAvailable) {
                                    tabs.push({name: "Bluetooth", icon: "bluetooth", id: "bluetooth", available: true})
                                }
                                
                                // Always show display
                                tabs.push({name: "Display", icon: "brightness_6", id: "display", available: true})
                                
                                return tabs
                            }
                            
                            Rectangle {
                                property int tabCount: {
                                    let count = 3 // Network + Audio + Display (always visible)
                                    if (root.bluetoothAvailable) count++
                                    return count
                                }
                                width: (parent.width - theme.spacingXS * (tabCount - 1)) / tabCount
                                height: 40
                                radius: theme.cornerRadius
                                color: controlCenterPopup.currentTab === index ? 
                                       Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16) : 
                                       tabArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08) : "transparent"
                                
                                Row {
                                    anchors.centerIn: parent
                                    spacing: theme.spacingXS
                                    
                                    Text {
                                        text: modelData.icon
                                        font.family: theme.iconFont
                                        font.pixelSize: theme.iconSize - 4
                                        color: controlCenterPopup.currentTab === index ? theme.primary : theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Text {
                                        text: modelData.name
                                        font.pixelSize: theme.fontSizeSmall
                                        color: controlCenterPopup.currentTab === index ? theme.primary : theme.surfaceText
                                        font.weight: controlCenterPopup.currentTab === index ? Font.Medium : Font.Normal
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                MouseArea {
                                    id: tabArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: {
                                        controlCenterPopup.currentTab = index
                                    }
                                }
                                
                                Behavior on color {
                                    ColorAnimation {
                                        duration: theme.shortDuration
                                        easing.type: theme.standardEasing
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Tab content area
                Rectangle {
                    width: parent.width
                    height: parent.height - 120
                    radius: theme.cornerRadius
                    color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.08)
                    
                    // Network Tab
                    Item {
                        anchors.fill: parent
                        anchors.margins: theme.spacingM
                        visible: controlCenterPopup.currentTab === 0
                        
                        Column {
                            anchors.fill: parent
                            spacing: theme.spacingM
                            
                            // Network sub-tabs
                            Row {
                                width: parent.width
                                spacing: theme.spacingXS
                                
                                Rectangle {
                                    width: (parent.width - theme.spacingXS) / 2
                                    height: 36
                                    radius: theme.cornerRadiusSmall
                                    color: controlCenterPopup.networkSubTab === 0 ? 
                                           Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16) : 
                                           ethernetTabArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08) : "transparent"
                                    
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: theme.spacingXS
                                        
                                        Text {
                                            text: "lan"
                                            font.family: theme.iconFont
                                            font.pixelSize: theme.iconSize - 4
                                            color: controlCenterPopup.networkSubTab === 0 ? theme.primary : theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        
                                        Text {
                                            text: "Ethernet"
                                            font.pixelSize: theme.fontSizeMedium
                                            color: controlCenterPopup.networkSubTab === 0 ? theme.primary : theme.surfaceText
                                            font.weight: controlCenterPopup.networkSubTab === 0 ? Font.Medium : Font.Normal
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: ethernetTabArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            controlCenterPopup.networkSubTab = 0
                                            // Disable auto-refresh when switching to ethernet tab
                                            root.wifiAutoRefreshEnabled = false
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    width: (parent.width - theme.spacingXS) / 2
                                    height: 36
                                    radius: theme.cornerRadiusSmall
                                    color: controlCenterPopup.networkSubTab === 1 ? 
                                           Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16) : 
                                           wifiTabArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08) : "transparent"
                                    
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: theme.spacingXS
                                        
                                        Text {
                                            text: root.wifiEnabled ? "wifi" : "wifi_off"
                                            font.family: theme.iconFont
                                            font.pixelSize: theme.iconSize - 4
                                            color: controlCenterPopup.networkSubTab === 1 ? theme.primary : theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        
                                        Text {
                                            text: "Wi-Fi"
                                            font.pixelSize: theme.fontSizeMedium
                                            color: controlCenterPopup.networkSubTab === 1 ? theme.primary : theme.surfaceText
                                            font.weight: controlCenterPopup.networkSubTab === 1 ? Font.Medium : Font.Normal
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: wifiTabArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            controlCenterPopup.networkSubTab = 1
                                            // Enable auto-refresh and scan for WiFi networks when switching to WiFi tab
                                            root.wifiAutoRefreshEnabled = true
                                            wifiScanner.running = true
                                            savedWifiScanner.running = true
                                        }
                                    }
                                }
                            }
                            
                            // Ethernet Tab Content
                            ScrollView {
                                width: parent.width
                                height: parent.height - 48
                                visible: controlCenterPopup.networkSubTab === 0
                                clip: true
                                
                                Column {
                                    width: parent.width
                                    spacing: theme.spacingL
                                    
                                    // Ethernet status card
                                    Rectangle {
                                        width: parent.width
                                        height: 100
                                        radius: theme.cornerRadius
                                        color: Qt.rgba(theme.surfaceContainer.r, theme.surfaceContainer.g, theme.surfaceContainer.b, 0.5)
                                        border.color: root.networkStatus === "ethernet" ? theme.primary : Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.12)
                                        border.width: root.networkStatus === "ethernet" ? 2 : 1
                                        
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: theme.spacingS
                                            
                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: theme.spacingM
                                                
                                                Text {
                                                    text: "lan"
                                                    font.family: theme.iconFont
                                                    font.pixelSize: theme.iconSizeLarge
                                                    color: root.networkStatus === "ethernet" ? theme.primary : theme.surfaceText
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                
                                                Column {
                                                    spacing: 2
                                                    
                                                    Text {
                                                        text: "Ethernet"
                                                        font.pixelSize: theme.fontSizeLarge
                                                        color: root.networkStatus === "ethernet" ? theme.primary : theme.surfaceText
                                                        font.weight: Font.Medium
                                                    }
                                                    
                                                    Text {
                                                        text: root.networkStatus === "ethernet" ? "Connected" : "Disconnected"
                                                        font.pixelSize: theme.fontSizeMedium
                                                        color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Ethernet control button
                                    Rectangle {
                                        width: parent.width
                                        height: 50
                                        radius: theme.cornerRadius
                                        color: ethernetControlArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08) : Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.08)
                                        
                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: theme.spacingM
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: theme.spacingM
                                            
                                            Text {
                                                text: root.networkStatus === "ethernet" ? "link_off" : "link"
                                                font.family: theme.iconFont
                                                font.pixelSize: theme.iconSize
                                                color: root.networkStatus === "ethernet" ? theme.error : theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Text {
                                                text: root.networkStatus === "ethernet" ? "Disconnect Ethernet" : "Connect Ethernet"
                                                font.pixelSize: theme.fontSizeMedium
                                                color: theme.surfaceText
                                                font.weight: Font.Medium
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: ethernetControlArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                toggleNetworkConnection("ethernet")
                                            }
                                        }
                                    }
                                    
                                    // Ethernet details
                                    Column {
                                        width: parent.width
                                        spacing: theme.spacingM
                                        visible: root.networkStatus === "ethernet"
                                        
                                        Text {
                                            text: "Connection Details"
                                            font.pixelSize: theme.fontSizeLarge
                                            color: theme.surfaceText
                                            font.weight: Font.Medium
                                        }
                                        
                                        Rectangle {
                                            width: parent.width
                                            height: 50
                                            radius: theme.cornerRadiusSmall
                                            color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.08)
                                            
                                            Row {
                                                anchors.left: parent.left
                                                anchors.leftMargin: theme.spacingM
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: theme.spacingM
                                                
                                                Text {
                                                    text: "language"
                                                    font.family: theme.iconFont
                                                    font.pixelSize: theme.iconSize
                                                    color: theme.surfaceText
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                
                                                Column {
                                                    spacing: 2
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    
                                                    Text {
                                                        text: "IP Address"
                                                        font.pixelSize: theme.fontSizeMedium
                                                        color: theme.surfaceText
                                                        font.weight: Font.Medium
                                                    }
                                                    
                                                    Text {
                                                        text: root.ethernetIP || "192.168.1.100"
                                                        font.pixelSize: theme.fontSizeSmall
                                                        color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // WiFi Tab Content
                            ScrollView {
                                width: parent.width
                                height: parent.height - 48
                                visible: controlCenterPopup.networkSubTab === 1
                                clip: true
                                
                                Column {
                                    width: parent.width
                                    spacing: theme.spacingL
                                    
                                    // WiFi toggle control (only show if WiFi hardware is available)
                                    Rectangle {
                                        width: parent.width
                                        height: 50
                                        radius: theme.cornerRadius
                                        color: wifiToggleArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08) : Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.08)
                                        visible: root.wifiAvailable
                                        
                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: theme.spacingM
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: theme.spacingM
                                            
                                            Text {
                                                text: "power_settings_new"
                                                font.family: theme.iconFont
                                                font.pixelSize: theme.iconSize
                                                color: root.wifiEnabled ? theme.primary : Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.5)
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Text {
                                                text: root.wifiEnabled ? "Turn WiFi Off" : "Turn WiFi On"
                                                font.pixelSize: theme.fontSizeMedium
                                                color: theme.surfaceText
                                                font.weight: Font.Medium
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: wifiToggleArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                toggleWifiRadio()
                                            }
                                        }
                                    }
                                    
                                    // Current WiFi connection (if connected)
                                    Rectangle {
                                        width: parent.width
                                        height: 80
                                        radius: theme.cornerRadius
                                        color: Qt.rgba(theme.surfaceContainer.r, theme.surfaceContainer.g, theme.surfaceContainer.b, 0.5)
                                        border.color: root.networkStatus === "wifi" ? theme.primary : Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.12)
                                        border.width: root.networkStatus === "wifi" ? 2 : 1
                                        visible: root.wifiAvailable && root.wifiEnabled
                                        
                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: theme.spacingL
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: theme.spacingM
                                            
                                            Text {
                                                text: root.networkStatus === "wifi" ? 
                                                    (root.wifiSignalStrength === "excellent" ? "wifi" :
                                                     root.wifiSignalStrength === "good" ? "wifi_2_bar" :
                                                     root.wifiSignalStrength === "fair" ? "wifi_1_bar" :
                                                     root.wifiSignalStrength === "poor" ? "wifi_calling_3" : "wifi") : "wifi"
                                                font.family: theme.iconFont
                                                font.pixelSize: theme.iconSizeLarge
                                                color: root.networkStatus === "wifi" ? theme.primary : theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Column {
                                                spacing: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                
                                                Text {
                                                    text: root.networkStatus === "wifi" ? (root.currentWifiSSID || "Connected") : "Not Connected"
                                                    font.pixelSize: theme.fontSizeLarge
                                                    color: root.networkStatus === "wifi" ? theme.primary : theme.surfaceText
                                                    font.weight: Font.Medium
                                                }
                                                
                                                Text {
                                                    text: root.networkStatus === "wifi" ? (root.wifiIP || "Connected") : "Select a network below"
                                                    font.pixelSize: theme.fontSizeSmall
                                                    color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Available WiFi Networks
                                    Column {
                                        width: parent.width
                                        spacing: theme.spacingM
                                        visible: root.wifiEnabled
                                        
                                        Row {
                                            width: parent.width
                                            
                                            Text {
                                                text: "Available Networks"
                                                font.pixelSize: theme.fontSizeLarge
                                                color: theme.surfaceText
                                                font.weight: Font.Medium
                                            }
                                            
                                            Item { width: parent.width - 200; height: 1 }
                                            
                                            Rectangle {
                                                width: 32
                                                height: 32
                                                radius: 16
                                                color: refreshArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : "transparent"
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "refresh"
                                                    font.family: theme.iconFont
                                                    font.pixelSize: theme.iconSize - 4
                                                    color: theme.surfaceText
                                                }
                                                
                                                MouseArea {
                                                    id: refreshArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        wifiScanner.running = true
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Connection status indicator
                                        Rectangle {
                                            width: parent.width
                                            height: 40
                                            radius: theme.cornerRadius
                                            color: {
                                                if (root.wifiConnectionStatus === "connecting") {
                                                    return Qt.rgba(theme.warning.r, theme.warning.g, theme.warning.b, 0.12)
                                                } else if (root.wifiConnectionStatus === "failed") {
                                                    return Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.12)
                                                } else if (root.wifiConnectionStatus === "connected") {
                                                    return Qt.rgba(theme.success.r, theme.success.g, theme.success.b, 0.12)
                                                }
                                                return "transparent"
                                            }
                                            border.color: {
                                                if (root.wifiConnectionStatus === "connecting") {
                                                    return Qt.rgba(theme.warning.r, theme.warning.g, theme.warning.b, 0.3)
                                                } else if (root.wifiConnectionStatus === "failed") {
                                                    return Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.3)
                                                } else if (root.wifiConnectionStatus === "connected") {
                                                    return Qt.rgba(theme.success.r, theme.success.g, theme.success.b, 0.3)
                                                }
                                                return "transparent"
                                            }
                                            border.width: root.wifiConnectionStatus !== "" ? 1 : 0
                                            visible: root.wifiConnectionStatus !== ""
                                            
                                            Row {
                                                anchors.centerIn: parent
                                                spacing: theme.spacingS
                                                
                                                Text {
                                                    text: {
                                                        if (root.wifiConnectionStatus === "connecting") return "sync"
                                                        if (root.wifiConnectionStatus === "failed") return "error"
                                                        if (root.wifiConnectionStatus === "connected") return "check_circle"
                                                        return ""
                                                    }
                                                    font.family: theme.iconFont
                                                    font.pixelSize: theme.iconSize - 6
                                                    color: {
                                                        if (root.wifiConnectionStatus === "connecting") return theme.warning
                                                        if (root.wifiConnectionStatus === "failed") return theme.error
                                                        if (root.wifiConnectionStatus === "connected") return theme.success
                                                        return theme.surfaceText
                                                    }
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    
                                                    RotationAnimation {
                                                        target: parent
                                                        running: root.wifiConnectionStatus === "connecting"
                                                        from: 0
                                                        to: 360
                                                        duration: 1000
                                                        loops: Animation.Infinite
                                                    }
                                                }
                                                
                                                Text {
                                                    text: {
                                                        if (root.wifiConnectionStatus === "connecting") return "Connecting to " + root.wifiPasswordSSID
                                                        if (root.wifiConnectionStatus === "failed") return "Failed to connect to " + root.wifiPasswordSSID
                                                        if (root.wifiConnectionStatus === "connected") return "Connected to " + root.wifiPasswordSSID
                                                        return ""
                                                    }
                                                    font.pixelSize: theme.fontSizeMedium
                                                    color: {
                                                        if (root.wifiConnectionStatus === "connecting") return theme.warning
                                                        if (root.wifiConnectionStatus === "failed") return theme.error
                                                        if (root.wifiConnectionStatus === "connected") return theme.success
                                                        return theme.surfaceText
                                                    }
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                            
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: theme.shortDuration
                                                    easing.type: theme.standardEasing
                                                }
                                            }
                                        }
                                        
                                        // WiFi networks list (only show if WiFi is available and enabled)
                                        Repeater {
                                            model: root.wifiAvailable && root.wifiEnabled ? root.wifiNetworks : []
                                            
                                            Rectangle {
                                                width: parent.width
                                                height: 50
                                                radius: theme.cornerRadiusSmall
                                                color: networkArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08) : 
                                                       modelData.connected ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : "transparent"
                                                border.color: modelData.connected ? theme.primary : "transparent"
                                                border.width: modelData.connected ? 1 : 0
                                                
                                                Item {
                                                    anchors.fill: parent
                                                    anchors.margins: theme.spacingM
                                                    
                                                    // Signal strength icon
                                                    Text {
                                                        id: signalIcon
                                                        anchors.left: parent.left
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: modelData.signalStrength === "excellent" ? "wifi" :
                                                              modelData.signalStrength === "good" ? "wifi_2_bar" :
                                                              modelData.signalStrength === "fair" ? "wifi_1_bar" :
                                                              modelData.signalStrength === "poor" ? "wifi_calling_3" : "wifi"
                                                        font.family: theme.iconFont
                                                        font.pixelSize: theme.iconSize
                                                        color: modelData.connected ? theme.primary : theme.surfaceText
                                                    }
                                                    
                                                    // Network info
                                                    Column {
                                                        anchors.left: signalIcon.right
                                                        anchors.leftMargin: theme.spacingM
                                                        anchors.right: rightIcons.left
                                                        anchors.rightMargin: theme.spacingM
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 2
                                                        
                                                        Text {
                                                            width: parent.width
                                                            text: modelData.ssid
                                                            font.pixelSize: theme.fontSizeMedium
                                                            color: modelData.connected ? theme.primary : theme.surfaceText
                                                            font.weight: modelData.connected ? Font.Medium : Font.Normal
                                                            elide: Text.ElideRight
                                                        }
                                                        
                                                        Text {
                                                            width: parent.width
                                                            text: {
                                                                if (modelData.connected) return "Connected"
                                                                if (modelData.saved) return "Saved" + (modelData.secured ? " • Secured" : " • Open")
                                                                return modelData.secured ? "Secured" : "Open"
                                                            }
                                                            font.pixelSize: theme.fontSizeSmall
                                                            color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                    
                                                    // Right side icons
                                                    Row {
                                                        id: rightIcons
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: theme.spacingXS
                                                        
                                                        // Lock icon (if secured)
                                                        Text {
                                                            text: "lock"
                                                            font.family: theme.iconFont
                                                            font.pixelSize: theme.iconSize - 6
                                                            color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.6)
                                                            visible: modelData.secured
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                        
                                                        // Forget button (for saved networks)
                                                        Rectangle {
                                                            width: 28
                                                            height: 28
                                                            radius: 14
                                                            color: forgetArea.containsMouse ? Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.12) : "transparent"
                                                            visible: modelData.saved || modelData.connected
                                                            
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "delete"
                                                                font.family: theme.iconFont
                                                                font.pixelSize: theme.iconSize - 6
                                                                color: forgetArea.containsMouse ? theme.error : theme.surfaceText
                                                            }
                                                            
                                                            MouseArea {
                                                                id: forgetArea
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    forgetWifiNetwork(modelData.ssid)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                MouseArea {
                                                    id: networkArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (modelData.connected) {
                                                            // Already connected, do nothing or show info
                                                            return
                                                        }
                                                        
                                                        if (modelData.saved) {
                                                            // Saved network, connect directly
                                                            connectToWifi(modelData.ssid)
                                                        } else if (modelData.secured) {
                                                            // Secured network, need password
                                                            root.wifiPasswordSSID = modelData.ssid
                                                            root.wifiPasswordInput = ""
                                                            root.wifiPasswordDialogVisible = true
                                                        } else {
                                                            // Open network, connect directly
                                                            connectToWifi(modelData.ssid)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // WiFi disabled message
                                    Column {
                                        width: parent.width
                                        spacing: theme.spacingM
                                        visible: !root.wifiEnabled
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "wifi_off"
                                            font.family: theme.iconFont
                                            font.pixelSize: 48
                                            color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.3)
                                        }
                                        
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "WiFi is turned off"
                                            font.pixelSize: theme.fontSizeLarge
                                            color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.6)
                                        }
                                        
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "Turn on WiFi to see available networks"
                                            font.pixelSize: theme.fontSizeMedium
                                            color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Audio Tab
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: theme.spacingM
                        visible: controlCenterPopup.currentTab === 1
                        clip: true
                        
                        Column {
                            width: parent.width
                            spacing: theme.spacingL
                            
                            // Volume Control
                            Column {
                                width: parent.width
                                spacing: theme.spacingM
                                
                                Text {
                                    text: "Volume"
                                    font.pixelSize: theme.fontSizeLarge
                                    color: theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                Row {
                                    width: parent.width
                                    spacing: theme.spacingM
                                    
                                    Text {
                                        text: "volume_down"
                                        font.family: theme.iconFont
                                        font.pixelSize: theme.iconSize
                                        color: theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Rectangle {
                                        id: volumeSliderTrack
                                        width: parent.width - 80
                                        height: 8
                                        radius: 4
                                        color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.3)
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Rectangle {
                                            id: volumeSliderFill
                                            width: parent.width * (root.volumeLevel / 100)
                                            height: parent.height
                                            radius: parent.radius
                                            color: theme.primary
                                            
                                            Behavior on width {
                                                NumberAnimation { duration: 100 }
                                            }
                                        }
                                        
                                        // Draggable handle
                                        Rectangle {
                                            id: volumeHandle
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: theme.primary
                                            border.color: Qt.lighter(theme.primary, 1.3)
                                            border.width: 2
                                            
                                            x: Math.max(0, Math.min(parent.width - width, volumeSliderFill.width - width/2))
                                            anchors.verticalCenter: parent.verticalCenter
                                            
                                            scale: volumeMouseArea.containsMouse || volumeMouseArea.pressed ? 1.2 : 1.0
                                            
                                            Behavior on scale {
                                                NumberAnimation { duration: 150 }
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: volumeMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            
                                            onClicked: (mouse) => {
                                                let ratio = Math.max(0, Math.min(1, mouse.x / width))
                                                let newVolume = Math.round(ratio * 100)
                                                setVolume(newVolume)
                                            }
                                            
                                            onPositionChanged: (mouse) => {
                                                if (pressed) {
                                                    let ratio = Math.max(0, Math.min(1, mouse.x / width))
                                                    let newVolume = Math.round(ratio * 100)
                                                    setVolume(newVolume)
                                                }
                                            }
                                        }
                                    }
                                    
                                    Text {
                                        text: "volume_up"
                                        font.family: theme.iconFont
                                        font.pixelSize: theme.iconSize
                                        color: theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                Text {
                                    text: root.volumeLevel + "%"
                                    font.pixelSize: theme.fontSizeMedium
                                    color: theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                            
                            // Output Devices
                            Column {
                                width: parent.width
                                spacing: theme.spacingM
                                
                                Text {
                                    text: "Output Device"
                                    font.pixelSize: theme.fontSizeLarge
                                    color: theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                // Current device indicator
                                Rectangle {
                                    width: parent.width
                                    height: 35
                                    radius: theme.cornerRadius
                                    color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12)
                                    border.color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.3)
                                    border.width: 1
                                    visible: root.currentAudioSink !== ""
                                    
                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: theme.spacingM
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: theme.spacingS
                                        
                                        Text {
                                            text: "check_circle"
                                            font.family: theme.iconFont
                                            font.pixelSize: theme.iconSize - 4
                                            color: theme.primary
                                        }
                                        
                                        Text {
                                            text: "Current: " + (function() {
                                                for (let sink of root.audioSinks) {
                                                    if (sink.name === root.currentAudioSink) {
                                                        return sink.displayName
                                                    }
                                                }
                                                return root.currentAudioSink
                                            })()
                                            font.pixelSize: theme.fontSizeMedium
                                            color: theme.primary
                                            font.weight: Font.Medium
                                        }
                                    }
                                }
                                
                                // Real audio devices
                                Repeater {
                                    model: root.audioSinks
                                    
                                    Rectangle {
                                        width: parent.width
                                        height: 50
                                        radius: theme.cornerRadius
                                        color: deviceArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08) : 
                                               (modelData.active ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.08))
                                        border.color: modelData.active ? theme.primary : "transparent"
                                        border.width: 1
                                        
                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: theme.spacingM
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: theme.spacingM
                                            
                                            Text {
                                                text: {
                                                    if (modelData.name.includes("bluez")) return "headset"
                                                    else if (modelData.name.includes("hdmi")) return "tv"
                                                    else if (modelData.name.includes("usb")) return "headset"
                                                    else return "speaker"
                                                }
                                                font.family: theme.iconFont
                                                font.pixelSize: theme.iconSize
                                                color: modelData.active ? theme.primary : theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Column {
                                                spacing: 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                
                                                Text {
                                                    text: modelData.displayName
                                                    font.pixelSize: theme.fontSizeMedium
                                                    color: modelData.active ? theme.primary : theme.surfaceText
                                                    font.weight: modelData.active ? Font.Medium : Font.Normal
                                                }
                                                
                                                Text {
                                                    text: modelData.active ? "Selected" : ""
                                                    font.pixelSize: theme.fontSizeSmall
                                                    color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.8)
                                                    visible: modelData.active
                                                }
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: deviceArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            
                                            onClicked: {
                                                setAudioSink(modelData.name)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Bluetooth Tab
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: theme.spacingM
                        visible: controlCenterPopup.currentTab === 2
                        clip: true
                        
                        Column {
                            width: parent.width
                            spacing: theme.spacingL
                            
                            // Bluetooth toggle
                            Rectangle {
                                width: parent.width
                                height: 60
                                radius: theme.cornerRadius
                                color: bluetoothToggle.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : 
                                       (root.bluetoothEnabled ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16) : Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.12))
                                border.color: root.bluetoothEnabled ? theme.primary : "transparent"
                                border.width: 2
                                
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: theme.spacingL
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: theme.spacingM
                                    
                                    Text {
                                        text: "bluetooth"
                                        font.family: theme.iconFont
                                        font.pixelSize: theme.iconSizeLarge
                                        color: root.bluetoothEnabled ? theme.primary : theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Column {
                                        spacing: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Text {
                                            text: "Bluetooth"
                                            font.pixelSize: theme.fontSizeLarge
                                            color: root.bluetoothEnabled ? theme.primary : theme.surfaceText
                                            font.weight: Font.Medium
                                        }
                                        
                                        Text {
                                            text: root.bluetoothEnabled ? "Enabled" : "Disabled"
                                            font.pixelSize: theme.fontSizeSmall
                                            color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    id: bluetoothToggle
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: {
                                        toggleBluetooth()
                                    }
                                }
                            }
                            
                            // Bluetooth devices (when enabled)
                            Column {
                                width: parent.width
                                spacing: theme.spacingM
                                visible: root.bluetoothEnabled
                                
                                Text {
                                    text: "Paired Devices"
                                    font.pixelSize: theme.fontSizeLarge
                                    color: theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                // Real Bluetooth devices
                                Repeater {
                                    model: root.bluetoothDevices
                                    
                                    Rectangle {
                                        width: parent.width
                                        height: 60
                                        radius: theme.cornerRadius
                                        color: btDeviceArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08) : 
                                               (modelData.connected ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.08))
                                        border.color: modelData.connected ? theme.primary : "transparent"
                                        border.width: 1
                                        
                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: theme.spacingM
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: theme.spacingM
                                            
                                            Text {
                                                text: {
                                                    switch (modelData.type) {
                                                        case "headset": return "headset"
                                                        case "mouse": return "mouse"
                                                        case "keyboard": return "keyboard"
                                                        case "phone": return "smartphone"
                                                        default: return "bluetooth"
                                                    }
                                                }
                                                font.family: theme.iconFont
                                                font.pixelSize: theme.iconSize
                                                color: modelData.connected ? theme.primary : theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Column {
                                                spacing: 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                
                                                Text {
                                                    text: modelData.name
                                                    font.pixelSize: theme.fontSizeMedium
                                                    color: modelData.connected ? theme.primary : theme.surfaceText
                                                    font.weight: modelData.connected ? Font.Medium : Font.Normal
                                                }
                                                
                                                Row {
                                                    spacing: theme.spacingXS
                                                    
                                                    Text {
                                                        text: modelData.connected ? "Connected" : "Disconnected"
                                                        font.pixelSize: theme.fontSizeSmall
                                                        color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                                                    }
                                                    
                                                    Text {
                                                        text: modelData.battery >= 0 ? "• " + modelData.battery + "%" : ""
                                                        font.pixelSize: theme.fontSizeSmall
                                                        color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                                                        visible: modelData.battery >= 0
                                                    }
                                                }
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: btDeviceArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            
                                            onClicked: {
                                                toggleBluetoothDevice(modelData.mac)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Display Tab
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: theme.spacingM
                        visible: controlCenterPopup.currentTab === 3
                        clip: true
                        
                        Column {
                            width: parent.width
                            spacing: theme.spacingL
                            
                            // Brightness Control
                            Column {
                                width: parent.width
                                spacing: theme.spacingM
                                
                                Text {
                                    text: "Brightness"
                                    font.pixelSize: theme.fontSizeLarge
                                    color: theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                Row {
                                    width: parent.width
                                    spacing: theme.spacingM
                                    
                                    Text {
                                        text: "brightness_low"
                                        font.family: theme.iconFont
                                        font.pixelSize: theme.iconSize
                                        color: theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Rectangle {
                                        width: parent.width - 80
                                        height: 6
                                        radius: 3
                                        color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.3)
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Rectangle {
                                            width: parent.width * (root.brightnessLevel / 100)
                                            height: parent.height
                                            radius: parent.radius
                                            color: theme.primary
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: (mouse) => {
                                                let newBrightness = Math.round((mouse.x / width) * 100)
                                                setBrightness(newBrightness)
                                            }
                                        }
                                    }
                                    
                                    Text {
                                        text: "brightness_high"
                                        font.family: theme.iconFont
                                        font.pixelSize: theme.iconSize
                                        color: theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                Text {
                                    text: root.brightnessLevel + "%"
                                    font.pixelSize: theme.fontSizeMedium
                                    color: theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                            
                            // Display settings
                            Column {
                                width: parent.width
                                spacing: theme.spacingM
                                
                                Text {
                                    text: "Display Settings"
                                    font.pixelSize: theme.fontSizeLarge
                                    color: theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                // Night mode toggle
                                Rectangle {
                                    width: parent.width
                                    height: 50
                                    radius: theme.cornerRadius
                                    color: nightModeToggle.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08) : Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.08)
                                    
                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: theme.spacingM
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: theme.spacingM
                                        
                                        Text {
                                            text: "dark_mode"
                                            font.family: theme.iconFont
                                            font.pixelSize: theme.iconSize
                                            color: theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        
                                        Text {
                                            text: "Night Mode"
                                            font.pixelSize: theme.fontSizeMedium
                                            color: theme.surfaceText
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: nightModeToggle
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        
                                        onClicked: {
                                            console.log("Toggle night mode")
                                            // TODO: Implement night mode toggle
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Click outside to close
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                root.controlCenterVisible = false
            }
        }
    }
    
    // WiFi Password Dialog
    PanelWindow {
        id: wifiPasswordDialog
        
        visible: root.wifiPasswordDialogVisible
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: root.wifiPasswordDialogVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        
        color: "transparent"
        
        onVisibleChanged: {
            if (visible) {
                passwordInput.forceActiveFocus()
            }
        }
        
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            opacity: root.wifiPasswordDialogVisible ? 1.0 : 0.0
            
            Behavior on opacity {
                NumberAnimation {
                    duration: theme.mediumDuration
                    easing.type: theme.standardEasing
                }
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.wifiPasswordDialogVisible = false
                    root.wifiPasswordInput = ""
                }
            }
        }
        
        Rectangle {
            width: Math.min(400, parent.width - theme.spacingL * 2)
            height: Math.min(250, parent.height - theme.spacingL * 2)
            anchors.centerIn: parent
            color: theme.surfaceContainer
            radius: theme.cornerRadiusLarge
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.12)
            border.width: 1
            
            opacity: root.wifiPasswordDialogVisible ? 1.0 : 0.0
            scale: root.wifiPasswordDialogVisible ? 1.0 : 0.9
            
            Behavior on opacity {
                NumberAnimation {
                    duration: theme.mediumDuration
                    easing.type: theme.emphasizedEasing
                }
            }
            
            Behavior on scale {
                NumberAnimation {
                    duration: theme.mediumDuration
                    easing.type: theme.emphasizedEasing
                }
            }
            
            Column {
                anchors.fill: parent
                anchors.margins: theme.spacingL
                spacing: theme.spacingL
                
                // Header
                Row {
                    width: parent.width
                    
                    Column {
                        width: parent.width - 40
                        spacing: theme.spacingXS
                        
                        Text {
                            text: "Connect to Wi-Fi"
                            font.pixelSize: theme.fontSizeLarge
                            color: theme.surfaceText
                            font.weight: Font.Medium
                        }
                        
                        Text {
                            text: "Enter password for \"" + root.wifiPasswordSSID + "\""
                            font.pixelSize: theme.fontSizeMedium
                            color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                            width: parent.width
                            elide: Text.ElideRight
                        }
                    }
                    
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: closeDialogArea.containsMouse ? Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.12) : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            font.family: theme.iconFont
                            font.pixelSize: theme.iconSize - 4
                            color: closeDialogArea.containsMouse ? theme.error : theme.surfaceText
                        }
                        
                        MouseArea {
                            id: closeDialogArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.wifiPasswordDialogVisible = false
                                root.wifiPasswordInput = ""
                            }
                        }
                    }
                }
                
                // Password input
                Rectangle {
                    width: parent.width
                    height: 50
                    radius: theme.cornerRadius
                    color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.08)
                    border.color: passwordInput.activeFocus ? theme.primary : Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.12)
                    border.width: passwordInput.activeFocus ? 2 : 1
                    
                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.margins: theme.spacingM
                        font.pixelSize: theme.fontSizeMedium
                        color: theme.surfaceText
                        echoMode: showPasswordCheckbox.checked ? TextInput.Normal : TextInput.Password
                        verticalAlignment: TextInput.AlignVCenter
                        cursorVisible: activeFocus
                        selectByMouse: true
                        
                        Text {
                            anchors.fill: parent
                            text: "Enter password"
                            font: parent.font
                            color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.5)
                            verticalAlignment: Text.AlignVCenter
                            visible: parent.text.length === 0
                        }
                        
                        onTextChanged: {
                            root.wifiPasswordInput = text
                        }
                        
                        onAccepted: {
                            connectToWifiWithPassword(root.wifiPasswordSSID, root.wifiPasswordInput)
                        }
                        
                        Component.onCompleted: {
                            if (root.wifiPasswordDialogVisible) {
                                forceActiveFocus()
                            }
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: {
                            passwordInput.forceActiveFocus()
                        }
                    }
                }
                
                // Show password checkbox
                Row {
                    spacing: theme.spacingS
                    
                    Rectangle {
                        id: showPasswordCheckbox
                        property bool checked: false
                        
                        width: 20
                        height: 20
                        radius: 4
                        color: checked ? theme.primary : "transparent"
                        border.color: checked ? theme.primary : Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.5)
                        border.width: 2
                        
                        Text {
                            anchors.centerIn: parent
                            text: "check"
                            font.family: theme.iconFont
                            font.pixelSize: 12
                            color: theme.background
                            visible: parent.checked
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                showPasswordCheckbox.checked = !showPasswordCheckbox.checked
                            }
                        }
                    }
                    
                    Text {
                        text: "Show password"
                        font.pixelSize: theme.fontSizeMedium
                        color: theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                // Buttons
                Item {
                    width: parent.width
                    height: 40
                    
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: theme.spacingM
                        
                        Rectangle {
                            width: Math.max(70, cancelText.contentWidth + theme.spacingM * 2)
                            height: 36
                            radius: theme.cornerRadius
                            color: cancelArea.containsMouse ? Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.08) : "transparent"
                            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.2)
                            border.width: 1
                            
                            Text {
                                id: cancelText
                                anchors.centerIn: parent
                                text: "Cancel"
                                font.pixelSize: theme.fontSizeMedium
                                color: theme.surfaceText
                                font.weight: Font.Medium
                            }
                            
                            MouseArea {
                                id: cancelArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.wifiPasswordDialogVisible = false
                                    root.wifiPasswordInput = ""
                                }
                            }
                        }
                        
                        Rectangle {
                            width: Math.max(80, connectText.contentWidth + theme.spacingM * 2)
                            height: 36
                            radius: theme.cornerRadius
                            color: connectArea.containsMouse ? Qt.darker(theme.primary, 1.1) : theme.primary
                            enabled: root.wifiPasswordInput.length > 0
                            opacity: enabled ? 1.0 : 0.5
                            
                            Text {
                                id: connectText
                                anchors.centerIn: parent
                                text: "Connect"
                                font.pixelSize: theme.fontSizeMedium
                                color: theme.background
                                font.weight: Font.Medium
                            }
                        
                        MouseArea {
                            id: connectArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: parent.enabled
                            onClicked: {
                                connectToWifiWithPassword(root.wifiPasswordSSID, root.wifiPasswordInput)
                            }
                        }
                        
                        Behavior on color {
                            ColorAnimation {
                                duration: theme.shortDuration
                                easing.type: theme.standardEasing
                            }
                        }
                        }
                    }
                }
            }
        }
    }
    
    // OS Detection
    Process {
        id: osDetector
        command: ["lsb_release", "-i", "-s"]
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let osId = data.trim().toLowerCase()
                    console.log("Detected OS:", osId)
                    
                    // Set OS-specific Nerd Font icons and names
                    if (osId.includes("arch")) {
                        root.osLogo = "\uf303"  // Arch Linux Nerd Font icon
                        root.osName = "Arch Linux"
                        console.log("Set Arch logo:", root.osLogo)
                    } else if (osId.includes("ubuntu")) {
                        root.osLogo = "\uf31b"  // Ubuntu Nerd Font icon
                        root.osName = "Ubuntu"
                    } else if (osId.includes("fedora")) {
                        root.osLogo = "\uf30a"  // Fedora Nerd Font icon
                        root.osName = "Fedora"
                    } else if (osId.includes("debian")) {
                        root.osLogo = "\uf306"  // Debian Nerd Font icon
                        root.osName = "Debian"
                    } else if (osId.includes("opensuse")) {
                        root.osLogo = "\uef6d"  // openSUSE Nerd Font icon
                        root.osName = "openSUSE"
                    } else if (osId.includes("manjaro")) {
                        root.osLogo = "\uf312"  // Manjaro Nerd Font icon
                        root.osName = "Manjaro"
                    } else {
                        root.osLogo = "\uf033"  // Generic Linux Nerd Font icon
                        root.osName = "Linux"
                    }
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                // Fallback: try checking /etc/os-release
                osDetectorFallback.running = true
            }
        }
    }
    
    // Fallback OS detection
    Process {
        id: osDetectorFallback
        command: ["sh", "-c", "grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '\"'"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let osId = data.trim().toLowerCase()
                    console.log("Detected OS (fallback):", osId)
                    
                    if (osId.includes("arch")) {
                        root.osLogo = "\uf303"
                        root.osName = "Arch Linux"
                    } else if (osId.includes("ubuntu")) {
                        root.osLogo = "\uf31b"
                        root.osName = "Ubuntu"
                    } else if (osId.includes("fedora")) {
                        root.osLogo = "\uf30a"
                        root.osName = "Fedora"
                    } else if (osId.includes("debian")) {
                        root.osLogo = "\uf306"
                        root.osName = "Debian"
                    } else if (osId.includes("opensuse")) {
                        root.osLogo = "\uef6d"
                        root.osName = "openSUSE"
                    } else if (osId.includes("manjaro")) {
                        root.osLogo = "\uf312"
                        root.osName = "Manjaro"
                    } else {
                        root.osLogo = "\uf033"
                        root.osName = "Linux"
                    }
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                // Ultimate fallback - use generic apps icon (empty logo means fallback to "apps")
                root.osLogo = ""
                root.osName = "Linux"
                console.log("OS detection failed, using generic icon")
            }
        }
    }
    
    
    // Color Picker Process
    Process {
        id: colorPickerProcess
        command: ["hyprpicker", "-a"]
        running: false
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Color picker failed. Make sure hyprpicker is installed: yay -S hyprpicker")
            }
        }
    }
    
    // Notification Server
    NotificationServer {
        id: notificationServer
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true
        
        onNotification: (notification) => {
            if (!notification || !notification.id) return
            
            // Filter empty notifications
            if (!notification.appName && !notification.summary && !notification.body) {
                return
            }
            
            console.log("New notification from:", notification.appName || "Unknown", "Summary:", notification.summary || "No summary")
            
            // Create notification object with correct properties
            var notifObj = {
                "id": notification.id,
                "appName": notification.appName || "App",
                "summary": notification.summary || "",
                "body": notification.body || "",
                "timestamp": new Date(),
                "appIcon": notification.appIcon || notification.icon || "",
                "icon": notification.icon || "",
                "image": notification.image || ""
            }
            
            // Add to history (prepend to show newest first)
            notificationHistory.insert(0, notifObj)
            
            // Keep only last 50 notifications
            while (notificationHistory.count > 50) {
                notificationHistory.remove(notificationHistory.count - 1)
            }
            
            // Show popup notification
            root.activeNotification = notifObj
            root.showNotificationPopup = true
            notificationTimer.restart()
        }
    }
    
    // Notification History Model
    ListModel {
        id: notificationHistory
    }
    
    // Weather Service
    Process {
        id: weatherFetcher
        command: ["bash", "-c", "curl -s 'wttr.in/?format=j1' | jq '{current: .current_condition[0], location: .nearest_area[0], astronomy: .weather[0].astronomy[0]}'"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() && text.trim().startsWith("{")) {
                    try {
                        let parsedData = JSON.parse(text.trim())
                        if (parsedData.current && parsedData.location) {
                            root.weather = {
                                available: true,
                                temp: parseInt(parsedData.current.temp_C || 0),
                                tempF: parseInt(parsedData.current.temp_F || 0),
                                city: parsedData.location.areaName[0]?.value || "Unknown",
                                wCode: parsedData.current.weatherCode || "113", 
                                humidity: parseInt(parsedData.current.humidity || 0),
                                wind: (parsedData.current.windspeedKmph || 0) + " km/h",
                                sunrise: parsedData.astronomy?.sunrise || "06:00",
                                sunset: parsedData.astronomy?.sunset || "18:00",
                                uv: parseInt(parsedData.current.uvIndex || 0),
                                pressure: parseInt(parsedData.current.pressure || 0)
                            }
                            console.log("Weather updated:", root.weather.city, root.weather.temp + "°C")
                        }
                    } catch (e) {
                        console.warn("Failed to parse weather data:", e.message)
                        root.weather.available = false
                    }
                } else {
                    console.warn("No valid weather data received")
                    root.weather.available = false
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Weather fetch failed with exit code:", exitCode)
                root.weather.available = false
            }
        }
    }
    
    // Weather fetch timer (every 10 minutes)
    Timer {
        interval: 600000  // 10 minutes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            weatherFetcher.running = true
        }
    }
    
    
    Timer {
        running: root.activePlayer?.playbackState === MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.activePlayer) {
                root.activePlayer.positionChanged()
            }
        }
    }
    
    // Real Network Management
    Process {
        id: networkStatusChecker
        command: ["bash", "-c", "nmcli -t -f DEVICE,TYPE,STATE device | grep -E '(ethernet|wifi)' && echo '---' && ip link show | grep -E '^[0-9]+:.*ethernet.*state UP'"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.log("Network status full output:", text.trim())
                    
                    let hasEthernet = text.includes("ethernet:connected")
                    let hasWifi = text.includes("wifi:connected")
                    let ethernetCableUp = text.includes("state UP")
                    
                    // Check if ethernet cable is physically connected but not managed
                    if (hasEthernet || ethernetCableUp) {
                        root.networkStatus = "ethernet"
                        ethernetIPChecker.running = true
                        console.log("Setting network status to ethernet (cable connected)")
                    } else if (hasWifi) {
                        root.networkStatus = "wifi"
                        currentWifiInfo.running = true
                        wifiIPChecker.running = true
                        console.log("Setting network status to wifi")
                    } else {
                        root.networkStatus = "disconnected"
                        root.ethernetIP = ""
                        root.wifiIP = ""
                        console.log("Setting network status to disconnected")
                    }
                    
                    // Always check WiFi radio status
                    wifiRadioChecker.running = true
                } else {
                    root.networkStatus = "disconnected"
                    root.ethernetIP = ""
                    root.wifiIP = ""
                    console.log("No network output, setting to disconnected")
                }
            }
        }
    }
    
    Process {
        id: wifiRadioChecker
        command: ["nmcli", "radio", "wifi"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                let response = data.trim()
                root.wifiAvailable = response === "enabled" || response === "disabled"
                root.wifiEnabled = response === "enabled"
                console.log("WiFi available:", root.wifiAvailable, "enabled:", root.wifiEnabled)
            }
        }
    }
    
    Process {
        id: ethernetIPChecker
        command: ["bash", "-c", "ip route get 1.1.1.1 | grep -oP 'src \\K\\S+' | head -1"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    root.ethernetIP = data.trim()
                    console.log("Ethernet IP:", root.ethernetIP)
                }
            }
        }
    }
    
    Process {
        id: wifiIPChecker
        command: ["bash", "-c", "nmcli -t -f IP4.ADDRESS dev show $(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1) | cut -d: -f2 | cut -d/ -f1"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    root.wifiIP = data.trim()
                    console.log("WiFi IP:", root.wifiIP)
                }
            }
        }
    }
    
    Process {
        id: currentWifiInfo
        command: ["bash", "-c", "nmcli -t -f ssid,signal connection show --active | grep -v '^--' | grep -v '^$'"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let parts = data.split(":")
                    if (parts.length >= 2 && parts[0].trim() !== "") {
                        root.currentWifiSSID = parts[0].trim()
                        let signal = parseInt(parts[1]) || 100
                        
                        if (signal >= 75) root.wifiSignalStrength = "excellent"
                        else if (signal >= 50) root.wifiSignalStrength = "good"
                        else if (signal >= 25) root.wifiSignalStrength = "fair"
                        else root.wifiSignalStrength = "poor"
                        
                        console.log("Active WiFi:", root.currentWifiSSID, "Signal:", signal + "%")
                    }
                }
            }
        }
    }
    
    Process {
        id: wifiScanner
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let networks = []
                    let lines = text.trim().split('\n')
                    
                    for (let line of lines) {
                        let parts = line.split(':')
                        if (parts.length >= 3 && parts[0].trim() !== "") {
                            let ssid = parts[0].trim()
                            let signal = parseInt(parts[1]) || 0
                            let security = parts[2].trim()
                            
                            // Skip duplicates
                            if (!networks.find(n => n.ssid === ssid)) {
                                networks.push({
                                    ssid: ssid,
                                    signal: signal,
                                    secured: security !== "",
                                    connected: ssid === root.currentWifiSSID,
                                    signalStrength: signal >= 75 ? "excellent" : 
                                                   signal >= 50 ? "good" : 
                                                   signal >= 25 ? "fair" : "poor"
                                })
                            }
                        }
                    }
                    
                    // Sort by signal strength
                    networks.sort((a, b) => b.signal - a.signal)
                    root.wifiNetworks = networks
                    console.log("Found", networks.length, "WiFi networks")
                    
                    // Run saved networks scanner to update saved status
                    savedWifiScanner.running = true
                }
            }
        }
    }
    
    // Saved WiFi Networks Scanner
    Process {
        id: savedWifiScanner
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let savedNetworks = []
                    let lines = text.trim().split('\n')
                    
                    for (let line of lines) {
                        let parts = line.split(':')
                        if (parts.length >= 2 && parts[1].trim() === "802-11-wireless") {
                            savedNetworks.push(parts[0].trim())
                        }
                    }
                    
                    root.savedWifiNetworks = savedNetworks
                    console.log("Found", savedNetworks.length, "saved WiFi networks:", savedNetworks)
                    
                    // Update wifi networks with saved status
                    let updatedNetworks = []
                    for (let network of root.wifiNetworks) {
                        updatedNetworks.push({
                            ssid: network.ssid,
                            signal: network.signal,
                            secured: network.secured,
                            connected: network.connected,
                            signalStrength: network.signalStrength,
                            saved: savedNetworks.includes(network.ssid)
                        })
                    }
                    root.wifiNetworks = updatedNetworks
                }
            }
        }
    }
    
    // Real Audio Control
    Process {
        id: volumeChecker
        command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ | grep -o '[0-9]*%' | head -1 | tr -d '%'"]
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    root.volumeLevel = Math.min(100, parseInt(data.trim()) || 50)
                }
            }
        }
    }
    
    Process {
        id: audioSinkLister
        command: ["bash", "-c", "pactl list sinks | grep -E '^Sink #|device.description|Name:' | paste - - - | sed 's/Sink #//g' | sed 's/Name: //g' | sed 's/device.description = //g' | sed 's/\"//g'"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let sinks = []
                    let lines = text.trim().split('\n')
                    
                    for (let line of lines) {
                        let parts = line.split('\t')
                        if (parts.length >= 3) {
                            let id = parts[0].trim()
                            let name = parts[1].trim()
                            let description = parts[2].trim()
                            
                            // Use description as display name if available, fallback to name processing
                            let displayName = description
                            if (!description || description === name) {
                                if (name.includes("analog-stereo")) displayName = "Built-in Speakers"
                                else if (name.includes("bluez")) displayName = "Bluetooth Audio"
                                else if (name.includes("usb")) displayName = "USB Audio"
                                else if (name.includes("hdmi")) displayName = "HDMI Audio"
                                else if (name.includes("easyeffects")) displayName = "EasyEffects"
                                else displayName = name
                            }
                            
                            sinks.push({
                                id: id,
                                name: name,
                                displayName: displayName,
                                active: false // Will be determined by default sink
                            })
                        }
                    }
                    
                    root.audioSinks = sinks
                    defaultSinkChecker.running = true
                }
            }
        }
    }
    
    Process {
        id: defaultSinkChecker
        command: ["pactl", "get-default-sink"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    root.currentAudioSink = data.trim()
                    console.log("Default audio sink:", root.currentAudioSink)
                    
                    // Update active status in audioSinks
                    let updatedSinks = []
                    for (let sink of root.audioSinks) {
                        updatedSinks.push({
                            id: sink.id,
                            name: sink.name,
                            displayName: sink.displayName,
                            active: sink.name === root.currentAudioSink
                        })
                    }
                    root.audioSinks = updatedSinks
                }
            }
        }
    }
    
    // Real Bluetooth Management
    Process {
        id: bluetoothStatusChecker
        command: ["bluetoothctl", "show"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                root.bluetoothAvailable = text.trim() !== "" && !text.includes("No default controller")
                root.bluetoothEnabled = text.includes("Powered: yes")
                console.log("Bluetooth available:", root.bluetoothAvailable, "enabled:", root.bluetoothEnabled)
                
                if (root.bluetoothEnabled && root.bluetoothAvailable) {
                    bluetoothDeviceScanner.running = true
                } else {
                    root.bluetoothDevices = []
                }
            }
        }
    }
    
    Process {
        id: bluetoothDeviceScanner
        command: ["bash", "-c", "bluetoothctl devices | while read -r line; do if [[ $line =~ Device\\ ([0-9A-F:]+)\\ (.+) ]]; then mac=\"${BASH_REMATCH[1]}\"; name=\"${BASH_REMATCH[2]}\"; if [[ ! $name =~ ^/org/bluez ]]; then info=$(bluetoothctl info $mac); connected=$(echo \"$info\" | grep 'Connected:' | grep -q 'yes' && echo 'true' || echo 'false'); battery=$(echo \"$info\" | grep 'Battery Percentage' | grep -o '([0-9]*)' | tr -d '()'); echo \"$mac|$name|$connected|${battery:-}\"; fi; fi; done"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    let devices = []
                    let lines = text.trim().split('\n')
                    
                    for (let line of lines) {
                        if (line.trim()) {
                            let parts = line.split('|')
                            if (parts.length >= 3) {
                                let mac = parts[0].trim()
                                let name = parts[1].trim()
                                let connected = parts[2].trim() === 'true'
                                let battery = parts[3] ? parseInt(parts[3]) : -1
                                
                                // Skip if name is still a technical path
                                if (name.startsWith('/org/bluez') || name.includes('hci0')) {
                                    continue
                                }
                                
                                // Determine device type from name
                                let type = "bluetooth"
                                let nameLower = name.toLowerCase()
                                if (nameLower.includes("headphone") || nameLower.includes("airpod") || nameLower.includes("headset") || nameLower.includes("arctis")) type = "headset"
                                else if (nameLower.includes("mouse")) type = "mouse"
                                else if (nameLower.includes("keyboard")) type = "keyboard"
                                else if (nameLower.includes("phone") || nameLower.includes("iphone") || nameLower.includes("samsung")) type = "phone"
                                else if (nameLower.includes("watch")) type = "watch"
                                else if (nameLower.includes("speaker")) type = "speaker"
                                
                                devices.push({
                                    mac: mac,
                                    name: name,
                                    type: type,
                                    connected: connected,
                                    battery: battery
                                })
                            }
                        }
                    }
                    
                    root.bluetoothDevices = devices
                    console.log("Found", devices.length, "Bluetooth devices")
                }
            }
        }
    }
    
    // Brightness Control
    Process {
        id: brightnessChecker
        command: ["bash", "-c", "if command -v brightnessctl > /dev/null; then brightnessctl get; elif command -v xbacklight > /dev/null; then xbacklight -get | cut -d. -f1; else echo 75; fi"]
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let brightness = parseInt(data.trim()) || 75
                    // brightnessctl returns absolute value, need to convert to percentage
                    if (brightness > 100) {
                        brightnessMaxChecker.running = true
                    } else {
                        root.brightnessLevel = brightness
                    }
                }
            }
        }
    }
    
    Process {
        id: brightnessMaxChecker
        command: ["brightnessctl", "max"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let maxBrightness = parseInt(data.trim()) || 100
                    brightnessCurrentChecker.property("maxBrightness", maxBrightness)
                    brightnessCurrentChecker.running = true
                }
            }
        }
    }
    
    Process {
        id: brightnessCurrentChecker
        property int maxBrightness: 100
        command: ["brightnessctl", "get"]
        running: false
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim()) {
                    let currentBrightness = parseInt(data.trim()) || 75
                    root.brightnessLevel = Math.round((currentBrightness / maxBrightness) * 100)
                }
            }
        }
    }
    
    // System Control Functions
    function setVolume(percentage) {
        let volumeSetProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "' + percentage + '%"]
                running: true
                onExited: volumeChecker.running = true
            }
        ', root)
    }
    
    function setAudioSink(sinkName) {
        let sinkSetProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["pactl", "set-default-sink", "' + sinkName + '"]
                running: true
                onExited: {
                    defaultSinkChecker.running = true
                    audioSinkLister.running = true
                }
            }
        ', root)
    }
    
    function connectToWifi(ssid) {
        console.log("Connecting to WiFi:", ssid)
        root.wifiConnectionStatus = "connecting"
        root.wifiPasswordSSID = ssid
        
        let connectProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["nmcli", "dev", "wifi", "connect", "' + ssid + '"]
                running: true
                onExited: (exitCode) => {
                    console.log("WiFi connection result:", exitCode)
                    if (exitCode === 0) {
                        root.wifiConnectionStatus = "connected"
                        wifiConnectionStatusTimer.start()
                    } else {
                        root.wifiConnectionStatus = "failed"
                        wifiConnectionStatusTimer.start()
                    }
                    networkStatusChecker.running = true
                    wifiScanner.running = true
                    savedWifiScanner.running = true
                }
            }
        ', root)
    }
    
    function connectToWifiWithPassword(ssid, password) {
        console.log("Connecting to WiFi with password:", ssid)
        root.wifiConnectionStatus = "connecting"
        root.wifiPasswordSSID = ssid
        
        let connectProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["nmcli", "dev", "wifi", "connect", "' + ssid + '", "password", "' + password + '"]
                running: true
                onExited: (exitCode) => {
                    console.log("WiFi connection with password result:", exitCode)
                    root.wifiPasswordDialogVisible = false
                    root.wifiPasswordInput = ""
                    if (exitCode === 0) {
                        root.wifiConnectionStatus = "connected"
                        wifiConnectionStatusTimer.start()
                    } else {
                        root.wifiConnectionStatus = "failed"
                        wifiConnectionStatusTimer.start()
                    }
                    networkStatusChecker.running = true
                    wifiScanner.running = true
                    savedWifiScanner.running = true
                }
            }
        ', root)
    }
    
    function forgetWifiNetwork(ssid) {
        console.log("Forgetting WiFi network:", ssid)
        let forgetProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["nmcli", "connection", "delete", "' + ssid + '"]
                running: true
                onExited: (exitCode) => {
                    console.log("WiFi forget result:", exitCode)
                    networkStatusChecker.running = true
                    wifiScanner.running = true
                    savedWifiScanner.running = true
                }
            }
        ', root)
    }
    
    function toggleBluetoothDevice(mac) {
        console.log("Toggling Bluetooth device:", mac)
        let device = root.bluetoothDevices.find(d => d.mac === mac)
        if (device) {
            let action = device.connected ? "disconnect" : "connect"
            let toggleProcess = Qt.createQmlObject('
                import Quickshell.Io
                Process {
                    command: ["bluetoothctl", "' + action + '", "' + mac + '"]
                    running: true
                    onExited: bluetoothDeviceScanner.running = true
                }
            ', root)
        }
    }
    
    function setBrightness(percentage) {
        let brightnessSetProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["bash", "-c", "if command -v brightnessctl > /dev/null; then brightnessctl set ' + percentage + '%; elif command -v xbacklight > /dev/null; then xbacklight -set ' + percentage + '; fi"]
                running: true
                onExited: brightnessChecker.running = true
            }
        ', root)
    }
    
    function toggleNetworkConnection(type) {
        if (type === "ethernet") {
            // Toggle ethernet connection
            if (root.networkStatus === "ethernet") {
                // Disconnect ethernet
                let disconnectProcess = Qt.createQmlObject('
                    import Quickshell.Io
                    Process {
                        command: ["bash", "-c", "nmcli device disconnect $(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1)"]
                        running: true
                        onExited: networkStatusChecker.running = true
                    }
                ', root)
            } else {
                // Connect ethernet with proper nmcli device connect
                let connectProcess = Qt.createQmlObject('
                    import Quickshell.Io
                    Process {
                        command: ["bash", "-c", "nmcli device connect $(nmcli -t -f DEVICE,TYPE device | grep ethernet | cut -d: -f1 | head -1)"]
                        running: true
                        onExited: networkStatusChecker.running = true
                    }
                ', root)
            }
        } else if (type === "wifi") {
            // Connect to WiFi if disconnected
            if (root.networkStatus !== "wifi" && root.wifiEnabled) {
                let connectProcess = Qt.createQmlObject('
                    import Quickshell.Io
                    Process {
                        command: ["bash", "-c", "nmcli device connect $(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -1)"]
                        running: true
                        onExited: networkStatusChecker.running = true
                    }
                ', root)
            }
        }
    }
    
    function toggleWifiRadio() {
        let action = root.wifiEnabled ? "off" : "on"
        let toggleProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["nmcli", "radio", "wifi", "' + action + '"]
                running: true
                onExited: {
                    networkStatusChecker.running = true
                    if (action === "on") {
                        wifiScanner.running = true
                    } else {
                        root.wifiNetworks = []
                    }
                }
            }
        ', root)
    }
    
    function toggleBluetooth() {
        let action = root.bluetoothEnabled ? "off" : "on"
        let toggleProcess = Qt.createQmlObject('
            import Quickshell.Io
            Process {
                command: ["bluetoothctl", "power", "' + action + '"]
                running: true
                onExited: bluetoothStatusChecker.running = true
            }
        ', root)
    }
    
    // Periodic system state updates
    Timer {
        interval: 10000  // 10 seconds
        running: true
        repeat: true
        onTriggered: {
            networkStatusChecker.running = true
            volumeChecker.running = true
            audioSinkLister.running = true
            bluetoothStatusChecker.running = true
            brightnessChecker.running = true
        }
    }
    
    // WiFi scan timer (when control center is open)
    Timer {
        interval: 5000  // 5 seconds
        running: root.controlCenterVisible && (root.networkStatus === "wifi" || root.networkStatus === "disconnected")
        repeat: true
        onTriggered: {
            wifiScanner.running = true
        }
    }
    
    Component.onCompleted: {
        console.log("DankMaterialDark shell loaded successfully!")
    }
}