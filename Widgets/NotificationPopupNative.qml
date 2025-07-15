import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../Common"
import "../Services"

PanelWindow {
    id: notificationPopup
    
    visible: NotificationService.popups.length > 0
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    
    color: "transparent"
    
    anchors {
        top: true
        right: true
    }
    
    margins {
        top: Theme.barHeight
        right: 16
    }
    
    implicitWidth: 400
    implicitHeight: notificationList.height + 32
    
    Column {
        id: notificationList
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 16
        anchors.rightMargin: 16
        spacing: Theme.spacingM
        width: 380
        
        Repeater {
            model: NotificationService.popups
            
            delegate: NotificationItem {
                required property var modelData
                notificationWrapper: modelData
                
                // Entry animation
                transform: [
                    Translate {
                        id: slideTransform
                        x: notificationPopup.visible ? 0 : 400
                        
                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.emphasizedEasing
                            }
                        }
                    },
                    Scale {
                        id: scaleTransform
                        origin.x: parent.width
                        origin.y: 0
                        xScale: notificationPopup.visible ? 1.0 : 0.95
                        yScale: notificationPopup.visible ? 1.0 : 0.8
                        
                        Behavior on xScale {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.emphasizedEasing
                            }
                        }
                        
                        Behavior on yScale {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.emphasizedEasing
                            }
                        }
                    }
                ]
                
                opacity: notificationPopup.visible ? 1.0 : 0.0
                
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }
        }
    }
    
    // Smooth height animation
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.emphasizedEasing
        }
    }
}