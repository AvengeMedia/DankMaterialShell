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
import "Widgets/CenterCommandCenter"
import "Widgets/ControlCenter"
import "Common"
import "Common/Utilities.js" as Utils

ShellRoot {
    id: root
    
    Component.onCompleted: {
        // Make root accessible to Theme singleton for error handling
        Theme.rootObj = root
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
    property var activeNotification: null
    property bool showNotificationPopup: false
    property bool mediaPlayerVisible: false
    property MprisPlayer activePlayer: MprisController.activePlayer
    property bool hasActiveMedia: activePlayer && (activePlayer.trackTitle || activePlayer.trackArtist)
    property bool controlCenterVisible: false
    property bool batteryPopupVisible: false
    property bool powerMenuVisible: false
    property bool powerConfirmVisible: false
    property string powerConfirmAction: ""
    property string powerConfirmTitle: ""
    property string powerConfirmMessage: ""
    
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
    
    // Microphone properties from AudioService
    property int micLevel: AudioService.micLevel
    property var audioSources: AudioService.audioSources
    property string currentAudioSource: AudioService.currentAudioSource
    
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
    
    // Wallpaper error status
    property string wallpaperErrorStatus: ""
    
    // Notification action handling - ALWAYS invoke action if exists
    function handleNotificationClick(notifObj) {
        console.log("Handling notification click for:", notifObj.appName)
        
        // ALWAYS try to invoke the action first (this is what real notifications do)
        if (notifObj.notification && notifObj.actions && notifObj.actions.length > 0) {
            // Look for "default" action first, then fallback to first action
            let defaultAction = notifObj.actions.find(action => action.identifier === "default") || notifObj.actions[0]
            if (defaultAction) {
                console.log("Invoking notification action:", defaultAction.text, "identifier:", defaultAction.identifier)
                attemptInvokeAction(notifObj.id, defaultAction.identifier)
                return
            }
        }
        
        // If no action exists, check for URLs in notification text
        let notificationText = (notifObj.summary || "") + " " + (notifObj.body || "")
        let urlRegex = /(https?:\/\/[^\s]+)/g
        let urls = notificationText.match(urlRegex)
        
        if (urls && urls.length > 0) {
            console.log("Opening URL from notification:", urls[0])
            Qt.openUrlExternally(urls[0])
            return
        }
        
        console.log("No action or URL found, notification will just dismiss")
    }
    
    // Helper function to invoke notification actions (based on EXAMPLE)
    function attemptInvokeAction(notifId, actionIdentifier) {
        console.log("Attempting to invoke action:", actionIdentifier, "for notification:", notifId)
        
        // Find the notification in the server's tracked notifications
        let trackedNotifications = notificationServer.trackedNotifications.values
        let serverNotification = trackedNotifications.find(notif => notif.id === notifId)
        
        if (serverNotification) {
            let action = serverNotification.actions.find(action => action.identifier === actionIdentifier)
            if (action) {
                console.log("Invoking action:", action.text)
                action.invoke()
            } else {
                console.warn("Action not found:", actionIdentifier)
            }
        } else {
            console.warn("Notification not found in server:", notifId, "Available IDs:", trackedNotifications.map(n => n.id))
            // Try to find by any available action
            if (trackedNotifications.length > 0) {
                let latestNotif = trackedNotifications[trackedNotifications.length - 1]
                let action = latestNotif.actions.find(action => action.identifier === actionIdentifier)
                if (action) {
                    console.log("Using latest notification for action")
                    action.invoke()
                }
            }
        }
    }
    
    // Screen size breakpoints for responsive design
    property real screenWidth: Screen.width
    property bool isSmallScreen: screenWidth < 1200
    property bool isMediumScreen: screenWidth >= 1200 && screenWidth < 1600
    property bool isLargeScreen: screenWidth >= 1600
    
    // Weather data from WeatherService
    property var weather: WeatherService.weather
    
    // Weather configuration
    property bool useFahrenheit: true  // Default to Fahrenheit
    
    
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
            
            // CRITICAL: Mark notification as tracked so it stays in server list for actions
            notification.tracked = true
            
            // Create notification object with correct properties (based on EXAMPLE)
            var notifObj = {
                "id": notification.id,
                "appName": notification.appName || "App",
                "summary": notification.summary || "",
                "body": notification.body || "",
                "timestamp": new Date(),
                "appIcon": notification.appIcon || notification.icon || "",
                "icon": notification.icon || "",
                "image": notification.image || "",
                "actions": notification.actions ? notification.actions.map(action => ({
                    "identifier": action.identifier,
                    "text": action.text
                })) : [],
                "urgency": notification.urgency ? notification.urgency.toString() : "normal",
                "notification": notification  // Keep reference for action handling
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
    CenterCommandCenter {}
    TrayMenuPopup {}
    NotificationPopup {}
    NotificationHistoryPopup {}
    ControlCenterPopup {}
    WifiPasswordDialog {}
    InputDialog {
        id: globalInputDialog
    }
    BatteryControlPopup {}
    PowerMenuPopup {}
    PowerConfirmDialog {}
    
    // Application and clipboard components
    AppLauncher {
        id: appLauncher
        theme: Theme
    }
    
    SpotlightLauncher {
        id: spotlightLauncher
    }
    
    ClipboardHistory {
        id: clipboardHistoryPopup
        theme: Theme
    }
}