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
    property bool notificationHistoryVisible: false
    property bool mediaPlayerVisible: false
    property bool hasActiveMedia: MprisController.active && (MprisController.active.trackTitle || MprisController.active.trackArtist)
    property bool controlCenterVisible: false
    
    property bool batteryPopupVisible: false
    property bool powerMenuVisible: false
    property bool powerConfirmVisible: false
    property string powerConfirmAction: ""
    property string powerConfirmTitle: ""
    property string powerConfirmMessage: ""
    property bool settingsVisible: false
    
    
    // WiFi password dialog
    property bool wifiPasswordDialogVisible: false
    property string wifiPasswordSSID: ""
    property string wifiPasswordInput: ""
    property bool wifiAutoRefreshEnabled: false
    
    // Wallpaper error status
    property string wallpaperErrorStatus: ""
    
    
    // Screen size breakpoints for responsive design
    property real screenWidth: Screen.width
    property bool isSmallScreen: screenWidth < 1200
    property bool isMediumScreen: screenWidth >= 1200 && screenWidth < 1600
    property bool isLargeScreen: screenWidth >= 1600
    
    
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
    NotificationInit {}
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