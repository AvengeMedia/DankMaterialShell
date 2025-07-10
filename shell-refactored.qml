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

ShellRoot {
    id: root
    
    property bool calendarVisible: false
    property bool showTrayMenu: false
    property real trayMenuX: 0
    property real trayMenuY: 0
    property var currentTrayMenu: null
    property var currentTrayItem: null
    property bool notificationHistoryVisible: false
    property var activeNotification: null
    property bool showNotificationPopup: false
    property bool mediaPlayerVisible: false
    property MprisPlayer activePlayer: MprisController.activePlayer
    property bool hasActiveMedia: MprisController.isPlaying && (activePlayer?.trackTitle || activePlayer?.trackArtist)
    
    property bool useFahrenheit: true
    property var weather: WeatherService.weather
    property string osLogo: OSDetectionService.osLogo
    property string osName: OSDetectionService.osName
    
    property var notificationHistory: notificationHistoryModel
    property var appLauncher: appLauncherPopup
    property var clipboardHistoryPopup: clipboardHistoryPopupInstance
    property var colorPickerProcess: colorPickerProcessInstance
    
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

    TopBar {
        id: topBar
        theme: root.theme
        root: root
    }
    
    AppLauncher {
        id: appLauncherPopup
        theme: root.theme
    }
    
    ClipboardHistory {
        id: clipboardHistoryPopupInstance
        theme: root.theme
    }
    
    MediaPlayer {
        id: mediaPlayer
        theme: root.theme
        isVisible: root.mediaPlayerVisible
    }
    
    Process {
        id: colorPickerProcessInstance
        command: ["hyprpicker", "-a"]
        running: false
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Color picker failed. Make sure hyprpicker is installed: yay -S hyprpicker")
            }
        }
    }
    
    NotificationServer {
        id: notificationServer
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true
        
        onNotification: (notification) => {
            if (!notification || !notification.id) return
            
            if (!notification.appName && !notification.summary && !notification.body) {
                return
            }
            
            console.log("New notification from:", notification.appName || "Unknown", "Summary:", notification.summary || "No summary")
            
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
            
            notificationHistoryModel.insert(0, notifObj)
            
            while (notificationHistoryModel.count > 50) {
                notificationHistoryModel.remove(notificationHistoryModel.count - 1)
            }
            
            root.activeNotification = notifObj
            root.showNotificationPopup = true
            notificationTimer.restart()
        }
    }
    
    ListModel {
        id: notificationHistoryModel
    }
    
    Timer {
        id: notificationTimer
        interval: 5000
        repeat: false
        onTriggered: hideNotificationPopup()
    }
    
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