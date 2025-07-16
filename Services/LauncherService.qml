pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

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