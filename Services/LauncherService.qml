import QtQuick
import Quickshell
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    signal showAppLauncher()
    signal hideAppLauncher()
    signal toggleAppLauncher()
    
    signal showSpotlight()
    signal hideSpotlight()
    signal toggleSpotlight()
    
    signal showClipboardHistory()
    signal hideClipboardHistory()
    signal toggleClipboardHistory()
}