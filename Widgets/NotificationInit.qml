import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../Common"
import "../Services"

PanelWindow {
    id: notificationPopup
    objectName: "notificationPopup"  // For context detection
    
    visible: NotificationService.groupedPopups.length > 0
    
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
    implicitHeight: groupedNotificationsList.height + 32
    
    Column {
        id: groupedNotificationsList
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 16
        anchors.rightMargin: 16
        spacing: Theme.spacingM
        width: 380
        
        Repeater {
            model: NotificationService.groupedPopups
            
            delegate: GroupedNotificationCard {
                required property var modelData
                group: modelData
                width: parent.width
                
                // Popup-specific styling: Extra padding for single notifications  
                property bool isPopupContext: true
                property int extraTopMargin: group.count === 1 ? 6 : 0
                property int extraBottomMargin: group.count === 1 ? 6 : 0
                
                // Hover detection for preventing auto-dismiss
                property bool isHovered: false
                
                MouseArea {
                    id: hoverDetection
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton  // Don't intercept clicks
                    propagateComposedEvents: true
                    z: -1  // Behind other elements
                    
                    onEntered: {
                        parent.isHovered = true
                        console.log("Notification hovered - pausing auto-dismiss")
                    }
                    
                    onExited: {
                        parent.isHovered = false
                        console.log("Notification hover ended - resuming auto-dismiss")
                    }
                }
                
                // Enhanced auto-dismiss timer with hover pause
                Timer {
                    id: autoDismissTimer
                    running: group.count === 1 && group.latestNotification.popup && !group.latestNotification.notification.hasInlineReply && !parent.isHovered
                    interval: group.latestNotification.notification.expireTimeout > 0 ? 
                             group.latestNotification.notification.expireTimeout * 1000 : 7000  // Increased to 7 seconds
                    onTriggered: {
                        if (!parent.isHovered) {
                            group.latestNotification.popup = false
                        }
                    }
                    
                    // Restart timer when hover ends
                    onRunningChanged: {
                        if (running && !parent.isHovered) {
                            restart()
                        }
                    }
                }
                
                // Don't auto-dismiss conversation groups - let user interact
                property bool isConversationGroup: group.isConversation && group.count > 1
                
                // Stabilized entry animation for popup context
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
                
                // Enhanced height transitions for popup stability
                Behavior on height {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 10  // Shorter pause for popup responsiveness
                        }
                        NumberAnimation {
                            duration: Theme.shortDuration  // Faster transitions in popup
                            easing.type: Theme.standardEasing
                        }
                    }
                }
                
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
                
                // Popup-specific stability improvements
                clip: true  // Prevent content overflow during animations
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