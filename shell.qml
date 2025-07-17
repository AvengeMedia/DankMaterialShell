//@ pragma UseQApplication

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
import qs.Services
import qs.Widgets
import qs.Widgets.CenterCommandCenter
import qs.Widgets.ControlCenter
import qs.Widgets.TopBar
import qs.Common
import "./Common/Utilities.js" as Utils

ShellRoot {
    id: root
    
    Component.onCompleted: {
        // Make root accessible to Theme singleton for error handling
        Theme.rootObj = root
        
        // Initialize service monitoring states based on preferences
        SystemMonitorService.enableTopBarMonitoring(Prefs.showSystemResources)
        ProcessMonitorService.enableMonitoring(false) // Start disabled, enable when process dropdown is opened
        // Audio service auto-updates devices, no manual scanning needed
    }
    
    property bool calendarVisible: false
    property bool showTrayMenu: false
    property real trayMenuX: 0
    property real trayMenuY: 0
    property var currentTrayMenu: null
    property var currentTrayItem: null
    property string osLogo: OSDetectorService.osLogo
    property string osName: OSDetectorService.osName
    property bool notificationHistoryVisible: false
    property bool mediaPlayerVisible: false
    property MprisPlayer activePlayer: MprisController.activePlayer
    property bool hasActiveMedia: activePlayer && (activePlayer.trackTitle || activePlayer.trackArtist)
    property bool controlCenterVisible: false
    
    // Monitor control center visibility to enable/disable bluetooth scanning
    onControlCenterVisibleChanged: {
        console.log("Control center", controlCenterVisible ? "opened" : "closed")
        BluetoothService.enableMonitoring(controlCenterVisible)
        if (controlCenterVisible) {
            // Refresh devices when opening control center
            AudioService.updateDevices()
        }
    }
    property bool batteryPopupVisible: false
    property bool powerMenuVisible: false
    property bool powerConfirmVisible: false
    property string powerConfirmAction: ""
    property string powerConfirmTitle: ""
    property string powerConfirmMessage: ""
    property bool settingsVisible: false
    
    // Network properties from NetworkService
    property string networkStatus: NetworkService.networkStatus
    property string ethernetIP: NetworkService.ethernetIP
    property string ethernetInterface: NetworkService.ethernetInterface
    property bool ethernetConnected: NetworkService.ethernetConnected
    property string wifiIP: NetworkService.wifiIP
    property bool bluetoothEnabled: BluetoothService.bluetoothEnabled
    property bool bluetoothAvailable: BluetoothService.bluetoothAvailable
    property bool wifiEnabled: NetworkService.wifiEnabled
    property bool wifiAvailable: NetworkService.wifiAvailable
    property bool wifiToggling: NetworkService.wifiToggling
    property bool changingNetworkPreference: NetworkService.changingPreference
    
    // WiFi properties from WifiService
    property string wifiSignalStrength: WifiService.wifiSignalStrength
    property string currentWifiSSID: WifiService.currentWifiSSID
    property var wifiNetworks: WifiService.wifiNetworks
    property var savedWifiNetworks: WifiService.savedWifiNetworks
    property bool wifiScanning: WifiService.isScanning
    
    // Audio properties from AudioService
    property int volumeLevel: AudioService.volumeLevel
    property bool volumeMuted: AudioService.sinkMuted
    property var audioSinks: AudioService.audioSinks
    property string currentAudioSink: AudioService.currentAudioSink
    
    // Microphone properties from AudioService
    property int micLevel: AudioService.micLevel
    property var audioSources: AudioService.audioSources
    property string currentAudioSource: AudioService.currentAudioSource
    
    // Bluetooth properties from BluetoothService
    property var bluetoothDevices: BluetoothService.bluetoothDevices
    
    // Brightness properties from BrightnessService
    property int brightnessLevel: BrightnessService.brightnessLevel
    
    // Calendar properties from CalendarService
    property bool calendarAvailable: CalendarService.khalAvailable
    property var calendarEvents: CalendarService.eventsByDate
    
    // WiFi password dialog
    property bool wifiPasswordDialogVisible: false
    property string wifiPasswordSSID: ""
    property string wifiPasswordInput: ""
    property string wifiConnectionStatus: WifiService.connectionStatus
    property bool wifiAutoRefreshEnabled: false
    
    // Wallpaper error status
    property string wallpaperErrorStatus: ""
    
    
    // Screen size breakpoints for responsive design
    property real screenWidth: Screen.width
    property bool isSmallScreen: screenWidth < 1200
    property bool isMediumScreen: screenWidth >= 1200 && screenWidth < 1600
    property bool isLargeScreen: screenWidth >= 1600
    
    // Weather data from WeatherService
    property var weather: WeatherService.weather
    
    // Weather configuration
    
    
    Timer {
        id: wifiAutoRefreshTimer
        interval: 20000
        running: root.wifiAutoRefreshEnabled && root.controlCenterVisible
        repeat: true
        onTriggered: {
            if (root.wifiAutoRefreshEnabled && root.controlCenterVisible && NetworkService.wifiEnabled) {
                WifiService.scanWifi()
            }
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
    
    // Wallpaper Error Status Timer
    Timer {
        id: wallpaperErrorTimer
        interval: 5000  // 5 seconds
        running: false
        repeat: false
        onTriggered: {
            root.wallpaperErrorStatus = ""
        }
    }
    
    // Function to show wallpaper error
    function showWallpaperError() {
        console.log("showWallpaperError called - setting error status")
        root.wallpaperErrorStatus = "error"
        wallpaperErrorTimer.restart()
    }
    
    
    // Multi-monitor support using Variants
    Variants {
        model: Quickshell.screens
        delegate: TopBar {
            modelData: item
            
            // Connect shell properties
            hasActiveMedia: root.hasActiveMedia
            activePlayer: root.activePlayer
            weatherAvailable: root.weather.available
            weatherCode: root.weather.wCode
            weatherTemp: root.weather.temp
            weatherTempF: root.weather.tempF
            osLogo: root.osLogo
            networkStatus: root.networkStatus
            wifiSignalStrength: root.wifiSignalStrength
            volumeLevel: root.volumeLevel
            volumeMuted: root.volumeMuted
            bluetoothAvailable: root.bluetoothAvailable
            bluetoothEnabled: root.bluetoothEnabled
            shellRoot: root
            notificationCount: NotificationService.notifications.length
            processDropdown: processListDropdown
            
            // Connect tray menu properties
            showTrayMenu: root.showTrayMenu
            currentTrayMenu: root.currentTrayMenu
            currentTrayItem: root.currentTrayItem
            trayMenuX: root.trayMenuX
            trayMenuY: root.trayMenuY
            
            // Connect clipboard
            onClipboardRequested: {
                clipboardHistoryPopup.toggle()
            }
        }
    }
    
    // Global popup windows
    CenterCommandCenter {}
    TrayMenuPopup {}
    NotificationPopup {}
    NotificationCenter {
        notificationHistoryVisible: root.notificationHistoryVisible
        onCloseRequested: {
            root.notificationHistoryVisible = false
        }
    }
    ControlCenterPopup {}
    WifiPasswordDialog {}
    InputDialog {
        id: globalInputDialog
    }
    BatteryControlPopup {}
    PowerMenuPopup {}
    PowerConfirmDialog {}
    
    ProcessListDropdown {
        id: processListDropdown
    }
    
    SettingsPopup {
        id: settingsPopup
        settingsVisible: root.settingsVisible
        
        // Use a more direct approach for two-way binding
        onSettingsVisibleChanged: {
            if (settingsVisible !== root.settingsVisible) {
                root.settingsVisible = settingsVisible
            }
        }
        
        // Also listen to root changes
        Connections {
            target: root
            function onSettingsVisibleChanged() {
                if (settingsPopup.settingsVisible !== root.settingsVisible) {
                    settingsPopup.settingsVisible = root.settingsVisible
                }
            }
        }
    }
    
    // Application and clipboard components
    AppLauncher {
        id: appLauncher
    }
    
    SpotlightLauncher {
        id: spotlightLauncher
    }
    
    ProcessListWidget {
        id: processListWidget
    }
    
    ClipboardHistory {
        id: clipboardHistoryPopup
    }
    
    IpcHandler {
        target: "wallpaper"
        
        function refresh() {
            console.log("Wallpaper IPC: refresh() called")
            // Trigger color extraction if using dynamic theme
            if (typeof Theme !== "undefined" && Theme.isDynamicTheme) {
                console.log("Triggering color extraction due to wallpaper IPC")
                Colors.extractColors()
            }
            return "WALLPAPER_REFRESH_SUCCESS"
        }
    }
}