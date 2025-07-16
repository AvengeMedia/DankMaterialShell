import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

ApplicationWindow {
    id: demoWindow
    width: 800
    height: 600
    visible: true
    title: "Native Notification System Demo"
    
    color: Theme.background
    
    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingL
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Native Notification System Demo"
            font.pixelSize: Theme.fontSizeXLarge
            color: Theme.surfaceText
            font.weight: Font.Bold
        }
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "This demo uses Quickshell's native NotificationServer"
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.onSurfaceVariant
        }
        
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingL
            
            Button {
                text: "Show Popups"
                onClicked: notificationPopup.visible = true
            }
            
            Button {
                text: "Show History"
                onClicked: notificationHistory.notificationHistoryVisible = true
            }
            
            Button {
                text: "Clear All"
                onClicked: NotificationService.clearAllNotifications()
            }
        }
        
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingM
            
            Text {
                text: `Total Notifications: ${NotificationService.notifications.length}`
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }
            
            Text {
                text: `Active Popups: ${NotificationService.popups.length}`
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }
        }
        
        Text {
            width: 600
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Instructions:\n" +
                  "• Send notifications from other applications (Discord, etc.)\n" +
                  "• Use 'notify-send' command to test\n" +
                  "• Notifications will appear automatically in the popup\n" +
                  "• Images from Discord/Vesktop will show as avatars\n" +
                  "• App icons are automatically detected"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.onSurfaceVariant
            wrapMode: Text.WordWrap
        }
    }
    
    // Native notification popup
    NotificationInit {
        id: notificationPopup
    }
    
    // Native notification history
    NotificationCenter {
        id: notificationHistory
    }
}