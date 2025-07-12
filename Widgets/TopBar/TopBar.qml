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
    property bool useFahrenheit: false
    property string osLogo: ""
    property string networkStatus: "disconnected"
    property string wifiSignalStrength: "good"
    property int volumeLevel: 50
    property bool bluetoothAvailable: false
    property bool bluetoothEnabled: false
    
    // Shell reference to access root properties directly
    property var shellRoot: null
    
    // Notification properties
    property int notificationCount: 0
    
    
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
    
    // Battery widget and other widgets are imported from their original locations
    // These will be handled by the parent shell
    property alias batteryWidget: batteryWidgetProxy
    property alias cpuMonitorWidget: cpuMonitorWidgetProxy
    property alias ramMonitorWidget: ramMonitorWidgetProxy
    property alias powerButton: powerButtonProxy
    
    QtObject { id: batteryWidgetProxy }
    QtObject { id: cpuMonitorWidgetProxy }
    QtObject { id: ramMonitorWidgetProxy }
    QtObject { id: powerButtonProxy }
    
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
            }
            
            ClockWidget {
                id: clockWidget
                anchors.centerIn: parent
                hasActiveMedia: topBar.hasActiveMedia
                activePlayer: topBar.activePlayer
                weatherAvailable: topBar.weatherAvailable
                weatherCode: topBar.weatherCode
                weatherTemp: topBar.weatherTemp
                weatherTempF: topBar.weatherTempF
                useFahrenheit: topBar.useFahrenheit
                
                onClockClicked: {
                    if (topBar.shellRoot) {
                        topBar.shellRoot.calendarVisible = !topBar.shellRoot.calendarVisible
                    }
                }
                
                // Insert audio visualization into the clock widget placeholder
                AudioVisualization {
                    parent: clockWidget.children[0].children[0].children[0] // Row -> Row (media info) -> Item (placeholder)
                    anchors.fill: parent
                    hasActiveMedia: topBar.hasActiveMedia
                    activePlayer: topBar.activePlayer
                    visible: topBar.hasActiveMedia
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
                    onMenuRequested: (menu, item, x, y) => {
                        topBar.currentTrayMenu = menu
                        topBar.currentTrayItem = item
                        topBar.trayMenuX = rightSection.x + rightSection.width - 400 - Theme.spacingL
                        topBar.trayMenuY = Theme.barHeight + Theme.spacingS
                        console.log("Showing menu at:", topBar.trayMenuX, topBar.trayMenuY)
                        menu.menuVisible = true
                        topBar.showTrayMenu = true
                    }
                }
                
                Rectangle {
                    width: 40
                    height: 30
                    radius: Theme.cornerRadius
                    color: clipboardArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    
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
                }

                RamMonitorWidget {
                    anchors.verticalCenter: parent.verticalCenter  
                }
                
                NotificationCenterButton {
                    anchors.verticalCenter: parent.verticalCenter
                    hasUnread: topBar.notificationCount > 0
                    isActive: topBar.shellRoot ? topBar.shellRoot.notificationHistoryVisible : false
                    onClicked: {
                        if (topBar.shellRoot) {
                            topBar.shellRoot.notificationHistoryVisible = !topBar.shellRoot.notificationHistoryVisible
                        }
                    }
                }
                
                // Battery Widget
                BatteryWidget {
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                ControlCenterButton {
                    anchors.verticalCenter: parent.verticalCenter
                    networkStatus: topBar.networkStatus
                    wifiSignalStrength: topBar.wifiSignalStrength
                    volumeLevel: topBar.volumeLevel
                    bluetoothAvailable: topBar.bluetoothAvailable
                    bluetoothEnabled: topBar.bluetoothEnabled
                    isActive: topBar.shellRoot ? topBar.shellRoot.controlCenterVisible : false
                    
                    onClicked: {
                        if (topBar.shellRoot) {
                            topBar.shellRoot.controlCenterVisible = !topBar.shellRoot.controlCenterVisible
                            if (topBar.shellRoot.controlCenterVisible) {
                                WifiService.scanWifi()
                                BluetoothService.scanDevices()
                            }
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