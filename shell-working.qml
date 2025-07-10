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
    property bool hasActiveMedia: MprisController.isPlaying && (activePlayer?.trackTitle || activePlayer?.trackArtist)
    
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

    // Top bar
    PanelWindow {
        id: topBar
        
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
                            text: "Applications"
                            font.pixelSize: theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: theme.surfaceText
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
            }
            
            Rectangle {
                id: clockContainer
                width: Math.min(root.hasActiveMedia ? 500 : (root.weather.available ? 280 : 200), parent.width - theme.spacingL * 2)
                height: root.hasActiveMedia ? 80 : 32
                radius: theme.cornerRadius
                color: clockMouseArea.containsMouse && root.hasActiveMedia ? 
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
                
                // Media player content (when active)
                Column {
                    visible: root.hasActiveMedia
                    anchors.centerIn: parent
                    width: parent.width - theme.spacingM * 2
                    spacing: theme.spacingXS
                    
                    Row {
                        width: parent.width
                        spacing: theme.spacingS
                        
                        Rectangle {
                            width: 48
                            height: 48
                            radius: theme.cornerRadiusSmall
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
                                        text: "music_note"
                                        font.family: theme.iconFont
                                        font.pixelSize: theme.iconSize
                                        color: theme.surfaceVariantText
                                    }
                                }
                            }
                        }
                        
                        Column {
                            width: parent.width - 48 - theme.spacingS - 120
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: root.activePlayer?.trackTitle || "Unknown Track"
                                font.pixelSize: theme.fontSizeMedium
                                color: theme.surfaceText
                                font.weight: Font.Medium
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: root.activePlayer?.trackArtist || "Unknown Artist"
                                font.pixelSize: theme.fontSizeSmall
                                color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }
                        
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: theme.spacingS
                            
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                color: prevBtnArea.containsMouse ? Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.12) : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "skip_previous"
                                    font.family: theme.iconFont
                                    font.pixelSize: 16
                                    color: theme.surfaceText
                                }
                                
                                MouseArea {
                                    id: prevBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activePlayer?.previous()
                                }
                            }
                            
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                color: theme.primary
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: root.activePlayer?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                                    font.family: theme.iconFont
                                    font.pixelSize: 16
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
                                width: 28
                                height: 28
                                radius: 14
                                color: nextBtnArea.containsMouse ? Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.12) : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "skip_next"
                                    font.family: theme.iconFont
                                    font.pixelSize: 16
                                    color: theme.surfaceText
                                }
                                
                                MouseArea {
                                    id: nextBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activePlayer?.next()
                                }
                            }
                        }
                    }
                    
                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.3)
                        
                        Rectangle {
                            id: progressFill
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
                                    const newPosition = (mouse.x / width) * root.activePlayer.length
                                    root.activePlayer.setPosition(newPosition)
                                }
                            }
                        }
                    }
                }
                
                // Normal clock/weather content (when no media)
                Row {
                    anchors.centerIn: parent
                    spacing: theme.spacingM
                    visible: !root.hasActiveMedia
                    
                    // Weather info (when available)
                    Row {
                        spacing: theme.spacingXS
                        visible: root.weather.available
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Text {
                            text: root.weatherIcons[root.weather.wCode] || "clear_day"
                            font.family: theme.iconFont
                            font.pixelSize: theme.iconSize - 2
                            color: theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: (root.useFahrenheit ? root.weather.tempF : root.weather.temp) + "°" + (root.useFahrenheit ? "F" : "C")
                            font.pixelSize: theme.fontSizeMedium
                            color: theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    // Separator when weather is available
                    Text {
                        text: "•"
                        font.pixelSize: theme.fontSizeMedium
                        color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.5)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.weather.available
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
                    cursorShape: !root.hasActiveMedia ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: !root.hasActiveMedia
                    
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
            }
        }
    }
    
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
            height: root.weather.available ? 480 : 400
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
                
                // Weather header (when available)
                Rectangle {
                    visible: root.weather.available
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
                    height: root.weather.available ? parent.height - 200 : parent.height - 120
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
                        anchors.centerIn: parent
                        sourceComponent: IconImage {
                            width: 32
                            height: 32
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
                                        anchors.centerIn: parent
                                        sourceComponent: IconImage {
                                            width: 28
                                            height: 28
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
    
    Component.onCompleted: {
        console.log("DankMaterialDark shell loaded successfully!")
    }
}