import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import "../../Common"
import "../../Common/Utilities.js" as Utils
import "../../Services"
import ".."

PanelWindow {
    id: topBar
    
    property var modelData
    screen: modelData
    property string screenName: modelData.name
    
    // Transparency property for the top bar background
    property real backgroundTransparency: Prefs.topBarTransparency
    
    Connections {
        target: Prefs
        function onTopBarTransparencyChanged() {
            topBar.backgroundTransparency = Prefs.topBarTransparency
        }
    }
    
    // Properties exposed to shell
    property bool hasActiveMedia: false
    property var activePlayer: null
    property bool weatherAvailable: false
    property string weatherCode: ""
    property int weatherTemp: 0
    property int weatherTempF: 0
    property string osLogo: ""
    property string networkStatus: "disconnected"
    property string wifiSignalStrength: "good"
    property int volumeLevel: 50
    property bool volumeMuted: false
    property bool bluetoothAvailable: false
    property bool bluetoothEnabled: false
    
    // Shell reference to access root properties directly
    property var shellRoot: null
    
    // Notification properties
    property int notificationCount: 0
    
    // Process dropdown reference
    property var processDropdown: null
    
    
    // Clipboard properties
    signal clipboardRequested()
    
    // Tray menu properties
    property bool showTrayMenu: false
    property var currentTrayMenu: null
    property var currentTrayItem: null
    property real trayMenuX: 0
    property real trayMenuY: 0
    
    
    
    // Proxy objects for external connections
    
    QtObject {
        id: notificationHistory
        property int count: 0
    }
    
    
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
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, topBar.backgroundTransparency)
            
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 4
                shadowBlur: 0.5  // radius/32, adjusted for visual match
                shadowColor: Qt.rgba(0, 0, 0, 0.15)
                shadowOpacity: 0.15
            }
            
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                border.width: 1
                radius: parent.radius
            }
            
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.surfaceTint.r, Theme.surfaceTint.g, Theme.surfaceTint.b, 0.04)
                radius: parent.radius
                
                SequentialAnimation on opacity {
                    running: false
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
            clip: true
            
            Row {
                id: leftSection
                height: parent.height
                spacing: Theme.spacingXS
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                
                LauncherButton {
                    anchors.verticalCenter: parent.verticalCenter
                    osLogo: topBar.osLogo
                }
                
                WorkspaceSwitcher {
                    anchors.verticalCenter: parent.verticalCenter
                    screenName: topBar.screenName
                }
                
                FocusedAppWidget {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Prefs.showFocusedWindow
                }
            }
            
            ClockWidget {
                id: clockWidget
                anchors.centerIn: parent
                
                onClockClicked: {
                    if (topBar.shellRoot) {
                        topBar.shellRoot.calendarVisible = !topBar.shellRoot.calendarVisible
                    }
                }
            }
            
            MediaWidget {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: clockWidget.left
                anchors.rightMargin: Theme.spacingS
                activePlayer: topBar.activePlayer
                hasActiveMedia: topBar.hasActiveMedia
                visible: Prefs.showMusic && topBar.hasActiveMedia
                
                onClicked: {
                    if (topBar.shellRoot) {
                        // Hide notification popup if visible
                        if (topBar.shellRoot.showNotificationPopup) {
                            Utils.hideNotificationPopup()
                        }
                        topBar.shellRoot.calendarVisible = !topBar.shellRoot.calendarVisible
                    }
                }
            }
            
            WeatherWidget {
                id: weatherWidget
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: clockWidget.right
                anchors.leftMargin: Theme.spacingS
                
                weatherAvailable: topBar.weatherAvailable
                weatherCode: topBar.weatherCode
                weatherTemp: topBar.weatherTemp
                weatherTempF: topBar.weatherTempF
                visible: Prefs.showWeather && topBar.weatherAvailable && topBar.weatherTemp > 0 && topBar.weatherTempF > 0
                
                onClicked: {
                    if (topBar.shellRoot) {
                        // Hide notification popup if visible
                        if (topBar.shellRoot.showNotificationPopup) {
                            Utils.hideNotificationPopup()
                        }
                        topBar.shellRoot.calendarVisible = !topBar.shellRoot.calendarVisible
                    }
                }
            }
            
            Row {
                id: rightSection
                height: parent.height
                spacing: Theme.spacingXS
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                
                SystemTrayWidget {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Prefs.showSystemTray
                    onMenuRequested: (menu, item, x, y) => {
                        if (topBar.shellRoot) {
                            topBar.shellRoot.currentTrayMenu = menu
                            topBar.shellRoot.currentTrayItem = item
                            topBar.shellRoot.trayMenuX = rightSection.x + rightSection.width - 400 - Theme.spacingL
                            topBar.shellRoot.trayMenuY = Theme.barHeight - Theme.spacingXS
                            topBar.shellRoot.showTrayMenu = true
                        }
                        menu.menuVisible = true
                    }
                }
                
                Rectangle {
                    width: 40
                    height: 30
                    radius: Theme.cornerRadius
                    color: clipboardArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Prefs.showClipboard
                    
                    Text {
                        anchors.centerIn: parent
                        text: "content_paste"
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
                            // Hide notification popup if visible
                            if (topBar.shellRoot && topBar.shellRoot.showNotificationPopup) {
                                Utils.hideNotificationPopup()
                            }
                            topBar.clipboardRequested()
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
                
                // System Monitor Widgets
                CpuMonitorWidget {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Prefs.showSystemResources
                    processDropdown: topBar.processDropdown
                }

                RamMonitorWidget {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Prefs.showSystemResources
                    processDropdown: topBar.processDropdown
                }
                
                NotificationCenterButton {
                    anchors.verticalCenter: parent.verticalCenter
                    hasUnread: topBar.notificationCount > 0
                    isActive: topBar.shellRoot ? topBar.shellRoot.notificationHistoryVisible : false
                    onClicked: {
                        if (topBar.shellRoot) {
                            // Hide notification popup if visible
                            if (topBar.shellRoot.showNotificationPopup) {
                                Utils.hideNotificationPopup()
                            }
                            topBar.shellRoot.notificationHistoryVisible = !topBar.shellRoot.notificationHistoryVisible
                        }
                    }
                }
                
                // Battery Widget
                BatteryWidget {
                    anchors.verticalCenter: parent.verticalCenter
                    batteryPopupVisible: topBar.shellRoot.batteryPopupVisible
                    onToggleBatteryPopup: {
                        topBar.shellRoot.batteryPopupVisible = !topBar.shellRoot.batteryPopupVisible
                    }
                }
                
                ControlCenterButton {
                    anchors.verticalCenter: parent.verticalCenter
                    networkStatus: topBar.networkStatus
                    wifiSignalStrength: topBar.wifiSignalStrength
                    volumeLevel: topBar.volumeLevel
                    volumeMuted: topBar.volumeMuted
                    bluetoothAvailable: topBar.bluetoothAvailable
                    bluetoothEnabled: topBar.bluetoothEnabled
                    isActive: topBar.shellRoot ? topBar.shellRoot.controlCenterVisible : false
                    
                    onClicked: {
                        if (topBar.shellRoot) {
                            // Hide notification popup if visible
                            if (topBar.shellRoot.showNotificationPopup) {
                                Utils.hideNotificationPopup()
                            }
                            topBar.shellRoot.controlCenterVisible = !topBar.shellRoot.controlCenterVisible
                            if (topBar.shellRoot.controlCenterVisible) {
                                WifiService.scanWifi()
                                // Bluetooth devices are automatically updated via signals
                            }
                        }
                    }
                }
            }
        }
    }
}