//@ pragma UseQApplication

import Quickshell
import qs.Widgets
import qs.Widgets.CenterCommandCenter
import qs.Widgets.ControlCenter
import qs.Widgets.TopBar

ShellRoot {
    id: root
    
    // Multi-monitor support using Variants
    Variants {
        model: Quickshell.screens
        delegate: TopBar {
            modelData: item
        }
    }
    
    // Global popup windows
    CenterCommandCenter {
        id: centerCommandCenter
    }
    TrayMenuPopup {
        id: trayMenuPopup
    }
    NotificationInit {}
    NotificationCenter {
        id: notificationCenter
    }
    ControlCenterPopup {
        id: controlCenterPopup
    }
    WifiPasswordDialog {
        id: wifiPasswordDialog
    }
    InputDialog {
        id: globalInputDialog
    }
    BatteryControlPopup {
        id: batteryControlPopup
    }
    PowerMenuPopup {
        id: powerMenuPopup
    }
    PowerConfirmDialog {
        id: powerConfirmDialog
    }
    
    ProcessListDropdown {
        id: processListDropdown
    }
    
    SettingsPopup {
        id: settingsPopup
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
    
    ToastWidget {
        id: toastWidget
    }
    
}