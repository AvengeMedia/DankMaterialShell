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
import "Widgets"
import "Common"
import "Common/Utilities.js" as Utils

ShellRoot {
    id: root
    
    property bool calendarVisible: false
    property bool showTrayMenu: false
    property real trayMenuX: 0
    property real trayMenuY: 0
    property var currentTrayMenu: null
    property var currentTrayItem: null
    property string osLogo: OSDetectorService.osLogo
    property string osName: OSDetectorService.osName
    property bool notificationHistoryVisible: false
    property var activeNotification: null
    property bool showNotificationPopup: false
    property bool mediaPlayerVisible: false
    property MprisPlayer activePlayer: MprisController.activePlayer
    property bool hasActiveMedia: activePlayer && (activePlayer.trackTitle || activePlayer.trackArtist)
    property bool controlCenterVisible: false
    
    // Network properties from NetworkService
    property string networkStatus: NetworkService.networkStatus
    property string ethernetIP: NetworkService.ethernetIP
    property string wifiIP: NetworkService.wifiIP
    property bool bluetoothEnabled: BluetoothService.bluetoothEnabled
    property bool bluetoothAvailable: BluetoothService.bluetoothAvailable
    property bool wifiEnabled: NetworkService.wifiEnabled
    property bool wifiAvailable: NetworkService.wifiAvailable
    
    // WiFi properties from WifiService
    property string wifiSignalStrength: WifiService.wifiSignalStrength
    property string currentWifiSSID: WifiService.currentWifiSSID
    property var wifiNetworks: WifiService.wifiNetworks
    property var savedWifiNetworks: WifiService.savedWifiNetworks
    
    // Audio properties from AudioService
    property int volumeLevel: AudioService.volumeLevel
    property var audioSinks: AudioService.audioSinks
    property string currentAudioSink: AudioService.currentAudioSink
    
    // Bluetooth properties from BluetoothService
    property var bluetoothDevices: BluetoothService.bluetoothDevices
    
    // Brightness properties from BrightnessService
    property int brightnessLevel: BrightnessService.brightnessLevel
    
    // WiFi password dialog
    property bool wifiPasswordDialogVisible: false
    property string wifiPasswordSSID: ""
    property string wifiPasswordInput: ""
    property string wifiConnectionStatus: ""
    property bool wifiAutoRefreshEnabled: false
    
    // Screen size breakpoints for responsive design
    property real screenWidth: Screen.width
    property bool isSmallScreen: screenWidth < 1200
    property bool isMediumScreen: screenWidth >= 1200 && screenWidth < 1600
    property bool isLargeScreen: screenWidth >= 1600
    
    // Weather data from WeatherService
    property var weather: WeatherService.weather
    
    // Weather configuration
    property bool useFahrenheit: true  // Default to Fahrenheit
    
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
        "335": "snowing_heavy",
        "338": "snowing_heavy",
        "350": "rainy",
        "353": "rainy",
        "356": "weather_hail",
        "359": "weather_hail",
        "362": "rainy",
        "365": "weather_hail",
        "368": "cloudy_snowing",
        "371": "snowing_heavy",
        "374": "weather_hail",
        "377": "weather_hail",
        "386": "thunderstorm",
        "389": "thunderstorm",
        "392": "snowing_heavy",
        "395": "snowing_heavy"
    })
    
    // WiFi Auto-refresh Timer
    Timer {
        id: wifiAutoRefreshTimer
        interval: 10000  // 10 seconds
        running: root.wifiAutoRefreshEnabled && root.controlCenterVisible
        repeat: true
        onTriggered: {
            WifiService.scanWifi()
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
            Utils.showNotificationPopup(notifObj)
        }
    }
    
    // Notification History Model
    ListModel {
        id: notificationHistory
    }
    
    // Notification popup timer
    Timer {
        id: notificationTimer
        interval: 5000
        repeat: false
        onTriggered: {
            Utils.hideNotificationPopup()
        }
    }
    
    Timer {
        id: clearNotificationTimer
        interval: 200
        repeat: false
        onTriggered: {
            root.activeNotification = null
        }
    }
    
    // Multi-monitor support using Variants
    Variants {
        model: Quickshell.screens
        delegate: TopBar {
            modelData: item
        }
    }
    
    // Global popup windows
    CalendarPopup {}
    TrayMenuPopup {}
    NotificationPopup {}
    NotificationHistoryPopup {}
    ControlCenterPopup {}
    WifiPasswordDialog {}
    
    // Application and clipboard components
    AppLauncher {
        id: appLauncher
        theme: Theme
    }
    
    ClipboardHistory {
        id: clipboardHistoryPopup
        theme: Theme
    }
}