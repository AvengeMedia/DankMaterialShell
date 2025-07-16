//NotificationCenter.qml
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.Common
import qs.Services

PanelWindow {
    id: notificationHistoryPopup
    
    property bool notificationHistoryVisible: false
    signal closeRequested()
    
    visible: notificationHistoryVisible
    
    implicitWidth: 400
    implicitHeight: 500
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    
    color: "transparent"
    
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    // Background to close popup when clicking outside
    MouseArea {
        anchors.fill: parent
        onClicked: {
            closeRequested()
        }
    }
    
    Rectangle {
        width: 400
        height: 500
        x: parent.width - width - Theme.spacingL
        y: Theme.barHeight + Theme.spacingXS
        color: Theme.popupBackground()
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 0.5
        
        // Animation
        transform: [
            Scale {
                id: scaleTransform
                origin.x: parent.width
                origin.y: 0
                xScale: notificationHistoryVisible ? 1.0 : 0.95
                yScale: notificationHistoryVisible ? 1.0 : 0.8
            },
            Translate {
                id: translateTransform
                x: notificationHistoryVisible ? 0 : 15
                y: notificationHistoryVisible ? 0 : -30
            }
        ]
        
        opacity: notificationHistoryVisible ? 1.0 : 0.0
        
        states: [
            State {
                name: "visible"
                when: notificationHistoryVisible
                PropertyChanges { target: scaleTransform; xScale: 1.0; yScale: 1.0 }
                PropertyChanges { target: translateTransform; x: 0; y: 0 }
            },
            State {
                name: "hidden"
                when: !notificationHistoryVisible
                PropertyChanges { target: scaleTransform; xScale: 0.95; yScale: 0.8 }
                PropertyChanges { target: translateTransform; x: 15; y: -30 }
            }
        ]
        
        transitions: [
            Transition {
                from: "*"; to: "*"
                ParallelAnimation {
                    NumberAnimation {
                        targets: [scaleTransform, translateTransform]
                        properties: "xScale,yScale,x,y"
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }
        ]
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
        
        // Prevent clicks from propagating to background
        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Stop propagation - do nothing
            }
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM
            
            // Header
            Row {
                width: parent.width
                height: 32
                
                Text {
                    text: "Notifications"
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Item { 
                    width: parent.width - 240 - Theme.spacingM
                    height: 1 
                }
                
                // Clear All Button
                Rectangle {
                    width: 120
                    height: 28
                    radius: Theme.cornerRadius
                    anchors.verticalCenter: parent.verticalCenter
                    visible: NotificationService.notifications.length > 0
                    
                    color: clearArea.containsMouse ? 
                           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                           Theme.surfaceContainer
                    
                    border.color: clearArea.containsMouse ? 
                                 Theme.primary : 
                                 Theme.outline
                    border.width: 1
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS
                        
                        Text {
                            text: "delete_sweep"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSizeSmall
                            color: clearArea.containsMouse ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: "Clear All"
                            font.pixelSize: Theme.fontSizeSmall
                            color: clearArea.containsMouse ? Theme.primary : Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: NotificationService.clearAllNotifications()
                    }
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                    
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }
            
            // Notification List
            ScrollView {
                width: parent.width
                height: parent.height - 120
                clip: true
                contentWidth: -1
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                
                ListView {
                    model: NotificationService.groupedNotifications
                    spacing: Theme.spacingL
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 1500
                    maximumFlickVelocity: 2000
                    
                    // Enhanced smooth animations to prevent layout jumping
                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                properties: "opacity"
                                from: 0
                                to: 1
                                duration: Theme.mediumDuration
                                easing.type: Theme.emphasizedEasing
                            }
                            NumberAnimation {
                                properties: "height"
                                from: 0
                                duration: Theme.mediumDuration
                                easing.type: Theme.emphasizedEasing
                            }
                        }
                    }
                    
                    remove: Transition {
                        SequentialAnimation {
                            // Pause to let internal content animations complete
                            PauseAnimation {
                                duration: 50
                            }
                            ParallelAnimation {
                                NumberAnimation {
                                    properties: "opacity"
                                    to: 0
                                    duration: Theme.mediumDuration
                                    easing.type: Theme.emphasizedEasing
                                }
                                NumberAnimation {
                                    properties: "height,anchors.topMargin,anchors.bottomMargin"
                                    to: 0
                                    duration: Theme.mediumDuration
                                    easing.type: Theme.emphasizedEasing
                                }
                            }
                        }
                    }
                    
                    displaced: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                    
                    // Add move transition for internal content changes
                    move: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                    
                    delegate: GroupedNotificationCard {
                        required property var modelData
                        group: modelData
                        width: ListView.view.width - Theme.spacingM
                        // expanded property is now readonly and managed by NotificationService
                    }
                }
                
                // Empty state
                Item {
                    width: parent.width
                    height: 200
                    anchors.centerIn: parent
                    visible: NotificationService.notifications.length === 0
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM
                        width: parent.width * 0.8
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "notifications_none"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSizeLarge + 16
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No notifications"
                            font.pixelSize: Theme.fontSizeLarge
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Notifications will appear here"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }
                }
            }
        }
    }
    
    // Click outside to close
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: notificationHistoryVisible = false
    }
}