import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import "../../Common"
import "../../Services"

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
    property bool nightModeEnabled: false
    
    Rectangle {
        width: Math.min(600, parent.width - Theme.spacingL * 2)
        height: Math.min(500, parent.height - Theme.barHeight - Theme.spacingS * 2)
        x: Math.max(Theme.spacingL, parent.width - width - Theme.spacingL)
        y: Theme.barHeight + Theme.spacingS
        color: Theme.surfaceContainer
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        border.width: 1
        
        opacity: root.controlCenterVisible ? 1.0 : 0.0
        scale: root.controlCenterVisible ? 1.0 : 0.85
        
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
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM
            
            // Header with tabs
            Column {
                width: parent.width
                spacing: Theme.spacingM
                
                Row {
                    width: parent.width
                    height: 32
                    
                    Text {
                        text: "Control Center"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Item { width: parent.width - 300; height: 1 }
                    
                    // Calendar status indicator
                    Rectangle {
                        width: 100
                        height: 24
                        radius: Theme.cornerRadiusSmall
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.16)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: CalendarService && CalendarService.khalAvailable
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS
                            
                            Text {
                                text: "event"
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize - 6
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Text {
                                id: todayEventsText
                                property var todayEvents: []
                                text: todayEvents.length === 0 ? "No events today" : 
                                      todayEvents.length === 1 ? "1 event today" : 
                                      todayEvents.length + " events today"
                                
                                function updateTodayEvents() {
                                    if (CalendarService && CalendarService.khalAvailable) {
                                        todayEvents = CalendarService.getEventsForDate(new Date())
                                    } else {
                                        todayEvents = []
                                    }
                                }
                                
                                Component.onCompleted: {
                                    console.log("ControlCenter: Calendar status text initialized, CalendarService available:", !!CalendarService)
                                    if (CalendarService) {
                                        console.log("ControlCenter: khal available:", CalendarService.khalAvailable)
                                    }
                                    updateTodayEvents()
                                }
                                font.pixelSize: Theme.fontSizeXS
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                
                                // Update when events change or khal becomes available
                                Connections {
                                    target: CalendarService
                                    enabled: CalendarService !== null
                                    function onEventsByDateChanged() {
                                        todayEventsText.updateTodayEvents()
                                    }
                                    function onKhalAvailableChanged() {
                                        todayEventsText.updateTodayEvents()
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Tab buttons
                Row {
                    width: parent.width
                    spacing: Theme.spacingXS
                    
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
                            width: (parent.width - Theme.spacingXS * (tabCount - 1)) / tabCount
                            height: 40
                            radius: Theme.cornerRadius
                            color: controlCenterPopup.currentTab === index ? 
                                   Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
                                   tabArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                            
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS
                                
                                Text {
                                    text: modelData.icon
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize - 4
                                    color: controlCenterPopup.currentTab === index ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: controlCenterPopup.currentTab === index ? Theme.primary : Theme.surfaceText
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
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
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
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                
                // Network Tab
                NetworkTab {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    visible: controlCenterPopup.currentTab === 0
                    
                    // Bind properties from root
                    networkStatus: root.networkStatus
                    wifiAvailable: root.wifiAvailable
                    wifiEnabled: root.wifiEnabled
                    ethernetIP: root.ethernetIP
                    currentWifiSSID: root.currentWifiSSID
                    wifiIP: root.wifiIP
                    wifiSignalStrength: root.wifiSignalStrength
                    wifiNetworks: root.wifiNetworks
                    wifiConnectionStatus: root.wifiConnectionStatus
                    wifiPasswordSSID: root.wifiPasswordSSID
                    wifiPasswordInput: root.wifiPasswordInput
                    wifiPasswordDialogVisible: root.wifiPasswordDialogVisible
                    
                    // Bind the auto-refresh flag
                    onWifiAutoRefreshEnabledChanged: {
                        root.wifiAutoRefreshEnabled = wifiAutoRefreshEnabled
                    }
                }
                
                // Audio Tab
                AudioTab {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    visible: controlCenterPopup.currentTab === 1
                    
                    // Bind properties from root
                    volumeLevel: root.volumeLevel
                    micLevel: root.micLevel
                    currentAudioSink: root.currentAudioSink
                    currentAudioSource: root.currentAudioSource
                    audioSinks: root.audioSinks
                    audioSources: root.audioSources
                }
                
                // Bluetooth Tab
                BluetoothTab {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    visible: controlCenterPopup.currentTab === 2
                    
                    // Bind properties from root
                    bluetoothEnabled: root.bluetoothEnabled
                    bluetoothDevices: root.bluetoothDevices
                }
                
                // Display Tab
                DisplayTab {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    visible: controlCenterPopup.currentTab === 3
                    
                    // Bind properties from parent
                    nightModeEnabled: controlCenterPopup.nightModeEnabled
                    
                    // Sync night mode state back to parent
                    onNightModeEnabledChanged: {
                        controlCenterPopup.nightModeEnabled = nightModeEnabled
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