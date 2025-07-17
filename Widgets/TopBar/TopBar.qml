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
import qs.Common
import qs.Services
import qs.Widgets
import "../../Common/Utilities.js" as Utils

PanelWindow {
    id: root
    
    property var modelData
    screen: modelData
    property string screenName: modelData.name
    
    // Transparency property for the top bar background
    property real backgroundTransparency: Prefs.topBarTransparency
    
    Connections {
        target: Prefs
        function onTopBarTransparencyChanged() {
            root.backgroundTransparency = Prefs.topBarTransparency
        }
    }
    
    
    // Notification properties
    readonly property int notificationCount: NotificationService.notifications.length
    
    
    
    
    
    
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
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, root.backgroundTransparency)
            
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
                }
                
                WorkspaceSwitcher {
                    anchors.verticalCenter: parent.verticalCenter
                    screenName: root.screenName
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
                    centerCommandCenter.calendarVisible = !centerCommandCenter.calendarVisible
                }
            }
            
            MediaWidget {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: clockWidget.left
                anchors.rightMargin: Theme.spacingS
                visible: Prefs.showMusic && MprisController.activePlayer
                
                onClicked: {
                    centerCommandCenter.calendarVisible = !centerCommandCenter.calendarVisible
                }
            }
            
            WeatherWidget {
                id: weatherWidget
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: clockWidget.right
                anchors.leftMargin: Theme.spacingS
                
                visible: Prefs.showWeather && WeatherService.weather.available && WeatherService.weather.temp > 0 && WeatherService.weather.tempF > 0
                
                onClicked: {
                    centerCommandCenter.calendarVisible = !centerCommandCenter.calendarVisible
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
                        trayMenuPopup.currentTrayMenu = menu
                        trayMenuPopup.currentTrayItem = item
                        trayMenuPopup.trayMenuX = rightSection.x + rightSection.width - 400 - Theme.spacingL
                        trayMenuPopup.trayMenuY = Theme.barHeight - Theme.spacingXS
                        trayMenuPopup.showTrayMenu = true
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
                
                // System Monitor Widgets
                CpuMonitorWidget {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Prefs.showSystemResources
                }

                RamMonitorWidget {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Prefs.showSystemResources
                }
                
                NotificationCenterButton {
                    anchors.verticalCenter: parent.verticalCenter
                    hasUnread: root.notificationCount > 0
                    isActive: notificationCenter.notificationHistoryVisible
                    onClicked: {
                        notificationCenter.notificationHistoryVisible = !notificationCenter.notificationHistoryVisible
                    }
                }
                
                // Battery Widget
                BatteryWidget {
                    anchors.verticalCenter: parent.verticalCenter
                    batteryPopupVisible: batteryControlPopup.batteryPopupVisible
                    onToggleBatteryPopup: {
                        batteryControlPopup.batteryPopupVisible = !batteryControlPopup.batteryPopupVisible
                    }
                }
                
                ControlCenterButton {
                    anchors.verticalCenter: parent.verticalCenter
                    isActive: controlCenterPopup.controlCenterVisible
                    
                    onClicked: {
                        controlCenterPopup.controlCenterVisible = !controlCenterPopup.controlCenterVisible
                        if (controlCenterPopup.controlCenterVisible) {
                            if (NetworkService.wifiEnabled) {
                                WifiService.scanWifi()
                            }
                            // Bluetooth devices are automatically updated via signals
                        }
                    }
                }
            }
        }
    }
}